
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/glass.dart';
import 'dashboard_page.dart';
import 'home_page.dart';
import 'settings_page.dart';

class NotificationItem {
  final String id;
  final String title;
  final String subtitle;
  final DateTime createdAt;
  final String type; // 'new_case' or 'reminder'
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.createdAt,
    required this.type,
    this.isRead = false,
  });
}

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  late List<NotificationItem> _items;
  int _currentBottomNavIndex = 2;
  String _filter = 'all'; // all, new_case, reminder

  @override
  void initState() {
    super.initState();
    _seedNotifications();
  }

  void _seedNotifications() {
    final now = DateTime.now();
    _items = [
      NotificationItem(
        id: 'n1',
        title: 'New case assigned: C000058',
        subtitle: 'General practitioner forwarded for expert labeling',
        createdAt: now.subtract(const Duration(minutes: 12)),
        type: 'new_case',
      ),
      NotificationItem(
        id: 'n2',
        title: 'Reminder: C000056 pending labeling',
        subtitle: 'Follow up: lesion classification still required',
        createdAt: now.subtract(const Duration(hours: 2, minutes: 15)),
        type: 'reminder',
      ),
      NotificationItem(
        id: 'n3',
        title: 'New case assigned: C000059',
        subtitle: 'Urgent triage requested by GP at Rural Hospital',
        createdAt: now.subtract(const Duration(hours: 5, minutes: 30)),
        type: 'new_case',
      ),
      NotificationItem(
        id: 'n4',
        title: 'Reminder: C000055 labeling due',
        subtitle: 'Confirm malignant/benign before end of day',
        createdAt: now.subtract(const Duration(days: 1, hours: 1)),
        type: 'reminder',
      ),
    ];
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

  List<NotificationItem> get _filteredItems {
    if (_filter == 'all') return _items;
    return _items.where((n) => n.type == _filter).toList();
  }

  Widget _buildFilterChips(bool isDark) {
    final options = [
      {'label': 'All', 'value': 'all'},
      {'label': 'New cases', 'value': 'new_case'},
      {'label': 'Pending labeling', 'value': 'reminder'},
    ];
    return Row(
      children: options.map((opt) {
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF2563EB).withOpacity(0.2)
                    : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? const Color(0xFF2563EB) : Colors.transparent,
                  width: 1.3,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(0.28),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                opt['label']!,
                style: TextStyle(
                  color: selected
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

  Color _typeColor(String type) {
    switch (type) {
      case 'reminder':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF22C55E);
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'reminder':
        return Icons.hourglass_bottom;
      default:
        return Icons.assignment_turned_in;
    }
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
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
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
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = _filteredItems[index];
                    final color = _typeColor(item.type);
                    final icon = _typeIcon(item.type);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            item.isRead = true;
                          });
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: glassBox(isDark, radius: 16, highlight: true).copyWith(
                                border: Border.all(
                                  color: color.withOpacity(isDark ? 0.6 : 0.4),
                                  width: item.isRead ? 1 : 1.6,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: glassCircle(isDark, highlight: true).copyWith(
                                      gradient: LinearGradient(
                                        colors: [
                                          color.withOpacity(0.8),
                                          color.withOpacity(0.5),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: Icon(icon, color: Colors.white),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: color.withOpacity(isDark ? 0.28 : 0.18),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(color: color.withOpacity(0.4), width: 1.1),
                                              ),
                                              child: Text(
                                                item.type == 'reminder' ? 'Pending Labeling' : 'New Case',
                                                style: TextStyle(
                                                  color: isDark ? Colors.white : Colors.black87,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              _relativeTime(item.createdAt),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? Colors.white70 : Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          item.title,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.subtitle,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark ? Colors.white70 : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!item.isRead)
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: color.withOpacity(0.6),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          _notificationNavItem(Icons.home, 'Home', 0, isDark),
                          _notificationNavItem(Icons.dashboard, 'Dashboard', 1, isDark),
                          _notificationNavItem(Icons.notifications, 'Notification', 2, isDark),
                          _notificationNavItem(Icons.settings, 'Setting', 3, isDark),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notificationNavItem(IconData icon, String label, int index, bool isDark) {
    final isSelected = _currentBottomNavIndex == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (index == 2) return;
        if (index == 3) {
          setState(() {
            _currentBottomNavIndex = 3;
          });
          _navigateTo(const SettingsPage());
        } else if (index == 0) {
          setState(() {
            _currentBottomNavIndex = 0;
          });
          _navigateTo(const HomePage());
        } else if (index == 1) {
          setState(() {
            _currentBottomNavIndex = 1;
          });
          _navigateTo(const DashboardPage());
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
