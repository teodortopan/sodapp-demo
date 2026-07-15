import 'dart:typed_data';

import 'package:flutter/widgets.dart' show ImageProvider;

// Web stubs: a browser has no local filesystem for the cached avatar. The
// demo web build shows the cloud URL (if any) or the placeholder icon, and
// profile-photo edits are demo-gated, so these never need to do real work.

Future<bool> photoExists(String path) async => false;

ImageProvider? photoImage(String path) => null;

Future<String?> savePhotoBytes(Uint8List bytes, String fileName) async => null;

Future<void> deletePhoto(String path) async {}
