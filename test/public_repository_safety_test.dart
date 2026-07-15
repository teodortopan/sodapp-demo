import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('public repository safety', () {
    test('production-only files and platforms are absent', () {
      const forbiddenPaths = [
        '.env',
        'android',
        'ios',
        'linux',
        'lib/screens/login_screen.dart',
        'macos',
        'windows',
        'supabase',
        'supabase_schema.sql',
        'vercel.json',
      ];

      for (final path in forbiddenPaths) {
        expect(
          FileSystemEntity.typeSync(path),
          FileSystemEntityType.notFound,
          reason: '$path must never be committed to the public demo',
        );
      }
    });

    test('source contains no backend, secret, or external mutation wiring', () {
      final sources = <File>[];
      for (final root in ['lib', 'web']) {
        sources.addAll(
          Directory(root)
              .listSync(recursive: true)
              .whereType<File>()
              .where(
                (file) =>
                    file.path.endsWith('.dart') ||
                    file.path.endsWith('.html') ||
                    file.path.endsWith('.yaml'),
              ),
        );
      }
      sources.add(File('pubspec.yaml'));

      const forbiddenText = [
        'SUPABASE_',
        'supabase_flutter',
        'flutter_dotenv',
        'package:http/',
        'package:url_launcher/',
        'Supabase.instance',
        'maps.googleapis.com',
        'api.mercadopago.com',
        'app.afipsdk.com',
        'wa.me/',
        'AIza',
      ];

      for (final file in sources) {
        final content = file.readAsStringSync();
        for (final forbidden in forbiddenText) {
          expect(
            content,
            isNot(contains(forbidden)),
            reason:
                '${file.path} contains forbidden public-demo text: $forbidden',
          );
        }
      }
    });

    test('the demo boots locally with clearly fictional seed records', () {
      final mainSource = File('lib/main.dart').readAsStringSync();
      final splashSource = File(
        'lib/screens/splash_screen.dart',
      ).readAsStringSync();
      final seedSource = File(
        'lib/demo/demo_data_seed.dart',
      ).readAsStringSync();

      expect(mainSource, contains('SodappDemo'));
      expect(mainSource, isNot(contains('LoginScreen')));
      expect(splashSource, contains('await seedDemoData();'));
      expect(seedSource, contains('Almacen Demo Norte'));
      expect(seedSource, contains('Familia Ejemplo'));
      expect(seedSource, contains('Ciudad Demo'));
    });

    test('Cloudflare blocks runtime network access outside this origin', () {
      final headers = File('web/_headers').readAsStringSync();
      expect(headers, contains("connect-src 'self'"));
      expect(headers, contains('geolocation=()'));
      expect(headers, contains("form-action 'self'"));
    });
  });
}
