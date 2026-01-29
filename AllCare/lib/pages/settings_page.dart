
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../theme/glass.dart';
import '../widgets/glass_bottom_nav.dart';
import '../routes.dart';
import 'dashboard_page.dart';
import 'home_page.dart';
import 'notification_page.dart';

// App Settings Page (accessed via settings icon in bottom nav)
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _currentBottomNavIndex = 3;

  @override
  void initState() {
    super.initState();
    appState.addListener(_onAppStateChanged);
  }

  @override
  void dispose() {
    appState.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    setState(() {});
  }

  void _navigateTo(Widget page, int newIndex) {
    setState(() {
      _currentBottomNavIndex = newIndex;
    });
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

  Future<void> _confirmLogout(BuildContext context, bool isDark) async {
    HapticFeedback.lightImpact();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0B1628) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            appState.translate('Logout', 'ออกจากระบบ'),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            appState.translate('Are you sure you want to logout?', 'คุณต้องการออกจากระบบหรือไม่?'),
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                appState.translate('No', 'ไม่'),
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(appState.translate('Yes', 'ใช่')),
            ),
          ],
        );
      },
    );

    if (!context.mounted) return;
    if (result == true) {
      // Clear user session data before navigating to login
      appState.clearUserSession();
      Navigator.of(context).pushNamedAndRemoveUntil(Routes.login, (route) => false);
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
              // Header
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Text(
                      appState.translate('App Settings', 'ตั้งค่าแอป'),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // Language Selection
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: glassBox(isDark, radius: 20, highlight: true),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.language,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      appState.translate('Language', 'ภาษา'),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                  child: Container(
                                      decoration: glassBox(isDark, radius: 12),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              HapticFeedback.lightImpact();
                                              appState.setLanguage('English');
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 20,
                                                vertical: 12,
                                              ),
                                              decoration: BoxDecoration(
                                                color: appState.language == 'English'
                                                    ? const Color(0xFF1976D2)
                                                        .withValues(alpha: 0.3)
                                                    : Colors.transparent,
                                                borderRadius: BorderRadius.circular(8),
                                                border: appState.language == 'English'
                                                    ? Border.all(
                                                        color: const Color(0xFF1976D2),
                                                        width: 2,
                                                      )
                                                    : null,
                                              ),
                                              child: Text(
                                                'English',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: appState.language == 'English'
                                                      ? const Color(0xFF1976D2)
                                                      : (isDark
                                                          ? Colors.grey.shade300
                                                          : Colors.grey.shade700),
                                                ),
                                              ),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              HapticFeedback.lightImpact();
                                              appState.setLanguage('Thai');
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 20,
                                                vertical: 12,
                                              ),
                                              decoration: BoxDecoration(
                                                color: appState.language == 'Thai'
                                                    ? const Color(0xFF1976D2)
                                                        .withValues(alpha: 0.3)
                                                    : Colors.transparent,
                                                borderRadius: BorderRadius.circular(8),
                                                border: appState.language == 'Thai'
                                                    ? Border.all(
                                                        color: const Color(0xFF1976D2),
                                                        width: 2,
                                                      )
                                                    : null,
                                              ),
                                              child: Text(
                                                'ไทย',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: appState.language == 'Thai'
                                                      ? const Color(0xFF1976D2)
                                                      : (isDark
                                                          ? Colors.grey.shade300
                                                          : Colors.grey.shade700),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Dark/Light Mode Toggle
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: glassBox(isDark, radius: 20, highlight: true),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      appState.isDarkMode
                                          ? Icons.dark_mode
                                          : Icons.light_mode,
                                      color: isDark ? Colors.white : Colors.black87,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      appState.translate(
                                        appState.isDarkMode
                                            ? 'Dark Mode'
                                            : 'Light Mode',
                                        appState.isDarkMode
                                            ? 'โหมดมืด'
                                            : 'โหมดสว่าง',
                                      ),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    appState.setDarkMode(!appState.isDarkMode);
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        width: 60,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: appState.isDarkMode
                                              ? const Color(0xFF1976D2)
                                              : Colors.grey.shade300,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: (isDark ? Colors.white : Colors.black)
                                                .withValues(alpha: 0.3),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Stack(
                                          children: [
                                            AnimatedPositioned(
                                              duration: const Duration(milliseconds: 200),
                                              curve: Curves.easeInOut,
                                              left: appState.isDarkMode ? 30 : 2,
                                              top: 2,
                                              child: Container(
                                                width: 28,
                                                height: 28,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.2),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Icon(
                                                  appState.isDarkMode
                                                      ? Icons.dark_mode
                                                      : Icons.light_mode,
                                                  size: 16,
                                                  color: appState.isDarkMode
                                                      ? const Color(0xFF1976D2)
                                                      : Colors.orange,
                                                ),
                                              ),
                                            ),
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
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Logout Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: glassBox(isDark, radius: 20, highlight: true),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.logout,
                                color: isDark ? Colors.white : Colors.black87,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                appState.translate('Logout', 'ออกจากระบบ'),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE11D48),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () => _confirmLogout(context, isDark),
                            child: Text(
                              appState.translate('Logout', 'ออกจากระบบ'),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GlassBottomNav(
                currentIndex: _currentBottomNavIndex,
                onTap: (index) {
                  if (index == _currentBottomNavIndex) return;
                  if (index == 0) {
                    _navigateTo(const HomePage(), 0);
                  } else if (index == 1) {
                    _navigateTo(const DashboardPage(), 1);
                  } else if (index == 2) {
                    _navigateTo(const NotificationPage(), 2);
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

