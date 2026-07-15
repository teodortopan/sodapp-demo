import 'dart:convert';
import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../demo/demo_mode.dart';
import '../services/afip_service.dart';
import '../services/invoice_pdf_service.dart';
import '../services/platform_file_helper.dart';
import '../services/sync_service.dart';

class FacturasScreen extends StatefulWidget {
  final int clienteId;
  final String clienteNombre;

  const FacturasScreen({
    super.key,
    required this.clienteId,
    required this.clienteNombre,
  });

  @override
  State<FacturasScreen> createState() => _FacturasScreenState();
}

class _FacturasScreenState extends State<FacturasScreen> {
  static const Color darkBlue = Color(0xFF070E1A);
  static const Color navColor = Color(0xFF152438);
  static const Color cardColor = Color(0xFF0F1B2D);
  static const Color lightBlue = Color(0xFF1292D3);
  static const Color borderColor = Color(0xFF1A2A40);
  static const Color greenColor = Color(0xFF4CAF50);

  final _db = AppDatabase.instance;
  List<Factura> _facturas = [];

  // Maps factura.id → resolved local PDF path. Populated by the lazy
  // resolution path below when a factura's stored pdfPath points at a file
  // that doesn't exist on this device (typical right after a fresh restore,
  // before SyncService's background PDF batch lands). Used by _openPdf and
  // _sharePdf so they open the actual local file, not the stale string.
  final Map<int, String> _resolvedPdfPaths = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await _db.getFacturasForClient(widget.clienteId);
    if (mounted) setState(() => _facturas = data);
  }

  String _formatDate(String fecha) {
    final parts = fecha.split('-');
    if (parts.length != 3) return fecha;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  String _formatMoney(double amount) {
    final abs = amount.abs().round();
    final formatted = abs.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return '\$$formatted';
  }

  String _cbteLabel(int cbteTipo) {
    switch (cbteTipo) {
      case 11:
        return 'Factura C';
      case 12:
        return 'Nota de Débito C';
      case 13:
        return 'Nota de Crédito C';
      default:
        return 'Comprobante';
    }
  }

  void _showFacturaDetail(Factura f) {
    final items = _parseItems(f.itemsJson);

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              // Header
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: lightBlue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _cbteLabel(f.cbteTipo),
                      style: const TextStyle(
                        color: lightBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatDate(f.fecha),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${f.ptoVta.toString().padLeft(4, '0')}-${f.cbteNro.toString().padLeft(8, '0')}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),

              // Items
              const Text(
                'DETALLE',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item['nombre']} x${item['cantidad']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        '\$ ${(item['subtotal'] as num).toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(color: borderColor, height: 24),

              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '\$ ${f.importeTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: greenColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // CAE info
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: darkBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('CAE', f.cae),
                    const SizedBox(height: 4),
                    _infoRow('Vto. CAE', _formatDate(f.caeFchVto)),
                    const SizedBox(height: 4),
                    _infoRow(
                      'Receptor',
                      f.receptorNombre.isNotEmpty
                          ? f.receptorNombre
                          : 'Consumidor Final',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action buttons
              _buildActionButtons(f, ctx),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(Factura f, BuildContext sheetCtx) {
    return FutureBuilder<bool>(
      future: _resolveLocalPdfPath(f),
      builder: (ctx, snapshot) {
        final fileExists = snapshot.data == true;

        if (fileExists) {
          // PDF exists — show Compartir (left) + Abrir PDF (right)
          return Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.share,
                  label: 'Compartir',
                  onTap: () => _sharePdf(f),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  icon: Icons.picture_as_pdf,
                  label: 'Abrir PDF',
                  onTap: () => _openPdf(f),
                ),
              ),
            ],
          );
        }

        // PDF missing — show regenerate button
        return _actionButton(
          icon: Icons.refresh,
          label: 'Regenerar PDF',
          color: Colors.orange,
          onTap: () => _regeneratePdf(f, sheetCtx),
        );
      },
    );
  }

  Future<void> _openPdf(Factura f) async {
    if (blockDemoAction(context)) return;
    final path = _resolvedPdfPaths[f.id] ?? f.pdfPath;
    if (path.isEmpty) return;
    await PlatformFileHelper.instance.openPdf(path);
  }

  /// Returns true if the factura's PDF is available locally (already on disk
  /// or freshly downloaded from cloud storage). Backs the action buttons in
  /// the bottom sheet — when this returns false we fall through to the
  /// existing "Regenerar PDF" affordance, so user-visible behavior is
  /// unchanged when the PDF is genuinely missing in cloud too.
  Future<bool> _resolveLocalPdfPath(Factura f) async {
    if (kDemoMode) return false;
    if (f.pdfPath.isEmpty) return false;
    // Already resolved earlier in this screen's lifecycle?
    final cached = _resolvedPdfPaths[f.id];
    if (cached != null &&
        await PlatformFileHelper.instance.fileExists(cached)) {
      return true;
    }
    // Stored path exists locally? (Common case once background download landed
    // or when the originating device is the current one.)
    if (await PlatformFileHelper.instance.fileExists(f.pdfPath)) {
      _resolvedPdfPaths[f.id] = f.pdfPath;
      return true;
    }
    // Local file missing — try one-shot lazy fetch from cloud storage. Covers
    // the post-restore window where SyncService's background PDF batch hasn't
    // landed yet (or never ran because the user opened a factura immediately).
    final fileName = f.pdfPath.split('/').last;
    if (fileName.isEmpty) return false;
    final newPath = await SyncService.instance.downloadFacturaPdfFromCloud(
      f.id,
      fileName,
    );
    if (newPath == null) return false;
    _resolvedPdfPaths[f.id] = newPath;
    return true;
  }

  Future<void> _regeneratePdf(Factura f, BuildContext sheetCtx) async {
    if (blockDemoAction(context)) return;
    final settings = await _db.getSettings();
    final items = _parseItems(f.itemsJson);

    // Generate QR URL
    final afip = AfipService(
      cuit: settings.afipCuit,
      production: settings.afipProduction,
    );
    final qrUrl = afip.generateQrUrl(
      ver: 1,
      fecha: f.fecha,
      cbteTipo: f.cbteTipo,
      ptoVta: f.ptoVta,
      cbteNro: f.cbteNro,
      importeTotal: f.importeTotal,
      cae: f.cae,
    );

    final pdfPath = await InvoicePdfService.generatePdf(
      razonSocial: settings.afipRazonSocial,
      cuit: settings.afipCuit,
      domicilio: settings.afipDomicilio,
      condicionIva: settings.afipCondicionIva,
      ptoVta: f.ptoVta,
      cbteNro: f.cbteNro,
      fecha: f.fecha,
      cae: f.cae,
      caeFchVto: f.caeFchVto,
      importeTotal: f.importeTotal,
      receptorNombre: f.receptorNombre,
      receptorDocTipo: f.receptorDocTipo,
      receptorDocNro: f.receptorDocNro,
      items: items,
      qrUrl: qrUrl,
      cbteTipo: f.cbteTipo,
    );

    // Update DB with new path
    await _db.updateFacturaPdfPath(f.id, pdfPath);

    if (!mounted) return;
    Navigator.pop(context); // close bottom sheet
    _loadData(); // refresh list

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PDF regenerado'),
        backgroundColor: Color(0xFF4CAF50),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    Color color = lightBlue,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sharePdf(Factura f) async {
    if (blockDemoAction(context)) return;
    final path = _resolvedPdfPaths[f.id] ?? f.pdfPath;
    if (path.isEmpty) return;
    if (!await PlatformFileHelper.instance.fileExists(path)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Archivo PDF no encontrado')),
        );
      }
      return;
    }
    if (!mounted) return;
    Navigator.pop(context); // close bottom sheet
    await PlatformFileHelper.instance.sharePdf(path);
  }

  List<Map<String, dynamic>> _parseItems(String json) {
    try {
      final list = jsonDecode(json) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBlue,
      appBar: AppBar(
        backgroundColor: navColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Facturas - ${widget.clienteNombre}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: _facturas.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long,
                      color: Colors.white.withValues(alpha: 0.2),
                      size: 64,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No hay facturas',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _facturas.length,
                itemBuilder: (ctx, i) {
                  final f = _facturas[i];
                  return _buildFacturaCard(f);
                },
              ),
      ),
    );
  }

  Widget _buildFacturaCard(Factura f) {
    return GestureDetector(
      onTap: () => _showFacturaDetail(f),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Row(
          children: [
            // Invoice icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: lightBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.receipt, color: lightBlue, size: 20),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_cbteLabel(f.cbteTipo)} ${f.ptoVta.toString().padLeft(4, '0')}-${f.cbteNro.toString().padLeft(8, '0')}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatDate(f.fecha),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Amount
            Text(
              _formatMoney(f.importeTotal),
              style: const TextStyle(
                color: greenColor,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
