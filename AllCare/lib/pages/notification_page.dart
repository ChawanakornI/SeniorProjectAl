import 'dart:developer';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../theme/glass.dart';
import '../widgets/glass_bottom_nav.dart';
import '../features/case/case_service.dart';
import '../features/case/case_summary_screen.dart';
import 'dashboard_page.dart';
import 'home_page.dart';
import 'settings_page.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<CaseRecord> _cases = [];
  bool _isLoading = false;
  String? _error;
  final int _currentBottomNavIndex = 2;
  String _filter = 'all'; // all, new_case, pending

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  Future<void> _loadCases() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final cases = await context.read<CaseService>().fetchCases();
      if (mounted) {
        setState(() {
          _cases = cases;
          _isLoading = false;
        });
      }
    } catch (e) {
      log('Failed to load cases: $e', name: 'NotificationPage');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
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

  List<CaseRecord> get _filteredCases {
    if (_filter == 'all') return _cases;
    if (_filter == 'new_case') {
      // New cases: Confirmed status
      return _cases.where((c) => c.status == 'Confirmed').toList();
    }
    if (_filter == 'pending') {
      // Pending labeling: pending status
      return _cases.where((c) => c.status == 'pending').toList();
    }
    return _cases;
  }

  Widget _buildFilterChips(bool isDark) {
    final options = [
      {'label': 'All', 'value': 'all'},
      {'label': 'New cases', 'value': 'new_case'},
      {'label': 'Pending labeling', 'value': 'pending'},
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children:
            options.map((opt) {
              final selected = _filter == opt['value'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _filter = opt['value']!;
                    });
                    HapticFeedback.lightImpact();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          selected
                              ? const Color(0xFF2563EB).withValues(alpha: 0.2)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            selected
                                ? const Color(0xFF2563EB)
                                : Colors.transparent,
                        width: 1.3,
                      ),
                      boxShadow:
                          selected
                              ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF2563EB,
                                  ).withValues(alpha: 0.28),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                              : null,
                    ),
                    child: Text(
                      opt['label']!,
                      style: TextStyle(
                        color:
                            selected
                                ? (isDark ? Colors.white : Colors.black87)
                                : (isDark ? Colors.white70 : Colors.black54),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  String _relativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
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
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    if (_cases.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          showDialog(
                            context: context,
                            builder:
                                (ctx) => AlertDialog(
                                  backgroundColor:
                                      isDark
                                          ? const Color(0xFF0B1628)
                                          : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  title: Text(
                                    'Clear Notifications',
                                    style: TextStyle(
                                      color:
                                          isDark
                                              ? Colors.white
                                              : Colors.black87,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  content: Text(
                                    'Are you sure you want to clear all notifications?',
                                    style: TextStyle(
                                      color:
                                          isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          _cases = [];
                                        });
                                        Navigator.of(ctx).pop();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      child: const Text(
                                        'Clear',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                          );
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
                            border: Border.all(
                              color:
                                  isDark
                                      ? Colors.white.withValues(alpha: 0.2)
                                      : Colors.black.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.clear_all,
                                size: 16,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Clear',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: _buildFilterChips(isDark),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadCases,
                  color: isDark ? Colors.white : Colors.blue,
                  child:
                      _isLoading
                          ? Center(
                            child: CircularProgressIndicator(
                              color:
                                  isDark ? Colors.white70 : Colors.blueAccent,
                            ),
                          )
                          : _error != null
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cloud_off,
                                  size: 48,
                                  color:
                                      isDark
                                          ? Colors.red.shade300
                                          : Colors.red.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Could not load notifications',
                                  style: TextStyle(
                                    color:
                                        isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _loadCases,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                          : _filteredCases.isEmpty
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.notifications_off_outlined,
                                  size: 48,
                                  color:
                                      isDark
                                          ? Colors.grey.shade500
                                          : Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No notifications',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color:
                                        isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                          : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _filteredCases.length,
                            itemBuilder: (context, index) {
                              final caseItem = _filteredCases[index];
                              final isPending = caseItem.status == 'pending';
                              final color =
                                  isPending
                                      ? const Color(
                                        0xFFF59E0B,
                                      ) // Amber for pending
                                      : const Color(
                                        0xFF22C55E,
                                      ); // Green for confirmed
                              final icon =
                                  isPending
                                      ? Icons.hourglass_bottom
                                      : Icons.assignment_turned_in;

                              // Parse createdAt for relative time
                              DateTime? createdAt;
                              if (caseItem.createdAt != null) {
                                try {
                                  createdAt = DateTime.parse(
                                    caseItem.createdAt!,
                                  );
                                } catch (_) {}
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => CaseSummaryScreen(
                                              caseId: caseItem.caseId,
                                              gender:
                                                  caseItem.gender ?? 'Unknown',
                                              age:
                                                  caseItem.age?.toString() ??
                                                  'Unknown',
                                              location:
                                                  caseItem.location ??
                                                  'Unknown',
                                              symptoms: caseItem.symptoms,
                                              imagePaths: caseItem.imagePaths,
                                              predictions: caseItem.predictions,
                                              createdAt: caseItem.createdAt,
                                              updatedAt: caseItem.updatedAt,
                                              isPrePrediction: false,
                                            ),
                                      ),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 12,
                                        sigmaY: 12,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: glassBox(
                                          isDark,
                                          radius: 16,
                                          highlight: true,
                                        ).copyWith(
                                          border: Border.all(
                                            color: color.withValues(alpha: 
                                              isDark ? 0.6 : 0.4,
                                            ),
                                            width: 1.6,
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: 46,
                                              height: 46,
                                              decoration: glassCircle(
                                                isDark,
                                                highlight: true,
                                              ).copyWith(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    color.withValues(alpha: 0.8),
                                                    color.withValues(alpha: 0.5),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                              ),
                                              child: Icon(
                                                icon,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Flexible(
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 10,
                                                                vertical: 4,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: color
                                                                .withValues(alpha: 
                                                                  isDark
                                                                      ? 0.28
                                                                      : 0.18,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  20,
                                                                ),
                                                            border: Border.all(
                                                              color: color
                                                                  .withValues(alpha: 
                                                                    0.4,
                                                                  ),
                                                              width: 1.1,
                                                            ),
                                                          ),
                                                          child: Text(
                                                            isPending
                                                                ? 'Pending Labeling'
                                                                : 'New Case',
                                                            style: TextStyle(
                                                              color:
                                                                  isDark
                                                                      ? Colors
                                                                          .white
                                                                      : Colors
                                                                          .black87,
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      if (createdAt != null)
                                                        Text(
                                                          _relativeTime(
                                                            createdAt,
                                                          ),
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color:
                                                                isDark
                                                                    ? Colors
                                                                        .white70
                                                                    : Colors
                                                                        .black54,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Case: ${caseItem.caseId}',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          isDark
                                                              ? Colors.white
                                                              : Colors.black87,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Prediction: ${caseItem.topPredictionLabel}',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color:
                                                          isDark
                                                              ? Colors.white70
                                                              : Colors.black54,
                                                    ),
                                                  ),
                                                  if (caseItem.location !=
                                                      null) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'Location: ${caseItem.location}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            isDark
                                                                ? Colors.white60
                                                                : Colors
                                                                    .black45,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                ),
              ),
              GlassBottomNav(
                currentIndex: _currentBottomNavIndex,
                onTap: (index) {
                  if (index == _currentBottomNavIndex) return;
                  if (index == 3) {
                    _navigateTo(const SettingsPage());
                  } else if (index == 0) {
                    _navigateTo(const HomePage());
                  } else if (index == 1) {
                    _navigateTo(const DashboardPage());
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

}
