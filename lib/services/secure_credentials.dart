/// Demo-only placeholder. Payment credentials are never accepted or stored.
class SecureCredentials {
  SecureCredentials._();
  static final SecureCredentials instance = SecureCredentials._();

  Future<String> readMpToken() async => '';
  Future<void> setMpToken(String value) async {}
}
