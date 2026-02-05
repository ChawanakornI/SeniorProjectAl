import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/glass.dart';
import 'api_config.dart';
import 'prediction_service.dart';
import '../../pages/result_screen.dart';
import 'create_case.dart';

/// Case Summary screen - shows case details after images are saved.
/// Has two modes:
/// 1. Pre-prediction: Shows Edit and Run Prediction buttons
/// 2. Post-prediction: Shows prediction results (legacy mode)
class CaseSummaryScreen extends StatefulWidget {
  final String caseId;
  final String? gender;
  final String? age;
  final String? location;
  final List<String> symptoms;
  final List<String> imagePaths;
  final String imagePath; // For backward compatibility
  final List<Map<String, dynamic>> predictions;
  final double? blurScore;
  final String? createdAt;
  final String? updatedAt;
  final int? imageCount;
  final String? aggregationInfo;
  final bool isPrePrediction; // NEW: Flag to show Edit/Run Prediction buttons
  final int predictIndex; // Index of image to use for prediction (from carousel)

  const CaseSummaryScreen({
    super.key,
    required this.caseId,
    required this.gender,
    required this.age,
    required this.location,
    required this.symptoms,
    this.imagePaths = const [],
    this.imagePath = '',
    this.predictions = const [],
    this.blurScore,
    this.createdAt,
    this.updatedAt,
    this.imageCount,
    this.aggregationInfo,
    this.isPrePrediction = false, // Default to old behavior
    this.predictIndex = 0, // Default to first image
  });

  @override
  State<CaseSummaryScreen> createState() => _CaseSummaryScreenState();
}

class _CaseSummaryScreenState extends State<CaseSummaryScreen> {
  bool _isLoading = false;
  late final String _fallbackCreatedAt;

  // For image carousel
  late PageController _imagePageController;
  int _currentImageIndex = 0;

  // Get the main image path (either from imagePaths or imagePath)
  String get _mainImagePath {
    final paths = _allImagePaths;
    return paths.isNotEmpty ? paths.first : '';
  }

  // Get all image paths (deduplicated)
  List<String> get _allImagePaths {
    final uniquePaths = <String>{};
    
    // Add paths from imagePaths list
    for (final p in widget.imagePaths) {
      final trimmed = p.trim();
      if (trimmed.isNotEmpty) {
        uniquePaths.add(trimmed);
      }
    }

    // Only add fallback imagePath if imagePaths is empty
    // This prevents duplicates when both contain the same path
    if (uniquePaths.isEmpty) {
      final fallback = widget.imagePath.trim();
      if (fallback.isNotEmpty) {
        uniquePaths.add(fallback);
      }
    }

    return uniquePaths.where((path) {
      if (_isNetworkPath(path)) return true;
      if (_isBackendRelativePath(path)) return true; // Backend paths are valid
      return File(path).existsSync();
    }).toList();
  }

