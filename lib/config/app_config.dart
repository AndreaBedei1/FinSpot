class AppConfig {
  static const String _apiBaseFromEnv = String.fromEnvironment('API_BASE');
  static const String _legacyApiBaseFromEnv = String.fromEnvironment('API_BASE_URL');

  static const String _filesBaseFromEnv = String.fromEnvironment('FILES_BASE');
  static const String _legacyFilesBaseFromEnv = String.fromEnvironment('FILES_BASE_URL');

  static const String _defaultApiBase = 'https://isi-seawatch.csr.unibo.it/api';
  static const String _defaultFilesBase = 'https://isi-seawatch.csr.unibo.it';

  static String get apiBaseUrl => _normalizeBaseUrl(
        _firstNonEmpty(_apiBaseFromEnv, _legacyApiBaseFromEnv, _defaultApiBase),
        fallback: _defaultApiBase,
      );

  static String get filesBaseUrl => _normalizeBaseUrl(
        _firstNonEmpty(_filesBaseFromEnv, _legacyFilesBaseFromEnv, _defaultFilesBase),
        fallback: _defaultFilesBase,
      );

  static String _firstNonEmpty(String a, String b, String fallback) {
    if (a.trim().isNotEmpty) {
      return a;
    }
    if (b.trim().isNotEmpty) {
      return b;
    }
    return fallback;
  }

  static String _normalizeBaseUrl(
    String raw, {
    required String fallback,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return fallback;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return fallback;
    }

    final path = uri.path.endsWith('/') && uri.path.length > 1
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;

    return uri.replace(path: path).toString();
  }

  static String normalizeUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) {
      return '$filesBaseUrl$value';
    }
    return '$filesBaseUrl/$value';
  }
}
