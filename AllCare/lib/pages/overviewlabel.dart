import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../app_state.dart';
import '../features/case/api_config.dart';
import '../features/case/annotate_screen.dart';
import '../features/case/case_service.dart';
import '../routes.dart';
import '../widgets/calendar_widget.dart';

class LabelPage extends StatefulWidget {
  const LabelPage({super.key});

  @override
  State<LabelPage> createState() => _LabelPageState();
}

// Legacy label dialog kept for reference; replaced by AnnotateScreen-based flow.
/*
  void _showLabelDialog(Map<String, dynamic> sample) {
    final predictions = List<Map<String, dynamic>>.from(sample['predictions'] ?? []);
    String selectedLabel = predictions.isNotEmpty ? predictions[0]['label'] : '';
    final TextEditingController customLabelController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.label, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('Select Correct Diagnosis'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose the correct diagnosis for this case:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              const Text(
                'Suggested labels (based on AI predictions):',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Column(
                    children: predictions.map((pred) => Card(
                      elevation: 0,
                      color: Colors.grey[50],
                      margin: const EdgeInsets.only(bottom: 4),
                      child: RadioListTile<String>(
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                pred['label'],
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (pred['confidence'] as double) > 0.5 ? Colors.green[100] : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${(pred['confidence'] * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: (pred['confidence'] as double) > 0.5 ? Colors.green[700] : Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        value: pred['label'],
                        groupValue: selectedLabel,
                        onChanged: (value) {
                          selectedLabel = value!;
                          customLabelController.clear();
                        },
                      ),
                    )).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Or enter a custom diagnosis:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: customLabelController,
                decoration: InputDecoration(
                  labelText: 'Custom diagnosis',
                  hintText: 'Enter diagnosis name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.edit),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    selectedLabel = value;
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: selectedLabel.isNotEmpty
                ? () {
                    submitLabel(sample['case_id'], selectedLabel);
                    Navigator.of(context).pop();
                  }
                : null,
            icon: const Icon(Icons.check),
            label: const Text('Submit Label'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
*/

class _LabelPageState extends State<LabelPage> {
  List<Map<String, dynamic>> uncertainSamples = [];
  bool isLoading = true;
  String errorMessage = '';
  Map<String, dynamic>? retrainStatus;
  DateTime? _selectedDate;

  double calculateImageMargin(List<Map<String, dynamic>> predictions) {
    if (predictions.length < 2) return 1.0;
    final sorted = List<Map<String, dynamic>>.from(predictions)
      ..sort((a, b) => ((b['confidence'] as num?)?.toDouble() ?? 0)
          .compareTo((a['confidence'] as num?)?.toDouble() ?? 0));
    return (sorted[0]['confidence'] as num).toDouble() - (sorted[1]['confidence'] as num).toDouble();
  }

  /// Check if a given date has any samples
  /// Note: Active learning samples might not have date fields, in which case this always returns false
  bool _hasSamplesOnDate(DateTime date) {
    return uncertainSamples.any((sample) {
      final sampleDate = sample['created_at'] ?? sample['timestamp'] ?? sample['date'];
      if (sampleDate == null) return false;
      try {
        final d = DateTime.parse(sampleDate.toString()).toLocal();
        return d.year == date.year && d.month == date.month && d.day == date.day;
      } catch (_) {
        return false;
      }
    });
  }