  bool _isNetworkPath(String path) {
    final lower = path.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  /// Check if path is a backend-relative path (e.g., 'user001/uuid.jpg')
  /// These need to be converted to full URLs for network access
  bool _isBackendRelativePath(String path) {
    // Backend paths look like 'user001/uuid.jpg' or 'userXXX/something.jpg'
    // They don't start with '/' (not absolute) and aren't URLs
    if (path.isEmpty) return false;
    if (_isNetworkPath(path)) return false;
    if (path.startsWith('/')) return false; // Absolute local path
    // Check if it matches pattern: userXXX/filename.ext
    return path.contains('/') && !path.contains('\\');
  }

  /// Convert a path to the appropriate format for display
  /// - Backend relative paths → full network URLs
  /// - Already full URLs → unchanged
  /// - Local paths → unchanged
  String _resolveImagePath(String path) {
    if (_isBackendRelativePath(path)) {
      return '${ApiConfig.baseUrl}/images/$path';
    }
    return path;
  }

  @override
  void initState() {
    super.initState();
    // Start carousel at the selected prediction image index
    _currentImageIndex = widget.predictIndex;
    _imagePageController = PageController(initialPage: widget.predictIndex);
    _fallbackCreatedAt = DateTime.now().toIso8601String();
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  /// Run ML prediction and navigate to Result screen
  Future<void> _runPrediction() async {
    if (_allImagePaths.isEmpty || _mainImagePath.isEmpty) return;

    setState(() => _isLoading = true);

    // Show glassmorphism loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDarkLoading = Theme.of(ctx).brightness == Brightness.dark;
        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                width: 280,
                padding: const EdgeInsets.symmetric(
                  vertical: 40,
                  horizontal: 32,
                ),
                decoration: glassBox(
                  isDarkLoading,
                  radius: 24,
                  highlight: true,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Loading spinner with gradient ring
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer gradient ring
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                Colors.blue.shade400,
                                Colors.purple.shade500,
                                Colors.blue.shade300,
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(5),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    isDarkLoading
                                        ? const Color(0xFF0B1628)
                                        : Colors.white,
                              ),
                            ),
                          ),
                        ),
                        // Inner spinner
                        const SizedBox(
                          width: 50,
                          height: 50,
                          child: CircularProgressIndicator(
                            color: Colors.blueAccent,
                            strokeWidth: 4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Analyzing Images',
                      style: TextStyle(
                        color: isDarkLoading ? Colors.white : Colors.black87,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Our AI is processing your skin images...\nThis may take a moment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            isDarkLoading ? Colors.white70 : Colors.grey[600],
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Image count indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: (isDarkLoading ? Colors.white : Colors.black)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.image,
                            size: 16,
                            color:
                                isDarkLoading
                                    ? Colors.white60
                                    : Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Builder(
                              builder: (_) {
                                final totalImages = _allImagePaths.length;
                                final safeIndex =
                                    totalImages == 0
                                        ? 0
                                        : (_currentImageIndex < 0
                                            ? 0
                                            : (_currentImageIndex >= totalImages
                                                ? totalImages - 1
                                                : _currentImageIndex));
                                final label =
                                    totalImages > 1
                                        ? 'Selected image ${safeIndex + 1} of $totalImages'
                                        : 'Selected image';
                                return Text(
                                  '$label being analyzed',
                                  style: TextStyle(
                                    color:
                                        isDarkLoading
                                            ? Colors.white60
                                            : Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    try {
      // Run prediction on the selected image only
      final safeIndex =
          _currentImageIndex < _allImagePaths.length ? _currentImageIndex : 0;
      final selectedPath = _allImagePaths[safeIndex];
      final predictionResult =
          await context.read<PredictionService>().predictSingle(
                selectedPath,
                caseId: widget.caseId,
              );
      final predictions =
          (predictionResult['predictions'] as List<dynamic>? ?? [])
              .map((p) => p as Map<String, dynamic>)
              .toList();

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      setState(() => _isLoading = false);

      // Navigate to Result screen with the selected prediction index
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder:
              (_) => ResultScreen(
                caseId: widget.caseId,
                gender: widget.gender,
                age: widget.age,
                location: widget.location,
                symptoms: widget.symptoms,
                imagePaths: _allImagePaths,
                predictions: predictions,
                selectedPredictionIndex: safeIndex,
              ),
        ),
      );

      // Handle result (confirm/reject/uncertain)
      if (result != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Case marked as: $result')));
        // Navigate back to home after decision
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Prediction failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final createdAtRaw = _resolveCreatedAtRaw();
    final updatedAtRaw = _resolveUpdatedAtRaw(createdAtRaw);
    final createdAtText = _formatTimestamp(createdAtRaw);
    final updatedAtText = _formatTimestamp(updatedAtRaw);

    final topPrediction =
        widget.predictions.isNotEmpty ? widget.predictions.first : null;
    final diagnosticPaths = _allImagePaths;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Stack(
          children: [
            Container(
              height: kToolbarHeight,
              decoration: BoxDecoration(
                color: Colors.transparent,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
            ),
            AppBar(
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: isDark ? Colors.white : Colors.black,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Case Summary',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    color:
                        isDark
                            ? Colors.black.withValues(alpha: 0.45)
                            : const Color(0xFFFBFBFB),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      body: Container(
        color:
            isDark
                ? const Color.fromARGB(255, 0, 0, 0)
                : const Color(0xFFFBFBFB),

        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Status Banner
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: (widget.isPrePrediction
                                    ? Colors.blue
                                    : Colors.green)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: (widget.isPrePrediction
                                      ? Colors.blue
                                      : Colors.green)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.isPrePrediction
                                    ? Icons.save
                                    : Icons.check_circle,
                                color:
                                    widget.isPrePrediction
                                        ? Colors.blue
                                        : Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.isPrePrediction
                                    ? 'Images Saved'
                                    : 'Case Recorded Successfully',
                                style: TextStyle(
                                  color:
                                      widget.isPrePrediction
                                          ? Colors.blue
                                          : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 2. Main Details Card
                      _buildGlassCard(
                        isDark: isDark,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Case ID',
                                  style: TextStyle(
                                    color:
                                        isDark
                                            ? Colors.white54
                                            : Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  widget.caseId,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDetailItem(
                                    isDark,
                                    'Created at',
                                    createdAtText,
                                  ),
                                ),
                                Expanded(
                                  child: _buildDetailItem(
                                    isDark,
                                    'Last updated',
                                    updatedAtText,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDetailItem(
                                    isDark,
                                    'Gender',
                                    widget.gender ?? '-',
                                  ),
                                ),
                                Expanded(
                                  child: _buildDetailItem(
                                    isDark,
                                    'Age',
                                    widget.age ?? '-',
                                  ),
                                ),
                                Expanded(
                                  child: _buildDetailItem(
                                    isDark,
                                    'Location',
                                    widget.location ?? '-',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3. Image Card
                      _buildGlassCard(
                        isDark: isDark,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Diagnostic Image',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (diagnosticPaths.length > 1)
                                  Text(
                                    '${diagnosticPaths.length} images',
                                    style: TextStyle(
                                      color:
                                          isDark
                                              ? Colors.white60
                                              : Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Swipeable image carousel
                            if (diagnosticPaths.isNotEmpty)
                              Column(
                                children: [
                                  SizedBox(
                                    height: 220,
                                    child: Stack(
                                      children: [
                                        PageView.builder(
                                          controller: _imagePageController,
                                          itemCount: diagnosticPaths.length,
                                          onPageChanged: (index) {
                                            setState(
                                              () => _currentImageIndex = index,
                                            );
                                          },
                                          itemBuilder: (context, index) {
                                            // Show badge on currently viewed image (will be used for prediction)
                                            final isSelectedForPrediction = index == _currentImageIndex;
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                  ),
                                              child: Stack(
                                                children: [
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(12),
                                                    child: _buildDiagnosticImage(
                                                      diagnosticPaths[index],
                                                      isDark,
                                                    ),
                                                  ),
                                                  // "Selected for Prediction" badge
                                                  if (isSelectedForPrediction)
                                                    Positioned(
                                                      bottom: 12,
                                                      left: 0,
                                                      right: 0,
                                                      child: Center(
                                                        child: ClipRRect(
                                                          borderRadius: BorderRadius.circular(16),
                                                          child: BackdropFilter(
                                                            filter: ImageFilter.blur(
                                                              sigmaX: 8,
                                                              sigmaY: 8,
                                                            ),
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(
                                                                horizontal: 12,
                                                                vertical: 6,
                                                              ),
                                                              decoration: BoxDecoration(
                                                                color: Colors.blue.withValues(alpha: 0.7),
                                                                borderRadius: BorderRadius.circular(16),
                                                                border: Border.all(
                                                                  color: Colors.white.withValues(alpha: 0.3),
                                                                  width: 1,
                                                                ),
                                                              ),
                                                              child: const Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Icon(
                                                                    Icons.check_circle,
                                                                    color: Colors.white,
                                                                    size: 14,
                                                                  ),
                                                                  SizedBox(width: 6),
                                                                  Text(
                                                                    'Selected for Prediction',
                                                                    style: TextStyle(
                                                                      color: Colors.white,
                                                                      fontSize: 11,
                                                                      fontWeight: FontWeight.w600,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                        // Image counter overlay (only for multiple images)
                                        if (diagnosticPaths.length > 1)
                                          Positioned(
                                            top: 12,
                                            right: 12,
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              child: BackdropFilter(
                                                filter: ImageFilter.blur(
                                                  sigmaX: 8,
                                                  sigmaY: 8,
                                                ),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.5),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '${_currentImageIndex + 1} / ${diagnosticPaths.length}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Page indicator dots (only for multiple images)
                                  if (diagnosticPaths.length > 1) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(
                                        diagnosticPaths.length,
                                        (index) {
                                          final isActive =
                                              index == _currentImageIndex;
                                          // The current image is the one that will be used for prediction
                                          final isPredictIndex =
                                              index == _currentImageIndex;
                                          return AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 3,
                                            ),
                                            width: isActive ? 20 : 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                              color: isActive
                                                  ? (isPredictIndex
                                                      ? Colors.green[500]
                                                      : (isDark
                                                          ? Colors.blue[400]
                                                          : Colors.blue[600]))
                                                  : (isPredictIndex
                                                      ? Colors.green[300]
                                                      : (isDark
                                                          ? Colors.white24
                                                          : Colors.grey.shade300)),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                              )
                            else
                              _buildMissingImagePlaceholder(isDark),
                            const SizedBox(height: 16),

                            // Only show prediction info if NOT pre-prediction mode
                            if (!widget.isPrePrediction &&
                                topPrediction != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'AI Prediction',
                                      style: TextStyle(
                                        color:
                                            isDark
                                                ? Colors.white70
                                                : Colors.grey[700],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      topPrediction['label'] ?? 'Unknown',
                                      style: TextStyle(
                                        color:
                                            isDark
                                                ? Colors.white
                                                : Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Confidence: ${((topPrediction['confidence'] ?? 0) * 100).toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        color:
                                            isDark
                                                ? Colors.blue[200]
                                                : Colors.blue[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (widget.imageCount != null &&
                                        widget.imageCount! > 1) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Based on ${widget.imageCount} images',
                                        style: TextStyle(
                                          color:
                                              isDark
                                                  ? Colors.white60
                                                  : Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ] else if (widget.isPrePrediction) ...[
                              // Show "Ready for prediction" message
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.blue.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.psychology,
                                      color: Colors.blue[600],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Ready for AI Prediction',
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 4. Symptoms Card
                      if (widget.symptoms.isNotEmpty)
                        _buildGlassCard(
                          isDark: isDark,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reported Symptoms',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children:
                                    widget.symptoms
                                        .map(
                                          (s) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  isDark
                                                      ? Colors.blue.withValues(alpha: 
                                                        0.2,
                                                      )
                                                      : Colors.blue.withValues(alpha: 
                                                        0.1,
                                                      ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: Colors.blue.withValues(alpha: 
                                                  0.3,
                                                ),
                                              ),
                                            ),
                                            child: Text(
                                              s,
                                              style: TextStyle(
                                                color:
                                                    isDark
                                                        ? Colors.blue[100]
                                                        : Colors.blue[800],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),

              // Bottom buttons
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withValues(alpha: 0.5) : Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child:
                    widget.isPrePrediction
                        ? _buildPrePredictionButtons(isDark)
                        : _buildPostPredictionButton(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Buttons for pre-prediction mode: Edit and Run Prediction
  Widget _buildPrePredictionButtons(bool isDark) {
    return Row(
      children: [
        // Edit button
        Expanded(
          child: OutlinedButton(
            onPressed:
                _isLoading
                    ? null
                    : () {
                      // Navigate back to Create Case page with pre-filled values
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder:
                              (_) => NewCaseScreen(
                                initialCaseId: widget.caseId,
                                initialGender: widget.gender,
                                initialAge: widget.age,
                                initialLocation: widget.location,
                                initialSymptoms: widget.symptoms,
                                initialImagePaths: _allImagePaths,
                                initialPredictions: widget.predictions,
                                initialCreatedAt: _resolveCreatedAtRaw(),
                                initialUpdatedAt: _resolveUpdatedAtRaw(
                                  _resolveCreatedAtRaw(),
                                ),
                                isEditing: true,
                              ),
                        ),
                      );
                    },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(
                color: isDark ? Colors.white54 : Colors.grey.shade400,
              ),
              foregroundColor: isDark ? Colors.white70 : Colors.grey[700],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Edit',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Run Prediction button
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _runPrediction,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : Colors.black,
              foregroundColor: isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Run Prediction',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  /// Button for post-prediction mode: Back to Home
  Widget _buildPostPredictionButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.white : Colors.black,
          foregroundColor: isDark ? Colors.black : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Back to Home',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildDiagnosticImage(String path, bool isDark) {
    // Resolve backend-relative paths to full URLs
    final resolvedPath = _resolveImagePath(path);
    final isNetworkImage = _isNetworkPath(resolvedPath);
    final placeholder = _buildMissingImagePlaceholder(isDark);

    return isNetworkImage
        ? Image.network(
          resolvedPath,
          width: double.infinity,
          height: 220,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
        )
        : Image.file(
          File(resolvedPath),
          width: double.infinity,
          height: 220,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
        );
  }

  Widget _buildMissingImagePlaceholder(bool isDark) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black12,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (isDark ? Colors.white24 : Colors.black12)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            color: isDark ? Colors.white54 : Colors.grey[600],
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'Diagnostic image not available',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey[700],
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'The file could not be found for this case.',
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.grey[600],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(bool isDark, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.grey[600],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard({required bool isDark, required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: glassBox(isDark, radius: 16, highlight: true),
          child: child,
        ),
      ),
    );
  }

  String _resolveCreatedAtRaw() {
    final raw = widget.createdAt?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
    return _fallbackCreatedAt;
  }

  String _resolveUpdatedAtRaw(String createdAtRaw) {
    final raw = widget.updatedAt?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
    return createdAtRaw;
  }

  DateTime? _parseTimestamp(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return DateTime.parse(raw.trim());
    } catch (_) {
      return null;
    }
  }

  DateTime _toThailandTime(DateTime dateTime) {
    final utc = dateTime.isUtc ? dateTime : dateTime.toUtc();
    return utc.add(const Duration(hours: 7));
  }

  String _formatTimestamp(String? raw) {
    final parsed = _parseTimestamp(raw);
    if (parsed == null) return '-';
    final th = _toThailandTime(parsed);
    final day = th.day.toString().padLeft(2, '0');
    final month = th.month.toString().padLeft(2, '0');
    final year = th.year.toString().padLeft(4, '0');
    final hour = th.hour.toString().padLeft(2, '0');
    final minute = th.minute.toString().padLeft(2, '0');
    final second = th.second.toString().padLeft(2, '0');
    return '$day-$month-$year $hour:$minute:$second';
  }
}
