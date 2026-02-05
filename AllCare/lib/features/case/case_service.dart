import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import '../../app_state.dart';

/// A single case record returned from the backend.
class CaseRecord {
  final String caseId;
  final String? imageId;
  final List<Map<String, dynamic>> predictions;
  final String status;
  final String? entryType;
  final String? gender;
  final String? age;
  final String? location;
  final List<String> symptoms;
  final List<String> imagePaths; // Paths to captured images
  final String? createdAt;
  final String? updatedAt;
  final bool isLabeled;
  final String? correctLabel;
  final int? selectedPredictionIndex; // Index of image selected for prediction

  CaseRecord({
    required this.caseId,
    this.imageId,
    this.predictions = const [],
    required this.status,
    this.entryType,
    this.gender,
    this.age,
    this.location,
    this.symptoms = const [],
    this.imagePaths = const [],
    this.createdAt,
    this.updatedAt,
    this.isLabeled = false,
    this.correctLabel,
    this.selectedPredictionIndex,
  });

  factory CaseRecord.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['status'] as String?)?.trim();
    final entryType = (json['entry_type'] as String?)?.toLowerCase().trim() ?? '';
    final correctLabel = json['correct_label'] as String?;
    final isLabeled =
        (json['isLabeled'] == true) ||
        (correctLabel != null && correctLabel.trim().isNotEmpty);

    String resolvedStatus;
    if (entryType == 'reject') {
      resolvedStatus = 'Rejected';
    } else if (entryType == 'uncertain') {
      resolvedStatus = 'Uncertain';
    } else {
      resolvedStatus = rawStatus ?? 'pending';
    }

    return CaseRecord(
      caseId: json['case_id'] as String? ?? '',
      imageId: json['image_id'] as String?,
      predictions:
          (json['predictions'] as List<dynamic>?)
              ?.map((p) => p as Map<String, dynamic>)
              .toList() ??
          [],
      status: resolvedStatus,
      entryType: entryType.isEmpty ? null : entryType,
      gender: json['gender'] as String?,
      age: json['age'] as String?,
      location: json['location'] as String?,
      symptoms:
          (json['symptoms'] as List<dynamic>?)
              ?.map((s) => s.toString())
              .toList() ??
          [],
      imagePaths:
          (json['image_paths'] as List<dynamic>?)
              ?.map((s) => s.toString())
              .toList() ??
          [],
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      isLabeled: isLabeled,
      correctLabel: correctLabel,
      selectedPredictionIndex: json['selected_prediction_index'] as int?,
    );
  }

  /// Get the top prediction label if available
  String get topPredictionLabel {
    if (predictions.isEmpty) return 'No prediction';
    return predictions.first['label'] as String? ?? 'Unknown';
  }

  /// Get the top prediction confidence
  double get topPredictionConfidence {
    if (predictions.isEmpty) return 0.0;
    return (predictions.first['confidence'] as num?)?.toDouble() ?? 0.0;
  }
}

/// Service for managing case records via the backend API.
class CaseService {
  CaseService(this._appState);

  final AppState _appState;

  /// Fetch all cases from the backend.
  /// Optionally filter by status: 'Confirmed', 'Rejected', 'pending', etc.
  Future<List<CaseRecord>> fetchCases({String? status, int limit = 100}) async {
    log('Fetching cases from backend', name: 'CaseService');
    log('Using base URL: ${ApiConfig.baseUrl}', name: 'CaseService');

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/cases').replace(
        queryParameters: {
          if (status != null) 'status': status,
          'limit': limit.toString(),
        },
      );

      log('Calling: $uri', name: 'CaseService');

      final headers = ApiConfig.buildHeaders(
        token: _appState.accessToken,
        userId: _appState.userId,
        userRole: _appState.userRole,
      );

