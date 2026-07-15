import '../demo/demo_mode.dart';

enum AuthChangeEvent { signedOut }

class DemoAuthState {
  final AuthChangeEvent event;
  const DemoAuthState(this.event);
}

class DemoUser {
  final String id;
  final String? email;
  const DemoUser({required this.id, this.email});
}

sealed class SignOutResult {
  const SignOutResult();
  bool get success => this is SignOutSucceeded;
}

class SignOutSucceeded extends SignOutResult {
  final bool forcedWithUnsynced;
  const SignOutSucceeded({this.forcedWithUnsynced = false});
}

class SignOutBlocked extends SignOutResult {
  final int pendingItemCount;
  const SignOutBlocked(this.pendingItemCount);
}

class SignOutFailed extends SignOutResult {
  final String message;
  const SignOutFailed(this.message);
}

class AuthService {
  static const DemoUser _demoUser = DemoUser(
    id: kDemoUserId,
    email: kDemoEmail,
  );

  static DemoUser? get currentUser => _demoUser;
  static String? get currentUserId => _demoUser.id;
  static String? get currentUserEmail => _demoUser.email;
  static bool get isLoggedIn => true;

  static Stream<DemoAuthState> get authStateChanges =>
      const Stream<DemoAuthState>.empty();

  static Future<SignOutResult> signOut({bool forceWipe = false}) async =>
      const SignOutSucceeded();
}
