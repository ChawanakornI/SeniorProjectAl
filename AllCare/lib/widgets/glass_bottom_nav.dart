import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/glass.dart';

class GlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const GlassBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: glassCase(isDark, radius: 20, highlight: true),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  'assets/Icons/HomeIcon.svg',
                  'Home',
                  0,
                  isDark,
                ),
                _buildNavItem(
                  'assets/Icons/DashboardIcon.svg',
                  'Dashboard',
                  1,
                  isDark,
                ),
                _buildNavItem(
                  'assets/Icons/NotificationIcon.svg',
                  'Notification',
                  2,
                  isDark,
                ),
                _buildNavItem(
                  'assets/Icons/SettingIcon.svg',
                  'Setting',
                  3,
                  isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    String svgAsset,
    String label,
    int index,
    bool isDark,
  ) {
    final isSelected = currentIndex == index;

    final Color iconColor = isSelected
        ? (isDark ? const Color(0xFF282828) : const Color(0xFFFEFEFE))
        : (isDark ? Colors.white : Colors.black87);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? const Color.fromARGB(255, 173, 173, 173)
                  : const Color(0xFF282828))
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
