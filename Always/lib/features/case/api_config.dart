/// Shared API configuration for the backend server.
/// 
/// Usage:
///   flutter run --dart-define=BACKSERVER_BASE=http://your ip addr:8000
/// 
/// For Android emulator, use: http://10.0.2.2:8000
/// For real device on same network, use your computer's local IP.
library;

class ApiConfig {
  ApiConfig._();

  /// Raw value from environment (may have typos)
  static const String _rawBase =
      String.fromEnvironment('BACKSERVER_BASE', defaultValue: 'http://10.0.2.2:8000');

  /// Sanitized base URL - always starts with http://
  static String get baseUrl {
    String base = _rawBase.trim();
    
    // Fix common typos: htp://, ht://, https:// -> http://
    if (base.startsWith('htp://')) {
      base = 'http://${base.substring(6)}';
    } else if (base.startsWith('ht://')) {
      base = 'http://${base.substring(5)}';
    } else if (base.startsWith('https://')) {
      // Force HTTP for local dev
      base = 'http://${base.substring(8)}';
    } else if (!base.startsWith('http://')) {
      base = 'http://$base';
    }
    
    // Remove trailing slash
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    
    return base;
  }

  /// Check-image endpoint for blur detection and ML prediction
  static Uri get checkImageUri => Uri.parse('$baseUrl/check-image');

  /// Health check endpoint
  static Uri get healthUri => Uri.parse('$baseUrl/health');

  /// Log cases endpoint
  static Uri get casesUri => Uri.parse('$baseUrl/cases');

  /// Next case ID endpoint
  static Uri get nextCaseIdUri => Uri.parse('$baseUrl/cases/next-id');

  /// Reject case endpoint
  static Uri get rejectCaseUri => Uri.parse('$baseUrl/cases/reject');

  /// User context headers
  static const String userIdHeader = 'X-User-Id';
  static const String userRoleHeader = 'X-User-Role';

  /// Optional API key (set via --dart-define=API_KEY=xxx)
  static const String? apiKey = String.fromEnvironment('API_KEY', defaultValue: '') == ''
      ? null
      : String.fromEnvironment('API_KEY');

  /// Build headers with API key and optional user context.
  static Map<String, String> buildHeaders({
    bool json = false,
    String? userId,
    String? userRole,
  }) {
    final headers = <String, String>{};
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    if (apiKey != null) {
      headers['X-API-Key'] = apiKey!;
    }
    if (userId != null && userId.trim().isNotEmpty) {
      headers[userIdHeader] = userId.trim();
    }
    if (userRole != null && userRole.trim().isNotEmpty) {
      headers[userRoleHeader] = userRole.trim();
    }
    return headers;
  }

  /// Debug: print the resolved config
  static void printConfig() {
    print('[ApiConfig] Raw BACKSERVER_BASE: $_rawBase');
    print('[ApiConfig] Resolved baseUrl: $baseUrl');
    print('[ApiConfig] checkImageUri: $checkImageUri');
    print('[ApiConfig] apiKey set: ${apiKey != null}');
  }
}
