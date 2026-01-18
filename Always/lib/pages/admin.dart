import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_state.dart';
import '../routes.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  Map<String, dynamic>? _modelData;
  String? _errorMessage;
  bool _isUploading = false;
  String? _fileName;

  static const Color cannoliCream = Color(0xFFF5EDDC); // RGB(245, 237, 220)

  @override
  Widget build(BuildContext context) {
    final isDark = appState.isDarkMode;
    final backgroundColor = isDark
        ? cannoliCream.withValues(alpha: 0.1)
        : cannoliCream;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Admin Panel',
          style: GoogleFonts.syne(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
        actions: [
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _confirmLogout(context, isDark),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header section
              Text(
                'Model Management',
                style: GoogleFonts.syne(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Upload and the system will validate',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 32),

              _buildUploadButton(isDark),
              const SizedBox(height: 24),

              if (_errorMessage != null) ...[
                _buildErrorCard(isDark),
                const SizedBox(height: 24),
              ],

              if (_modelData != null) ...[
                _buildModelDataCard(isDark),
                const SizedBox(height: 24),
                _buildActionButtons(isDark),
              ],

              if (_modelData == null && _errorMessage == null)
                _buildEmptyState(isDark),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildUploadButton(bool isDark) {
    return ElevatedButton.icon(
      onPressed: _isUploading ? null : _pickAndUploadFile,
      icon: _isUploading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.upload_file, size: 24),
      label: Text(
        _isUploading ? 'Uploading...' : 'Upload Model JSON',
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark ? const Color(0xFF2196F3) : const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
    );
  }

  /// Build error card
  Widget _buildErrorCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.red.shade900.withValues(alpha: 0.3)
            : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.red.shade700 : Colors.red.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: isDark ? Colors.red.shade300 : Colors.red.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Validation Error',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _errorMessage!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.red.shade200 : Colors.red.shade800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            color: isDark ? Colors.red.shade300 : Colors.red.shade700,
            onPressed: () {
              setState(() {
                _errorMessage = null;
              });
            },
          ),
        ],
      ),
    );
  }

  /// Build model data display card with syntax highlighting
  Widget _buildModelDataCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade500,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Model Loaded Successfully',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (_fileName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _fileName!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Model details
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailSection(
                  'Model Information',
                  [
                    _DetailItem('Model Name', _modelData!['model_name']),
                    _DetailItem('Model Type', _modelData!['model_type']),
                    _DetailItem('Version', _modelData!['model_version'].toString()),
                    _DetailItem('Training Dataset', _modelData!['training_dataset']),
                    _DetailItem('Status', _modelData!['status']),
                    _DetailItem('Timestamp', _modelData!['timestamp']),
                  ],
                  isDark,
                ),
                const SizedBox(height: 24),

                _buildDetailSection(
                  'Performance Metrics',
                  _buildMetricsItems(_modelData!['performance_metrics']),
                  isDark,
                ),
                const SizedBox(height: 24),

                _buildDetailSection(
                  'Training Details',
                  _buildTrainingItems(_modelData!['training_details']),
                  isDark,
                ),
                const SizedBox(height: 24),

                _buildDetailSection(
                  'Class Mappings',
                  _buildClassMappingItems(_modelData!['class_mappings']),
                  isDark,
                ),
                const SizedBox(height: 24),

                // Raw JSON view (collapsible)
                _buildRawJsonSection(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build a detail section
  Widget _buildDetailSection(String title, List<_DetailItem> items, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            children: items.map((item) => _buildDetailRow(item, isDark)).toList(),
          ),
        ),
      ],
    );
  }

  /// Build detail row
  Widget _buildDetailRow(_DetailItem item, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              item.label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              item.value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_DetailItem> _buildMetricsItems(Map<String, dynamic> metrics) {
    return [
      _DetailItem('Accuracy', '${(metrics['accuracy'] * 100).toStringAsFixed(2)}%'),
      _DetailItem('AUC', metrics['auc'].toStringAsFixed(4)),
      _DetailItem('F1 Score', metrics['f1_score'].toStringAsFixed(4)),
      _DetailItem('Precision', metrics['precision'].toStringAsFixed(4)),
      _DetailItem('Recall', metrics['recall'].toStringAsFixed(4)),
    ];
  }

  List<_DetailItem> _buildTrainingItems(Map<String, dynamic> training) {
    return [
      _DetailItem('Epochs', training['epochs'].toString()),
      _DetailItem('Batch Size', training['batch_size'].toString()),
      _DetailItem('Learning Rate', training['learning_rate'].toString()),
      _DetailItem('Optimizer', training['optimizer']),
      _DetailItem('Augmentation', training['augmentation_applied'].toString()),
      if (training.containsKey('total_parameters'))
        _DetailItem('Parameters', _formatNumber(training['total_parameters'])),
    ];
  }

  List<_DetailItem> _buildClassMappingItems(Map<String, dynamic> mappings) {
    return mappings.entries
        .map((e) => _DetailItem('Class ${e.key}', e.value.toString()))
        .toList();
  }

  Widget _buildRawJsonSection(bool isDark) {
    return ExpansionTile(
      title: Text(
        'Raw JSON',
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(top: 12),
      iconColor: isDark ? Colors.white : Colors.black87,
      collapsedIconColor: isDark ? Colors.white60 : Colors.black54,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1117) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.1),
            ),
          ),
          child: SelectableText(
            _formatJson(_modelData!),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: isDark ? Colors.white : Colors.black87,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _confirmclearModel(context, isDark),
            icon: const Icon(Icons.clear, size: 20),
            label: Text(
              'Clear',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white70 : Colors.black87,
              side: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.3),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _deployModel,
            icon: const Icon(Icons.rocket_launch, size: 20),
            label: Text(
              'Deploy Model',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }

  /// Build empty state
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 80,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            const SizedBox(height: 16),
            Text(
              'No model uploaded',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload a model JSON file to get started',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, bool isDark) async {
    HapticFeedback.lightImpact();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark
              ? const Color(0xFF1E1E1E)
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.logout,
                color: isDark ? Colors.white : Colors.black87,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Logout',
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to logout from the admin page?',
            style: GoogleFonts.inter(
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Logout',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    // If user confirmed logout
    if (!context.mounted) return;
    if (result == true) {
      // Clear user session data
      appState.clearUserSession();

      // Navigate to login and remove all previous routes
      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.login,
        (route) => false, // Remove all routes
      );
    }
  }

  /// Pick and upload file
  Future<void> _pickAndUploadFile() async {
    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final contents = await file.readAsString();

        // Parse and validate JSON
        final jsonData = jsonDecode(contents) as Map<String, dynamic>;
        _validateModelJson(jsonData);

        setState(() {
          _modelData = jsonData;
          _fileName = result.files.single.name;
          _isUploading = false;
        });
      } else {
        setState(() {
          _isUploading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _modelData = null;
        _isUploading = false;
      });
    }
  }

  /// Validate model JSON structure
  void _validateModelJson(Map<String, dynamic> json) {
    final requiredFields = [
      'model_version',
      'model_name',
      'model_type',
      'training_dataset',
      'performance_metrics',
      'class_mappings',
      'training_details',
      'status',
    ];

    for (final field in requiredFields) {
      if (!json.containsKey(field)) {
        throw Exception('Missing required field: $field');
      }
    }

    // Validate performance_metrics structure
    final metrics = json['performance_metrics'] as Map<String, dynamic>;
    final requiredMetrics = ['accuracy', 'auc', 'f1_score', 'precision', 'recall'];
    for (final metric in requiredMetrics) {
      if (!metrics.containsKey(metric)) {
        throw Exception('Missing required metric: $metric');
      }
    }
  }

  Future<void> _confirmclearModel(BuildContext context, bool isDark) async {
    HapticFeedback.mediumImpact();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(children: [
            Icon(
              Icons.warning_amber_rounded,
            color: Colors.orange.shade700,
            ),
            const SizedBox(width: 12),
            Text( "Clear Data??",
            style: GoogleFonts.inter(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w700,
            ),
            ),
          ],
          ),
          content: Column (
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will remove the uploaded model data',
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
                Text("You will need to upload the file again!",
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize:13,
                ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false), 
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
              ),
          ElevatedButton(
            style: ElevatedButton.styleFrom( 
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white60,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              "CLEAR",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
              ),
            )
          ),
          ],
          );
      }
    );
    if (!context.mounted) return;
    if (result == true) {
      _clearModel();
    }
  }

  /// Clear loaded model (existing method - keep as is)
  void _clearModel() {
    setState(() {
      _modelData = null;
      _fileName = null;
      _errorMessage = null;
    });
  
  }

  /// Deploy model (placeholder)
  void _deployModel() {
    // TODO: Implement actual deployment logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Model deployment initiated: ${_modelData!['model_name']}',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Format JSON with indentation
  String _formatJson(Map<String, dynamic> json) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(json);
  }

  /// Format large numbers with commas
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

/// Helper class for detail items
class _DetailItem {
  final String label;
  final String value;

  _DetailItem(this.label, this.value);
}
