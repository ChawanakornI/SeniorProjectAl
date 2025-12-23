import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/glass.dart';
import 'case_service.dart';

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
  // Per-image decision: Map of image index to decision
  final Map<int, String?> _imageDecisions = {};
  final TextEditingController _noteController = TextEditingController();

  // For image carousel
  late PageController _imagePageController;
  int _currentImageIndex = 0;

  // Get risk level based on confidence
  String _getRiskLevel(double confidence) {
    if (confidence >= 0.7) return 'HIGH';
    if (confidence >= 0.4) return 'MODERATE';
    return 'LOW';
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

    final decisionText = decisions.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');

    if (note == null) return 'Decisions: $decisionText';
    return '$note\nDecisions: $decisionText';
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

    final gradientColors =
        isDark
            ? [
              const Color(0xFF050A16),
              const Color(0xFF0B1224),
              const Color(0xFF0F1E33),
            ]
            : [
              const Color(0xFFFBFBFB),
              const Color(0xFFF5F5F5),
              const Color(0xFFFFFFFF),
            ];

    final topConfidence = _topConfidenceForImage(_currentImageIndex);
    final topLabel = _topPredictionForImage(_currentImageIndex)?['label'] ??
        'Unknown';
    final riskLevel = _getRiskLevel(topConfidence);
    final currentPredictions = _predictionsForImage(_currentImageIndex);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
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
              color: (isDark ? Colors.black : Colors.white).withOpacity(0.5),
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
                      // Header text
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

                      // Main Prediction Banner
                      _buildMainPredictionBanner(
                        isDark,
                        topLabel,
                        topConfidence,
                        riskLevel,
                        currentPredictions,
                      ),
                      const SizedBox(height: 20),

                      // Image Decisions Section
                      _buildImageDecisionsSection(isDark),
                      const SizedBox(height: 20),

                      // Recommended Section
                      _buildRecommendedSection(isDark, riskLevel),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Bottom Action Buttons
              _buildBottomButtons(isDark),
            ],
          ),
        ),
      ),
    );
  }

  /// Main prediction banner with suspected condition
  Widget _buildMainPredictionBanner(
    bool isDark,
    String label,
    double confidence,
    String riskLevel,
    List<Map<String, dynamic>> predictions,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SUSPECTED: ${label.toUpperCase()}',
            style: const TextStyle(
              color: Colors.red,
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
              Icon(
                Icons.warning_amber_rounded,
                color: _getRiskColor(riskLevel),
                size: 18,
              ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showDetails ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _showDetails ? 'Hide' : 'Details',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Expanded details
          if (_showDetails) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 12),
            const Text(
              'Confidence',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ...predictions.take(3).toList().asMap().entries.map((entry) {
              final pred = entry.value;
              final predLabel = pred['label'] ?? '-';
              final predConf =
                  ((pred['confidence'] as num?)?.toDouble() ?? 0.0) * 100;
              final predRisk = _getRiskLevel(predConf / 100);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${entry.key + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        predLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      '${predConf.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      predRisk,
                      style: TextStyle(
                        color: _getRiskColor(predRisk),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
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
    final topLabel =
        _topPredictionForImage(_currentImageIndex)?['label'] ?? 'Unknown';
    final topConf = _topConfidenceForImage(_currentImageIndex) * 100;
    final currentDecision =
        hasImages ? (_imageDecisions[_currentImageIndex] ?? "None") : "None";
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

        // Swipeable image carousel with predictions
        if (widget.imagePaths.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              // Responsive sizing based on available width
              final imageSize =
                  constraints.maxWidth < 340
                      ? 120.0
                      : constraints.maxWidth < 420
                      ? 140.0
                      : 160.0;
              final cardHeight = imageSize + 220;

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
                            onPageChanged: (index) {
                              setState(() => _currentImageIndex = index);
                            },
                            itemBuilder: (context, index) {
                              final imagePreds = _predictionsForImage(index);
                              final imageTopLabel =
                                  _topPredictionForImage(index)?['label'] ??
                                  'Unknown';
                              final imageTopConf =
                                  _topConfidenceForImage(index) * 100;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Image.file(
                                          File(widget.imagePaths[index]),
                                          width: imageSize,
                                          height: imageSize,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          height: imageSize,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(18),
                                            gradient: const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Color(0xFF3B0F0F),
                                                Color(0xFF6E1E1E),
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.25),
                                                blurRadius: 12,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
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
                                    final label = pred['label'] ?? '-';
                                    final conf =
                                        ((pred['confidence'] as num?)?.toDouble() ??
                                            0.0) *
                                        100;
                                    final risk = _getRiskLevel(conf / 100);
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
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
                                    color:
                                        isDark
                                            ? Colors.white.withOpacity(0.08)
                                            : Colors.grey[100],
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
                                      icon: Icon(
                                        Icons.keyboard_arrow_down,
                                        color: Colors.grey[600],
                                      ),
                                      onChanged:
                                          (val) => setState(
                                            () => _imageDecisions[index] = val,
                                          ),
                                      items: ['Confirm', 'Reject', 'Uncertain']
                                          .map(
                                            (d) => DropdownMenuItem(
                                              value: d,
                                              child: Text(d),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                          // Image counter overlay (for multiple images)
                          if (widget.imagePaths.length > 1)
                            Positioned(
                              top: 12,
                              right: 16,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
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
                  // Page indicator dots (for multiple images)
                  if (widget.imagePaths.length > 1) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(widget.imagePaths.length, (
                        index,
                      ) {
                        final isActive = index == _currentImageIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: isActive ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color:
                                isActive
                                    ? (isDark
                                        ? Colors.blue[400]
                                        : Colors.blue[600])
                                    : (isDark
                                        ? Colors.white24
                                        : Colors.grey.shade300),
                          ),
                        );
                      }),
                    ),
                  ],
                ],
              );
            }, // Close LayoutBuilder builder
          ), // Close LayoutBuilder
        const SizedBox(height: 12),

        // Doctor note
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
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: 'Add notes here...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
            filled: true,
            fillColor:
                isDark ? Colors.white.withOpacity(0.08) : Colors.grey[100],
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
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  color: Colors.orange,
                  size: 20,
                ),
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
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
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
        onTap: () {
          // TODO: Implement action
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$text clicked')));
        },
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

  /// Bottom action buttons
  Widget _buildBottomButtons(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.5) : Colors.white,
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
                    // Log rejected case to backend
                    try {
                      await CaseService().rejectCase(
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
                    } catch (_) {
                      // Continue even if logging fails
                    }
                    if (mounted) Navigator.of(context).pop('Rejected');
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    // Log pending case to backend
                    try {
                      await CaseService().logCase(
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
                    } catch (_) {
                      // Continue even if logging fails
                    }
                    if (mounted) Navigator.of(context).pop('pending');
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade400),
                    foregroundColor: Colors.grey[700],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Uncertain'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    // Log confirmed case to backend
                    try {
                      await CaseService().logCase(
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
                    } catch (_) {
                      // Continue even if logging fails
                    }
                    if (mounted) Navigator.of(context).pop('Confirmed');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
