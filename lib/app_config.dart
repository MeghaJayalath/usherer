import 'data/local/hive_cache.dart';

class AppConfig {
  static const List<String> _flightApiKeys = [
    '06c40c5377msh4a0ab91154f66d1p1be5cdjsn341d88703e9d',
    '01f0d883a7mshb6067de60391043p18cf3bjsn4567e0ff843b',
  ];

  static List<String> get flightApiKeys => List.unmodifiable(_flightApiKeys);

  static String? get spreadsheetId =>
      _spreadsheetIdOverride ?? HiveCache.getSpreadsheetId();

  // Allow runtime override (used for initial migration)
  static String? _spreadsheetIdOverride;
  static void setSpreadsheetIdOverride(String? id) {
    _spreadsheetIdOverride = id;
  }

  static const String serviceAccountAssetPath =
      'assets/credentials/service_account.json';

  // Bcrypt hash for the password "admin123"
  static const String adminPasswordHash =
      r'$2a$10$FUxuNcGJp9nKMHrDwe0gE.f2QobMNqFZJjOAwsTknhF8bFD./ykUS';
}
