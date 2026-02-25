import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import '../../app_state.dart';

/// Service for getting ML predictions from the backend server.
/// 
/// This service calls the FastAPI backend's /check-image endpoint
class PredictionService {
  PredictionService(this._appState);

  final AppState _appState;

  /// Predict skin lesion classification for a single image.
  /// 
  /// Calls the backend /check-image endpoint and returns the predictions.
  /// Returns a list of predictions sorted by confidence (highest first).
  Future<Map<String, dynamic>> predictSingle(
    String imagePath, {
    String? caseId,
  }) async {
    log('Starting prediction for image: $imagePath', name: 'PredictionService');
    log('Using API endpoint: ${ApiConfig.checkImageUri}', name: 'PredictionService');

    try {
      final uri = _buildCheckUri(caseId);
      
      // Create multipart request
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', imagePath));
      
      request.headers.addAll(
        ApiConfig.buildHeaders(
          token: _appState.accessToken,
          userId: _appState.userId,
          userRole: _appState.userRole,
        ),
      );

      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timed out. Check if the server is running at ${ApiConfig.baseUrl}');
        },
      );
      
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        log('Server response: $jsonResponse', name: 'PredictionService');
        
        // Extract predictions from response
        final predictions = (jsonResponse['predictions'] as List<dynamic>? ?? [])
            .map((p) => p as Map<String, dynamic>)
            .toList();

        return {
          'status': jsonResponse['status'],
          'message': jsonResponse['message'],
          'blur_score': jsonResponse['blur_score'],
          'predictions': predictions,
          'image_id': jsonResponse['image_id'],
          'case_id': jsonResponse['case_id'],
        };
      } else {
        log('Server error: ${response.statusCode} - ${response.body}', name: 'PredictionService');
        throw Exception('Server error: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      log('Network error: $e', name: 'PredictionService');
      throw Exception('Cannot connect to server at ${ApiConfig.baseUrl}. Check if the server is running and the IP address is correct.');
    } catch (e) {
      log('Prediction error: $e', name: 'PredictionService');
      rethrow;
    }
  }
  /// Legacy method for compatibility - extracts just the predictions list
  Future<List<Map<String, dynamic>>> predict(String imagePath) async {
    final result = await predictSingle(imagePath);
    return (result['predictions'] as List<dynamic>? ?? [])
        .map((p) => p as Map<String, dynamic>)
        .toList();
  }

  /// Predict a selected image from a list of image paths.
  Future<Map<String, dynamic>> predictMultiple(
    List<String> imagePaths, {
    String? caseId,
    int? selectedIndex,
    void Function(int current, int total)? onProgress,
  }) async {
    if (imagePaths.isEmpty) {
      throw Exception('No images provided for prediction');
    }

    final index = (selectedIndex != null &&
            selectedIndex >= 0 &&
            selectedIndex < imagePaths.length)
        ? selectedIndex
        : 0;

    final selectedPath = imagePaths[index];
    log(
      'Predicting selected image (index $index) from ${imagePaths.length} images',
      name: 'PredictionService',
    );
    onProgress?.call(0, 1);

    final result = await predictSingle(selectedPath, caseId: caseId);

    onProgress?.call(1, 1);
    return {
      ...result,
      'selected_prediction_index': index,
    };
  }

  /*
  /// Aggregate predictions from multiple images by averaging confidence scores
  Map<String, dynamic> _aggregatePredictions(
    List<List<Map<String, dynamic>>> allPredictions,
  ) {
    // Initialize a map to accumulate confidence scores for each class
    final Map<String, double> classConfidenceSum = {};
    final Map<String, int> classCount = {};

    // Process each image's predictions
    for (final predictions in allPredictions) {
      for (final prediction in predictions) {
        final label = prediction['label'] as String;
        final confidence = (prediction['confidence'] as num).toDouble();

        // Accumulate confidence scores
        classConfidenceSum[label] = (classConfidenceSum[label] ?? 0) + confidence;
        classCount[label] = (classCount[label] ?? 0) + 1;
      }
    }

    // Calculate average confidence for each class
    final List<Map<String, dynamic>> aggregatedPredictions = [];
    classConfidenceSum.forEach((label, totalConfidence) {
      final count = classCount[label]!;
      final averageConfidence = totalConfidence / count;

      aggregatedPredictions.add({
        'label': label,
        'confidence': averageConfidence,
      });
    });

    // Sort by confidence descending
    aggregatedPredictions.sort((a, b) =>
      (b['confidence'] as double).compareTo(a['confidence'] as double)
    );

    // Normalize so that the sum of all confidences equals 1
    final total = aggregatedPredictions.fold(0.0,
      (sum, pred) => sum + (pred['confidence'] as double));

    if (total > 0) {
      for (final pred in aggregatedPredictions) {
        pred['confidence'] = (pred['confidence'] as double) / total;
      }
    }

    return {
      'predictions': aggregatedPredictions,
      'image_count': allPredictions.length,
      'aggregation_method': 'average_confidence'
    };
  }
  */

  /// Check if the backend server is reachable
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(ApiConfig.healthUri).timeout(
        const Duration(seconds: 5),
      );
      return response.statusCode == 200;
    } catch (e) {
      log('Health check failed: $e', name: 'PredictionService');
      return false;
    }
  }

  Uri _buildCheckUri(String? caseId) {
    final base = ApiConfig.checkImageUri;
    final trimmed = caseId?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return base;
    }
    return base.replace(
      queryParameters: {
        ...base.queryParameters,
        if (caseId != null) 'case_id': caseId,
        'predict_only': 'true',              // <-- skip save
      },
      
    );
  }
}
