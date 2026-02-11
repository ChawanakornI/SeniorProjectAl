import 'package:flutter/material.dart';

// Reusable glassmorphism helpers to keep dark mode surfaces consistent
BoxDecoration glassBox(
  bool isDark, {
  double radius = 16,
  bool highlight = false,
}) {
  final darkGradient = [
    const Color(0xFF0B1628).withValues(alpha: 0.82),
    const Color(0xFF0E1F35).withValues(alpha: 0.76),
  ];
  final lightGradient = [
    Colors.white.withValues(alpha: 0.92),
    Colors.white.withValues(alpha: 0.86),
  ];

  return BoxDecoration(
    gradient: LinearGradient(
      colors: isDark ? darkGradient : lightGradient,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color:
          isDark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.black.withValues(alpha: 0.06),
      width: 1.4,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.2),
        blurRadius: 4,
        offset: Offset(0, 0.5),
      ),
    ],
  );
}

BoxDecoration glassCircle(bool isDark, {bool highlight = false}) {
  final base = glassBox(isDark, highlight: highlight);
  return BoxDecoration(
    // gradient: base.gradient,
    shape: BoxShape.circle,
    border: base.border,
    // boxShadow: base.boxShadow,
  );
}

BoxDecoration glassCalendarCircle({required bool isDark, double radius = 30}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    color: const Color(0xFFEFEFEF),

    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.1),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

BoxDecoration glassSearchBox({required bool isDark, double radius = 30}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    color: isDark ? Color.fromARGB(255, 19, 19, 19) : Color(0xFFEFEFEF),

    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.1),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

BoxDecoration glassSearchFilter({required bool isDark, bool highlight = true}) {
  return BoxDecoration(
    shape: BoxShape.circle,
    color: const Color.fromARGB(255, 0, 0, 0),
    border: Border.all(
      color:
          isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
      width: 1,
    ),
  );
}

BoxDecoration glassCalendar(bool isDark, {double radius = 16}) {
  return BoxDecoration(
    color:
        isDark
            ? Color(0xFF282828) // dark navy
            : Color(0xFF282828), // light mode
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color:
          isDark
              ? Colors.black.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
      width: 1.2,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

BoxDecoration modalBox(bool isDark, {double radius = 18}) {
  return BoxDecoration(
    color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFFBFBFB),
    borderRadius: BorderRadius.circular(radius),

    boxShadow: [
      /// 🌫 Main drop shadow (depth)
      BoxShadow(
        color: const Color.fromARGB(255, 255, 255, 255).withValues(alpha: 0.45),
        blurRadius: 10,
        spreadRadius: 2,
        offset: const Offset(0, 8),
      ),

      BoxShadow(
        color: Colors.black.withValues(alpha: 0.25),
        blurRadius: 60,
        offset: const Offset(0, 8),
      ),

      if (isDark)
        BoxShadow(
          color: const Color(0xFFFBFBFB).withValues(alpha: 0.08),
          blurRadius: 10,
          spreadRadius: 2,
          offset: const Offset(0, 8),
        ),

      if (isDark)
        BoxShadow(
          color: const Color(0xFFFBFBFB).withValues(alpha: 0.04),
          blurRadius: 60,
          offset: const Offset(0, 8),
        ),
    ],
  );
}

BoxDecoration glassBoxSection(
  bool isDark, {
  double radius = 16,
  bool highlight = true,
}) {
  return BoxDecoration(
    color:
        isDark
            ? Colors.white.withValues(alpha: 0.10) // Dark mode
            : const Color(0xFFFBFBFB), // Light mode

    borderRadius: BorderRadius.circular(radius),

    border: Border.all(
      color:
          isDark
              ? Colors.white.withValues(alpha: 0.20)
              : Colors.black.withValues(alpha: 0.08),
      width: 1.2,
    ),
  );
}

BoxDecoration glassCoverCalendar(
  bool isDark, {
  double radius = 16,
  bool highlight = false,
}) {
  final lightGradient = [
    Colors.white.withValues(alpha: 0.92),
    Colors.white.withValues(alpha: 0.86),
  ];

  return BoxDecoration(
    gradient: LinearGradient(
      colors: lightGradient,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color:
          isDark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.black.withValues(alpha: 0.06),
      width: 1.4,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.2),
        blurRadius: 4,
        offset: Offset(0, 0.5),
      ),
    ],
  );
}

BoxDecoration glassFilter(
  bool isDark, {
  double radius = 16,
  bool highlight = false,
}) {
  final darkGradient = [
    const Color.fromARGB(255, 0, 0, 0),
    const Color.fromARGB(255, 0, 0, 0),
  ];
  final lightGradient = [
    Colors.white.withValues(alpha: 0.92),
    Colors.white.withValues(alpha: 0.86),
  ];

  return BoxDecoration(
    gradient: LinearGradient(
      colors: isDark ? darkGradient : lightGradient,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color:
          isDark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.black.withValues(alpha: 0.06),
      width: 1.4,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.2),
        blurRadius: 4,
        offset: Offset(0, 0.5),
      ),
    ],
  );
}

BoxDecoration glassCase(
  bool isDark, {
  double radius = 16,
  bool highlight = false,
}) {
  final darkGradient = [const Color(0xFF282828), const Color(0xFF282828)];
  final lightGradient = [
    Colors.white.withValues(alpha: 0.92),
    Colors.white.withValues(alpha: 0.86),
  ];

  return BoxDecoration(
    gradient: LinearGradient(
      colors: isDark ? darkGradient : lightGradient,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color:
          isDark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.black.withValues(alpha: 0.06),
      width: 1.4,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.2),
        blurRadius: 4,
        offset: Offset(0, 0.5),
      ),
    ],
  );
}
