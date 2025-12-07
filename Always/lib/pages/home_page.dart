
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../theme/glass.dart';
import 'dashboard_page.dart';
import 'notification_page.dart';
import 'profile_settings_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.showLabeling = true});

  /// When false, hides the labeling action so GPs only start new cases.
  final bool showLabeling;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  DateTime _currentWeekStart = _getWeekStart(DateTime.now());
  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDate;
  int _currentBottomNavIndex = 0;
  bool _isMonthView = false;
  bool _showPatientTypeModal = false;
  String _selectedCaseStatus = 'All'; // All, Confirmed, Pending, Rejected
  String _searchQuery = '';
  final GlobalKey _caseFilterKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    appState.addListener(_onAppStateChanged);
  }

  @override
  void dispose() {
    appState.removeListener(_onAppStateChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onAppStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _navigateWithFade(Widget page) {
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

  static DateTime _getWeekStart(DateTime date) {
    // Get Monday of the week (weekday 1 = Monday)
    final daysFromMonday = date.weekday - 1;
    return date.subtract(Duration(days: daysFromMonday));
  }

  final List<Map<String, dynamic>> _caseRecords = [
    {
      'id': 'C000058',
      'patientName': 'Dr. Strange',
      'patientType': 'Hospital Patient',
      'time': '09:00 A.M.',
      'prediction': 'Predict: Malignant Melanoma',
      'status': 'Confirmed',
    },
    {
      'id': 'C000057',
      'patientName': 'John Doe',
      'patientType': 'Rural Hospital Patient',
      'time': '09:30 A.M.',
      'prediction': 'Predict: Epidermodysplasia verruciformis',
      'status': 'Rejected',
    },
    {
      'id': 'C000056',
      'patientName': 'Jane Smith',
      'patientType': 'Hospital Patient',
      'time': '10:00 A.M.',
      'prediction': 'Predict: Basal Cell Carcinoma',
      'status': 'Uncertain',
    },
    {
      'id': 'C000055',
      'patientName': 'Mike Johnson',
      'patientType': 'Rural Hospital Patient',
      'time': '10:30 A.M.',
      'prediction': 'Predict: Actinic Keratosis',
      'status': 'Confirmed',
    },
  ];
  
  List<Map<String, dynamic>> get _filteredCaseRecords {
    return _caseRecords.where((record) {
      // Filter by status
      final recordStatus = (record['status'] as String?) ?? '';
      final statusMatch = _selectedCaseStatus == 'All' || recordStatus == _selectedCaseStatus;
      
      // Filter by search query (patient name or ID)
      final patientName = (record['patientName'] as String?) ?? '';
      final caseId = (record['id'] as String?) ?? '';
      final searchMatch = _searchQuery.isEmpty ||
                         patientName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                         caseId.toLowerCase().contains(_searchQuery.toLowerCase());
      
      return statusMatch && searchMatch;
    }).toList();
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
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          _buildHeader(isDark),
          
                          // Action Cards Section
                          _buildActionCards(isDark),
                          
                          // Calendar Section
                          _buildCalendarSection(isDark),
                          
                          // Case Record Section
                          _buildCaseRecordSection(isDark),
                          
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  // Bottom Navigation Bar
                  _buildBottomNavigationBar(isDark),
                ],
              ),
              // Patient Type Selection Modal
              if (_showPatientTypeModal) _buildPatientTypeModal(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Home',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
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
                      width: 40,
                      height: 40,
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
          const SizedBox(height: 16),
          Text(
            'Hi, ${appState.displayName}',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Welcome to ALLCARE',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      height: 50,
                      decoration: glassBox(isDark, radius: 12, highlight: true),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        onSubmitted: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                          FocusScope.of(context).unfocus();
                          HapticFeedback.selectionClick();
                        },
                        textInputAction: TextInputAction.search,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search patient name or ID...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.grey.shade400 : Colors.grey,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: isDark ? Colors.grey.shade400 : Colors.grey,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: glassCircle(isDark, highlight: true),
                    child: IconButton(
                      icon: Icon(
                        Icons.tune,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      onPressed: () {
                        // Handle filter
                      },
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

  Widget _buildActionCards(bool isDark) {
    final children = <Widget>[
          Expanded(
            child: _buildActionCard(
              icon: Icons.camera_alt,
              title: 'Start New Case',
              description: 'Capture patient skin images for diagnosis',
              buttonText: 'Start New Case',
              isDark: isDark,
              onTap: () {
                HapticFeedback.mediumImpact();
                setState(() {
                  _showPatientTypeModal = true;
                });
              },
            ),
          ),
      if (widget.showLabeling) ...[
          const SizedBox(width: 16),
          Expanded(
            child: _buildActionCard(
              icon: Icons.bookmark,
              title: 'Labeling Case',
              description: 'Active learning selection for doctor labeling',
              buttonText: 'Start Labeling Case',
              isDark: isDark,
              onTap: () {
                // Handle labeling case
              },
            ),
          ),
        ],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(children: children),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String description,
    required String buttonText,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: glassBox(isDark, radius: 16, highlight: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF1976D2), size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2).withOpacity(0.9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                    shadowColor: const Color(0xFF1976D2).withOpacity(0.3),
                  ).copyWith(
                    overlayColor: WidgetStateProperty.all(Colors.white.withOpacity(0.2)),
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  List<DateTime> _getCurrentWeekDays() {
    final List<DateTime> days = [];
    for (int i = 0; i < 7; i++) {
      days.add(_currentWeekStart.add(Duration(days: i)));
    }
    return days;
  }

  List<DateTime> _getMonthDays() {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    
    // Get the first day of the week (1 = Monday, 7 = Sunday)
    int firstWeekday = firstDayOfMonth.weekday; // 1 = Monday, 7 = Sunday
    
    // Calculate offset: Monday=0, Tuesday=1, ..., Sunday=6
    int offset = firstWeekday - 1; // Monday (1) -> 0, Sunday (7) -> 6
    
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
    
    // Fill remaining days to complete the week (next month)
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

  String _getWeekRange() {
    final weekEnd = _currentWeekStart.add(const Duration(days: 6));
    final startMonth = _getMonthName(_currentWeekStart.month);
    final endMonth = _getMonthName(weekEnd.month);
    
    if (_currentWeekStart.month == weekEnd.month) {
      return '${startMonth} ${_currentWeekStart.day} - ${weekEnd.day}, ${_currentWeekStart.year}';
    } else {
      return '${startMonth} ${_currentWeekStart.day} - ${endMonth} ${weekEnd.day}, ${_currentWeekStart.year}';
    }
  }

  String _getDayAbbreviation(int weekday) {
    // weekday: 1 = Monday, 7 = Sunday
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[weekday - 1];
  }

  bool _canNavigatePrevious() {
    // Allow navigation to past dates for viewing historical cases
    // Limit to January 2020 as a reasonable starting point
    if (_isMonthView) {
      return _currentMonth.year > 2020 || 
             (_currentMonth.year == 2020 && _currentMonth.month > 1);
    } else {
      final previousWeek = _currentWeekStart.subtract(const Duration(days: 7));
      return previousWeek.year >= 2020;
    }
  }

  bool _canNavigateNext() {
    // Allow navigation up to 2030 for future appointments
    if (_isMonthView) {
      return _currentMonth.year < 2030 || 
             (_currentMonth.year == 2030 && _currentMonth.month < 12);
    } else {
      final nextWeek = _currentWeekStart.add(const Duration(days: 7));
      return nextWeek.year <= 2030;
    }
  }

  Widget _buildCalendarSection(bool isDark) {
    final today = DateTime.now();
    final isCurrentMonth = (date) => 
        date.year == _currentMonth.year && date.month == _currentMonth.month;
    final baseTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.6);
    final accent = isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB);
    final selectionFill = isDark ? accent.withOpacity(0.85) : accent.withOpacity(0.22);
    final selectionBorder = accent.withOpacity(isDark ? 0.9 : 0.8);
    final selectionTextColor = isDark ? Colors.black : const Color(0xFF0B1224);
    final todayFill = isDark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.05);
    final todayBorder = isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.35);
    
    return Container(
      margin: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: glassBox(isDark, radius: 16, highlight: true),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.chevron_left,
                            color: _canNavigatePrevious() 
                                ? (isDark ? Colors.white : Colors.black87)
                                : (isDark ? Colors.white : Colors.black87).withOpacity(0.3),
                          ),
                          onPressed: _canNavigatePrevious() ? () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              if (_isMonthView) {
                                if (_currentMonth.month == 1) {
                                  _currentMonth = DateTime(_currentMonth.year - 1, 12);
                                } else {
                                  _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                                }
                                // Deselect if selected date is not in the new month
                                if (_selectedDate != null) {
                                  if (_selectedDate!.year != _currentMonth.year || 
                                      _selectedDate!.month != _currentMonth.month) {
                                    _selectedDate = null;
                                  }
                                }
                              } else {
                                _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
                                // Deselect if selected date is not in the new week
                                if (_selectedDate != null) {
                                  final weekEnd = _currentWeekStart.add(const Duration(days: 6));
                                  // Normalize dates to compare only year, month, day
                                  final selectedNormalized = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
                                  final weekStartNormalized = DateTime(_currentWeekStart.year, _currentWeekStart.month, _currentWeekStart.day);
                                  final weekEndNormalized = DateTime(weekEnd.year, weekEnd.month, weekEnd.day);
                                  
                                  if (selectedNormalized.isBefore(weekStartNormalized) || 
                                      selectedNormalized.isAfter(weekEndNormalized)) {
                                    _selectedDate = null;
                                  }
                                }
                              }
                            });
                          } : null,
                        ),
                        Text(
                          _isMonthView
                              ? '${_getMonthName(_currentMonth.month)} ${_currentMonth.year}'
                              : _getWeekRange(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.chevron_right,
                            color: _canNavigateNext() 
                                ? (isDark ? Colors.white : Colors.black87)
                                : (isDark ? Colors.white : Colors.black87).withOpacity(0.3),
                          ),
                          onPressed: _canNavigateNext() ? () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              if (_isMonthView) {
                                if (_currentMonth.month == 12) {
                                  _currentMonth = DateTime(_currentMonth.year + 1, 1);
                                } else {
                                  _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                                }
                                // Deselect if selected date is not in the new month
                                if (_selectedDate != null) {
                                  if (_selectedDate!.year != _currentMonth.year || 
                                      _selectedDate!.month != _currentMonth.month) {
                                    _selectedDate = null;
                                  }
                                }
                              } else {
                                _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
                                // Deselect if selected date is not in the new week
                                if (_selectedDate != null) {
                                  final weekEnd = _currentWeekStart.add(const Duration(days: 6));
                                  // Normalize dates to compare only year, month, day
                                  final selectedNormalized = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
                                  final weekStartNormalized = DateTime(_currentWeekStart.year, _currentWeekStart.month, _currentWeekStart.day);
                                  final weekEndNormalized = DateTime(weekEnd.year, weekEnd.month, weekEnd.day);
                                  
                                  if (selectedNormalized.isBefore(weekStartNormalized) || 
                                      selectedNormalized.isAfter(weekEndNormalized)) {
                                    _selectedDate = null;
                                  }
                                }
                              }
                            });
                          } : null,
                        ),
                      ],
                    ),
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
                                  // Use the middle of the week to determine which month to show
                                  final weekMiddle = _currentWeekStart.add(const Duration(days: 3));
                                  _currentMonth = DateTime(weekMiddle.year, weekMiddle.month, 1);
                                  // If there's a selected date, ensure it's in the visible month
                                  if (_selectedDate != null) {
                                    final selectedMonth = DateTime(_selectedDate!.year, _selectedDate!.month, 1);
                                    // If selected date is in a different month than week middle, use selected date's month
                                    if (selectedMonth.month != weekMiddle.month || selectedMonth.year != weekMiddle.year) {
                                      _currentMonth = selectedMonth;
                                    }
                                  }
                                } else {
                                  // Sync week view with selected date or current month
                                  if (_selectedDate != null) {
                                    // Use the week containing the selected date
                                    _currentWeekStart = _getWeekStart(_selectedDate!);
                                  } else {
                                    // Use today's week, or if today is not in current month, use first day of month's week
                                    final today = DateTime.now();
                                    if (today.year == _currentMonth.year && today.month == _currentMonth.month) {
                                      _currentWeekStart = _getWeekStart(today);
                                    } else {
                                      final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
                                      _currentWeekStart = _getWeekStart(firstDayOfMonth);
                                    }
                                  }
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: glassBox(isDark, radius: 20, highlight: true),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: glassCircle(isDark, highlight: true),
                                    child: Icon(
                                      Icons.calendar_today,
                                      color: isDark ? Colors.white : Colors.black87,
                                      size: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Calendar',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? Colors.white : Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Day headers
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(7, (index) {
                    final weekday = index + 1; // 1 = Monday, 7 = Sunday
                    return SizedBox(
                      width: 40,
                      child: Text(
                        _getDayAbbreviation(weekday),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: mutedTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                // Calendar days (week or month view)
                if (_isMonthView)
                  // Month view - show grid
                  ...List.generate((_getMonthDays().length / 7).ceil(), (weekIndex) {
                    final weekDays = _getMonthDays().skip(weekIndex * 7).take(7).toList();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: weekDays.map((date) {
                          final isSelected = _selectedDate != null &&
                              _selectedDate!.year == date.year &&
                              _selectedDate!.month == date.month &&
                              _selectedDate!.day == date.day;
                          final isToday = date.year == today.year &&
                              date.month == today.month &&
                              date.day == today.day;
                          final isCurrentMonthDay = isCurrentMonth(date);
                          
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedDate = date;
                                // If in month view and selected date is from different month, update month
                                if (_isMonthView && 
                                    (date.year != _currentMonth.year || date.month != _currentMonth.month)) {
                                  _currentMonth = DateTime(date.year, date.month, 1);
                                }
                                // If in week view and selected date is not in current week, update week
                                if (!_isMonthView) {
                                  final selectedWeekStart = _getWeekStart(date);
                                  if (selectedWeekStart != _currentWeekStart) {
                                    _currentWeekStart = selectedWeekStart;
                                  }
                                }
                              });
                            },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                              child: Container(
                                width: 40,
                                height: 40,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? selectionFill
                                        : (isToday ? todayFill : Colors.transparent),
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected
                                        ? Border.all(
                                            color: selectionBorder,
                                            width: 1.2,
                                          )
                                        : (isToday
                                            ? Border.all(
                                                color: todayBorder,
                                                width: 1.2,
                                              )
                                            : null),
                                  ),
                                child: Center(
                                  child: Text(
                                    '${date.day}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? selectionTextColor
                                          : (isCurrentMonthDay
                                              ? baseTextColor
                                              : mutedTextColor),
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
                  // Week view - show single row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _getCurrentWeekDays().map((date) {
                      final isSelected = _selectedDate != null &&
                          _selectedDate!.year == date.year &&
                          _selectedDate!.month == date.month &&
                          _selectedDate!.day == date.day;
                      final isToday = date.year == today.year &&
                          date.month == today.month &&
                          date.day == today.day;
                      
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedDate = date;
                            // Ensure the week view shows the week containing the selected date
                            final selectedWeekStart = _getWeekStart(date);
                            if (selectedWeekStart != _currentWeekStart) {
                              _currentWeekStart = selectedWeekStart;
                            }
                          });
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: Container(
                              width: 40,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? selectionFill
                                    : (isToday ? todayFill : Colors.transparent),
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected
                                    ? Border.all(
                                        color: selectionBorder,
                                        width: 1.2,
                                      )
                                    : (isToday
                                        ? Border.all(
                                            color: todayBorder,
                                            width: 1.2,
                                          )
                                        : null),
                              ),
                              child: Center(
                                  child: Text(
                                    '${date.day}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? selectionTextColor
                                          : baseTextColor,
                                    ),
                                  ),
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

  Widget _buildCaseRecordSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Case record',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              GestureDetector(
                key: _caseFilterKey,
                onTap: () {
                  HapticFeedback.selectionClick();
                  final RenderBox? renderBox = _caseFilterKey.currentContext?.findRenderObject() as RenderBox?;
                  if (renderBox == null) return;
                  final Offset offset = renderBox.localToGlobal(Offset.zero);
                  final Size size = renderBox.size;
                  final double horizontalPadding = 20;
                  final double screenWidth = MediaQuery.of(context).size.width;
                  final double menuWidth = screenWidth - (horizontalPadding * 2);
                  final double menuLeft = horizontalPadding;
                  final double menuTop = offset.dy + size.height + 8;

                  showGeneralDialog<String>(
                    context: context,
                    barrierDismissible: true,
                    barrierLabel: 'Case status filter',
                    barrierColor: Colors.transparent,
                    transitionDuration: const Duration(milliseconds: 200),
                    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
                    transitionBuilder: (context, animation, secondaryAnimation, child) {
                      return SizedBox.expand(
                        child: Stack(
                          children: [
                            Positioned(
                              left: menuLeft,
                              top: menuTop,
                              child: FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                        child: Container(
                                          width: menuWidth,
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.5),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.7),
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.15),
                                                blurRadius: 20,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: ['All', 'Confirmed', 'Uncertain', 'Rejected'].map((String value) {
                                              final isSelected = _selectedCaseStatus == value;
                                              return GestureDetector(
                                                onTap: () {
                                                  HapticFeedback.lightImpact();
                                                  Navigator.pop(context, value);
                                                },
                                                child: Container(
                                                  width: double.infinity,
                                                  margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? Colors.blue.withOpacity(0.3)
                                                        : Colors.transparent,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: isSelected
                                                        ? Border.all(
                                                            color: Colors.blue.withOpacity(0.5),
                                                            width: 1.5,
                                                          )
                                                        : null,
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      if (isSelected)
                                                        const Icon(
                                                          Icons.check_circle,
                                                          size: 18,
                                                          color: Colors.blue,
                                                        ),
                                                      if (isSelected) const SizedBox(width: 10),
                                                      Text(
                                                        value,
                                                        style: TextStyle(
                                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                          color: Colors.black87,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ).then((value) {
                    if (value != null) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedCaseStatus = value;
                      });
                    }
                  });
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: glassBox(isDark, radius: 12, highlight: true),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedCaseStatus,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.tune, size: 18, color: isDark ? Colors.white : Colors.black87),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_filteredCaseRecords.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 48,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No cases found',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try adjusting your filters or search',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._filteredCaseRecords.map((record) => _buildCaseRecordItem(record, isDark)),
        ],
      ),
    );
  }

  Widget _buildCaseRecordItem(Map<String, dynamic> record, bool isDark) {
    final String status = (record['status'] as String?) ?? 'Uncertain';
    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'Confirmed':
        statusColor = const Color(0xFF10B981); // Emerald green
        statusIcon = Icons.check_circle;
        break;
      case 'Rejected':
        statusColor = const Color(0xFFEF4444); // Soft red
        statusIcon = Icons.cancel;
        break;
      case 'Uncertain':
        statusColor = const Color(0xFFF59E0B); // Amber
        statusIcon = Icons.help_outline;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }
    final isUncertain = status == 'Uncertain';
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: glassBox(isDark, radius: 12, highlight: true),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1976D2).withOpacity(0.9),
                      const Color(0xFF1565C0).withOpacity(0.9),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black)
                        .withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      (record['id'] as String?) ?? 'N/A',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            status,
                            style: TextStyle(
                              fontSize: 10,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  (record['patientName'] as String?) ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(record['time'] as String?) ?? 'N/A'} • ${(record['patientType'] as String?) ?? 'N/A'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade400 : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (record['prediction'] as String?) ?? 'No prediction',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade400 : Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isUncertain)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    // Handle uncertain action
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor.withOpacity(0.9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.hourglass_top, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Uncertain',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: statusColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, color: statusColor, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
        ),
      ),
    ),
    );
  }

  Widget _buildBottomNavigationBar(bool isDark) {
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
                _buildNavItem(Icons.home, 'Home', 0, isDark),
                _buildNavItem(Icons.dashboard, 'Dashboard', 1, isDark),
                _buildNavItem(Icons.notifications, 'Notification', 2, isDark),
                _buildNavItem(Icons.settings, 'Setting', 3, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, bool isDark) {
    final isSelected = _currentBottomNavIndex == index;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (index == 3) {
          setState(() {
            _currentBottomNavIndex = 3;
          });
          _navigateWithFade(const SettingsPage());
        } else if (index == 2) {
          _navigateWithFade(const NotificationPage());
        } else if (index == 1) {
          setState(() {
            _currentBottomNavIndex = 1;
          });
          _navigateWithFade(const DashboardPage());
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

  Widget _buildPatientTypeModal(bool isDark) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showPatientTypeModal = false;
        });
      },
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Prevent tap from closing when tapping inside modal
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(24),
                    decoration: glassBox(isDark, radius: 20, highlight: true),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with close button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Select Patient Type',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _showPatientTypeModal = false;
                                });
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: glassCircle(isDark),
                                child: Icon(
                                  Icons.close,
                                  color: isDark ? Colors.white : Colors.black87,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please choose your patient category to continue',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey.shade400 : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Hospital patient card
                        _buildPatientTypeCard(
                          icon: Icons.local_hospital,
                          title: 'Hospital patient',
                          description: 'Look up an existing patient by HN to link new diagnostic results to their record',
                          isDark: isDark,
                          onTap: () {
                            setState(() {
                              _showPatientTypeModal = false;
                            });
                            HapticFeedback.mediumImpact();
                          },
                        ),
                        const SizedBox(height: 16),
                        // Rural Hospital patient card
                        _buildPatientTypeCard(
                          icon: Icons.add_business,
                          title: 'Rural Hospital patient',
                          description: 'For new patients or referrals. Select this to register and create a new patient profile.',
                          isDark: isDark,
                          onTap: () {
                            setState(() {
                              _showPatientTypeModal = false;
                            });
                            HapticFeedback.mediumImpact();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientTypeCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: glassBox(isDark, radius: 16, highlight: true),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF1976D2).withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF1976D2),
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.7),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Create button
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF2563EB),
                              Color(0xFF38BDF8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withOpacity(0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withOpacity(isDark ? 0.35 : 0.55),
                            width: 1.4,
                          ),
                        ),
                        child: const Text(
                          'Create',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
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
}
