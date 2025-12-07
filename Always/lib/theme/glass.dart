import 'package:flutter/material.dart';

// Reusable glassmorphism helpers to keep dark mode surfaces consistent
BoxDecoration glassBox(bool isDark, {double radius = 16, bool highlight = false}) {
  final darkGradient = [
    const Color(0xFF0B1628).withOpacity(0.82),
    const Color(0xFF0E1F35).withOpacity(0.76),
  ];
  final lightGradient = [
    Colors.white.withOpacity(0.92),
    Colors.white.withOpacity(0.86),
  ];

  return BoxDecoration(
    gradient: LinearGradient(
      colors: isDark ? darkGradient : lightGradient,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: isDark ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.06),
      width: 1.4,
    ),
    boxShadow: [
      BoxShadow(
        color: isDark
            ? const Color(0xFF38BDF8).withOpacity(highlight ? 0.24 : 0.14)
            : Colors.black.withOpacity(0.06),
        blurRadius: highlight ? 36 : 26,
        offset: const Offset(0, 14),
      ),
      if (isDark)
        BoxShadow(
          color: Colors.black.withOpacity(0.35),
          blurRadius: 32,
          offset: const Offset(0, 18),
        ),
    ],
  );
}

BoxDecoration glassCircle(bool isDark, {bool highlight = false}) {
  final base = glassBox(isDark, highlight: highlight);
  return BoxDecoration(
    gradient: base.gradient,
    shape: BoxShape.circle,
    border: base.border,
    boxShadow: base.boxShadow,
  );
}
