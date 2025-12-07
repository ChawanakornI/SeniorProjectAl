
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/glass.dart';
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

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  int _currentBottomNavIndex = 1;
  String _selectedPeriod = 'This Week';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Sample analytics data
  final Map<String, dynamic> _dashboardData = {
    'totalCases': 156,
    'pendingCases': 23,
    'confirmedCases': 118,
    'rejectedCases': 15,
    'totalPatients': 89,
    'newPatientsThisWeek': 12,
    'avgResponseTime': '2.4h',
    'accuracyRate': 94.2,
    // Weekly case trend (Mon-Sun)
    'weeklyTrend': [8, 12, 15, 10, 18, 14, 9],
    // Diagnosis distribution
    'diagnosisDistribution': {
      'Malignant Melanoma': 28,
      'Basal Cell Carcinoma': 35,
      'Actinic Keratosis': 22,
      'Benign Lesion': 45,
      'Other': 26,
    },
    // Recent activity
    'recentActivity': [
      {'time': '10 min ago', 'action': 'Case C000058 confirmed', 'type': 'confirmed'},
      {'time': '25 min ago', 'action': 'New case C000059 assigned', 'type': 'new'},
      {'time': '1h ago', 'action': 'Case C000057 rejected', 'type': 'rejected'},
      {'time': '2h ago', 'action': 'Case C000056 pending review', 'type': 'pending'},
    ],
  };

  // Period-based trend data (labels and values must align)
  // Today: AM=6, PM=9 → total 15
  // This Week: Mon-Sun → total 86
  // This Month: W1-W4 → total 134
  // All Time: Jan-Jun → total 503
  final Map<String, List<int>> _trendSeries = {
    'Today': [6, 9],
    'This Week': [8, 12, 15, 10, 18, 14, 9],
    'This Month': [32, 28, 40, 34],
    'All Time': [80, 74, 90, 95, 88, 76],
  };

  final Map<String, List<String>> _trendLabels = {
    'Today': ['AM', 'PM'],
    'This Week': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    'This Month': ['W1', 'W2', 'W3', 'W4'],
    'All Time': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
  };

  // Period-based stats for cards (totalCases = sum of trendSeries)
  // pendingCases & confirmedCases are proportional subsets
  final Map<String, Map<String, num>> _periodStats = {
    'Today': {
      'totalCases': 15,       // 6+9
      'pendingCases': 3,
      'confirmedCases': 10,
      'accuracyRate': 94.6,
    },
    'This Week': {
      'totalCases': 86,       // 8+12+15+10+18+14+9
      'pendingCases': 12,
      'confirmedCases': 65,
      'accuracyRate': 94.2,
    },
    'This Month': {
      'totalCases': 134,      // 32+28+40+34
      'pendingCases': 18,
      'confirmedCases': 102,
      'accuracyRate': 93.8,
    },
    'All Time': {
      'totalCases': 503,      // 80+74+90+95+88+76
      'pendingCases': 42,
      'confirmedCases': 412,
      'accuracyRate': 92.5,
    },
  };

  final Map<String, Map<String, num>> _previousPeriodStats = {
    // Day-on-day (yesterday)
    'Today': {
      'totalCases': 13,
      'pendingCases': 4,
      'confirmedCases': 8,
      'accuracyRate': 93.9,
    },
    // Week-on-week (last week)
    'This Week': {
      'totalCases': 78,
      'pendingCases': 14,
      'confirmedCases': 56,
      'accuracyRate': 93.5,
    },
    // Month-on-month (last month)
    'This Month': {
      'totalCases': 120,
      'pendingCases': 22,
      'confirmedCases': 88,
      'accuracyRate': 93.1,
    },
    // Year-on-year (last year same period)
    'All Time': {
      'totalCases': 460,
      'pendingCases': 52,
      'confirmedCases': 370,
      'accuracyRate': 91.8,
    },
  };

  // Accuracy metrics (overall and per diagnosis)
  final Map<String, Map<String, double>> _accuracyMetrics = {
    'overall': {'precision': 94.2, 'recall': 92.8, 'f1Score': 93.5},
    'Malignant Melanoma': {'precision': 96.1, 'recall': 94.5, 'f1Score': 95.3},
    'Basal Cell Carcinoma': {'precision': 93.8, 'recall': 91.2, 'f1Score': 92.5},
    'Actinic Keratosis': {'precision': 92.4, 'recall': 90.8, 'f1Score': 91.6},
    'Benign Lesion': {'precision': 95.2, 'recall': 94.1, 'f1Score': 94.6},
    'Other': {'precision': 89.5, 'recall': 87.2, 'f1Score': 88.3},
  };

  Map<String, num> get _currentStats =>
      _periodStats[_selectedPeriod] ?? _periodStats['This Week']!;

  Map<String, num> get _previousStats =>
      _previousPeriodStats[_selectedPeriod] ?? _previousPeriodStats['This Week']!;

  double _percentChange(String key) {
    final current = _currentStats[key] ?? 0;
    final previous = _previousStats[key] ?? 0;
    if (previous == 0) return 0;
    return ((current - previous) / previous) * 100;
  }

  Map<String, dynamic> get _currentTrendData {
    final values = _trendSeries[_selectedPeriod] ?? _trendSeries['This Week']!;
    final labels = _trendLabels[_selectedPeriod] ?? _trendLabels['This Week']!;
    final total = values.fold<int>(0, (sum, v) => sum + v);
    final maxValue = values.isNotEmpty ? values.reduce((a, b) => a > b ? a : b) : 1;
    return {
      'values': values,
      'labels': labels,
      'total': total,
      'max': maxValue == 0 ? 1 : maxValue,
    };
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
    final gradientColors = isDark
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
                              backgroundColor: isDark ? const Color(0xFF0B1628) : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                                  color: isDark ? Colors.white70 : Colors.black87,
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
                        decoration: glassBox(isDark, radius: 12, highlight: true),
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
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileSettingsPage()),
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
                      child: Icon(
                        Icons.person,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
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
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: periods.length,
        itemBuilder: (context, index) {
          final period = periods[index];
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
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF0EA5E9), const Color(0xFF2563EB)]
                            : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected
                    ? null
                    : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
                borderRadius: BorderRadius.circular(26),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                period,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black54),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
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
                  value: '${(_currentStats['accuracyRate'] ?? 0).toStringAsFixed(1)}%',
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
    final changeLabel = '${changePositive ? '+' : ''}${change.toStringAsFixed(1)}%';

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
                        color: color.withOpacity(isDark ? 0.2 : 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: 22,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: changePositive
                            ? const Color(0xFF22C55E).withOpacity(0.15)
                            : const Color(0xFFEF4444).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            changePositive ? Icons.trending_up : Icons.trending_down,
                            size: 14,
                            color: changePositive ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            changeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: changePositive ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? Colors.white.withOpacity(0.1) 
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Cases',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.black.withOpacity(0.06),
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
                      final heightPercent = maxValue == 0 ? 0.0 : value / maxValue;
                      
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
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: 28,
                                  height: 110 * animation,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
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
                                        color: const Color(0xFF3B82F6).withOpacity(0.3),
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
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
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
    final distribution = _dashboardData['diagnosisDistribution'] as Map<String, int>;
    final total = distribution.values.reduce((a, b) => a + b);
    final colors = [
      const Color(0xFFEF4444), // Red - Malignant
      const Color(0xFFF59E0B), // Orange - Basal Cell
      const Color(0xFF8B5CF6), // Purple - Actinic
      const Color(0xFF22C55E), // Green - Benign
      const Color(0xFF6B7280), // Gray - Other
    ];
    
    return Container(
      margin: const EdgeInsets.all(20),
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
                Text(
                  'Diagnosis Distribution',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                // Distribution bars
                ...distribution.entries.toList().asMap().entries.map((entry) {
                  final index = entry.key;
                  final diagnosis = entry.value.key;
                  final count = entry.value.value;
                  final percentage = (count / total * 100).toStringAsFixed(1);
                  final color = colors[index % colors.length];
                  
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: count / total),
                    duration: Duration(milliseconds: 800 + (index * 150)),
                    curve: Curves.easeOutCubic,
                    builder: (context, animation, _) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      diagnosis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? Colors.white : Colors.black87,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '$count ($percentage%)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 8,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isDark 
                                    ? Colors.white.withOpacity(0.1) 
                                    : Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: animation,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [color, color.withOpacity(0.7)],
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withOpacity(0.4),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity(bool isDark) {
    final activities = _dashboardData['recentActivity'] as List<Map<String, String>>;
    
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
                        // View all activity
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
                  final activity = entry.value;
                  final type = activity['type']!;
                  
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
                        child: Opacity(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      margin: EdgeInsets.only(bottom: index < activities.length - 1 ? 12 : 0),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? Colors.white.withOpacity(0.05) 
                            : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark 
                              ? Colors.white.withOpacity(0.08) 
                              : Colors.black.withOpacity(0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              typeIcon,
                              color: typeColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activity['action']!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  activity['time']!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                            size: 20,
                          ),
                        ],
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
    final overall = metrics['overall'] ?? {'precision': 0.0, 'recall': 0.0, 'f1Score': 0.0};
    final diagnosisEntries = metrics.entries.where((e) => e.key != 'overall').toList();
    final diagColors = [
      const Color(0xFFEF4444),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
      const Color(0xFF22C55E),
      const Color(0xFF6B7280),
    ];

    double _clampPct(double v) => v.clamp(0.0, 100.0);

    Widget _metricCircle(String label, double value, Color color) {
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
                  value: (_clampPct(value)) / 100,
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

    Widget _metricBar(String label, double value, Color color) {
      final pct = (_clampPct(value)) / 100;
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
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                          _metricCircle('Precision', (overall['precision'] ?? 0), const Color(0xFF3B82F6)),
                          _metricCircle('Recall', (overall['recall'] ?? 0), const Color(0xFFF59E0B)),
                          _metricCircle('F1-Score', (overall['f1Score'] ?? 0), const Color(0xFF22C55E)),
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
                            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
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
                              _metricBar('Precision', (data['precision'] ?? 0), color),
                              const SizedBox(height: 8),
                              _metricBar('Recall', (data['recall'] ?? 0), const Color(0xFFF59E0B)),
                              const SizedBox(height: 8),
                              _metricBar('F1-Score', (data['f1Score'] ?? 0), const Color(0xFF22C55E)),
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
                _buildDashboardNavItem(Icons.home, 'Home', 0, isDark),
                _buildDashboardNavItem(Icons.dashboard, 'Dashboard', 1, isDark),
                _buildDashboardNavItem(Icons.notifications, 'Notification', 2, isDark),
                _buildDashboardNavItem(Icons.settings, 'Setting', 3, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardNavItem(IconData icon, String label, int index, bool isDark) {
    final isSelected = _currentBottomNavIndex == index;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (index == 3) {
          setState(() {
            _currentBottomNavIndex = 3;
          });
          _navigateTo(const SettingsPage());
        } else if (index == 2) {
          setState(() {
            _currentBottomNavIndex = 2;
          });
          _navigateTo(const NotificationPage());
        } else if (index == 0) {
          setState(() {
            _currentBottomNavIndex = 0;
          });
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1976D2).withOpacity(0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(
                  color: const Color(0xFF1976D2),
                  width: 2.5,
                )
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                color: isSelected
                    ? const Color(0xFF1976D2)
                    : (isDark ? Colors.white : Colors.black87),
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? const Color(0xFF1976D2)
                    : (isDark ? Colors.white : Colors.black87),
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
