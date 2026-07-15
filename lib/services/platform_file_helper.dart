import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'platform_file_helper_web.dart';

abstract class PlatformFileHelper {
  static PlatformFileHelper? _instance;
  static PlatformFileHelper get instance {
    _instance ??= createPlatformFileHelper();
    return _instance!;
  }

  /// Save PDF bytes to the platform's storage. Returns a path (native) or name (web).
  Future<String> savePdf(String fileName, Uint8List bytes);

  /// Check if a file exists at the given path.
  Future<bool> fileExists(String path);

  /// Read file bytes from the given path.
  Future<Uint8List?> readFileBytes(String path);

  /// Share/download a PDF file. On native uses Share, on web triggers browser download.
  /// `sharePositionOrigin` is the anchor rect for the iPad share popover.
  Future<void> sharePdf(
    String path, {
    Uint8List? bytes,
    String? fileName,
    Rect? sharePositionOrigin,
  });

  /// Open a PDF for viewing/printing.
  Future<void> openPdf(String path, {Uint8List? bytes});

  /// Trigger a browser download of arbitrary bytes. Web-only behavior; the
  /// native impl is a no-op (the web admin export UI that calls this is never
  /// reached on mobile). Routing through this abstract keeps `package:web` out
  /// of the mobile compilation graph.
  void downloadBytes(
    String fileName,
    Uint8List bytes, {
    String mimeType = 'application/octet-stream',
  });

  /// Whether this platform uses real file paths (false on web).
  bool get usesFilePaths => false;
}
