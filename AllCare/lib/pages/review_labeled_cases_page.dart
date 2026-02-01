import 'package:flutter/material.dart';
import '../app_state.dart';
import '../widgets/calendar_widget.dart';
import '../features/case/annotate_screen.dart';

/// Review Labeled Cases Page
/// Allows Specialists and Admins to review all labeled cases in the system,
/// view annotation details, compare with AI predictions, and edit labels if needed.
class ReviewLabeledCasesPage extends StatefulWidget {
  const ReviewLabeledCasesPage({super.key});

  @override
  State<ReviewLabeledCasesPage> createState() => _ReviewLabeledCasesPageState();
}

class _ReviewLabeledCasesPageState extends State<ReviewLabeledCasesPage> {
  // Selected date for filtering
  DateTime? _selectedDate;

  // List of labeled cases
  List<LabeledCase> _labeledCases = [];

  // Loading state
  bool _isLoading = false;

  // Error message
  String? _errorMessage;

  // Dates that have labeled cases (for calendar indicators)
  Set<DateTime> _datesWithCases = {};

  @override
  void initState() {
    super.initState();
    _checkAccessControl();
    _loadLabeledCases();
  }

  /// Check if the current user has access to this page
  void _checkAccessControl() {
    final role = appState.userRole.toLowerCase().trim();
    if (role == 'gp') {
      // GPs are not allowed to access this page
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access denied. This page is only available to Specialists and Admins.'),
            backgroundColor: Colors.red,
          ),
        );
      });
    }
  }

  /// Load labeled cases from the backend
  Future<void> _loadLabeledCases() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // TODO: Implement API call to fetch labeled cases
      // For now, using empty list
      await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

      setState(() {
        _labeledCases = [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load labeled cases: $e';
        _isLoading = false;
      });
    }
  }

  /// Refresh the case list
  Future<void> _refresh() async {
    await _loadLabeledCases();
  }

  /// Filter cases by selected date
  List<LabeledCase> _getFilteredCases() {
    if (_selectedDate == null) {
      return _labeledCases;
    }

    return _labeledCases.where((case_) {
      final labeledDate = case_.labeledAt;
      return labeledDate.year == _selectedDate!.year &&
             labeledDate.month == _selectedDate!.month &&
             labeledDate.day == _selectedDate!.day;
    }).toList();
  }

  /// Check if a date has labeled cases (for calendar indicators)
  bool _hasIndicatorForDate(DateTime date) {
    return _datesWithCases.any((d) =>
        d.year == date.year && d.month == date.month && d.day == date.day);
  }

  /// Handle edit button press
  void _handleEdit(LabeledCase case_) {
    // Navigate to AnnotateScreen with pre-loaded data
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AnnotateScreen(
          caseId: case_.caseId,
          imagePaths: case_.images.map((img) => img.path).toList(),
          initialIndex: case_.labeledImageIndex,
        ),
      ),
    ).then((_) {
      // Refresh the list after returning from annotation
      _refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredCases = _getFilteredCases();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Review Labeled Cases'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Calendar Widget for date filtering
          CalendarWidget(
            selectedDate: _selectedDate,
            onDateSelected: (date) {
              setState(() {
                _selectedDate = date;
              });
            },
            hasIndicatorForDate: _hasIndicatorForDate,
            isDark: isDark,
          ),

          // Case list
          Expanded(
            child: _buildCaseList(filteredCases, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildCaseList(List<LabeledCase> cases, bool isDark) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refresh,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (cases.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedDate == null
                  ? 'No labeled cases found'
                  : 'No labeled cases for selected date',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cases.length,
      itemBuilder: (context, index) {
        return LabeledCaseCard(
          case_: cases[index],
          onEdit: () => _handleEdit(cases[index]),
          isDark: isDark,
        );
      },
    );
  }
}

// ============================================================================
// Data Models
// ============================================================================

/// Represents a labeled case with all its data
class LabeledCase {
  final String caseId;
  final List<CaseImage> images;
  final UserLabel userLabel;
  final List<AIPrediction> aiPredictions;
  final bool agreement; // Whether user label matches AI top prediction
  final int labeledImageIndex; // Which image was labeled

  LabeledCase({
    required this.caseId,
    required this.images,
    required this.userLabel,
    required this.aiPredictions,
    required this.agreement,
    required this.labeledImageIndex,
  });

  factory LabeledCase.fromJson(Map<String, dynamic> json) {
    final images = (json['images'] as List<dynamic>)
        .map((img) => CaseImage.fromJson(img as Map<String, dynamic>))
        .toList();

    final userLabel = UserLabel.fromJson(json['user_label'] as Map<String, dynamic>);

    final aiPredictions = (json['ai_predictions'] as List<dynamic>)
        .map((pred) => AIPrediction.fromJson(pred as Map<String, dynamic>))
        .toList();

    return LabeledCase(
      caseId: json['case_id'] as String,
      images: images,
      userLabel: userLabel,
      aiPredictions: aiPredictions,
      agreement: json['agreement'] as bool? ?? false,
      labeledImageIndex: userLabel.imageIndex,
    );
  }

  DateTime get labeledAt => userLabel.timestamp;
}

/// Represents a case image with annotations
class CaseImage {
  final String path;
  final List<Map<String, dynamic>> strokes;
  final List<Map<String, dynamic>> boxes;

  CaseImage({
    required this.path,
    required this.strokes,
    required this.boxes,
  });

  factory CaseImage.fromJson(Map<String, dynamic> json) {
    final annotations = json['annotations'] as Map<String, dynamic>? ?? {};
    return CaseImage(
      path: json['path'] as String,
      strokes: (annotations['strokes'] as List<dynamic>?)
              ?.map((s) => s as Map<String, dynamic>)
              .toList() ??
          [],
      boxes: (annotations['boxes'] as List<dynamic>?)
              ?.map((b) => b as Map<String, dynamic>)
              .toList() ??
          [],
    );
  }

  bool get hasAnnotations => strokes.isNotEmpty || boxes.isNotEmpty;
}

/// Represents the user's label
class UserLabel {
  final String classification;
  final String labeledBy;
  final String labeledByName;
  final DateTime timestamp;
  final int imageIndex;

  UserLabel({
    required this.classification,
    required this.labeledBy,
    required this.labeledByName,
    required this.timestamp,
    required this.imageIndex,
  });

  factory UserLabel.fromJson(Map<String, dynamic> json) {
    return UserLabel(
      classification: json['classification'] as String,
      labeledBy: json['labeled_by'] as String,
      labeledByName: json['labeled_by_name'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      imageIndex: json['image_index'] as int? ?? 0,
    );
  }
}

/// Represents an AI prediction
class AIPrediction {
  final String label;
  final double confidence;

  AIPrediction({
    required this.label,
    required this.confidence,
  });

  factory AIPrediction.fromJson(Map<String, dynamic> json) {
    return AIPrediction(
      label: json['label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }
}

// ============================================================================
// Case Card Component
// ============================================================================

/// Displays a single labeled case card
class LabeledCaseCard extends StatelessWidget {
  final LabeledCase case_;
  final VoidCallback onEdit;
  final bool isDark;

  const LabeledCaseCard({
    super.key,
    required this.case_,
    required this.onEdit,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = isDark ? Colors.white70 : Colors.black54;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: case_.agreement
              ? Colors.green.withValues(alpha: .3)
              : Colors.orange.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Case ID and metadata
            _buildHeader(textColor, mutedTextColor),
            const SizedBox(height: 16),

            // Images section (placeholder - will show thumbnails with annotations)
            _buildImagesSection(textColor),
            const SizedBox(height: 16),

            // AI Predictions vs User Label Comparison
            // TODO(human): Implement the comparison widget
            // This section should display:
            // - AI top predictions with confidence scores (left/top side)
            // - User's chosen label (right/bottom side)
            // - Visual indicator showing if they agree or disagree
            // Consider using a Row with two columns, or a custom comparison layout
            // The case_.aiPredictions list contains AIPrediction objects with label and confidence
            // The case_.userLabel.classification contains the user's choice
            // The case_.agreement bool tells if they match
            _buildPredictionComparison(textColor),
            const SizedBox(height: 16),

            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor, Color mutedTextColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.medical_information,
                    color: textColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Case #${case_.caseId}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: mutedTextColor),
                  const SizedBox(width: 4),
                  Text(
                    'Labeled by: ${case_.userLabel.labeledByName}',
                    style: TextStyle(
                      fontSize: 12,
                      color: mutedTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: mutedTextColor),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(case_.userLabel.timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: mutedTextColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Agreement badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: case_.agreement
                ? Colors.green.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: case_.agreement ? Colors.green : Colors.orange,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                case_.agreement ? Icons.check_circle : Icons.warning,
                color: case_.agreement ? Colors.green : Colors.orange,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                case_.agreement ? 'Agreement' : 'Disagreement',
                style: TextStyle(
                  color: case_.agreement ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImagesSection(Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Images with Annotations:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: case_.images.length,
            itemBuilder: (context, index) {
              final image = case_.images[index];
              return Container(
                width: 120,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: index == case_.labeledImageIndex
                        ? Colors.blue
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Stack(
                  children: [
                    // TODO: Add actual image display with Image.network
                    Center(
                      child: Icon(
                        Icons.image,
                        size: 40,
                        color: Colors.grey[600],
                      ),
                    ),
                    // Show annotation indicator
                    if (image.hasAnnotations)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.brush,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    // Show labeled indicator
                    if (index == case_.labeledImageIndex)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Labeled',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionComparison(Color textColor) {
    // TODO(human): Replace this placeholder with a proper comparison widget
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Predictions vs User Label',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'TODO: Implement comparison view',
            style: TextStyle(color: textColor.withValues( alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: () {
            // TODO: Implement history drawer

            
          },
          icon: const Icon(Icons.history, size: 16),
          label: const Text('History'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit, size: 16),
          label: const Text('Edit Label'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
