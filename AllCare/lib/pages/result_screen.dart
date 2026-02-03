import 'dart:io';
import 'dart:ui';

import '../app_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/glass.dart';
import '../features/case/case_service.dart';
import '../features/case/annotate_screen.dart';
import '../features/case/api_config.dart';

/// Result screen showing ML prediction results.
/// Displayed after running prediction from Case Summary.
class ResultScreen extends StatefulWidget {
  final String caseId;
  final String? gender;
  final String? age;
  final String? location;
  final List<String> symptoms;
  final List<String> imagePaths;

  final List<Map<String, dynamic>> predictions;
  final List<List<Map<String, dynamic>>> perImagePredictions;

  final int? imageCount;
  final String? aggregationInfo;

  const ResultScreen({
    super.key,
    required this.caseId,
    this.gender,
    this.age,
    this.location,
    this.symptoms = const [],
    required this.imagePaths,
    this.predictions = const [],
    this.perImagePredictions = const [],
    this.imageCount,
    this.aggregationInfo,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _showDetails = false;
  bool _isRejected = false;

  // Per-image decision: Map of image index to decision
  final Map<int, String?> _imageDecisions = {};
  final TextEditingController _noteController = TextEditingController();

  static const Map<String, String> _diagnosisLabelMap = {
    'akiec': 'Actinic keratoses',
    'bcc': 'Basal cell carcinoma',
    'bkl': 'Benign keratosis-like lesions',
    'df': 'Dermatofibroma',
    'mel': 'Melanoma',
    'nv': 'Melanocytic nevi',
    'vasc': 'Vascular lesions',
  };

  // For image carousel
  late final PageController _imagePageController;
  int _currentImageIndex = 0;

  // Get risk level based on confidence
  String _getRiskLevel(double confidence) {
    if (confidence >= 0.7) return 'HIGH';
    if (confidence >= 0.4) return 'MODERATE';
    return 'LOW';
  }

  /// Decide which color theme to use for the card.
  bool _isCancerLikeLabel(String? rawLabel) {
    final l = rawLabel?.trim().toLowerCase();
    if (l == null || l.isEmpty) return false;
    return l == 'mel' || l == 'bcc' || l == 'akiec';
  }

  String _displayLabel(String? rawLabel) {
    final trimmed = rawLabel?.trim();
    if (trimmed == null || trimmed.isEmpty) return 'Unknown';
    final mapped = _diagnosisLabelMap[trimmed.toLowerCase()];
    if (mapped != null) return mapped;
    final cleaned = trimmed.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    return _toTitleCase(cleaned);
  }

  String _toTitleCase(String input) {
    return input
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          final lower = word.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  Color _getRiskColor(String risk) {
    switch (risk) {
      case 'HIGH':
        return Colors.red;
      case 'MODERATE':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  List<Map<String, dynamic>> _predictionsForImage(int index) {
    if (index >= 0 &&
        index < widget.perImagePredictions.length &&
        widget.perImagePredictions[index].isNotEmpty) {
      return widget.perImagePredictions[index];
    }
    return widget.predictions;
  }

  Map<String, dynamic>? _topPredictionForImage(int index) {
    final preds = _predictionsForImage(index);
    return preds.isNotEmpty ? preds.first : null;
  }

  String? _topRawLabelForImage(int index) {
    final v = _topPredictionForImage(index)?['label'];
    return v is String ? v : null;
  }

  double _topConfidenceForImage(int index) {
    return ((_topPredictionForImage(index)?['confidence'] as num?)?.toDouble() ??
        0.0);
  }

  Map<String, String> _decisionPayload() {
    final payload = <String, String>{};
    widget.imagePaths.asMap().forEach((i, _) {
      final decision = _imageDecisions[i];
      if (decision != null && decision.isNotEmpty) {
        payload['image_${i + 1}'] = decision;
      }
    });
    return payload;
  }

  String? _trimmedNote() {
    final note = _noteController.text.trim();
    return note.isEmpty ? null : note;
  }

  String? _noteWithDecisions() {
    final note = _trimmedNote();
    final decisions = _decisionPayload();
    if (decisions.isEmpty) return note;

    final decisionText = decisions.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    if (note == null) return 'Decisions: $decisionText';
    return '$note\nDecisions: $decisionText';
  }

  bool _isNetworkPath(String path) {
    final lower = path.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  /// Check if path is a backend-relative path (e.g., 'user001/uuid.jpg')
  bool _isBackendRelativePath(String path) {
    if (path.isEmpty) return false;
    if (_isNetworkPath(path)) return false;
    if (path.startsWith('/')) return false;
    return path.contains('/') && !path.contains('\\');
  }

  String _resolveImagePath(String path) {
    if (_isBackendRelativePath(path)) {
      return '${ApiConfig.baseUrl}/images/$path';
    }
    return path;
  }

  /// Build image widget that handles both local files and network URLs
  Widget _buildCaseImage(String path, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    final resolvedPath = _resolveImagePath(path);
    if (resolvedPath.isEmpty) return _imagePlaceholder(width, height);

    if (_isNetworkPath(resolvedPath)) {
      return Image.network(
        resolvedPath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _imagePlaceholder(width, height),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: width,
            height: height,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
      );
    }

    return Image.file(
      File(resolvedPath),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => _imagePlaceholder(width, height),
    );
  }

  Widget _imagePlaceholder(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[800],
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }

  @override
  void initState() {
    super.initState();
    _imagePageController = PageController();
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gradientColors = isDark
        ? const [
            Color(0xFF050A16),
            Color(0xFF0B1224),
            Color(0xFF0F1E33),
          ]
        : const [
            Color(0xFFFBFBFB),
            Color(0xFFF5F5F5),
            Color(0xFFFFFFFF),
          ];

    final topConfidence = _topConfidenceForImage(_currentImageIndex);
    final rawTopLabel = _topRawLabelForImage(_currentImageIndex);
    final topLabel = _displayLabel(rawTopLabel);
    final riskLevel = _getRiskLevel(topConfidence);
    final currentPredictions = _predictionsForImage(_currentImageIndex);

    final scheme =
        _isCancerLikeLabel(rawTopLabel) ? GradientScheme.red : GradientScheme.blue;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Result',
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
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
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
                      Text(
                        'Result',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The AI model has analyzed your skin image and generated a prediction result. Please review the details below.',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildMainPredictionBanner(
                        isDark: isDark,
                        label: topLabel,
                        confidence: topConfidence,
                        riskLevel: riskLevel,
                        predictions: currentPredictions,
                        scheme: scheme,
                      ),
                      const SizedBox(height: 20),

                      _buildImageDecisionsSection(isDark),
                      const SizedBox(height: 20),

                      _buildRecommendedSection(isDark, riskLevel),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              _buildBottomButtons(isDark),
            ],
          ),
        ),
      ),
    );
  }

  /// Main prediction banner with suspected condition
  Widget _buildMainPredictionBanner({
    required bool isDark,
    required String label,
    required double confidence,
    required String riskLevel,
    required List<Map<String, dynamic>> predictions,
    required GradientScheme scheme,
  }) {
    return SevenLayerGradientBox(
      radius: 16,
      padding: const EdgeInsets.all(20),
      scheme: scheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SUSPECTED: ${label.toUpperCase()}',
            style: TextStyle(
              color: scheme == GradientScheme.blue ? const Color(0xFF9DD6FF) : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(confidence * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 48,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: _getRiskColor(riskLevel), size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'PREDICTION: $riskLevel RISK',
                  style: TextStyle(
                    color: _getRiskColor(riskLevel),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _showDetails = !_showDetails),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_showDetails ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(_showDetails ? 'Hide' : 'Details',
                          style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_showDetails) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 12),
            const Text('Confidence', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            ...predictions.take(3).toList().asMap().entries.map((entry) {
              final pred = entry.value;
              final predLabel = _displayLabel(pred['label'] as String?);
              final predConf = ((pred['confidence'] as num?)?.toDouble() ?? 0.0) * 100;
              final predRisk = _getRiskLevel(predConf / 100);

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('${entry.key + 1}',
                            style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(predLabel,
                          style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ),
                    Text('${predConf.toStringAsFixed(0)}%',
                        style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(width: 10),
                    Text(predRisk,
                        style: TextStyle(
                          color: _getRiskColor(predRisk),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        )),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  /// Image Decisions section
  Widget _buildImageDecisionsSection(bool isDark) {
    final hasImages = widget.imagePaths.isNotEmpty;
    final displayIndex = hasImages ? _currentImageIndex + 1 : 0;
    final currentDecision = hasImages ? (_imageDecisions[_currentImageIndex] ?? "None") : "None";

    Color decisionColor;
    switch (currentDecision.toLowerCase()) {
      case 'confirm':
        decisionColor = const Color(0xFF22C55E);
        break;
      case 'reject':
        decisionColor = const Color(0xFFEF4444);
        break;
      case 'uncertain':
        decisionColor = const Color(0xFFF59E0B);
        break;
      default:
        decisionColor = isDark ? Colors.white70 : Colors.black87;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Image Decisions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$displayIndex/${widget.imagePaths.length}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black,
            ),
            children: [
              const TextSpan(text: 'Current Status: '),
              TextSpan(
                text: currentDecision,
                style: TextStyle(
                  decoration: TextDecoration.underline,
                  color: decisionColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (widget.imagePaths.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              final imageSize = constraints.maxWidth < 340
                  ? 120.0
                  : constraints.maxWidth < 420
                      ? 140.0
                      : 160.0;
              final cardHeight = imageSize + 300;

              return Column(
                children: [
                  SizedBox(
                    height: cardHeight,
                    child: _buildGlassCard(
                      isDark: isDark,
                      child: Stack(
                        children: [
                          PageView.builder(
                            controller: _imagePageController,
                            itemCount: widget.imagePaths.length,
                            onPageChanged: (index) => setState(() => _currentImageIndex = index),
                            itemBuilder: (context, index) {
                              final imagePreds = _predictionsForImage(index);
                              final rawTop = _topRawLabelForImage(index);
                              final imageTopLabel = _displayLabel(rawTop);
                              final imageTopConf = _topConfidenceForImage(index) * 100;

                              final scheme =
                                  _isCancerLikeLabel(rawTop) ? GradientScheme.red : GradientScheme.blue;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: _buildCaseImage(
                                          widget.imagePaths[index],
                                          width: imageSize,
                                          height: imageSize,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Container(
                                          height: imageSize,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(18),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.25),
                                                blurRadius: 12,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: SevenLayerGradientBox(
                                            radius: 18,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                            scheme: scheme,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  imageTopLabel.toUpperCase(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  '${imageTopConf.toStringAsFixed(0)}%',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 42,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  if (imagePreds.isNotEmpty) ...[
                                    Text(
                                      'Top findings',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white70 : Colors.grey[800],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ...imagePreds.take(3).map((pred) {
                                      final label = _displayLabel(pred['label'] as String?);
                                      final conf = ((pred['confidence'] as num?)?.toDouble() ?? 0.0) * 100;
                                      final risk = _getRiskLevel(conf / 100);

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: (isDark ? Colors.white : Colors.black)
                                                    .withValues(alpha: 0.06),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                label,
                                                style: TextStyle(
                                                  color: isDark ? Colors.white : Colors.black87,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${conf.toStringAsFixed(0)}%',
                                              style: TextStyle(
                                                color: isDark ? Colors.blue[200] : Colors.blue[700],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              risk,
                                              style: TextStyle(
                                                color: _getRiskColor(risk),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                    const SizedBox(height: 12),
                                  ],
                                  Text(
                                    'Decision',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        value: _imageDecisions[index],
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                        hint: Text(
                                          "doctor's decision",
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
                                        onChanged: (val) => setState(() => _imageDecisions[index] = val),
                                        items: ['Confirm', 'Reject', 'Uncertain']
                                            .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                                            .toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          if (widget.imagePaths.length > 1)
                            Positioned(
                              top: 12,
                              right: 16,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_currentImageIndex + 1}/${widget.imagePaths.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.imagePaths.length > 1) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(widget.imagePaths.length, (index) {
                        final isActive = index == _currentImageIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: isActive ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: isActive
                                ? (isDark ? Colors.blue[400] : Colors.blue[600])
                                : (isDark ? Colors.white24 : Colors.grey.shade300),
                          ),
                        );
                      }),
                    ),
                  ],
                ],
              );
            },
          ),
        const SizedBox(height: 12),
        Text(
          'Doctor note:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _noteController,
          minLines: 2,
          maxLines: 2,
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: 'Add notes here...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
      ],
    );
  }

  /// Recommended actions section
  Widget _buildRecommendedSection(bool isDark, String riskLevel) {
    return _buildGlassCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lightbulb_outline, color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Recommended',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            riskLevel == 'HIGH'
                ? 'Urgent referral to a dermatologist for biopsy is recommended.'
                : riskLevel == 'MODERATE'
                    ? 'Follow-up examination with a dermatologist is recommended.'
                    : 'Continue monitoring. Schedule follow-up if changes occur.',
            style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.grey[700]),
          ),
          const SizedBox(height: 16),
          _buildActionLink('Add to Patient Record'),
          _buildActionLink('Create Referral'),
          _buildActionLink('Schedule follow-up'),
        ],
      ),
    );
  }

  Widget _buildActionLink(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => _handleActionLink(text),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.blue,
            fontSize: 14,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  Future<void> _handleActionLink(String text) async {
    switch (text) {
      case 'Add to Patient Record':
        final confidence = _topConfidenceForImage(_currentImageIndex);
        final label = _displayLabel(
          _topPredictionForImage(_currentImageIndex)?['label'] as String?,
        );
        final riskLevel = _getRiskLevel(confidence);
        _appendNoteLine(
          'Added to patient record: $label '
          '(${(confidence * 100).toStringAsFixed(0)}% $riskLevel risk).',
        );
        _showActionSnack('Added note for patient record.');
        return;
      case 'Create Referral':
        _appendNoteLine('Referral requested for case ${widget.caseId}.');
        _showActionSnack('Referral noted.');
        return;
      case 'Schedule follow-up':
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now().add(const Duration(days: 14)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (!mounted || picked == null) return;
        _appendNoteLine('Follow-up scheduled for ${_formatDate(picked)}.');
        _showActionSnack('Follow-up date added.');
        return;
    }
    _showActionSnack('$text selected.');
  }

  void _appendNoteLine(String line) {
    final current = _noteController.text.trimRight();
    if (current.isEmpty) {
      _noteController.text = line;
    } else {
      _noteController.text = '$current\n$line';
    }
    _noteController.selection = TextSelection.fromPosition(
      TextPosition(offset: _noteController.text.length),
    );
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  void _showActionSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<bool> _confirmAction(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('ตกลง'),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  /// Bottom action buttons
  Widget _buildBottomButtons(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.5) : Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final ok = await _confirmAction(
                      'ยืนยันการ Reject',
                      'ต้องการ Reject เคสนี้จริงๆ ไหม?',
                    );
                    if (!ok) return;
                    try {
                      await context.read<CaseService>().rejectCase(
                        caseId: widget.caseId,
                        reason: 'User rejected prediction',
                        notes: _noteWithDecisions(),
                        predictions: widget.predictions,
                        gender: widget.gender,
                        age: widget.age,
                        location: widget.location,
                        symptoms: widget.symptoms,
                        imagePaths: widget.imagePaths,
                        imageDecisions: _decisionPayload(),
                      );
                      setState(() => _isRejected = true);
                    } catch (e) {
                      if (mounted) {
                        _showActionSnack("Failed to reject case: $e");
                      }
                      return; // Stop execution on failure
                    }
                    
                    if (!mounted) return;

                    try {
                      await context.read<CaseService>().isActiveLearningCandidate(
                        caseId: widget.caseId,
                      );
                    } catch (e) {
                      if (mounted) {
                        _showActionSnack("AL check failed: $e");
                      }
                    }

                    if (mounted) {
                      _showActionSnack('Rejected and AL margin calculated');
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    try {
                      await context.read<CaseService>().logCase(
                        caseId: widget.caseId,
                        predictions: widget.predictions,
                        status: 'pending',
                        gender: widget.gender,
                        age: widget.age,
                        location: widget.location,
                        symptoms: widget.symptoms,
                        imagePaths: widget.imagePaths,
                        imageDecisions: _decisionPayload(),
                        notes: _noteWithDecisions(),
                      );
                    } catch (_) {}
                    if (mounted) Navigator.of(context).pop('pending');
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade400),
                    foregroundColor: Colors.grey[700],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Uncertain'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final ok = await _confirmAction(
                      'ยืนยันการ Confirm',
                      'ต้องการ Confirm เคสนี้จริงๆ ไหม?',
                    );
                    if (!ok) return;
                    try {
                      await context.read<CaseService>().logCase(
                        caseId: widget.caseId,
                        predictions: widget.predictions,
                        status: 'Confirmed',
                        gender: widget.gender,
                        age: widget.age,
                        location: widget.location,
                        symptoms: widget.symptoms,
                        imagePaths: widget.imagePaths,
                        imageDecisions: _decisionPayload(),
                        notes: _noteWithDecisions(),
                      );
                    } catch (_) {}
                    if (mounted) Navigator.of(context).pop('Confirmed');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Confirm'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'DISCLAIMER: This is an AI-powered clinical decision support tool, not diagnosis. All results must be verified by a qualified medical professional.',
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required bool isDark, required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: glassBox(isDark, radius: 16, highlight: true),
          child: child,
        ),
      ),
    );
  }
}

enum GradientScheme { red, blue }

class SevenLayerGradientBox extends StatelessWidget {
  final double radius;
  final EdgeInsets padding;
  final Widget? child;

  /// Choose red/blue scheme
  final GradientScheme scheme;

  const SevenLayerGradientBox({
    super.key,
    this.radius = 24,
    this.padding = EdgeInsets.zero,
    this.child,
    this.scheme = GradientScheme.red,
  });

  @override
  Widget build(BuildContext context) {
    final base =
        scheme == GradientScheme.blue ? const Color(0xFF0051A2) : const Color(0xFF0D0D0D);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        children: [
          Positioned.fill(child: Container(color: base)),

          if (scheme == GradientScheme.red) ...[
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 40),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-1.45, -1.5),
                      radius: 1.2,
                      colors: [
                        const Color(0xFFFF4B4B).withValues(alpha: 0.85),
                        const Color(0xFFFF4B4B).withValues(alpha: 0.85),
                        const Color(0xFFB14A4A).withValues(alpha: 0.20),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.55, 0.85, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 150, sigmaY: 40),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-1.0, 1.7),
                      radius: 1.0,
                      colors: [
                        Colors.white.withValues(alpha: 1.0),
                        Colors.white.withValues(alpha: 0.9),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.8, -1.0),
                      radius: 2.0,
                      colors: [
                        const Color(0xFFBC1414).withValues(alpha: 0.6),
                        const Color(0xFFB56A6A).withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.65, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(1.1, 0.5),
                      radius: 1.5,
                      colors: [
                        Colors.white.withValues(alpha: 0.35),
                        const Color(0xFFB56A6A).withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.75, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(1.1, 0.95),
                      radius: 1.0,
                      colors: [
                        Colors.white.withValues(alpha: 0.28),
                        const Color(0xFFB56A6A).withValues(alpha: 0.04),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.8, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-1.10, 0.10),
                      radius: 0.95,
                      colors: [
                        const Color(0xFF000000).withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.98, 0.10),
                      radius: 1.10,
                      colors: [
                        const Color(0xFFF2E7E7).withValues(alpha: 0.16),
                        const Color(0xFFCFAFAF).withValues(alpha: 0.07),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.65, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ],

          if (scheme == GradientScheme.blue) ...[
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 40),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-1.35, -1.35),
                      radius: 1.25,
                      colors: [
                        const Color(0xFF77C7FF).withValues(alpha: 0.55),
                        const Color(0xFF2A86FF).withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.65, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 150, sigmaY: 45),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-1.0, 1.7),
                      radius: 1.05,
                      colors: [
                        Colors.white.withValues(alpha: 0.95),
                        Colors.white.withValues(alpha: 0.55),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(1.15, -0.10),
                      radius: 1.35,
                      colors: [
                        const Color(0xFFEAF6FF).withValues(alpha: 0.22),
                        const Color(0xFF9EDCFF).withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: const Alignment(0, -0.10),
                    colors: [
                      Colors.white.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.98, 0.98),
                      radius: 1.10,
                      colors: [
                        const Color(0xFF000000).withValues(alpha: 0.55),
                        const Color(0xFF000000).withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.70, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-1.10, 0.10),
                      radius: 0.95,
                      colors: [
                        const Color(0xFF000000).withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.98, 0.10),
                      radius: 1.10,
                      colors: [
                        const Color(0xFFBEE7FF).withValues(alpha: 0.20),
                        const Color(0xFF79C7FF).withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.65, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ],

          if (child != null) Padding(padding: padding, child: child!),
        ],
      ),
    );
  }
}
