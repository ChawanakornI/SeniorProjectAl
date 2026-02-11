import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../features/case/api_config.dart';
import '../features/case/annotate_screen.dart';
import '../features/case/case_service.dart';
import '../routes.dart';

class LabelPage extends StatefulWidget {
  const LabelPage({super.key});

  @override
  State<LabelPage> createState() => _LabelPageState();
}

class _LabelPageState extends State<LabelPage> {
  bool isLoading = true;
  String errorMessage = '';
  _CaseFilter _filter = _CaseFilter.all;

  List<_AlCaseView> cases = [];

  AppState get appState => context.read<AppState>();
  CaseService get caseService => context.read<CaseService>();

  @override
  void initState() {
    super.initState();

    if (appState.userRole.toLowerCase() == 'gp') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GP role is not allowed to access labeling')),
        );
        Navigator.pushReplacementNamed(context, Routes.gpHome);
      });
      return;
    }

    _loadCases();
  }

  Future<void> _loadCases() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final data = await caseService.fetchActiveLearningCandidates();
      final mapped = data.map(_mapCandidateToView).toList();
      final Map<String, _AlCaseView> unique = {};
      for (final item in mapped) {
        final id = item.record.caseId;
        final existing = unique[id];
        if (existing == null || item.margin < existing.margin) {
          unique[id] = item;
        }
      }
      final deduped = unique.values.toList();
      deduped.sort((a, b) => a.margin.compareTo(b.margin));
      final limited = deduped.length > 5 ? deduped.sublist(0, 5) : deduped;
      setState(() {
        cases = limited;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  List<_AlCaseView> get filteredCases {
    if (_filter == _CaseFilter.all) return cases;

    final now = DateTime.now();
    final start = _filter.startDate(now);

    return cases.where((c) {
      if (c.createdAt == null) return true;
      final created = DateTime.tryParse(c.createdAt!)?.toLocal();
      if (created == null) return true;
      return _isOnOrAfter(created, start);
    }).toList();
  }

  // ========================= UI =========================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'List of labeled',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _buildFilterBar(isDark),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadCases,
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 32),
        children: const [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading cases that need your expertise...'),
              ],
            ),
          ),
        ],
      );
    }

    if (errorMessage.isNotEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 32),
        children: [
          Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      );
    }

    if (filteredCases.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 32),
        children: const [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.task_alt, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text(
                  'You are all caught up',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text('No uncertain cases available right now'),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: filteredCases.length,
      itemBuilder: (_, i) => _buildCaseCard(filteredCases[i]),
    );
  }

  Widget _buildCaseCard(_AlCaseView view) {
    final c = view.record;
    final confidence = c.topPredictionConfidence;
    final status = c.status;
    final statusColor =
        status.toLowerCase() == 'rejected' ? Colors.red : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.white.withOpacity(0.96),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Case #${c.caseId}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              _pill(
                text: 'Margin ${view.margin.toStringAsFixed(3)}',
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              _pill(
                text: status,
                color: statusColor,
              ),
            ],
          ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              if (c.gender != null) _metaChip(Icons.person, c.gender!),
              if (c.age != null) _metaChip(Icons.cake, c.age!),
              if (c.location != null) _metaChip(Icons.location_on, c.location!),
            ],
          ),

          const SizedBox(height: 14),

          if (c.imagePaths.isNotEmpty)
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: c.imagePaths.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    '${ApiConfig.baseUrl}/images/${c.imagePaths[i]}',
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 16),

          Row(
            children: [
              const Text(
                'Top AI Prediction',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${(confidence * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(c.topPredictionLabel),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: confidence,
              minHeight: 8,
              valueColor: AlwaysStoppedAnimation<Color>(
                confidence > 0.5 ? Colors.green : Colors.orange,
              ),
              backgroundColor: Colors.black.withOpacity(0.06),
            ),
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text(
                'Annotate & Label Case',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => _openAnnotate(c),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    final items = _CaseFilter.values;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: items.map((filter) {
            final isSelected = _filter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(filter.label),
                selected: isSelected,
                onSelected: (_) => setState(() => _filter = filter),
                selectedColor: isDark ? Colors.white : const Color.fromARGB(255, 19, 169, 255),
                labelStyle: TextStyle(
                  color: isSelected
                      ? (isDark ? const Color.fromARGB(255, 19, 169, 255) : Colors.white)
                      : (isDark ? Colors.white70 : const Color.fromARGB(255, 19, 169, 255)),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(text),
      backgroundColor: Colors.grey.withOpacity(.15),
    );
  }

  Widget _pill({required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  _AlCaseView _mapCandidateToView(Map<String, dynamic> raw) {
    final margin = (raw['margin'] as num?)?.toDouble() ?? 1.0;
    final imagePaths =
        (raw['image_paths'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    List<Map<String, dynamic>> predictions = [];
    final rawPreds = raw['predictions'];
    if (rawPreds is List) {
      predictions =
          rawPreds.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } else {
      final images = raw['images'];
      if (images is List && images.isNotEmpty) {
        final first = images.first;
        if (first is Map && first['predictions'] is List) {
          predictions = (first['predictions'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }
    }

    final record = CaseRecord(
      caseId: raw['case_id']?.toString() ?? '',
      predictions: predictions,
      status: raw['status']?.toString() ?? 'Uncertain',
      entryType: raw['entry_type']?.toString(),
      gender: raw['gender']?.toString(),
      age: raw['age']?.toString(),
      location: raw['location']?.toString(),
      symptoms: (raw['symptoms'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      imagePaths: imagePaths,
      createdAt: raw['created_at']?.toString(),
      updatedAt: raw['updated_at']?.toString(),
      isLabeled: raw['correct_label'] != null,
      correctLabel: raw['correct_label']?.toString(),
      selectedPredictionIndex: raw['selected_prediction_index'] as int?,
    );

    return _AlCaseView(
      record: record,
      margin: margin,
      createdAt: record.createdAt,
    );
  }

  // ========================= ACTION =========================

  Future<void> _openAnnotate(CaseRecord c) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AnnotateScreen(
          caseId: c.caseId,
          imagePaths: c.imagePaths,
        ),
      ),
    );

    if (result == null) return;

    await caseService.saveAnnotations(
      caseId: c.caseId,
      imageIndex: result['imageIndex'] ?? 0,
      correctLabel: result['class'],
      strokes: result['strokes'] ?? [],
      boxes: result['boxes'] ?? [],
      caseUserId: null,
    );

    _loadCases();
  }
}

class _AlCaseView {
  final CaseRecord record;
  final double margin;
  final String? createdAt;

  _AlCaseView({
    required this.record,
    required this.margin,
    required this.createdAt,
  });
}

enum _CaseFilter {
  all,
  last3Days,
  weekly,
  monthly,
  yearly;

  String get label {
    switch (this) {
      case _CaseFilter.all:
        return 'All';
      case _CaseFilter.last3Days:
        return 'Last 3 Days';
      case _CaseFilter.weekly:
        return 'Weekly';
      case _CaseFilter.monthly:
        return 'Monthly';
      case _CaseFilter.yearly:
        return 'Yearly';
    }
  }

  DateTime startDate(DateTime now) {
    switch (this) {
      case _CaseFilter.all:
        return DateTime.fromMillisecondsSinceEpoch(0);
      case _CaseFilter.last3Days:
        return DateTime(now.year, now.month, now.day).subtract(
          const Duration(days: 2),
        );
      case _CaseFilter.weekly:
        return DateTime(now.year, now.month, now.day).subtract(
          const Duration(days: 6),
        );
      case _CaseFilter.monthly:
        return DateTime(now.year, now.month, now.day).subtract(
          const Duration(days: 29),
        );
      case _CaseFilter.yearly:
        return DateTime(now.year, now.month, now.day).subtract(
          const Duration(days: 364),
        );
    }
  }
}

bool _isOnOrAfter(DateTime target, DateTime start) {
  return target.isAtSameMomentAs(start) || target.isAfter(start);
}
