/// Usage:
///   flutter run --dart-define=BACKSERVER_BASE=http://your ip addr:8000
/// 
/// For Android emulator, use: http://10.0.2.2:8000
/// For real device on same network, use your computer's local IP.
library;

import 'dart:developer';

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

  /// Release case ID endpoint
  static Uri get releaseCaseIdUri => Uri.parse('$baseUrl/cases/release-id');

  /// Reject case endpoint
  static Uri get rejectCaseUri => Uri.parse('$baseUrl/cases/reject');

  /// Active learning candidates (uncertainty sampling)
  static Uri get activeLearningCandidatesUri =>
      Uri.parse('$baseUrl/active-learning/candidates');


  // (bridge-frontend-backend): Add annotations endpoint
  // This endpoint saves manual annotations (strokes, boxes, correct class)
  // from the AnnotateScreen to the backend for active learning.
  static Uri annotationsUri(String caseId) =>
      Uri.parse('$baseUrl/cases/$caseId/annotations');

  /// Authentication login endpoint
  static Uri get authLoginUri => Uri.parse('$baseUrl/auth/login');

  // ==========================================================================
  // Admin - Active Learning Endpoints
  // ==========================================================================

  /// Training configuration endpoints
  static Uri get adminTrainingConfigUri => Uri.parse('$baseUrl/admin/training-config');

  /// List all models
  static Uri get adminModelsUri => Uri.parse('$baseUrl/admin/models');

  /// Get production model info
  static Uri get adminProductionModelUri => Uri.parse('$baseUrl/admin/models/production');

  /// Promote a specific model
  static Uri adminPromoteModelUri(String versionId) =>
      Uri.parse('$baseUrl/admin/models/$versionId/promote');

  /// Rollback to a specific model
  static Uri adminRollbackModelUri(String versionId) =>
      Uri.parse('$baseUrl/admin/models/$versionId/rollback');

  /// Trigger retraining
  static Uri get adminRetrainTriggerUri => Uri.parse('$baseUrl/admin/retrain/trigger');

  /// Get retraining status
  static Uri get adminRetrainStatusUri => Uri.parse('$baseUrl/admin/retrain/status');

  /// Get AL events
  static Uri get adminEventsUri => Uri.parse('$baseUrl/admin/events');

  /// Get label counts
  static Uri get adminLabelsCountUri => Uri.parse('$baseUrl/admin/labels/count');

  /// Get labels list
  static Uri get adminLabelsUri => Uri.parse('$baseUrl/admin/labels');

  /// User context headers (legacy - kept for backward compatibility)
  static const String userIdHeader = 'X-User-Id';
  static const String userRoleHeader = 'X-User-Role';

  /// Optional API key (set via --dart-define=API_KEY=xxx)
  static const String? apiKey = String.fromEnvironment('API_KEY', defaultValue: '') == ''
      ? null
      : String.fromEnvironment('API_KEY');

  /// Build headers with API key and optional user context.
  /// If [token] is provided, uses Bearer token authentication.
  /// Otherwise falls back to legacy X-User-Id/X-User-Role headers.
  static Map<String, String> buildHeaders({
    bool json = false,
    String? token,
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
    // Prefer Bearer token if available
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    } else {
      // Fall back to legacy headers
      if (userId != null && userId.trim().isNotEmpty) {
        headers[userIdHeader] = userId.trim();
      }
      if (userRole != null && userRole.trim().isNotEmpty) {
        headers[userRoleHeader] = userRole.trim();
      }
    }
    return headers;
  }

  /// Debug: print the resolved config
  static void printConfig() {
    log('[ApiConfig] Raw BACKSERVER_BASE: $_rawBase', name: 'ApiConfig');
    log('[ApiConfig] Resolved baseUrl: $baseUrl', name: 'ApiConfig');
    log('[ApiConfig] checkImageUri: $checkImageUri', name: 'ApiConfig');
    log('[ApiConfig] apiKey set: ${apiKey != null}', name: 'ApiConfig');
  }

}
