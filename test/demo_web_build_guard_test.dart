import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('demo-only entrypoint', () {
    late String mainSrc;

    setUpAll(() => mainSrc = File('lib/main.dart').readAsStringSync());

    test('boots directly into the seeded mobile UI', () {
      expect(mainSrc, contains('SodappDemo'));
      expect(mainSrc, contains('home: const SplashScreen()'));
      expect(mainSrc, contains('WebPhoneFrame(child: child!)'));
      expect(mainSrc, isNot(contains('Supabase')));
      expect(mainSrc, isNot(contains('dotenv')));
      expect(mainSrc, isNot(contains('WebLogin')));
    });

    test('splash always seeds local data and opens HomeScreen', () {
      final src = File('lib/screens/splash_screen.dart').readAsStringSync();
      expect(src, contains('await seedDemoData()'));
      expect(src, contains('const HomeScreen()'));
      expect(src, isNot(contains('LoginScreen')));
      expect(src, isNot(contains('Supabase')));
    });
  });

  group('browser-local storage', () {
    test('uses Drift WASM with committed worker assets', () {
      final src = File('lib/database/connection/web.dart').readAsStringSync();
      expect(src, contains('WasmDatabase.open('));
      expect(src, contains("import 'package:drift/wasm.dart'"));
      expect(File('web/sqlite3.wasm').existsSync(), isTrue);
      expect(File('web/drift_worker.js').existsSync(), isTrue);
    });

    test('photo operations are web-only no-ops', () {
      final barrel = File(
        'lib/services/photo_file_helper.dart',
      ).readAsStringSync();
      final implementation = File(
        'lib/services/photo_file_helper_web.dart',
      ).readAsStringSync();
      expect(barrel, contains("export 'photo_file_helper_web.dart'"));
      expect(implementation, isNot(contains("import 'dart:io'")));
      expect(
        File('lib/services/photo_file_helper_native.dart').existsSync(),
        isFalse,
      );
    });
  });

  group('static hosting', () {
    test('Cloudflare assets and security policy are present', () {
      final html = File('web/index.html').readAsStringSync();
      final headers = File('web/_headers').readAsStringSync();

      expect(html, contains('SODAPP Demo'));
      expect(html, isNot(contains('maps.googleapis.com')));
      expect(html, isNot(contains('_vercel')));
      expect(headers, contains("connect-src 'self'"));
      expect(headers, contains("worker-src 'self' blob:"));
    });

    test('no runtime environment asset is bundled', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, isNot(contains('.env')));
      expect(pubspec, isNot(contains('supabase_flutter')));
      expect(pubspec, isNot(contains('flutter_dotenv')));
      expect(pubspec, isNot(contains('url_launcher')));
    });
  });
}
