import 'dart:typed_data';
import 'dart:convert';
import 'dart:ui' show Rect;
import 'package:printing/printing.dart';
import 'package:web/web.dart' as web;
import 'platform_file_helper.dart';

PlatformFileHelper createPlatformFileHelper() => WebFileHelper();

class WebFileHelper extends PlatformFileHelper {
  // In-memory cache for PDFs on web (no filesystem)
  final Map<String, Uint8List> _pdfCache = {};

  @override
  Future<String> savePdf(String fileName, Uint8List bytes) async {
    _pdfCache[fileName] = bytes;
    return fileName;
  }

  @override
  Future<bool> fileExists(String path) async {
    return _pdfCache.containsKey(path);
  }

  @override
  Future<Uint8List?> readFileBytes(String path) async {
    return _pdfCache[path];
  }

  @override
  Future<void> sharePdf(
    String path, {
    Uint8List? bytes,
    String? fileName,
    Rect? sharePositionOrigin,
  }) async {
    final data = bytes ?? _pdfCache[path];
    if (data == null) return;
    final name = fileName ?? path.split('/').last;
    _triggerDownload(name, data);
  }

  @override
  Future<void> openPdf(String path, {Uint8List? bytes}) async {
    final data = bytes ?? _pdfCache[path];
    if (data == null) return;
    await Printing.layoutPdf(onLayout: (_) => data);
  }

  @override
  void downloadBytes(
    String fileName,
    Uint8List bytes, {
    String mimeType = 'application/octet-stream',
  }) {
    _triggerDownload(fileName, bytes, mimeType: mimeType);
  }

  void _triggerDownload(
    String fileName,
    Uint8List bytes, {
    String mimeType = 'application/pdf',
  }) {
    final base64 = base64Encode(bytes);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = 'data:$mimeType;base64,$base64';
    anchor.download = fileName;
    anchor.click();
  }
}
