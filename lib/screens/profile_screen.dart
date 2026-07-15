import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../database/app_database.dart';
import '../demo/demo_mode.dart';
import '../services/auth_service.dart';
import '../services/photo_file_helper.dart';
import '../services/secure_credentials.dart';
import '../utils/app_tokens.dart';
import '../widgets/sync_indicator.dart';
import '../widgets/onboarding/tutorial_controller.dart';
import '../widgets/onboarding/guided_tutorial_overlay.dart';

enum _PhotoAction { gallery, camera, remove }

class _PreparedProfilePhoto {
  final img.Image image;
  final Uint8List previewBytes;

  const _PreparedProfilePhoto({
    required this.image,
    required this.previewBytes,
  });
}

class _ProfileCropResult {
  final double scale;
  final Offset offset;
  final double viewportSize;

  const _ProfileCropResult({
    required this.scale,
    required this.offset,
    required this.viewportSize,
  });
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.activeRepartoNameProvider,
    this.onOpenRepartoSelector,
  });

  /// Returns the currently-active reparto's name, or `null` if none is
  /// selected. Called on every build so the tile always reflects the
  /// latest selection (post-pick refresh).
  final String? Function()? activeRepartoNameProvider;

  /// Opens the bottom-sheet reparto selector. Awaited so the tile can
  /// refresh after the user picks (or cancels).
  final Future<void> Function()? onOpenRepartoSelector;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  AppTokens get tokens => AppTokens.of(context);

  final _db = AppDatabase.instance;
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _mpTokenCtrl = TextEditingController();
  final _cuitCtrl = TextEditingController();
  final _razonSocialCtrl = TextEditingController();
  final _domicilioCtrl = TextEditingController();
  final _ptoVtaCtrl = TextEditingController();
  bool _loading = true;
  bool _mpTokenObscured = true;
  Timer? _debounce;
  // Guard 1: only true after _loadProfile() finishes successfully (or
  // confirmed there's no existing cuentas row). _autoSave() refuses to run
  // unless this is true — prevents the blank-overwrite bug where a slow
  // cloud SELECT + early dispose/pause wrote {nombre:'', email:'',
  // telefono:''} over real data.
  bool _profileLoaded = false;
  // Guard 2: starts true so the controller.text = '' assignments in initState
  // and the controller.text = data['...'] assignments inside _loadProfile()
  // don't trigger debounced auto-saves while we're still hydrating.
  bool _suppressAutoSave = true;
  bool _settingsLoaded = false;
  String _loadedMpToken = '';
  String _loadedAfipCuit = '';
  String _loadedAfipRazonSocial = '';
  String _loadedAfipDomicilio = '';
  int _loadedAfipPtoVta = 0;
  String _loadedAfipCondicionIva = 'Monotributista';
  bool _loadedAfipProduction = false;

  // AFIP config
  String _afipCondicionIva = 'Monotributista';
  bool _afipProduction = false;

  // Profile photo: local cached path + last-known cloud URL. Local file is
  // the source of truth for display; cloud URL is what syncs across devices
  // via `cuentas.foto_url`.
  String _fotoPath = '';
  String _fotoUrl = '';
  bool _fotoFileExists = false;
  bool _uploadingFoto = false;

  final GlobalKey _kPhoto = GlobalKey();
  final GlobalKey _kReparto = GlobalKey();
  final GlobalKey _kPersonal = GlobalKey();
  final GlobalKey _kMP = GlobalKey();
  final GlobalKey _kFacturacion = GlobalKey();
  final GlobalKey _kBack = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProfile();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => TutorialController.instance.onProfileOpened(),
    );
    // Auto-save on any text field change
    for (final ctrl in [
      _nombreCtrl,
      _emailCtrl,
      _telefonoCtrl,
      _mpTokenCtrl,
      _cuitCtrl,
      _razonSocialCtrl,
      _domicilioCtrl,
      _ptoVtaCtrl,
    ]) {
      ctrl.addListener(_onFieldChanged);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    // Guard 3: only auto-save on dispose if the profile actually loaded.
    // Otherwise we'd upsert empty controllers over real cloud data.
    if (_profileLoaded) _autoSave();
    for (final ctrl in [
      _nombreCtrl,
      _emailCtrl,
      _telefonoCtrl,
      _mpTokenCtrl,
      _cuitCtrl,
      _razonSocialCtrl,
      _domicilioCtrl,
      _ptoVtaCtrl,
    ]) {
      ctrl.removeListener(_onFieldChanged);
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Guard 3: don't fire auto-save on pause/detach/hidden if profile
    // hasn't loaded yet. Backgrounding mid-load was the failure mode that
    // blanked profile data in production.
    if (!_profileLoaded) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _debounce?.cancel();
      _autoSave();
    }
  }

  void _onFieldChanged() {
    // Guard 2: suppress listener events while _loadProfile() is hydrating
    // controllers. Without this, the controller.text = '...' assignments
    // inside _loadProfile() schedule debounced auto-saves with the
    // freshly-loaded values — usually harmless, but in race conditions
    // can fire before _profileLoaded flips true.
    if (_suppressAutoSave) return;
    if (kDemoMode) {
      _debounce?.cancel();
      showDemoUpgradeSnack(context);
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: 800), _autoSave);
  }

  Future<void> _loadProfile() async {
    final userId = AuthService.currentUserId;
    final userEmail = AuthService.currentUserEmail ?? '';
    if (userId == null) return;

    bool cuentasLoaded = false;
    try {
      // P0.6: profile reads from local Drift (cuentas_local), NEVER directly
      // from cloud. AuthService._ensureProfile seeds local from cloud at
      // sign-in. Reading from local means: no network dependency, no slow
      // SELECT race window, and the autoSave can never blank cloud over a
      // failed local read.
      final data = await _db.getCuentaLocal(userId);
      if (data != null && mounted) {
        final fotoPath = (data['foto_path'] as String?) ?? '';
        final fotoExists = fotoPath.isNotEmpty && await photoExists(fotoPath);
        if (!mounted) return;
        _nombreCtrl.text = (data['nombre'] as String?) ?? '';
        final localEmail = (data['email'] as String?) ?? '';
        _emailCtrl.text = localEmail.isNotEmpty ? localEmail : userEmail;
        _telefonoCtrl.text = (data['telefono'] as String?) ?? '';
        _fotoPath = fotoPath;
        _fotoFileExists = fotoExists;
        _fotoUrl = (data['foto_url'] as String?) ?? '';
        cuentasLoaded = true;
      } else if (mounted) {
        // No local row yet — first time on this device. Seed from
        // Auth email; user can fill nombre/telefono and the
        // first save creates the row.
        _emailCtrl.text = userEmail;
        _fotoFileExists = false;
        cuentasLoaded = true;
      }
    } catch (e) {
      debugPrint('[ProfileScreen] _loadProfile failed: $e');
      // Local SELECT failed (DB locked, etc.) — keep autoSave disabled so
      // a controller-blank state can't corrupt anything.
      if (mounted) _emailCtrl.text = userEmail;
    }

    // Load MP + AFIP settings (AFIP: local Drift; MP token: Keystore —
    // P0-4b moved it out of the plaintext DB).
    try {
      final settings = await _db.getSettings();
      final mpToken = kDemoMode
          ? ''
          : await SecureCredentials.instance.readMpToken();
      if (mounted) {
        _mpTokenCtrl.text = mpToken;
        _cuitCtrl.text = settings.afipCuit;
        _razonSocialCtrl.text = settings.afipRazonSocial;
        _domicilioCtrl.text = settings.afipDomicilio;
        _ptoVtaCtrl.text = settings.afipPtoVta > 0
            ? settings.afipPtoVta.toString()
            : '';
        _afipCondicionIva = settings.afipCondicionIva;
        _afipProduction = settings.afipProduction;
        _snapshotSecureSettings(settings, mpToken: mpToken);
        _settingsLoaded = true;
      }
    } catch (e) {
      debugPrint('[ProfileScreen] getSettings failed: $e');
    }

    if (mounted) {
      setState(() => _loading = false);
      // Flip the guards LAST. Order matters: _profileLoaded gates
      // _autoSave; _suppressAutoSave gates _onFieldChanged. If
      // cuentasLoaded is false (cloud SELECT errored), neither flips —
      // the screen renders, but auto-save stays disabled until the user
      // closes and re-opens Profile.
      if (cuentasLoaded) {
        _profileLoaded = true;
      }
      _suppressAutoSave = false;
    }
  }

  Future<void> _autoSave() async {
    if (kDemoMode) return;
    final user = AuthService.currentUser;
    if (user == null) return;
    // Guard 3 (belt-and-suspenders): refuse to save if profile never loaded.
    // dispose() and lifecycle pause already check this, but a debounced
    // fire that survived the load failure could still reach here.
    if (!_profileLoaded) return;

    final newNombre = _nombreCtrl.text.trim();
    final newEmail = _emailCtrl.text.trim();
    final newTelefono = _telefonoCtrl.text.trim();

    try {
      // P0.6: write to LOCAL Drift, not directly to cloud. SyncService picks
      // up dirty cuentas_local rows and pushes them. The blank-rejection
      // guard from yesterday's Phase 4 now defends the local write — same
      // logic, but reading from local Drift instead of slow cloud SELECT.
      final current = await _db.getCuentaLocal(user.id);
      final localNombre = (current?['nombre'] as String? ?? '');
      final localEmail = (current?['email'] as String? ?? '');
      final localTelefono = (current?['telefono'] as String? ?? '');

      // Decide what to write per field. Allow explicit clearing (user had
      // a value, then typed nothing); refuse accidental blanks (controller
      // never populated despite _profileLoaded=true — shouldn't happen,
      // but belt-and-suspenders).
      final writeNombre = (newNombre.isNotEmpty || localNombre.isEmpty)
          ? newNombre
          : localNombre;
      final writeEmail = (newEmail.isNotEmpty || localEmail.isEmpty)
          ? newEmail
          : localEmail;
      final writeTelefono = (newTelefono.isNotEmpty || localTelefono.isEmpty)
          ? newTelefono
          : localTelefono;

      // Skip the local write if nothing changed (avoids dirty-flag churn).
      final changed =
          writeNombre != localNombre ||
          writeEmail != localEmail ||
          writeTelefono != localTelefono;
      if (changed) {
        await _db.setCuentaLocal(
          userId: user.id,
          email: writeEmail,
          nombre: writeNombre,
          telefono: writeTelefono,
        );
        // SyncService reads dirty cuentas_local rows and pushes to cloud
        // on its normal cycle.
      }

      await _saveSecureSettingsIfChanged();
    } catch (e) {
      debugPrint('[ProfileScreen] _autoSave failed: $e');
    }
  }

  void _snapshotSecureSettings(
    UserSetting settings, {
    required String mpToken,
  }) {
    // P0-4b: the MP token comes from the Keystore, never the DB column.
    _loadedMpToken = mpToken;
    _loadedAfipCuit = settings.afipCuit;
    _loadedAfipRazonSocial = settings.afipRazonSocial;
    _loadedAfipDomicilio = settings.afipDomicilio;
    _loadedAfipPtoVta = settings.afipPtoVta;
    _loadedAfipCondicionIva = settings.afipCondicionIva;
    _loadedAfipProduction = settings.afipProduction;
  }

  Future<void> _saveSecureSettingsIfChanged() async {
    if (kDemoMode) return;
    // MP/AFIP values are long, high-friction credentials. Only write them
    // after the settings row has hydrated; otherwise a blank controller state
    // can mark secure settings dirty and push empty values to every device.
    if (!_settingsLoaded) return;

    final nextMpToken = _mpTokenCtrl.text.trim();
    final nextCuit = _cuitCtrl.text.trim();
    final nextRazonSocial = _razonSocialCtrl.text.trim();
    final nextDomicilio = _domicilioCtrl.text.trim();
    final nextPtoVta = int.tryParse(_ptoVtaCtrl.text.trim()) ?? 0;
    final nextCondicionIva = _afipCondicionIva;
    final nextProduction = _afipProduction;

    if (nextMpToken != _loadedMpToken) {
      // P0-4b: keystore write + MP dirty counters (column stays blank).
      await SecureCredentials.instance.setMpToken(nextMpToken);
      _loadedMpToken = nextMpToken;
    }

    final afipChanged =
        nextCuit != _loadedAfipCuit ||
        nextRazonSocial != _loadedAfipRazonSocial ||
        nextDomicilio != _loadedAfipDomicilio ||
        nextPtoVta != _loadedAfipPtoVta ||
        nextCondicionIva != _loadedAfipCondicionIva ||
        nextProduction != _loadedAfipProduction;
    if (!afipChanged) return;

    await _db.updateAfipSettings(
      cuit: nextCuit,
      razonSocial: nextRazonSocial,
      domicilio: nextDomicilio,
      ptoVta: nextPtoVta,
      condicionIva: nextCondicionIva,
      production: nextProduction,
    );
    _loadedAfipCuit = nextCuit;
    _loadedAfipRazonSocial = nextRazonSocial;
    _loadedAfipDomicilio = nextDomicilio;
    _loadedAfipPtoVta = nextPtoVta;
    _loadedAfipCondicionIva = nextCondicionIva;
    _loadedAfipProduction = nextProduction;
  }

  Future<_PhotoAction?> _askPhotoSource() async {
    return showModalBottomSheet<_PhotoAction>(
      context: context,
      backgroundColor: tokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.photo_library, color: tokens.text),
              title: Text(
                'Elegir de la galería',
                style: TextStyle(color: tokens.text),
              ),
              onTap: () => Navigator.pop(ctx, _PhotoAction.gallery),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: tokens.text),
              title: Text(
                'Sacar una foto',
                style: TextStyle(color: tokens.text),
              ),
              onTap: () => Navigator.pop(ctx, _PhotoAction.camera),
            ),
            if (_fotoPath.isNotEmpty || _fotoUrl.isNotEmpty)
              ListTile(
                leading: Icon(Icons.delete_outline, color: tokens.danger),
                title: Text(
                  'Quitar foto',
                  style: TextStyle(color: tokens.danger),
                ),
                onTap: () => Navigator.pop(ctx, _PhotoAction.remove),
                trailing: Icon(Icons.close, color: Colors.transparent),
              ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<_PreparedProfilePhoto?> _prepareProfilePhoto(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final oriented = img.bakeOrientation(decoded);
    return _PreparedProfilePhoto(
      image: oriented,
      previewBytes: Uint8List.fromList(img.encodeJpg(oriented, quality: 92)),
    );
  }

  Future<Uint8List?> _cropProfilePhotoBytes(Uint8List pickedBytes) async {
    final prepared = await _prepareProfilePhoto(pickedBytes);
    if (prepared == null || !mounted) {
      _showSnack('No se pudo leer la foto');
      return null;
    }

    final crop = await showDialog<_ProfileCropResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProfilePhotoCropDialog(
        imageBytes: prepared.previewBytes,
        imageWidth: prepared.image.width,
        imageHeight: prepared.image.height,
      ),
    );
    if (crop == null) return null;

    final image = prepared.image;
    final baseScale = math.max(
      crop.viewportSize / image.width,
      crop.viewportSize / image.height,
    );
    final effectiveScale = baseScale * crop.scale;
    final renderedWidth = image.width * effectiveScale;
    final renderedHeight = image.height * effectiveScale;
    final imageLeft = (crop.viewportSize - renderedWidth) / 2 + crop.offset.dx;
    final imageTop = (crop.viewportSize - renderedHeight) / 2 + crop.offset.dy;
    final sourceLeft = ((-imageLeft) / effectiveScale).clamp(
      0.0,
      image.width.toDouble(),
    );
    final sourceTop = ((-imageTop) / effectiveScale).clamp(
      0.0,
      image.height.toDouble(),
    );
    final sourceSize = (crop.viewportSize / effectiveScale)
        .clamp(1.0, math.min(image.width, image.height).toDouble())
        .toDouble();
    final x = sourceLeft.round().clamp(0, image.width - 1).toInt();
    final y = sourceTop.round().clamp(0, image.height - 1).toInt();
    final maxWidth = image.width - x;
    final maxHeight = image.height - y;
    final size = sourceSize
        .round()
        .clamp(1, math.min(maxWidth, maxHeight))
        .toInt();

    final cropped = img.copyCrop(image, x: x, y: y, width: size, height: size);
    final resized = img.copyResize(
      cropped,
      width: 512,
      height: 512,
      interpolation: img.Interpolation.cubic,
    );
    return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
  }

  Future<void> _pickProfilePhoto() async {
    if (blockDemoAction(context)) return;
    if (_uploadingFoto) return;
    final user = AuthService.currentUser;
    if (user == null) return;

    final action = await _askPhotoSource();
    if (!mounted) return;
    if (action == null) return;

    if (action == _PhotoAction.remove) {
      if (_fotoPath.isEmpty && _fotoUrl.isEmpty) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: tokens.card,
          title: Text(
            'Quitar foto de perfil',
            style: TextStyle(color: tokens.text),
          ),
          content: Text(
            '¿Seguro que querés quitar tu foto?',
            style: TextStyle(color: tokens.textSub),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar', style: TextStyle(color: tokens.textSub)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Quitar', style: TextStyle(color: tokens.danger)),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      await _clearProfilePhoto(user.id);
      return;
    }

    final source = action == _PhotoAction.camera
        ? ImageSource.camera
        : ImageSource.gallery;
    final picker = ImagePicker();
    XFile? picked;
    try {
      picked = await picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 80,
      );
    } catch (e) {
      _showSnack(
        'No se pudo abrir la ${source == ImageSource.camera ? 'cámara' : 'galería'}',
      );
      return;
    }
    if (picked == null || !mounted) return;

    final pickedBytes = await picked.readAsBytes();
    final bytes = await _cropProfilePhotoBytes(pickedBytes);
    if (bytes == null || !mounted) return;

    setState(() => _uploadingFoto = true);

    try {
      final fileName =
          'profile_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final newPath = await savePhotoBytes(bytes, fileName);
      if (newPath == null) {
        // Web has no local filesystem (demo build); profile photo edits are
        // demo-gated there anyway, so there is nothing to persist locally.
        if (mounted) _showSnack('No se pudo guardar la foto');
        return;
      }

      // Clean up the previous file so we don't leak disk space.
      if (_fotoPath.isNotEmpty && _fotoPath != newPath) {
        await deletePhoto(_fotoPath);
      }

      await _db.setCuentaFotoPath(
        userId: user.id,
        fotoPath: newPath,
        pendingUpload: true,
      );

      if (mounted) {
        setState(() {
          _fotoPath = newPath;
          _fotoFileExists = true;
        });
      }
    } catch (e) {
      debugPrint('[ProfileScreen] photo pick failed: $e');
      _showSnack('No se pudo guardar la foto');
    } finally {
      if (mounted) setState(() => _uploadingFoto = false);
    }
  }

  Future<void> _clearProfilePhoto(String userId) async {
    setState(() => _uploadingFoto = true);
    try {
      if (_fotoPath.isNotEmpty) {
        await deletePhoto(_fotoPath);
      }
      await _db.setCuentaFotoPath(userId: userId, fotoPath: '');
      await _db.setCuentaFotoUrl(userId: userId, fotoUrl: '');
      if (mounted) {
        setState(() {
          _fotoPath = '';
          _fotoUrl = '';
          _fotoFileExists = false;
        });
      }
    } finally {
      if (mounted) setState(() => _uploadingFoto = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _buildAvatar() {
    ImageProvider? image;
    if (_fotoPath.isNotEmpty && _fotoFileExists) {
      image = photoImage(_fotoPath);
    }
    return GestureDetector(
      key: _kPhoto,
      onTap: _pickProfilePhoto,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: tokens.actionRowCargaTint,
            backgroundImage: image,
            child: image == null
                ? Icon(Icons.person, color: tokens.primaryBlue, size: 52)
                : null,
          ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: tokens.primaryBlue,
                shape: BoxShape.circle,
                border: Border.all(color: tokens.card, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: tokens.primaryBlue.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: _uploadingFoto
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      Icons.camera_alt_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wrapGuided(Widget child) => Stack(
    children: [
      child,
      GuidedTutorialOverlay(
        screen: GuidedScreen.profile,
        views: _guidedViews(),
      ),
    ],
  );

  Map<GuidedStep, GuidedStepView> _guidedViews() => {
    GuidedStep.profilePhoto: GuidedStepView(
      targetKey: _kPhoto,
      title: 'Tu foto',
      body: kDemoMode
          ? 'En el demo ves un perfil de ejemplo. En la app completa podés cargar tu foto.'
          : 'Si querés, tocá para agregar una foto de perfil.',
    ),
    GuidedStep.profileReparto: GuidedStepView(
      targetKey: _kReparto,
      title: 'Tu reparto',
      body: 'Acá va el reparto con el que trabajás. En un momento lo creás.',
    ),
    GuidedStep.profilePersonal: GuidedStepView(
      targetKey: _kPersonal,
      title: 'Tus datos',
      body: kDemoMode
          ? 'Estos datos son de ejemplo. En la app completa los completás una sola vez.'
          : 'Tu nombre, email y teléfono. Completá lo que quieras.',
    ),
    GuidedStep.profileMP: GuidedStepView(
      targetKey: _kMP,
      title: 'Mercado Pago',
      body: kDemoMode
          ? 'En la app completa podés conectar Mercado Pago para generar QR de cobro.'
          : 'Si cobrás con Mercado Pago, pegá tu token acá (opcional).',
    ),
    GuidedStep.profileFacturacion: GuidedStepView(
      targetKey: _kFacturacion,
      title: 'Facturación',
      body: kDemoMode
          ? 'En la app completa cargás tus datos de facturación si necesitás emitir comprobantes.'
          : 'Si hacés facturas, cargá tus datos de AFIP acá (opcional).',
    ),
    GuidedStep.createReparto: GuidedStepView(
      targetKey: _kReparto,
      title: 'Creá tu reparto',
      body: kDemoMode
          ? 'El demo ya trae un reparto de ejemplo. En la app completa podés crear tus propios repartos.'
          : 'Tocá acá y creá tu primer reparto. Te vamos a dejar un cliente de ejemplo para practicar la ruta.',
    ),
    GuidedStep.perfilBack: GuidedStepView(
      targetKey: _kBack,
      title: '¡Listo!',
      body: 'Tocá la flecha para volver al inicio.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    return _wrapGuided(
      Scaffold(
        backgroundColor: tokens.bg,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: AppBar(
            backgroundColor: tokens.card,
            surfaceTintColor: tokens.card,
            elevation: 0,
            scrolledUnderElevation: 0,
            systemOverlayStyle: tokens.isDark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            leading: IconButton(
              key: _kBack,
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: tokens.text,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'PERFIL',
              style: TextStyle(
                color: tokens.text,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            centerTitle: false,
            shape: Border(
              bottom: BorderSide(color: tokens.cardBorder, width: 1),
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              SyncIndicator(),
              Expanded(
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: tokens.primaryBlue,
                        ),
                      )
                    : GestureDetector(
                        onTap: () => FocusScope.of(context).unfocus(),
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(16, 18, 16, 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeroProfileCard(),
                              SizedBox(height: 22),
                              _sectionLabel('INFORMACIÓN PERSONAL'),
                              SizedBox(height: 8),
                              KeyedSubtree(
                                key: _kPersonal,
                                child: _buildInfoCard(),
                              ),
                              SizedBox(height: 22),
                              _sectionLabel('MERCADO PAGO'),
                              SizedBox(height: 8),
                              KeyedSubtree(
                                key: _kMP,
                                child: _buildMercadoPagoCard(),
                              ),
                              SizedBox(height: 22),
                              _sectionLabel('FACTURACIÓN ELECTRÓNICA'),
                              SizedBox(height: 8),
                              KeyedSubtree(
                                key: _kFacturacion,
                                child: _buildFacturacionCard(),
                              ),
                              SizedBox(height: 28),
                              _buildSignOutTile(),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── New aesthetic helpers ──────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
    padding: EdgeInsets.only(left: 4),
    child: Text(
      text,
      style: TextStyle(
        color: tokens.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    ),
  );

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: tokens.card,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 1)),
    ],
  );

  Widget _cardDivider() => Padding(
    padding: EdgeInsets.symmetric(horizontal: 14),
    child: Container(height: 1, color: tokens.cardBorder),
  );

  Widget _buildHeroProfileCard() {
    final name = _nombreCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    return Container(
      padding: EdgeInsets.fromLTRB(20, 26, 20, 16),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildAvatar(),
          SizedBox(height: 16),
          Text(
            name.isNotEmpty ? name : 'Tu nombre',
            style: TextStyle(
              color: tokens.text,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (email.isNotEmpty) ...[
            SizedBox(height: 4),
            Text(
              email,
              style: TextStyle(
                color: tokens.textSub,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (widget.onOpenRepartoSelector != null) ...[
            SizedBox(height: 18),
            Container(height: 1, color: tokens.cardBorder),
            SizedBox(height: 6),
            _buildRepartoInlineRow(),
          ],
        ],
      ),
    );
  }

  Widget _buildRepartoInlineRow() {
    final repartoName = widget.activeRepartoNameProvider?.call();
    final hasReparto = (repartoName ?? '').trim().isNotEmpty;
    return Material(
      key: _kReparto,
      color: tokens.primaryBlue.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final opener = widget.onOpenRepartoSelector;
          if (opener == null) return;
          await opener();
          if (mounted) setState(() {});
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  hasReparto ? repartoName! : 'Seleccionar reparto',
                  style: TextStyle(
                    color: tokens.primaryBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: tokens.primaryBlue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _buildCardField(
            label: 'Nombre',
            controller: _nombreCtrl,
            hint: 'Tu nombre',
            textCapitalization: TextCapitalization.words,
          ),
          _cardDivider(),
          _buildCardField(
            label: 'Email',
            controller: _emailCtrl,
            hint: 'tu@email.com',
            keyboard: TextInputType.emailAddress,
          ),
          _cardDivider(),
          _buildCardField(
            label: 'Teléfono',
            controller: _telefonoCtrl,
            hint: 'Tu teléfono',
            keyboard: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _buildMercadoPagoCard() {
    return Container(
      decoration: _cardDecoration(),
      padding: EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOKEN DE ACCESO',
            style: TextStyle(
              color: tokens.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'mercadopago.com.ar/developers → Tus integraciones → Credenciales de producción',
            style: TextStyle(color: tokens.textSub, fontSize: 11),
          ),
          SizedBox(height: 10),
          TextField(
            controller: _mpTokenCtrl,
            readOnly: kDemoMode,
            enableInteractiveSelection: !kDemoMode,
            onTap: () {
              if (kDemoMode) showDemoUpgradeSnack(context);
            },
            obscureText: _mpTokenObscured,
            style: TextStyle(color: tokens.text, fontSize: 14),
            decoration: _flatInputDecoration(
              hint: 'APP_USR-...',
              suffix: IconButton(
                icon: Icon(
                  _mpTokenObscured ? Icons.visibility_off : Icons.visibility,
                  color: tokens.textMuted,
                  size: 20,
                ),
                onPressed: () {
                  if (kDemoMode) {
                    showDemoUpgradeSnack(context);
                    return;
                  }
                  setState(() => _mpTokenObscured = !_mpTokenObscured);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacturacionCard() {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _buildCardField(
            label: 'CUIT',
            controller: _cuitCtrl,
            hint: 'Ej: 20123456789',
            keyboard: TextInputType.number,
          ),
          _cardDivider(),
          _buildCardField(
            label: 'Razón social',
            controller: _razonSocialCtrl,
            hint: 'Nombre o razón social',
            textCapitalization: TextCapitalization.words,
          ),
          _cardDivider(),
          _buildCardField(
            label: 'Domicilio comercial',
            controller: _domicilioCtrl,
            hint: 'Dirección fiscal',
          ),
          _cardDivider(),
          _buildCardField(
            label: 'Punto de venta',
            controller: _ptoVtaCtrl,
            hint: 'Ej: 1',
            keyboard: TextInputType.number,
          ),
          _cardDivider(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONDICIÓN IVA',
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                SizedBox(height: 2),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _afipCondicionIva,
                    isExpanded: true,
                    dropdownColor: tokens.card,
                    style: TextStyle(
                      color: tokens.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    icon: Icon(
                      Icons.arrow_drop_down_rounded,
                      color: tokens.textMuted,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Monotributista',
                        child: Text('Monotributista'),
                      ),
                      DropdownMenuItem(
                        value: 'Responsable Inscripto',
                        child: Text('Responsable Inscripto'),
                      ),
                      DropdownMenuItem(value: 'Exento', child: Text('Exento')),
                    ],
                    onChanged: (v) {
                      if (kDemoMode) {
                        showDemoUpgradeSnack(context);
                        return;
                      }
                      if (v == null) return;
                      setState(() => _afipCondicionIva = v);
                      _autoSave();
                    },
                  ),
                ),
              ],
            ),
          ),
          _cardDivider(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Modo Producción',
                        style: TextStyle(
                          color: tokens.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        _afipProduction
                            ? 'Facturas reales en ARCA'
                            : 'Modo prueba (testing)',
                        style: TextStyle(
                          color: _afipProduction
                              ? tokens.warn
                              : tokens.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _afipProduction,
                  onChanged: (v) {
                    if (kDemoMode) {
                      showDemoUpgradeSnack(context);
                      return;
                    }
                    setState(() => _afipProduction = v);
                    _autoSave();
                  },
                  activeThumbColor: tokens.warn,
                  activeTrackColor: tokens.warn.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboard = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: tokens.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: 2),
          Builder(
            builder: (fieldContext) => Focus(
              onFocusChange: (hasFocus) {
                if (hasFocus) {
                  Future.delayed(Duration(milliseconds: 300), () {
                    if (fieldContext.mounted) {
                      Scrollable.ensureVisible(
                        fieldContext,
                        duration: Duration(milliseconds: 250),
                        alignmentPolicy:
                            ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
                      );
                    }
                  });
                } else {
                  _debounce?.cancel();
                  _autoSave();
                }
              },
              child: TextField(
                controller: controller,
                readOnly: kDemoMode,
                enableInteractiveSelection: !kDemoMode,
                onTap: () {
                  if (kDemoMode) showDemoUpgradeSnack(context);
                },
                keyboardType: keyboard,
                textCapitalization: textCapitalization,
                style: TextStyle(
                  color: tokens.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: tokens.textMuted,
                    fontWeight: FontWeight.w400,
                  ),
                  isCollapsed: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 6),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _flatInputDecoration({
    required String hint,
    Widget? suffix,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: tokens.textMuted),
    filled: true,
    fillColor: tokens.bg,
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: tokens.primaryBlue, width: 1.5),
    ),
    suffixIcon: suffix,
  );

  // ignore: unused_element
  Widget _buildRepartoTile() {
    final repartoName = widget.activeRepartoNameProvider?.call();
    final subtitle = (repartoName ?? '').trim().isNotEmpty
        ? repartoName!
        : 'Sin reparto seleccionado';
    return Material(
      color: tokens.card,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final opener = widget.onOpenRepartoSelector;
          if (opener == null) return;
          await opener();
          if (mounted) setState(() {});
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: tokens.card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 8,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tokens.primaryBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.local_shipping_outlined,
                  size: 18,
                  color: tokens.primaryBlue,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Reparto activo',
                      style: TextStyle(
                        color: tokens.text,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: tokens.textSub, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: tokens.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignOutTile() {
    return Material(
      color: tokens.card,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _handleProfileSignOut,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: tokens.card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 8,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tokens.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.logout_rounded,
                  size: 18,
                  color: tokens.danger,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cerrar sesión',
                  style: TextStyle(
                    color: tokens.danger,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 22, color: tokens.danger),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleProfileSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cerrar sesión', style: TextStyle(color: tokens.text)),
        content: Text(
          '¿Estás seguro de que querés cerrar sesión?',
          style: TextStyle(color: tokens.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: tokens.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Cerrar sesión',
              style: TextStyle(color: tokens.danger.withValues(alpha: 0.85)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await AuthService.signOut();
    if (!mounted) return;
    Future<void> showSignOutFailed() async {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo cerrar sesión: no se limpiaron las credenciales locales.',
          ),
          backgroundColor: tokens.danger,
        ),
      );
    }

    if (result is SignOutBlocked) {
      final pending = result.pendingItemCount;
      final forceConfirm = await showDialog<bool>(
        context: context,
        builder: (dCtx) => AlertDialog(
          title: Text('Hay cambios sin sincronizar'),
          content: Text(
            'Hay $pending cambio${pending == 1 ? '' : 's'} '
            'sin sincronizar. Si cerrás sesión '
            'ahora, se perderán. '
            '¿Continuar igualmente?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dCtx, true),
              style: TextButton.styleFrom(foregroundColor: tokens.danger),
              child: Text('Cerrar sesión igual'),
            ),
          ],
        ),
      );
      if (forceConfirm != true) return;
      final forced = await AuthService.signOut(forceWipe: true);
      if (!forced.success) {
        await showSignOutFailed();
        return;
      }
    } else if (!result.success) {
      await showSignOutFailed();
      return;
    }
    TutorialController.instance.skip();
  }
}

class _ProfilePhotoCropDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final int imageWidth;
  final int imageHeight;

  const _ProfilePhotoCropDialog({
    required this.imageBytes,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  State<_ProfilePhotoCropDialog> createState() =>
      _ProfilePhotoCropDialogState();
}

class _ProfilePhotoCropDialogState extends State<_ProfilePhotoCropDialog> {
  AppTokens get tokens => AppTokens.of(context);

  double _scale = 1;
  double _startScale = 1;
  Offset _offset = Offset.zero;

  Size _renderedSize(double viewportSize, double scale) {
    final baseScale = math.max(
      viewportSize / widget.imageWidth,
      viewportSize / widget.imageHeight,
    );
    return Size(
      widget.imageWidth * baseScale * scale,
      widget.imageHeight * baseScale * scale,
    );
  }

  Offset _clampOffset(Offset offset, double scale, double viewportSize) {
    final rendered = _renderedSize(viewportSize, scale);
    final maxX = math.max(0.0, (rendered.width - viewportSize) / 2);
    final maxY = math.max(0.0, (rendered.height - viewportSize) / 2);
    return Offset(
      offset.dx.clamp(-maxX, maxX).toDouble(),
      offset.dy.clamp(-maxY, maxY).toDouble(),
    );
  }

  void _updateScale(double value, double viewportSize) {
    setState(() {
      _scale = value;
      _offset = _clampOffset(_offset, _scale, viewportSize);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cropSize = math
        .min(screenWidth - 80, 320)
        .clamp(220.0, 320.0)
        .toDouble();
    final rendered = _renderedSize(cropSize, _scale);
    final left = (cropSize - rendered.width) / 2 + _offset.dx;
    final top = (cropSize - rendered.height) / 2 + _offset.dy;

    return AlertDialog(
      backgroundColor: tokens.card,
      insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      title: Text(
        'Ajustar foto',
        style: TextStyle(color: tokens.text, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: cropSize,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onScaleStart: (_) => _startScale = _scale,
              onScaleUpdate: (details) {
                final nextScale = (_startScale * details.scale)
                    .clamp(1.0, 4.0)
                    .toDouble();
                final nextOffset = _offset + details.focalPointDelta;
                setState(() {
                  _scale = nextScale;
                  _offset = _clampOffset(nextOffset, _scale, cropSize);
                });
              },
              child: Container(
                width: cropSize,
                height: cropSize,
                decoration: BoxDecoration(
                  color: tokens.bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: tokens.primaryBlue, width: 2),
                ),
                child: ClipOval(
                  child: Stack(
                    children: [
                      Positioned(
                        left: left,
                        top: top,
                        width: rendered.width,
                        height: rendered.height,
                        child: Image.memory(
                          widget.imageBytes,
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 18),
            Row(
              children: [
                Icon(Icons.zoom_out, color: tokens.textMuted, size: 20),
                Expanded(
                  child: Slider(
                    value: _scale,
                    min: 1,
                    max: 4,
                    activeColor: tokens.primaryBlue,
                    inactiveColor: tokens.cardBorder,
                    onChanged: (value) => _updateScale(value, cropSize),
                  ),
                ),
                Icon(Icons.zoom_in, color: tokens.textMuted, size: 20),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar', style: TextStyle(color: tokens.textSub)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            _ProfileCropResult(
              scale: _scale,
              offset: _clampOffset(_offset, _scale, cropSize),
              viewportSize: cropSize,
            ),
          ),
          child: Text(
            'Guardar',
            style: TextStyle(
              color: tokens.primaryBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