  /// Get filtered samples based on selected date
  /// If no date is selected, returns all samples
  /// If samples don't have date fields, filtering won't work (returns all samples)
  List<Map<String, dynamic>> get filteredSamples {
    if (_selectedDate == null) return uncertainSamples;

    return uncertainSamples.where((sample) {
      final sampleDate = sample['created_at'] ?? sample['timestamp'] ?? sample['date'];
      if (sampleDate == null) return true; // If no date field, show all samples

      try {
        final d = DateTime.parse(sampleDate.toString()).toLocal();
        return d.year == _selectedDate!.year &&
               d.month == _selectedDate!.month &&
               d.day == _selectedDate!.day;
      } catch (_) {
        return true; // If date parsing fails, include the sample
      }
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    if (appState.userRole == 'gp') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GP role is not allowed to access labeling')),
        );
        Navigator.of(context).pushReplacementNamed(Routes.gpHome);
      });
      return;
    }

    fetchUncertainSamples();
    if (appState.userRole == 'admin') {
      fetchRetrainStatus();
    }
  }

  Future<void> fetchUncertainSamples() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // Get active learning candidates directly from backend
      final alResponse = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/active-learning/candidates'),
        headers: ApiConfig.buildHeaders(
          json: true,
          userId: appState.userId,
          userRole: appState.userRole,
        ),
        body: json.encode({
          'top_k': 5,
        }),
      );

      if (alResponse.statusCode == 200) {
        final alData = json.decode(alResponse.body);
        setState(() {
          uncertainSamples = List<Map<String, dynamic>>.from(alData['candidates'] ?? []);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to get active learning candidates: ${alResponse.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  Future<void> fetchRetrainStatus() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/model/retrain-status'),
        headers: ApiConfig.buildHeaders(
          json: true,
          userId: appState.userId,
          userRole: appState.userRole,
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          retrainStatus = data;
        });
      }
    } catch (e) {
      // Silently fail for status check
    }
  }

  Future<void> _retrainModel() async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/model/retrain'),
        headers: ApiConfig.buildHeaders(
          json: true,
          userId: appState.userId,
          userRole: appState.userRole,
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Model retraining started: ${data['message']}')),
          );
          // Refresh status after starting retrain
          await Future.delayed(const Duration(seconds: 2));
          fetchRetrainStatus();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start retraining: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting retraining: $e')),
        );
      }
    }
  }

  List<String> _extractImagePaths(Map<String, dynamic> sample) {
    final images = List<Map<String, dynamic>>.from(sample['images'] ?? []);
    final pathsFromImages = images
        .map((img) => (img['path'] ?? img['image_path'])?.toString() ?? '')
        .where((p) => p.trim().isNotEmpty)
        .toList();
    if (pathsFromImages.isNotEmpty) return pathsFromImages;

    final fallback = (sample['image_paths'] as List<dynamic>?)
            ?.map((p) => p.toString())
            .where((p) => p.trim().isNotEmpty)
            .toList() ??
        [];
    return fallback;
  }

  Future<void> _openAnnotateScreen(Map<String, dynamic> sample) async {
    final caseId = (sample['case_id'] ?? '').toString();
    final entryType = (sample['entry_type'] ?? '').toString().toLowerCase();
    final caseUserId = (sample['user_id'] ?? '').toString().trim();

    // Block GP users from entering annotation flow for rejected cases
    if (appState.userRole.toLowerCase() == 'gp' && entryType == 'reject') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GP role is not allowed to annotate rejected cases')),
        );
      }
      return;
    }

    final imagePaths = _extractImagePaths(sample);

    if (caseId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Missing case ID for annotation')),
        );
      }
      return;
    }

    if (imagePaths.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No images available to annotate for this case')),
        );
      }
      return;
    }

    final annotationResult = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => AnnotateScreen(
          caseId: caseId,
          imagePaths: imagePaths,
        ),
      ),
    );

    if (annotationResult == null || !mounted) return;

    final label = (annotationResult['class'] as String?)?.trim() ?? '';
    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a class before saving')),
      );
      return;
    }

    try {
      await CaseService().saveAnnotations(
        caseId: caseId,
        imageIndex: (annotationResult['imageIndex'] as num?)?.toInt() ?? 0,
        correctLabel: label,
        strokes: (annotationResult['strokes'] as List?)?.cast<Map<String, dynamic>>() ?? [],
        boxes: (annotationResult['boxes'] as List?)?.cast<Map<String, dynamic>>() ?? [],
        caseUserId: caseUserId.isEmpty ? null : caseUserId,
      );

      setState(() {
        uncertainSamples.removeWhere((c) => (c['case_id'] ?? '').toString() == caseId);
      });

      if (appState.userRole.toLowerCase() == 'admin') {
        fetchRetrainStatus();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Annotations saved')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save annotations: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.school, color: Colors.white),
            SizedBox(width: 8),
            Text('Overview Label Page'),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (appState.userRole.toLowerCase() == 'admin') ...[
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.model_training, size: 18),
                label: const Text('Retrain'),
                onPressed: _retrainModel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).primaryColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
          ],
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: fetchUncertainSamples,
              tooltip: 'Refresh samples',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white24,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark 
                ? [Theme.of(context).primaryColor, Theme.of(context).scaffoldBackgroundColor]
                : [Theme.of(context).primaryColor.withValues(alpha: 0.05), Theme.of(context).scaffoldBackgroundColor],
          ),
        ),
        child: Column(
          children: [
            // Retrain status banner for admins
            if (appState.userRole.toLowerCase() == 'admin' && retrainStatus != null) ...[
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: retrainStatus!['should_retrain'] 
                      ? Colors.orange.withValues(alpha: 0.1) 
                      : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: retrainStatus!['should_retrain'] ? Colors.orange : Colors.green,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      retrainStatus!['should_retrain'] ? Icons.warning : Icons.check_circle,
                      color: retrainStatus!['should_retrain'] ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            retrainStatus!['should_retrain'] ? 'Ready for Retraining' : 'Model Up to Date',
                            style: TextStyle(
                              color: retrainStatus!['should_retrain'] ? Colors.orange : Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            retrainStatus!['should_retrain']
                                ? '${retrainStatus!['new_samples_since_last']} new labels available'
                                : '${retrainStatus!['total_labeled_samples']} total labeled samples',
                            style: TextStyle(
                              color: retrainStatus!['should_retrain'] ? Colors.orange : Colors.green,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (retrainStatus!['should_retrain'])
                      ElevatedButton(
                        onPressed: _retrainModel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retrain Now'),
                      ),
                  ],
                ),
              ),
            ],
            // Calendar section
            CalendarWidget(
              selectedDate: _selectedDate,
              onDateSelected: (date) {
                setState(() {
                  _selectedDate = date;
                });
              },
              hasIndicatorForDate: _hasSamplesOnDate,
              isDark: isDark,
            ),
            // Main content
            Expanded(
              child: Builder(
                builder: (context) {
                  if (isLoading) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading uncertain samples...'),
                        ],
                      ),
                    );
                  }

                  if (errorMessage.isNotEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              errorMessage,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: fetchUncertainSamples,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (filteredSamples.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.disabled_by_default,
                              size: 64,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedDate != null ? 'No samples for this date' : 'All caught up!',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedDate != null
                                  ? 'No uncertain samples available for the selected date.'
                                  : 'No uncertain samples available for labeling at this time.',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredSamples.length,
                    itemBuilder: (context, index) {
                      final sample = filteredSamples[index];
                      final predictions = List<Map<String, dynamic>>.from(sample['predictions'] ?? []);
                      final margin = sample['margin'] ?? 0.0;
                      final images = List<Map<String, dynamic>>.from(sample['images'] ?? []);

                      return Card(
                        margin: const EdgeInsets.all(12.0),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with Case ID and Margin
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Case ${sample['case_id'] ?? 'Unknown'}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: margin < 0.1 ? Colors.red.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          margin < 0.1 ? Icons.warning : Icons.info_outline,
                                          size: 16,
                                          color: margin < 0.1 ? Colors.red : Colors.orange,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Margin: ${margin.toStringAsFixed(3)}',
                                          style: TextStyle(
                                            color: margin < 0.1 ? Colors.red : Colors.orange,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Display images in a grid
                              if (images.isNotEmpty) ...[
                                const Text(
                                  'Images in this case:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                    childAspectRatio: 1,
                                  ),
                                  itemCount: images.length,
                                  itemBuilder: (context, imgIndex) {
                                    final image = images[imgIndex];
                                    final imagePredictions = List<Map<String, dynamic>>.from(image['predictions'] ?? []);
                                    final imageMargin = calculateImageMargin(imagePredictions);
                                    final imagePath = image['path'] ?? image['image_path'];

                                    return Card(
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Image thumbnail
                                          Expanded(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                                color: Colors.grey[200],
                                              ),
                                              child: imagePath != null
                                                  ? ClipRRect(
                                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                                      child: Image.network(
                                                        '${ApiConfig.baseUrl}/images/$imagePath',
                                                        fit: BoxFit.cover,
                                                        width: double.infinity,
                                                        headers: ApiConfig.buildHeaders(
                                                          userId: appState.userId,
                                                          userRole: appState.userRole,
                                                        ),
                                                        errorBuilder: (context, error, stackTrace) {
                                                          return Container(
                                                            color: Colors.grey[300],
                                                            child: const Icon(
                                                              Icons.image_not_supported,
                                                              size: 40,
                                                              color: Colors.grey,
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons.image,
                                                      size: 40,
                                                      color: Colors.grey,
                                                    ),
                                            ),
                                          ),
                                          // Image info
                                          Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Image ${imgIndex + 1}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                Text(
                                                  'Margin: ${imageMargin.toStringAsFixed(3)}',
                                                  style: TextStyle(
                                                    color: imageMargin < 0.1 ? Colors.red : Colors.grey[600],
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                ...imagePredictions.take(2).map((pred) => Text(
                                                      '${pred['label']}: ${(pred['confidence'] * 100).toStringAsFixed(0)}%',
                                                      style: TextStyle(
                                                        color: pred['confidence'] > 0.5 ? Colors.green[700] : Colors.grey[600],
                                                        fontSize: 10,
                                                      ),
                                                    )),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ] else ...[
                                // Fallback for cases without images structure
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.grey),
                                      SizedBox(width: 8),
                                      Text(
                                        'No images available for preview',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 20),

                              // Predictions summary
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Top Predictions:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ...predictions.take(3).map((pred) => Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  pred['label'],
                                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: pred['confidence'] > 0.5 ? Colors.green : Colors.grey[300],
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '${(pred['confidence'] * 100).toStringAsFixed(0)}%',
                                                  style: TextStyle(
                                                    color: pred['confidence'] > 0.5 ? Colors.white : Colors.black,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Action button
                              SizedBox(
                                width: double.infinity,
                                child: Builder(
                                  builder: (context) {
                                    final isGp = appState.userRole.toLowerCase() == 'gp';
                                    final isRejected = (sample['entry_type'] ?? '').toString().toLowerCase() == 'reject';
                                    final isDisabled = isGp && isRejected;

                                    return ElevatedButton.icon(
                                      onPressed: isDisabled ? null : () => _openAnnotateScreen(sample),
                                      icon: Icon(isDisabled ? Icons.lock : Icons.label),
                                      label: Text(isDisabled ? 'Annotation Restricted' : 'Label This Case'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        backgroundColor: isDisabled ? Colors.grey[300] : null,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
