class GoogleOAuthConfig {
  static const String clientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
  );

  static const String clientSecret = String.fromEnvironment(
    'GOOGLE_CLIENT_SECRET',
  );

  static const int redirectPort = 8080;
}
