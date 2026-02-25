import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/glass.dart';

/// A reusable calendar widget that supports both week and month views.
///
/// This widget manages its own navigation state (current week/month, view mode)
/// while delegating date selection and data indicators to parent widgets via callbacks.
class CalendarWidget extends StatefulWidget {
  /// The currently selected date (if any)
  final DateTime? selectedDate;

  /// Callback when user selects a date
  final Function(DateTime?) onDateSelected;

  /// Optional callback to determine if a date should show an indicator dot
  final bool Function(DateTime)? hasIndicatorForDate;

  /// Optional primary color (defaults to theme primary color)
  final Color? primaryColor;

  /// Whether dark mode is active
  final bool isDark;

  const CalendarWidget({
    super.key,
    this.selectedDate,
    required this.onDateSelected,
    this.hasIndicatorForDate,
    this.primaryColor,
    this.isDark = false,
  });

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  // Internal navigation state
  late DateTime _currentWeekStart;
  late DateTime _currentMonth;
  bool _isMonthView = false;

  @override
  void initState() {
    super.initState();
    // Initialize based on selected date or today
    final referenceDate = widget.selectedDate ?? DateTime.now();
    _currentWeekStart = _getWeekStart(referenceDate);
    _currentMonth = DateTime(referenceDate.year, referenceDate.month, 1);
  }

  // Helper: Get the Monday of the week containing the given date
  static DateTime _getWeekStart(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return date.subtract(Duration(days: daysFromMonday));
  }

