import 'dart:developer';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
//import 'package:fl_chart/fl_chart.dart';


import '../app_state.dart';
import '../theme/glass.dart';
import '../features/case/case_service.dart';
import '../features/case/case_summary_screen.dart';
import 'home_page.dart';
import 'notification_page.dart';
import 'profile_settings_page.dart';
import 'settings_page.dart';

// ==================== DASHBOARD PAGE ====================

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  int _currentBottomNavIndex = 1;
  String _selectedPeriod = 'All Time';
  bool _isStackedView = false; // Toggle for stacked bar chart
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Case data from backend
  List<CaseRecord> _cases = [];
  bool _isLoading = false;

  // Accuracy metrics derived from real case outcomes (confirmed vs rejected).
  Map<String, Map<String, double>> get _accuracyMetrics =>
      _calculateAccuracyMetrics();

  // Computed stats from fetched cases
  Map<String, num> get _currentStats {
    final total = _cases.length;
    final pending = _cases.where((c) => c.status == 'pending').length;
    final confirmed = _cases.where((c) => c.status == 'Confirmed').length;
    final rejected = _cases.where((c) => c.status == 'Rejected').length;
    final accuracy = total > 0 ? (confirmed / total) * 100 : 0.0;
    return {
      'totalCases': total,
      'pendingCases': pending,
      'confirmedCases': confirmed,
      'rejectedCases': rejected,
      'accuracyRate': accuracy,
    };
  }

  // Placeholder for previous stats (would need historical data from backend)
  Map<String, num> get _previousStats => {
    'totalCases': 0,
    'pendingCases': 0,
    'confirmedCases': 0,
    'accuracyRate': 0,
  };

  double _percentChange(String key) {
    final current = _currentStats[key] ?? 0;
    final previous = _previousStats[key] ?? 0;
    if (previous == 0) return current > 0 ? 100.0 : 0.0;
    return ((current - previous) / previous) * 100;
  }

  Map<String, dynamic> get _currentTrendData {
    // Filter cases based on selected period
    final filteredCases = _filterCasesByPeriod(_cases, _selectedPeriod);

    if (_isStackedView) {
      // For stacked view, we need to group by time periods and then stack by status
      final groupedData = _groupCasesByTimePeriod(filteredCases, _selectedPeriod);

      if (groupedData.isEmpty) {
        return {
          'values': [0, 0, 0],
          'labels': ['Accept', 'Uncertain', 'Reject'],
          'colors': [const Color(0xFF22C55E), const Color(0xFFF59E0B), const Color(0xFFEF4444)],
          'total': 0,
          'max': 1,
          'isStacked': true,
        };
      }

      // For stacked view, we show one set of stacked bars for the entire period
      final confirmed = filteredCases.where((c) => c.status == 'Confirmed').length;
      final uncertain = filteredCases.where((c) => c.status == 'Uncertain').length;
      final rejected = filteredCases.where((c) => c.status == 'Rejected').length;

      final values = [confirmed, uncertain, rejected];
      final labels = ['Accept', 'Uncertain', 'Reject'];
      final colors = [
        const Color(0xFF22C55E), 
        const Color(0xFFF59E0B), 
        const Color(0xFFEF4444), 
      ];
      final maxValue = values.reduce((a, b) => a > b ? a : b);
      final total = confirmed + uncertain + rejected;

      return {
        'values': values,
        'labels': labels,
        'colors': colors,
        'total': total,
        'max': maxValue > 0 ? maxValue : 1,
        'isStacked': true,
      };
    } else {
      // Single bar view: group by time periods
      final groupedData = _groupCasesByTimePeriod(filteredCases, _selectedPeriod);

      if (groupedData.isEmpty) {
        return {
          'values': [0],
          'labels': ['No Data'],
          'total': 0,
          'max': 1,
          'isStacked': false,
        };
      }

      final values = groupedData.values.toList();
      final labels = groupedData.keys.toList();
      final maxValue = values.reduce((a, b) => a > b ? a : b);
      final total = values.reduce((a, b) => a + b);

      return {
        'values': values,
        'labels': labels,
        'total': total,
        'max': maxValue > 0 ? maxValue : 1,
        'isStacked': false,
      };
    }
  }

  List<CaseRecord> _filterCasesByPeriod(List<CaseRecord> cases, String period) {
    final now = DateTime.now();
    DateTime startDate;

    switch (period) {
      case 'Today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'This Week':
        // Start from Monday of current week
        final monday = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(monday.year, monday.month, monday.day);
        break;
      case 'This Month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'All Time':
      default:
        return cases; // No filtering
    }

    return cases.where((caseRecord) {
      if (caseRecord.createdAt == null) return false;
      try {
        final caseDate = DateTime.parse(caseRecord.createdAt!);
        return caseDate.isAfter(startDate) || caseDate.isAtSameMomentAs(startDate);
      } catch (e) {
        return false;
      }
    }).toList();
  }

  Map<String, int> _groupCasesByTimePeriod(List<CaseRecord> cases, String period) {
    final Map<String, int> grouped = {};

    for (final caseRecord in cases) {
      if (caseRecord.createdAt == null) continue;

      try {
        final caseDate = DateTime.parse(caseRecord.createdAt!);
        String key;

        switch (period) {
          case 'Today':
            // For today, just one group
            key = 'Today';
            break;
          case 'This Week':
            // Group by day of week
            final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
            key = weekdays[caseDate.weekday - 1];
            break;
          case 'This Month':
            // Group by week of month
            final dayOfMonth = caseDate.day;
            final weekOfMonth = ((dayOfMonth - 1) ~/ 7) + 1;
            key = 'W$weekOfMonth';
            break;
          case 'All Time':
            // Group by month and year
            key = '${caseDate.year}-${caseDate.month.toString().padLeft(2, '0')}';
            break;
          default:
            key = 'All';
        }

        grouped[key] = (grouped[key] ?? 0) + 1;
      } catch (e) {
        // Skip invalid dates
        continue;
      }
    }

    // Sort the keys appropriately
    switch (period) {
      case 'This Week':
        final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final sortedGrouped = <String, int>{};
        for (final day in weekdays) {
          if (grouped.containsKey(day)) {
            sortedGrouped[day] = grouped[day]!;
          }
        }
        return sortedGrouped;
      case 'This Month':
        final sortedKeys = grouped.keys.toList()..sort();
        final sortedGrouped = <String, int>{};
        for (final key in sortedKeys) {
          sortedGrouped[key] = grouped[key]!;
        }
        return sortedGrouped;
      case 'All Time':
        final sortedKeys = grouped.keys.toList()..sort();
        final sortedGrouped = <String, int>{};
        for (final key in sortedKeys) {
          // Convert to readable month format
          final parts = key.split('-');
          if (parts.length == 2) {
            final year = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final monthNames = [
              'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
              'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
            ];
            final readableKey = '${monthNames[month - 1]} $year';
            sortedGrouped[readableKey] = grouped[key]!;
          } else {
            sortedGrouped[key] = grouped[key]!;
          }
        }
        return sortedGrouped;
      default:
        return grouped;
    }
  }

  // Diagnosis distribution from predictions
  Map<String, int> get _diagnosisDistribution {
    final Map<String, int> distribution = {};
    for (final c in _cases) {
      final label = c.topPredictionLabel;
      distribution[label] = (distribution[label] ?? 0) + 1;
    }
    return distribution;
  }

  Map<String, Map<String, double>> _calculateAccuracyMetrics() {
    if (_cases.isEmpty) {
      return {
        'overall': {'precision': 0, 'recall': 0, 'f1Score': 0},
      };
    }

    final Map<String, int> totalByLabel = {};
    final Map<String, int> confirmedByLabel = {};
    final Map<String, int> rejectedByLabel = {};

    for (final c in _cases) {
      final label = c.topPredictionLabel;
      final status = c.status.toLowerCase();

      totalByLabel[label] = (totalByLabel[label] ?? 0) + 1;
      if (status == 'confirmed') {
        confirmedByLabel[label] = (confirmedByLabel[label] ?? 0) + 1;
      } else if (status == 'rejected') {
        rejectedByLabel[label] = (rejectedByLabel[label] ?? 0) + 1;
      }
    }

    double precision(int tp, int fp) {
      final denom = tp + fp;
      if (denom == 0) return 0.0;
      return (tp / denom) * 100;
    }

    double recall(int tp, int total) {
      if (total == 0) return 0.0;
      return (tp / total) * 100;
    }

    double f1(double p, double r) {
      if (p <= 0 || r <= 0) return 0.0;
      return 2 * p * r / (p + r);
    }

    final confirmedOverall =
        confirmedByLabel.values.fold<int>(0, (a, b) => a + b);
    final rejectedOverall =
        rejectedByLabel.values.fold<int>(0, (a, b) => a + b);

    final overallPrecision = precision(confirmedOverall, rejectedOverall);
    final overallRecall = recall(confirmedOverall, _cases.length);
    final overallF1 = f1(overallPrecision, overallRecall);

    final metrics = <String, Map<String, double>>{
      'overall': {
        'precision': overallPrecision,
        'recall': overallRecall,
        'f1Score': overallF1,
      },
    };

    totalByLabel.forEach((label, total) {
      final tp = confirmedByLabel[label] ?? 0;
      final fp = rejectedByLabel[label] ?? 0;
      final p = precision(tp, fp);
      final r = recall(tp, total);
      metrics[label] = {
        'precision': p,
        'recall': r,
        'f1Score': f1(p, r),
      };
    });

    return metrics;
  }

  // Recent activity from cases (returns CaseRecords for navigation)
  List<CaseRecord> get _recentActivityCases {
    final sorted = List<CaseRecord>.from(_cases);
    sorted.sort((a, b) {
      final aTime =
          a.createdAt != null ? DateTime.tryParse(a.createdAt!) : null;
      final bTime =
          b.createdAt != null ? DateTime.tryParse(b.createdAt!) : null;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return sorted.take(5).toList();
  }

  String _getTimeAgo(String? createdAt) {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      } else {
        return '${diff.inDays}d ago';
      }
    } catch (_) {
      return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
    _loadCases();
  }

  Future<void> _loadCases() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final cases = await CaseService().fetchCases();
      if (mounted) {
        setState(() {
          _cases = cases;
          _isLoading = false;
        });
      }
    } catch (e) {
      log('Failed to load dashboard cases: $e', name: 'DashboardPage');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateTo(Widget page) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF050A16) : const Color(0xFFFBFBFB);
    final gradientColors =
        isDark
            ? [
              const Color(0xFF050A16),
              const Color(0xFF0B1224),
              const Color(0xFF0F1E33),
            ]
            : [
              const Color(0xFFFBFBFB),
              const Color(0xFFE8F4F8),
              const Color(0xFFF0F5F9),
            ];

    return Scaffold(
      backgroundColor: bgColor,
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
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDashboardHeader(isDark),
                        _buildPeriodSelector(isDark),
                        _buildStatsOverview(isDark),
                        _buildCaseTrendChart(isDark),
                        _buildDiagnosisDistribution(isDark),
                        _buildRecentActivity(isDark),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
              _buildDashboardBottomNav(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Case analytics & insights',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) {
                            return AlertDialog(
                              backgroundColor:
                                  isDark
                                      ? const Color(0xFF0B1628)
                                      : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: Text(
                                'Download CSV',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              content: Text(
                                'Export the current dashboard data as CSV?',
                                style: TextStyle(
                                  color:
                                      isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('No'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('Yes'),
                                ),
                              ],
                            );
                          },
                        );
                        if (confirmed == true && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('CSV download started'),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: glassBox(
                          isDark,
                          radius: 12,
                          highlight: true,
                        ),
                        child: Icon(
                          Icons.file_download_outlined,
                          color: isDark ? Colors.white : Colors.black87,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ListenableBuilder(
                listenable: appState,
                builder: (context, _) {
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileSettingsPage(),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: glassCircle(isDark, highlight: true),
                          child: appState.profileImageFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.file(
                                    appState.profileImageFile!,
                                    width: 42,
                                    height: 42,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Icon(
                                  Icons.person,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(bool isDark) {
    final periods = ['Today', 'This Week', 'This Month', 'All Time'];

    return Container(
      height: 46,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children:
              periods.asMap().entries.map((entry) {
                final period = entry.value;
                final isSelected = _selectedPeriod == period;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedPeriod = period;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient:
                          isSelected
                              ? LinearGradient(
                                colors:
                                    isDark
                                        ? [
                                          const Color(0xFF0EA5E9),
                                          const Color(0xFF2563EB),
                                        ]
                                        : [
                                          const Color(0xFF3B82F6),
                                          const Color(0xFF1D4ED8),
                                        ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                              : null,
                      color:
                          isSelected
                              ? null
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow:
                          isSelected
                              ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF2563EB,
                                  ).withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                              : null,
                    ),
                    child: Text(
                      period,
                      style: TextStyle(
                        color:
                            isSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : Colors.black54),
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatsOverview(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.folder_outlined,
                  title: 'Total Cases',
                  value: (_currentStats['totalCases'] ?? 0).toString(),
                  change: _percentChange('totalCases'),
                  color: const Color(0xFF3B82F6),
                  isDark: isDark,
                  delay: 0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.pending_actions_outlined,
                  title: 'Pending',
                  value: (_currentStats['pendingCases'] ?? 0).toString(),
                  change: _percentChange('pendingCases'),
                  color: const Color(0xFFF59E0B),
                  isDark: isDark,
                  delay: 100,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.check_circle_outline,
                  title: 'Confirmed',
                  value: (_currentStats['confirmedCases'] ?? 0).toString(),
                  change: _percentChange('confirmedCases'),
                  color: const Color(0xFF22C55E),
                  isDark: isDark,
                  delay: 200,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.speed_outlined,
                  title: 'Accuracy',
                  value:
                      '${(_currentStats['accuracyRate'] ?? 0).toStringAsFixed(1)}%',
                  change: _percentChange('accuracyRate'),
                  color: const Color(0xFF8B5CF6),
                  isDark: isDark,
                  delay: 300,
                  onTap: () => _showAccuracyMetricsModal(isDark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required double change,
    required Color color,
    required bool isDark,
    required int delay,
    VoidCallback? onTap,
  }) {
    final changePositive = change >= 0;
    final changeLabel =
        '${changePositive ? '+' : ''}${change.toStringAsFixed(1)}%';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, animation, child) {
        final card = Transform.translate(
          offset: Offset(0, 20 * (1 - animation)),
          child: Opacity(opacity: animation, child: child),
        );
        return onTap != null
            ? GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: onTap,
              child: card,
            )
            : card;
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: glassBox(isDark, radius: 20, highlight: true),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isDark ? 0.2 : 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            changePositive
                                ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                                : const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            changePositive
                                ? Icons.trending_up
                                : Icons.trending_down,
                            size: 14,
                            color:
                                changePositive
                                    ? const Color(0xFF22C55E)
                                    : const Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            changeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color:
                                  changePositive
                                      ? const Color(0xFF22C55E)
                                      : const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaseTrendChart(bool isDark) {
    final trend = _currentTrendData;
    final values = trend['values'] as List<int>;
    final labels = trend['labels'] as List<String>;
    final maxValue = trend['max'] as int;
    final total = trend['total'] as int;
    final isStacked = trend['isStacked'] as bool;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: glassBox(isDark, radius: 20, highlight: true),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Case Trend',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    // Toggle button for stacked view
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _isStackedView = !_isStackedView;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isStacked ? Icons.bar_chart : Icons.stacked_bar_chart,
                              size: 16,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isStacked ? 'Stacked' : 'Total',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color:
                                  isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.06),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '$total',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 190,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(values.length, (index) {
                      final value = values[index];
                      final heightPercent =
                          maxValue == 0 ? 0.0 : value / maxValue;

                      return Expanded(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: heightPercent),
                          duration: Duration(milliseconds: 800 + (index * 100)),
                          curve: Curves.easeOutCubic,
                          builder: (context, animation, _) {
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  value.toString(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isDark
                                            ? Colors.white70
                                            : Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: 28,
                                  height: 110 * animation,
                                  decoration: BoxDecoration(
                                    gradient: isStacked
                                        ? LinearGradient(
                                          colors: [
                                            (trend['colors'] as List<Color>)[index],
                                            (trend['colors'] as List<Color>)[index].withValues(alpha: 0.7),
                                          ],
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                        )
                                        : LinearGradient(
                                          colors: [
                                            const Color(0xFF3B82F6),
                                            const Color(0xFF0EA5E9),
                                          ],
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                        ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isStacked
                                            ? (trend['colors'] as List<Color>)[index]
                                            : const Color(0xFF3B82F6)).withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  labels[index],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiagnosisDistribution(bool isDark) {
    final distribution = _diagnosisDistribution;
    if (distribution.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxCount = distribution.values.reduce((a, b) => a > b ? a : b);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: glassBox(isDark, radius: 20, highlight: true),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Diagnosis Distribution',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: SizedBox(
                    height: 200,
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: [
                          DataColumn(
                            label: Text(
                              'Diagnosis',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Cases',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                        rows: (distribution.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).map((entry) {
                          final isMax = entry.value == maxCount;
                          return DataRow(
                            color: isMax
                                ? WidgetStateProperty.all(
                                    Colors.red.withValues(alpha: 0.1),
                                  )
                                : null,
                            cells: [
                              DataCell(
                                Text(
                                  entry.key,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontWeight: isMax ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  entry.value.toString(),
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontWeight: isMax ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity(bool isDark) {
    final activities = _recentActivityCases;

    if (activities.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: glassBox(isDark, radius: 20, highlight: true),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _navigateTo(const NotificationPage());
                      },
                      child: Text(
                        'View all',
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF3B82F6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...activities.asMap().entries.map((entry) {
                  final index = entry.key;
                  final caseRecord = entry.value;
                  final type = caseRecord.status.toLowerCase();

                  Color typeColor;
                  IconData typeIcon;
                  switch (type) {
                    case 'confirmed':
                      typeColor = const Color(0xFF22C55E);
                      typeIcon = Icons.check_circle;
                      break;
                    case 'rejected':
                      typeColor = const Color(0xFFEF4444);
                      typeIcon = Icons.cancel;
                      break;
                    case 'pending':
                      typeColor = const Color(0xFFF59E0B);
                      typeIcon = Icons.hourglass_bottom;
                      break;
                    default:
                      typeColor = const Color(0xFF3B82F6);
                      typeIcon = Icons.add_circle;
                  }

                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 500 + (index * 100)),
                    curve: Curves.easeOut,
                    builder: (context, animation, child) {
                      return Transform.translate(
                        offset: Offset(20 * (1 - animation), 0),
                        child: Opacity(opacity: animation, child: child),
                      );
                    },
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => CaseSummaryScreen(
                                  caseId: caseRecord.caseId,
                                  gender: caseRecord.gender ?? 'Unknown',
                                  age: caseRecord.age?.toString() ?? 'Unknown',
                                  location: caseRecord.location ?? 'Unknown',
                                  symptoms: caseRecord.symptoms,
                                  imagePaths: caseRecord.imagePaths,
                                  predictions: caseRecord.predictions,
                                  createdAt: caseRecord.createdAt,
                                  updatedAt: caseRecord.updatedAt,
                                  isPrePrediction: false,
                                ),
                          ),
                        );
                      },
                      child: Container(
                        margin: EdgeInsets.only(
                          bottom: index < activities.length - 1 ? 12 : 0,
                        ),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(typeIcon, color: typeColor, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Case ${caseRecord.caseId} ${caseRecord.status.toLowerCase()}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          isDark
                                              ? Colors.white
                                              : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getTimeAgo(caseRecord.createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color:
                                  isDark
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade400,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAccuracyMetricsModal(bool isDark) async {
    final metrics = _accuracyMetrics;
    final overall =
        metrics['overall'] ?? {'precision': 0.0, 'recall': 0.0, 'f1Score': 0.0};
    final diagnosisEntries =
        metrics.entries.where((e) => e.key != 'overall').toList();
    final diagColors = [
      const Color(0xFFEF4444),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
      const Color(0xFF22C55E),
      const Color(0xFF6B7280),
    ];

    double clampPct(double v) => v.clamp(0.0, 100.0);

    Widget metricCircle(String label, double value, Color color) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  value: (clampPct(value)) / 100,
                  strokeWidth: 7,
                  backgroundColor: (isDark ? Colors.white24 : Colors.black12),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Text(
                '${value.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      );
    }

    Widget metricBar(String label, double value, Color color) {
      final pct = (clampPct(value)) / 100;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              Text(
                '${value.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      );
    }

    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                decoration: glassBox(isDark, radius: 20, highlight: true),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Accuracy Metrics',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(ctx).pop(),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: glassCircle(isDark, highlight: true),
                              child: Icon(
                                Icons.close,
                                color: isDark ? Colors.white : Colors.black87,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Overall',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          metricCircle(
                            'Precision',
                            (overall['precision'] ?? 0),
                            const Color(0xFF3B82F6),
                          ),
                          metricCircle(
                            'Recall',
                            (overall['recall'] ?? 0),
                            const Color(0xFFF59E0B),
                          ),
                          metricCircle(
                            'F1-Score',
                            (overall['f1Score'] ?? 0),
                            const Color(0xFF22C55E),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'By Diagnosis',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...diagnosisEntries.asMap().entries.map((entry) {
                        final index = entry.key;
                        final diag = entry.value.key;
                        final data = entry.value.value;
                        final color = diagColors[index % diagColors.length];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color:
                                  isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                diag,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              metricBar(
                                'Precision',
                                (data['precision'] ?? 0),
                                color,
                              ),
                              const SizedBox(height: 8),
                              metricBar(
                                'Recall',
                                (data['recall'] ?? 0),
                                const Color(0xFFF59E0B),
                              ),
                              const SizedBox(height: 8),
                              metricBar(
                                'F1-Score',
                                (data['f1Score'] ?? 0),
                                const Color(0xFF22C55E),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDashboardBottomNav(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: glassBox(isDark, radius: 20, highlight: true),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDashboardNavItem('assets/Icons/HomeIcon.svg', 'Home', 0, isDark),
                _buildDashboardNavItem('assets/Icons/DashboardIcon.svg', 'Dashboard', 1, isDark),
                _buildDashboardNavItem('assets/Icons/NotificationIcon.svg', 'Notification', 2, isDark),
                _buildDashboardNavItem('assets/Icons/SettingIcon.svg', 'Setting', 3, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardNavItem(
    String svgAsset,
    String label,
    int index,
    bool isDark,
  ) {
    final isSelected = _currentBottomNavIndex == index;

    final Color iconColor =
        isSelected
            ? (isDark ? const Color(0xFF282828) : const Color(0xFFFEFEFE))
            : (isDark ? Colors.white : Colors.black87);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (index == _currentBottomNavIndex) return;
        if (index == 3) {
          _navigateTo(const SettingsPage());
        } else if (index == 2) {
          _navigateTo(const NotificationPage());
        } else if (index == 0) {
          _navigateTo(const HomePage());
        } else {
          setState(() {
            _currentBottomNavIndex = index;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color.fromARGB(255, 173, 173, 173) : const Color(0xFF282828))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: 1.1,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: SvgPicture.asset(
                svgAsset,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                height: 1.5,
                color: iconColor,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
