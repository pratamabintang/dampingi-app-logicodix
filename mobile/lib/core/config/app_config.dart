abstract final class AppConfig {
  static const appName = 'Dampingi';
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const useBackendAuth = bool.fromEnvironment(
    'USE_BACKEND_AUTH',
    defaultValue: false,
  );
}
