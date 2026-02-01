import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../app_state.dart';
import '../routes.dart';
import '../features/case/api_config.dart';
import '../services/auth_service.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  Map<String, dynamic>? _modelData;
  String? _errorMessage;
  bool _isUploading = false;
  bool _isDeploying = false;
  String? _fileName;

  // Model History state
  List<Map<String, dynamic>> _modelHistory = [];
  bool _isLoadingHistory = false;
  String? _currentProduction;

  // Training Events state
  List<Map<String, dynamic>> _events = [];
  bool _isLoadingEvents = false;
  int _totalLabels = 0;
  int _unusedLabels = 0;
  int _retrainThreshold = 10;
  bool _isRetrain = false;

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

              // Model History Section
              const SizedBox(height: 32),
              _buildModelHistorySection(isDark),

              // Training Events Section
              const SizedBox(height: 32),
              _buildTrainingEventsSection(isDark),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Model History Section
  // ===========================================================================

  Widget _buildModelHistorySection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Model History',
              style: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            IconButton(
              onPressed: _isLoadingHistory ? null : _fetchModelHistory,
              icon: _isLoadingHistory
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_modelHistory.isEmpty && !_isLoadingHistory)
          _buildEmptyHistoryCard(isDark)
        else
          ..._modelHistory.map((model) => _buildModelHistoryCard(model, isDark)),
      ],
    );
  }

  Widget _buildEmptyHistoryCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(Icons.history, size: 48, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          Text(
            'No model history yet',
            style: GoogleFonts.inter(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _fetchModelHistory,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text('Load History', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }

  Widget _buildModelHistoryCard(Map<String, dynamic> model, bool isDark) {
    final versionId = model['version_id'] ?? 'Unknown';
    final status = model['status'] ?? 'unknown';
    final createdAt = model['created_at'] ?? '';
    final metrics = model['metrics'] as Map<String, dynamic>? ?? {};
    final accuracy = metrics['val_accuracy'];
    final isProduction = status == 'production';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isProduction ? Colors.green.shade400 : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
          width: isProduction ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  versionId,
                  style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (accuracy != null) ...[
                Icon(Icons.analytics, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Accuracy: ${(accuracy * 100).toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 16),
              ],
              Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                _formatDate(createdAt),
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
          if (!isProduction) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status == 'archived')
                  TextButton.icon(
                    onPressed: () => _promoteModel(versionId),
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    label: Text('Promote', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                    style: TextButton.styleFrom(foregroundColor: Colors.green.shade600),
                  ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showRollbackDialog(),
                  icon: const Icon(Icons.undo, size: 18),
                  label: Text('Rollback', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                  style: TextButton.styleFrom(foregroundColor: Colors.orange.shade700),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case 'production':
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        icon = Icons.star;
        break;
      case 'archived':
        bgColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        icon = Icons.archive;
        break;
      case 'training':
        bgColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        icon = Icons.model_training;
        break;
      case 'evaluating':
        bgColor = Colors.amber.shade100;
        textColor = Colors.amber.shade800;
        icon = Icons.pending;
        break;
      case 'failed':
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        icon = Icons.error;
        break;
      default:
        bgColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '-';
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  Future<void> _fetchModelHistory() async {
    setState(() => _isLoadingHistory = true);

    try {
      final token = await AuthService().getToken();
      final response = await http.get(
        ApiConfig.adminModelsUri,
        headers: ApiConfig.buildHeaders(token: token),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _modelHistory = List<Map<String, dynamic>>.from(data['models'] ?? []);
          _currentProduction = data['current_production'];
        });
      } else {
        throw Exception('Failed to fetch: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load history: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _promoteModel(String versionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Promote Model', style: GoogleFonts.syne(fontWeight: FontWeight.w600)),
        content: Text('Promote $versionId to production?', style: GoogleFonts.inter()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.inter())),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
            child: Text('Promote', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final token = await AuthService().getToken();
      final response = await http.post(
        ApiConfig.adminPromoteModelUri(versionId),
        headers: ApiConfig.buildHeaders(json: true, token: token),
        body: jsonEncode({'reason': 'Manual promotion from admin panel'}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Model $versionId promoted!', style: GoogleFonts.inter()),
            backgroundColor: Colors.green.shade700,
          ),
        );
        _fetchModelHistory();
      } else {
        throw Exception('Failed: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Promotion failed: $e', style: GoogleFonts.inter()), backgroundColor: Colors.red.shade700),
      );
    }
  }

  void _showRollbackDialog() {
    final archivedModels = _modelHistory.where((m) => m['status'] == 'archived').toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rollback to Previous', style: GoogleFonts.syne(fontWeight: FontWeight.w600)),
        content: archivedModels.isEmpty
            ? Text('No archived models available.', style: GoogleFonts.inter())
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: archivedModels.length,
                  itemBuilder: (_, i) {
                    final m = archivedModels[i];
                    final acc = m['metrics']?['val_accuracy'];
                    return ListTile(
                      title: Text(m['version_id'] ?? '', style: GoogleFonts.jetBrainsMono(fontSize: 13)),
                      subtitle: acc != null ? Text('Accuracy: ${(acc * 100).toStringAsFixed(1)}%', style: GoogleFonts.inter(fontSize: 12)) : null,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(ctx);
                        _rollbackToModel(m['version_id']);
                      },
                    );
                  },
                ),
              ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter())),
        ],
      ),
    );
  }

  Future<void> _rollbackToModel(String versionId) async {
    try {
      final token = await AuthService().getToken();
      final response = await http.post(
        ApiConfig.adminRollbackModelUri(versionId),
        headers: ApiConfig.buildHeaders(json: true, token: token),
        body: jsonEncode({'reason': 'Manual rollback from admin panel'}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rolled back to $versionId', style: GoogleFonts.inter()), backgroundColor: Colors.green.shade700),
        );
        _fetchModelHistory();
      } else {
        throw Exception('Failed: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rollback failed: $e', style: GoogleFonts.inter()), backgroundColor: Colors.red.shade700),
      );
    }
  }

  // ===========================================================================
  // Training Events Section
  // ===========================================================================

  Widget _buildTrainingEventsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Training Events', style: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w600)),
            IconButton(
              onPressed: _isLoadingEvents ? null : _fetchEventsAndLabels,
              icon: _isLoadingEvents
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Label count card
        _buildLabelCountCard(isDark),
        const SizedBox(height: 16),

        // Events list
        if (_events.isEmpty && !_isLoadingEvents)
          _buildEmptyEventsCard(isDark)
        else
          ..._events.take(10).map((e) => _buildEventCard(e, isDark)),
      ],
    );
  }

  Widget _buildLabelCountCard(bool isDark) {
    final progress = _retrainThreshold > 0 ? (_unusedLabels / _retrainThreshold).clamp(0.0, 1.0) : 0.0;
    final ready = _unusedLabels >= _retrainThreshold;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.label, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              Text('Label Pool', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              const Spacer(),
              if (ready)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Text('Ready to Train', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade800)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLabelStat('Total', _totalLabels, Colors.blue),
              _buildLabelStat('Unused', _unusedLabels, Colors.orange),
              _buildLabelStat('Threshold', _retrainThreshold, Colors.grey),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation(ready ? Colors.green.shade500 : Colors.orange.shade400),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_unusedLabels / $_retrainThreshold labels for next training',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isRetrain ? null : _triggerRetrain,
              icon: _isRetrain
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_arrow, size: 20),
              label: Text(_isRetrain ? 'Training...' : 'Trigger Retrain', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: ready ? Colors.green.shade600 : Colors.orange.shade600,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelStat(String label, int value, Color color) {
    return Column(
      children: [
        Text('$value', style: GoogleFonts.jetBrainsMono(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildEmptyEventsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(Icons.event_note, size: 48, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          Text('No events yet', style: GoogleFonts.inter(color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _fetchEventsAndLabels,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text('Load Events', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event, bool isDark) {
    final type = event['type'] ?? '';
    final message = event['message'] ?? '';
    final timestamp = event['timestamp'] ?? '';

    IconData icon;
    Color color;
    switch (type) {
      case 'model_promoted':
        icon = Icons.star;
        color = Colors.green;
        break;
      case 'training_completed':
        icon = Icons.check_circle;
        color = Colors.blue;
        break;
      case 'training_failed':
        icon = Icons.error;
        color = Colors.red;
        break;
      case 'retrain_triggered':
      case 'training_started':
        icon = Icons.play_circle;
        color = Colors.orange;
        break;
      case 'config_updated':
        icon = Icons.settings;
        color = Colors.purple;
        break;
      case 'model_rollback':
        icon = Icons.undo;
        color = Colors.amber;
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: GoogleFonts.inter(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(_formatDate(timestamp), style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchEventsAndLabels() async {
    setState(() => _isLoadingEvents = true);

    try {
      final token = await AuthService().getToken();

      // Fetch events and labels in parallel
      final responses = await Future.wait([
        http.get(ApiConfig.adminEventsUri, headers: ApiConfig.buildHeaders(token: token)),
        http.get(ApiConfig.adminLabelsCountUri, headers: ApiConfig.buildHeaders(token: token)),
      ]);

      if (!mounted) return;

      if (responses[0].statusCode == 200) {
        final data = jsonDecode(responses[0].body);
        setState(() => _events = List<Map<String, dynamic>>.from(data['events'] ?? []));
      }

      if (responses[1].statusCode == 200) {
        final data = jsonDecode(responses[1].body);
        setState(() {
          _totalLabels = data['total_labels'] ?? 0;
          _unusedLabels = data['unused_labels'] ?? 0;
          _retrainThreshold = data['retrain_threshold'] ?? 10;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load: $e', style: GoogleFonts.inter()), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _isLoadingEvents = false);
    }
  }

  Future<void> _triggerRetrain() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Trigger Retraining', style: GoogleFonts.syne(fontWeight: FontWeight.w600)),
        content: Text(
          _unusedLabels >= _retrainThreshold
              ? 'Start training with $_unusedLabels new labels?'
              : 'Only $_unusedLabels labels available (threshold: $_retrainThreshold). Force retrain anyway?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.inter())),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
            child: Text('Start', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRetrain = true);

    try {
      final token = await AuthService().getToken();
      final response = await http.post(
        ApiConfig.adminRetrainTriggerUri,
        headers: ApiConfig.buildHeaders(json: true, token: token),
        body: jsonEncode({'force': _unusedLabels < _retrainThreshold}),
      );

      if (!mounted) return;

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Training started: ${data['version_id']}', style: GoogleFonts.inter()),
            backgroundColor: Colors.green.shade700,
          ),
        );
        _fetchEventsAndLabels();
        _fetchModelHistory();
      } else {
        throw Exception(data['error'] ?? data['reason'] ?? 'Failed');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Retrain failed: $e', style: GoogleFonts.inter()), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _isRetrain = false);
    }
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
            onPressed: _isDeploying ? null : _deployModel,
            icon: _isDeploying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.rocket_launch, size: 20),
            label: Text(
              _isDeploying ? 'Deploying...' : 'Deploy Model',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.green.shade400,
              disabledForegroundColor: Colors.white70,
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

  /// Deploy model - sends training config to backend
  Future<void> _deployModel() async {
    if (_modelData == null) return;

    setState(() => _isDeploying = true);

    try {
      final trainingDetails = _modelData!['training_details'] as Map<String, dynamic>?;
      if (trainingDetails == null) {
        throw Exception('No training_details found in model configuration');
      }

      // Build config request from training_details
      final configRequest = <String, dynamic>{};
      if (trainingDetails['epochs'] != null) configRequest['epochs'] = trainingDetails['epochs'];
      if (trainingDetails['batch_size'] != null) configRequest['batch_size'] = trainingDetails['batch_size'];
      if (trainingDetails['learning_rate'] != null) configRequest['learning_rate'] = trainingDetails['learning_rate'];
      if (trainingDetails['optimizer'] != null) configRequest['optimizer'] = trainingDetails['optimizer'];
      if (trainingDetails['dropout'] != null) configRequest['dropout'] = trainingDetails['dropout'];
      if (trainingDetails['augmentation_applied'] != null) configRequest['augmentation_applied'] = trainingDetails['augmentation_applied'];

      final token = await AuthService().getToken();
      final response = await http.post(
        ApiConfig.adminTrainingConfigUri,
        headers: ApiConfig.buildHeaders(json: true, token: token),
        body: jsonEncode(configRequest),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Training config deployed: ${_modelData!['model_name']}', style: GoogleFonts.inter()),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        _showDeploymentSuccessDialog(responseData);
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['detail'] ?? 'Failed: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deployment failed: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isDeploying = false);
    }
  }

  void _showDeploymentSuccessDialog(Map<String, dynamic> responseData) {
    final isDark = appState.isDarkMode;
    final config = responseData['config'] as Map<String, dynamic>?;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600),
            const SizedBox(width: 8),
            Text('Config Deployed', style: GoogleFonts.syne(fontWeight: FontWeight.w600)),
          ],
        ),
        content: config == null
            ? Text('Configuration updated.', style: GoogleFonts.inter())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Active training configuration:', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  _configRow('Epochs', config['epochs']),
                  _configRow('Batch Size', config['batch_size']),
                  _configRow('Learning Rate', config['learning_rate']),
                  _configRow('Optimizer', config['optimizer']),
                  _configRow('Dropout', config['dropout']),
                  _configRow('Augmentation', config['augmentation_applied']),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _configRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter()),
          Text('${value ?? '-'}', style: GoogleFonts.jetBrainsMono(fontSize: 13)),
        ],
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
