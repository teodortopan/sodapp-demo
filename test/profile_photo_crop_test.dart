import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String profileSrc;
  late String pubspecSrc;

  setUpAll(() {
    profileSrc = File('lib/screens/profile_screen.dart').readAsStringSync();
    pubspecSrc = File('pubspec.yaml').readAsStringSync();
  });

  test('profile photo picker opens a crop dialog before saving', () {
    expect(profileSrc, contains('class _ProfilePhotoCropDialog'));
    expect(profileSrc, contains('await showDialog<_ProfileCropResult>'));
    expect(profileSrc, contains('final bytes = await _cropProfilePhotoBytes'));
  });

  test('profile photo save writes the cropped JPEG bytes only', () {
    expect(pubspecSrc, contains('image: ^4.8.0'));
    expect(profileSrc, contains("import 'package:image/image.dart' as img;"));
    expect(profileSrc, contains('img.copyCrop('));
    expect(profileSrc, contains('img.copyResize('));
    expect(profileSrc, contains('img.encodeJpg(resized, quality: 85)'));
  });
}
