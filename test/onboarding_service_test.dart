import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sodapp_demo/services/onboarding_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a brand-new user has not seen the tutorial', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await OnboardingService.hasSeenInicioTutorial('user-1'), isFalse);
  });

  test('marking seen makes hasSeen return true for that user', () async {
    SharedPreferences.setMockInitialValues({});
    await OnboardingService.markInicioTutorialSeen('user-1');
    expect(await OnboardingService.hasSeenInicioTutorial('user-1'), isTrue);
  });

  test('the seen flag is per-user (does not leak across accounts)', () async {
    SharedPreferences.setMockInitialValues({});
    await OnboardingService.markInicioTutorialSeen('user-1');
    expect(await OnboardingService.hasSeenInicioTutorial('user-2'), isFalse);
  });

  test(
    'an empty userId is treated as seen so it never auto-launches',
    () async {
      SharedPreferences.setMockInitialValues({});
      expect(await OnboardingService.hasSeenInicioTutorial(''), isTrue);
      // marking an empty user is a no-op and does not throw
      await OnboardingService.markInicioTutorialSeen('');
    },
  );
}