  // Helper: Check if two dates are the same day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // Helper: Get month abbreviation
  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }

  // Helper: Get current week days (7 days starting from _currentWeekStart)
  List<DateTime> _getCurrentWeekDays() {
    final List<DateTime> days = [];
    for (int i = 0; i < 7; i++) {
      days.add(_currentWeekStart.add(Duration(days: i)));
    }
    return days;
  }

  // Helper: Get all days to display in month view (including padding days)
  List<DateTime> _getMonthDays() {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

    int firstWeekday = firstDayOfMonth.weekday;
    int offset = firstWeekday - 1;

    final List<DateTime> days = [];

    // Add days from previous month if needed
    if (offset > 0) {
      final lastDayPreviousMonth = DateTime(_currentMonth.year, _currentMonth.month, 0).day;
      final previousMonthYear = _currentMonth.month == 1 ? _currentMonth.year - 1 : _currentMonth.year;
      final previousMonth = _currentMonth.month == 1 ? 12 : _currentMonth.month - 1;

      for (int i = lastDayPreviousMonth - offset + 1; i <= lastDayPreviousMonth; i++) {
        days.add(DateTime(previousMonthYear, previousMonth, i));
      }
    }

    // Add days of current month
    for (int i = 1; i <= lastDayOfMonth.day; i++) {
      days.add(DateTime(_currentMonth.year, _currentMonth.month, i));
    }

    // Fill remaining days to complete the week
    final remainingDays = 7 - (days.length % 7);
    if (remainingDays < 7) {
      final nextMonthYear = _currentMonth.month == 12 ? _currentMonth.year + 1 : _currentMonth.year;
      final nextMonth = _currentMonth.month == 12 ? 1 : _currentMonth.month + 1;

      for (int i = 1; i <= remainingDays; i++) {
        days.add(DateTime(nextMonthYear, nextMonth, i));
      }
    }

    return days;
  }

  // Helper: Get week range string (e.g., "Jan 1 - 7, 2024")
  String _getWeekRange() {
    final weekEnd = _currentWeekStart.add(const Duration(days: 6));
    final startMonth = _getMonthName(_currentWeekStart.month);
    final endMonth = _getMonthName(weekEnd.month);

    if (_currentWeekStart.month == weekEnd.month) {
      return '$startMonth ${_currentWeekStart.day} - ${weekEnd.day}, ${_currentWeekStart.year}';
    } else {
      return '$startMonth ${_currentWeekStart.day} - $endMonth ${weekEnd.day}, ${_currentWeekStart.year}';
    }
  }

  // Helper: Get day abbreviation
  String _getDayAbbreviation(int weekday) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[weekday - 1];
  }

  // Helper: Check if can navigate to previous week/month
  bool _canNavigatePrevious() {
    if (_isMonthView) {
      return _currentMonth.year > 2020 || (_currentMonth.year == 2020 && _currentMonth.month > 1);
    } else {
      final previousWeek = _currentWeekStart.subtract(const Duration(days: 7));
      return previousWeek.year >= 2020;
    }
  }

  // Helper: Check if can navigate to next week/month
  bool _canNavigateNext() {
    if (_isMonthView) {
      return _currentMonth.year < 2030 || (_currentMonth.year == 2030 && _currentMonth.month < 12);
    } else {
      final nextWeek = _currentWeekStart.add(const Duration(days: 7));
      return nextWeek.year <= 2030;
    }
  }

  // Jump to today; toggle off if already selected
  void _jumpToToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final alreadySelected =
        widget.selectedDate != null && _isSameDay(widget.selectedDate!, today);
    setState(() {
      widget.onDateSelected(alreadySelected ? null : today);
      _currentMonth = DateTime(today.year, today.month, 1);
      _currentWeekStart = _getWeekStart(today);
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    isCurrentMonth(date) => date.year == _currentMonth.year && date.month == _currentMonth.month;

    final baseTextColor = widget.isDark ? Colors.white : const Color(0xFFFBFBFB);
    final mutedTextColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.black.withValues(alpha: 0.6);
    final accent = widget.isDark ? const Color(0xFF38BDF8) : const Color(0xFFFBFBFB);
    final selectionFill = widget.isDark ? const Color(0xFF282828) : const Color(0xFF282828);
    final selectionBorder = accent.withValues(alpha: widget.isDark ? 0.9 : 0.8);
    final selectionTextColor = widget.isDark ? Colors.black : const Color(0xFFFBFBFB);
    final todayFill = widget.isDark
        ? Colors.white.withValues(alpha: 0.18)
        : const Color(0xFFFEFEFE);
    final todayBorder = widget.isDark
        ? Colors.white.withValues(alpha: 0.7)
        : const Color(0xFFFEFEFE);

    final navLabelSize = () {
      final width = MediaQuery.of(context).size.width;
      if (width < 360) return 10.0;
      if (width < 420) return 11.0;
      return 12.0;
    }();

    final isTodaySelected = widget.selectedDate != null && _isSameDay(widget.selectedDate!, today);

    return Container(
      margin: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(7, 10, 7, 11),
            decoration: glassCalendar(widget.isDark, radius: 16),
            child: Column(
              children: [
                // Navigation header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Previous button
                          IconButton(
                            icon: Icon(
                              Icons.chevron_left,
                              color: _canNavigatePrevious()
                                  ? (widget.isDark ? const Color(0xFFFBFBFB) : const Color(0xFFFBFBFB))
                                  : (widget.isDark
                                      ? const Color.fromARGB(255, 190, 190, 190)
                                      : const Color.fromARGB(255, 190, 190, 190))
                                      .withValues(alpha: 0.3),
                              size: 30,
                            ),
                            onPressed: _canNavigatePrevious()
                                ? () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      if (_isMonthView) {
                                        // Navigate to previous month
                                        if (_currentMonth.month == 1) {
                                          _currentMonth = DateTime(_currentMonth.year - 1, 12);
                                        } else {
                                          _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                                        }
                                        // Deselect if selected date is not in the new month
                                        if (widget.selectedDate != null) {
                                          if (widget.selectedDate!.year != _currentMonth.year ||
                                              widget.selectedDate!.month != _currentMonth.month) {
                                            widget.onDateSelected(null);
                                          }
                                        }
                                      } else {
                                        // Navigate to previous week
                                        _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
                                        // Deselect if selected date is not in the new week
                                        if (widget.selectedDate != null) {
                                          final weekEnd = _currentWeekStart.add(const Duration(days: 6));
                                          final selectedNormalized = DateTime(
                                            widget.selectedDate!.year,
                                            widget.selectedDate!.month,
                                            widget.selectedDate!.day,
                                          );
                                          final weekStartNormalized = DateTime(
                                            _currentWeekStart.year,
                                            _currentWeekStart.month,
                                            _currentWeekStart.day,
                                          );
                                          final weekEndNormalized = DateTime(
                                            weekEnd.year,
                                            weekEnd.month,
                                            weekEnd.day,
                                          );

                                          if (selectedNormalized.isBefore(weekStartNormalized) ||
                                              selectedNormalized.isAfter(weekEndNormalized)) {
                                            widget.onDateSelected(null);
                                          }
                                        }
                                      }
                                    });
                                  }
                                : null,
                          ),
                          // Month/week label
                          Expanded(
                            child: Text(
                              _isMonthView
                                  ? '${_getMonthName(_currentMonth.month)} ${_currentMonth.year}'
                                  : _getWeekRange(),
                              style: GoogleFonts.inter(
                                fontSize: navLabelSize,
                                fontWeight: FontWeight.bold,
                                color: widget.isDark
                                    ? const Color(0xFFFBFBFB)
                                    : const Color(0xFFFBFBFB),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          // Next button
                          IconButton(
                            icon: Icon(
                              Icons.chevron_right,
                              color: _canNavigateNext()
                                  ? (widget.isDark ? Colors.white : const Color(0xFFFBFBFB))
                                  : (widget.isDark ? Colors.white : Colors.black87)
                                      .withValues(alpha: 0.3),
                              size: 30,
                            ),
                            onPressed: _canNavigateNext()
                                ? () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      if (_isMonthView) {
                                        // Navigate to next month
                                        if (_currentMonth.month == 12) {
                                          _currentMonth = DateTime(_currentMonth.year + 1, 1);
                                        } else {
                                          _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                                        }
                                        // Deselect if selected date is not in the new month
                                        if (widget.selectedDate != null) {
                                          if (widget.selectedDate!.year != _currentMonth.year ||
                                              widget.selectedDate!.month != _currentMonth.month) {
                                            widget.onDateSelected(null);
                                          }
                                        }
                                      } else {
                                        // Navigate to next week
                                        _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
                                        // Deselect if selected date is not in the new week
                                        if (widget.selectedDate != null) {
                                          final weekEnd = _currentWeekStart.add(const Duration(days: 6));
                                          final selectedNormalized = DateTime(
                                            widget.selectedDate!.year,
                                            widget.selectedDate!.month,
                                            widget.selectedDate!.day,
                                          );
                                          final weekStartNormalized = DateTime(
                                            _currentWeekStart.year,
                                            _currentWeekStart.month,
                                            _currentWeekStart.day,
                                          );
                                          final weekEndNormalized = DateTime(
                                            weekEnd.year,
                                            weekEnd.month,
                                            weekEnd.day,
                                          );

                                          if (selectedNormalized.isBefore(weekStartNormalized) ||
                                              selectedNormalized.isAfter(weekEndNormalized)) {
                                            widget.onDateSelected(null);
                                          }
                                        }
                                      }
                                    });
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                    // Today and Calendar toggle buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Today button
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  _jumpToToday();
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: glassCoverCalendar(
                                    widget.isDark,
                                    radius: 20,
                                    highlight: isTodaySelected,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.today,
                                        color: widget.isDark ? Colors.black87 : Colors.black87,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Today',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: widget.isDark ? Colors.black87 : Colors.black87,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Calendar toggle button
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  setState(() {
                                    _isMonthView = !_isMonthView;
                                    if (_isMonthView) {
                                      // Sync month view with current week
                                      final weekMiddle = _currentWeekStart.add(const Duration(days: 3));
                                      _currentMonth = DateTime(weekMiddle.year, weekMiddle.month, 1);
                                      // If there's a selected date, ensure it's in the visible month
                                      if (widget.selectedDate != null) {
                                        final selectedMonth = DateTime(
                                          widget.selectedDate!.year,
                                          widget.selectedDate!.month,
                                          1,
                                        );
                                        if (selectedMonth.month != weekMiddle.month ||
                                            selectedMonth.year != weekMiddle.year) {
                                          _currentMonth = selectedMonth;
                                        }
                                      }
                                    } else {
                                      // Sync week view with selected date or current month
                                      if (widget.selectedDate != null) {
                                        _currentWeekStart = _getWeekStart(widget.selectedDate!);
                                      } else {
                                        final today = DateTime.now();
                                        if (today.year == _currentMonth.year &&
                                            today.month == _currentMonth.month) {
                                          _currentWeekStart = _getWeekStart(today);
                                        } else {
                                          final firstDayOfMonth = DateTime(
                                            _currentMonth.year,
                                            _currentMonth.month,
                                            1,
                                          );
                                          _currentWeekStart = _getWeekStart(firstDayOfMonth);
                                        }
                                      }
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  margin: const EdgeInsets.fromLTRB(0, 0, 5, 0),
                                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                                  decoration: glassCoverCalendar(
                                    widget.isDark,
                                    radius: 30,
                                    highlight: true,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: glassCalendarCircle(isDark: widget.isDark),
                                        child: Icon(
                                          Icons.calendar_today,
                                          color: widget.isDark ? Colors.black87 : Colors.black87,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        'Calendar',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: widget.isDark ? Colors.black87 : Colors.black87,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Calendar grid
                if (_isMonthView)
                  // Month view
                  ...List.generate((_getMonthDays().length / 7).ceil(), (weekIndex) {
                    final weekDays = _getMonthDays().skip(weekIndex * 7).take(7).toList();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: weekDays.map((date) {
                          final isSelected = widget.selectedDate != null &&
                              widget.selectedDate!.year == date.year &&
                              widget.selectedDate!.month == date.month &&
                              widget.selectedDate!.day == date.day;
                          final isToday = date.year == today.year &&
                              date.month == today.month &&
                              date.day == today.day;
                          final isCurrentMonthDay = isCurrentMonth(date);
                          final hasIndicator = widget.hasIndicatorForDate?.call(date) ?? false;

                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                final alreadySelected = widget.selectedDate != null &&
                                    _isSameDay(widget.selectedDate!, date);
                                setState(() {
                                  widget.onDateSelected(alreadySelected ? null : date);
                                  if (!alreadySelected) {
                                    if (_isMonthView &&
                                        (date.year != _currentMonth.year ||
                                            date.month != _currentMonth.month)) {
                                      _currentMonth = DateTime(date.year, date.month, 1);
                                    }
                                    if (!_isMonthView) {
                                      final selectedWeekStart = _getWeekStart(date);
                                      if (selectedWeekStart != _currentWeekStart) {
                                        _currentWeekStart = selectedWeekStart;
                                      }
                                    }
                                  }
                                });
                              },
                              child: Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? selectionFill
                                            : (isToday ? todayFill : Colors.transparent),
                                        borderRadius: BorderRadius.circular(8),
                                        border: isSelected
                                            ? Border.all(color: selectionBorder, width: 1.2)
                                            : (isToday
                                                ? Border.all(color: todayBorder, width: 1.2)
                                                : null),
                                      ),
                                      child: Stack(
                                        children: [
                                          Center(
                                            child: Text(
                                              '${date.day}',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected
                                                    ? selectionTextColor
                                                    : isToday
                                                        ? const Color(0xFF282828)
                                                        : (isCurrentMonthDay
                                                            ? baseTextColor
                                                            : mutedTextColor),
                                              ),
                                            ),
                                          ),
                                          if (hasIndicator)
                                            Positioned(
                                              bottom: 2,
                                              left: 0,
                                              right: 0,
                                              child: Center(
                                                child: Container(
                                                  width: 4,
                                                  height: 4,
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFF22C55E),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  })
                else
                  // Week view
                  Row(
                    children: _getCurrentWeekDays().map((date) {
                      final isSelected = widget.selectedDate != null &&
                          widget.selectedDate!.year == date.year &&
                          widget.selectedDate!.month == date.month &&
                          widget.selectedDate!.day == date.day;
                      final weekdayLabel = _getDayAbbreviation(date.weekday);
                      final isToday = date.year == today.year &&
                          date.month == today.month &&
                          date.day == today.day;
                      final hasIndicator = widget.hasIndicatorForDate?.call(date) ?? false;

                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            final alreadySelected = widget.selectedDate != null &&
                                _isSameDay(widget.selectedDate!, date);
                            setState(() {
                              widget.onDateSelected(alreadySelected ? null : date);
                              _currentWeekStart = _getWeekStart(date);
                            });
                          },
                          child: Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 48,
                              height: 80,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : isToday
                                        ? (widget.isDark
                                            ? const Color.fromARGB(255, 0, 0, 0)
                                            : const Color.fromARGB(255, 0, 0, 0))
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected
                                    ? null
                                    : isToday
                                        ? Border.all(
                                            color: widget.isDark
                                                ? const Color.fromARGB(255, 255, 255, 255)
                                                    .withValues(alpha: 0.7)
                                                : const Color.fromARGB(255, 255, 255, 255),
                                            width: 1.4,
                                          )
                                        : Border.all(
                                            color: Colors.white.withValues(alpha: 0.9),
                                            width: 1.4,
                                          ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${date.day}',
                                    style: GoogleFonts.inter(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? const Color(0xFF282828)
                                          : isToday
                                              ? const Color(0xFFFBFBFB)
                                              : Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    weekdayLabel,
                                    style: GoogleFonts.inter(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? const Color(0xFF282828)
                                          : isToday
                                              ? const Color(0xFFFBFBFB)
                                              : Colors.white.withValues(alpha: 0.9),
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  if (hasIndicator) ...[
                                    const SizedBox(height: 2),
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF22C55E),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