      final response = await http
          .get(uri, headers: headers)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Request timed out'),
          );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final casesJson = jsonResponse['cases'] as List<dynamic>? ?? [];

        final cases =
            casesJson
                .map((c) => CaseRecord.fromJson(c as Map<String, dynamic>))
                .toList();

        log('Fetched ${cases.length} cases', name: 'CaseService');
        return cases;
      } else {
        log(
          'Failed to fetch cases: ${response.statusCode}',
          name: 'CaseService',
        );
        throw Exception('Failed to fetch cases: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      log('Network error: $e', name: 'CaseService');
      throw Exception(
        'Cannot connect to server. Check if the backend is running.',
      );
    } catch (e) {
      log('Error fetching cases: $e', name: 'CaseService');
      rethrow;
    }
  }

  /// Fetch the next running case ID from the backend.
  Future<String> fetchNextCaseId() async {
    log('Fetching next case ID from backend', name: 'CaseService');

    try {
      final headers = ApiConfig.buildHeaders(
        token: _appState.accessToken,
        userId: _appState.userId,
        userRole: _appState.userRole,
      );

      final response = await http
          .post(ApiConfig.nextCaseIdUri, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final caseId = jsonResponse['case_id']?.toString();
        if (caseId == null || caseId.isEmpty) {
          throw Exception('Invalid case ID response');
        }
        return caseId;
      } else {
        log(
          'Failed to fetch case ID: ${response.statusCode}',
          name: 'CaseService',
        );
        throw Exception('Failed to fetch case ID: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      log('Network error: $e', name: 'CaseService');
      throw Exception('Cannot connect to server.');
    } catch (e) {
      log('Error fetching case ID: $e', name: 'CaseService');
      rethrow;
    }
  }

  /// Release the most recently issued case ID if it was not used.
  Future<void> releaseCaseId(String caseId) async {
    log('Releasing case ID $caseId', name: 'CaseService');

    try {
      final headers = ApiConfig.buildHeaders(
        json: true,
        token: _appState.accessToken,
        userId: _appState.userId,
        userRole: _appState.userRole,
      );

      final response = await http
          .post(
            ApiConfig.releaseCaseIdUri,
            headers: headers,
            body: jsonEncode({'case_id': caseId}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        log(
          'Failed to release case ID: ${response.statusCode}',
          name: 'CaseService',
        );
        throw Exception('Failed to release case ID: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      log('Network error: $e', name: 'CaseService');
      throw Exception('Cannot connect to server.');
    } catch (e) {
      log('Error releasing case ID: $e', name: 'CaseService');
      rethrow;
    }
  }

  /// Log a confirmed/pending case to the backend.
  Future<void> logCase({
    required String caseId,
    String? imageId,
    List<Map<String, dynamic>> predictions = const [],
    required String status,
    String? gender,
    String? age,
    String? location,
    List<String> symptoms = const [],
    List<String> imagePaths = const [], // Image paths to store
    Map<String, String>? imageDecisions,
    String? notes,
    int? selectedPredictionIndex, // Index of image selected for prediction
  }) async {
    log('Logging case $caseId with status $status', name: 'CaseService');

    try {
      final headers = ApiConfig.buildHeaders(
        json: true,
        token: _appState.accessToken,
        userId: _appState.userId,
        userRole: _appState.userRole,
      );

      final body = jsonEncode({
        'case_id': caseId,
        if (imageId != null) 'image_id': imageId,
        'predictions': predictions,
        'status': status,
        if (gender != null) 'gender': gender,
        if (age != null) 'age': age,
        if (location != null) 'location': location,
        'symptoms': symptoms,
        'image_paths': imagePaths, // Include image paths
        if (imageDecisions != null && imageDecisions.isNotEmpty)
          'image_decisions': imageDecisions,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        'created_at': DateTime.now().toIso8601String(),
        if (selectedPredictionIndex != null)
          'selected_prediction_index': selectedPredictionIndex,
      });

      final response = await http
          .post(ApiConfig.casesUri, headers: headers, body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        log('Case logged successfully', name: 'CaseService');
      } else {
        log('Failed to log case: ${response.statusCode}', name: 'CaseService');
        throw Exception('Failed to log case: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      log('Network error: $e', name: 'CaseService');
      throw Exception('Cannot connect to server.');
    } catch (e) {
      log('Error logging case: $e', name: 'CaseService');
      rethrow;
    }
  }

  /// Update an existing case record.
  Future<void> updateCase({
    required String caseId,
    String? gender,
    String? age,
    String? location,
    List<String>? symptoms,
  }) async {
    log('Updating case $caseId', name: 'CaseService');

    final payload = <String, dynamic>{};
    if (gender != null) payload['gender'] = gender;
    if (age != null) payload['age'] = age;
    if (location != null) payload['location'] = location;
    if (symptoms != null) payload['symptoms'] = symptoms;
    if (payload.isEmpty) {
      log('No fields provided for update', name: 'CaseService');
      return;
    }

    try {
      final headers = ApiConfig.buildHeaders(
        json: true,
        token: _appState.accessToken,
        userId: _appState.userId,
        userRole: _appState.userRole,
      );

      final uri = Uri.parse('${ApiConfig.baseUrl}/cases/$caseId');
      final response = await http
          .put(uri, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        log('Case updated successfully', name: 'CaseService');
      } else {
        log('Failed to update case: ${response.statusCode}', name: 'CaseService');
        throw Exception('Failed to update case: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      log('Network error: $e', name: 'CaseService');
      throw Exception('Cannot connect to server.');
    } catch (e) {
      log('Error updating case: $e', name: 'CaseService');
      rethrow;
    }
  }

  /// Log a rejected case to the backend.
  Future<void> rejectCase({
    required String caseId,
    String? imageId,
    String? reason,
    String? notes,
    List<Map<String, dynamic>> predictions = const [],
    String? gender,
    String? age,
    String? location,
    List<String> symptoms = const [],
    List<String> imagePaths = const [],
    Map<String, String>? imageDecisions,
    int? selectedPredictionIndex, // Index of image selected for prediction
  }) async {
    log('Rejecting case $caseId', name: 'CaseService');

    try {
      final headers = ApiConfig.buildHeaders(
        json: true,
        token: _appState.accessToken,
        userId: _appState.userId,
        userRole: _appState.userRole,
      );

      final body = jsonEncode({
        'case_id': caseId,
        if (imageId != null) 'image_id': imageId,
        if (reason != null) 'reason': reason,
        if (notes != null) 'notes': notes,
        'predictions': predictions,
        if (gender != null) 'gender': gender,
        if (age != null) 'age': age,
        if (location != null) 'location': location,
        'symptoms': symptoms,
        'image_paths': imagePaths,
        if (imageDecisions != null && imageDecisions.isNotEmpty)
          'image_decisions': imageDecisions,
        'created_at': DateTime.now().toIso8601String(),
        if (selectedPredictionIndex != null)
          'selected_prediction_index': selectedPredictionIndex,
      });

      final response = await http
          .post(ApiConfig.rejectCaseUri, headers: headers, body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        log('Case rejected successfully', name: 'CaseService');
      } else {
        log(
          'Failed to reject case: ${response.statusCode}',
          name: 'CaseService',
        );
        throw Exception('Failed to reject case: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      log('Network error: $e', name: 'CaseService');
      throw Exception('Cannot connect to server.');
    } catch (e) {
      log('Error rejecting case: $e', name: 'CaseService');
      rethrow;
    }
  }

  /// Check whether a case is selected for active learning labeling.
  /// Returns true if the case appears in the top-k uncertain candidates.
  Future<bool> isActiveLearningCandidate({
    required String caseId,
    int topK = 5,
    String? entryType,
    String? status,
  }) async {
    log('Checking AL candidates for case $caseId', name: 'CaseService');

    try {
      final headers = ApiConfig.buildHeaders(
        json: true,
        token: _appState.accessToken,
        userId: _appState.userId,
        userRole: _appState.userRole,
      );

      final body = jsonEncode({
        'top_k': topK,
        if (entryType != null && entryType.trim().isNotEmpty)
          'entry_type': entryType.trim(),
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      });

      final response = await http
          .post(
            ApiConfig.activeLearningCandidatesUri,
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = (jsonResponse['candidates'] as List<dynamic>? ?? []);
        for (final item in candidates) {
          if (item is Map<String, dynamic>) {
            final id = item['case_id']?.toString();
            if (id == caseId) return true;
          }
        }
        return false;
      } else {
        log(
          'Failed to fetch AL candidates: ${response.statusCode}',
          name: 'CaseService',
        );
        throw Exception(
          'Failed to fetch AL candidates: ${response.statusCode}',
        );
      }
    } on SocketException catch (e) {
      log('Network error: $e', name: 'CaseService');
      throw Exception('Cannot connect to server.');
    } catch (e) {
      log('Error checking AL candidates: $e', name: 'CaseService');
      rethrow;
    }
  }

  /// Fetch active learning candidates with margin scores.
  Future<List<Map<String, dynamic>>> fetchActiveLearningCandidates({
    int topK = 50,
    String? entryType,
    String? status,
  }) async {
    log('Fetching AL candidates (topK=$topK)', name: 'CaseService');

    try {
      final headers = ApiConfig.buildHeaders(
        json: true,
        token: _appState.accessToken,
        userId: _appState.userId,
        userRole: _appState.userRole,
      );

      final body = jsonEncode({
        'top_k': topK,
        if (entryType != null && entryType.trim().isNotEmpty)
          'entry_type': entryType.trim(),
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      });

      final response = await http
          .post(
            ApiConfig.activeLearningCandidatesUri,
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates =
            (jsonResponse['candidates'] as List<dynamic>? ?? []);
        return candidates
            .whereType<Map<String, dynamic>>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else {
        log(
          'Failed to fetch AL candidates: ${response.statusCode}',
          name: 'CaseService',
        );
        throw Exception(
          'Failed to fetch AL candidates: ${response.statusCode}',
        );
      }
    } on SocketException catch (e) {
      log('Network error: $e', name: 'CaseService');
      throw Exception('Cannot connect to server.');
    } catch (e) {
      log('Error fetching AL candidates: $e', name: 'CaseService');
      rethrow;
    }
  }

  // (bridge-frontend-backend): Add saveAnnotations() method
  // This method bridges AnnotateScreen output to the backend.
  // It sends the annotation data (strokes, boxes, correct label) to the server
  // for storage and future active learning model retraining.
  //
  Future<void> saveAnnotations({
    required String caseId,
    required int imageIndex,
    required String correctLabel,
    List<Map<String, dynamic>> strokes = const [],
    List<Map<String, dynamic>> boxes = const [],
    String? caseUserId,
    String? notes,
  }) async {
    final role = _appState.userRole.trim().toLowerCase();
    if (role == 'gp') {
      log('Blocked GP annotation attempt for case $caseId', name: 'CaseService');
      throw Exception('GP role is not allowed to annotate rejected cases');
    }

    log('Saving annotations for case $caseId, image $imageIndex', name: 'CaseService');
  
    try {
      final headers = ApiConfig.buildHeaders(
        json: true,
        token: _appState.accessToken,
        userId: _appState.userId,
        userRole: _appState.userRole,
      );
      final body = jsonEncode({
        'image_index': imageIndex,
        'correct_label': correctLabel,
        'annotations': {
          'strokes': strokes,
          'boxes': boxes,
        },
        if (caseUserId != null && caseUserId.trim().isNotEmpty)
          'case_user_id': caseUserId.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        'annotated_at': DateTime.now().toIso8601String(),
      });
  
      final response = await http
          .post(ApiConfig.annotationsUri(caseId), headers: headers, body: body)
          .timeout(const Duration(seconds: 10));
  
      if (response.statusCode == 200) {
        log('Annotations saved successfully', name: 'CaseService');
      } else {
        log('Failed to save annotations: ${response.statusCode}', name: 'CaseService');
        throw Exception('Failed to save annotations: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      log('Network error: $e', name: 'CaseService');
      throw Exception('Cannot connect to server.');
    } catch (e) {
      log('Error saving annotations: $e', name: 'CaseService');
      rethrow;
    }
  }
}
