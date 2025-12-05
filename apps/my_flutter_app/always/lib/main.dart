import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

// Language and Theme State Management
class AppState extends ChangeNotifier {
  String _language = 'English';
  bool _isDarkMode = false;
  String _firstName = 'Dr.';
  String _lastName = 'Strange';

  String get language => _language;
  bool get isDarkMode => _isDarkMode;
  String get firstName => _firstName;
  String get lastName => _lastName;
  String get displayName {
    final parts = [firstName.trim(), lastName.trim()].where((p) => p.isNotEmpty).toList();
    return parts.isEmpty ? 'Doctor' : parts.join(' ');
  }

  void setLanguage(String lang) {
    _language = lang;
    notifyListeners();
  }

  void setDarkMode(bool isDark) {
    _isDarkMode = isDark;
    notifyListeners();
  }

  void setFirstName(String value) {
    _firstName = value;
    notifyListeners();
  }

  void setLastName(String value) {
    _lastName = value;
    notifyListeners();
  }

  // Localization helper
  String translate(String en, String th) {
    return _language == 'English' ? en : th;
  }
}

final appState = AppState();

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

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
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

  @override
  Widget build(BuildContext context) {
    final isDark = appState.isDarkMode;
    
    return MaterialApp(
      title: 'Alskin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.white,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFBFBFB),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0EA5E9),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF050A16),
        useMaterial3: true,
      ),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        children: [
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
      ),
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

// Profile Settings Page (accessed via person icon)
class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Initialize with default values (you can load from shared preferences or state management)
    _firstNameController.text = appState.firstName;
    _lastNameController.text = appState.lastName;
    _firstNameController.addListener(() {
      appState.setFirstName(_firstNameController.text);
    });
    _lastNameController.addListener(() {
      appState.setLastName(_lastNameController.text);
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (!mounted) return;
      final message = e.toString();
      final bool cameraUnavailable = source == ImageSource.camera &&
          message.toLowerCase().contains('cameradelegate');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cameraUnavailable
                ? 'Camera not available on this device. Please upload an image instead.'
                : 'Error picking image: $e',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (cameraUnavailable) {
        _pickImage(ImageSource.gallery);
      }
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Select Image Source',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildImageSourceOption(
                          icon: Icons.camera_alt,
                          label: 'Camera',
                          onTap: () {
                            Navigator.pop(context);
                            _pickImage(ImageSource.camera);
                          },
                        ),
                        _buildImageSourceOption(
                          icon: Icons.photo_library,
                          label: 'Gallery',
                          onTap: () {
                            Navigator.pop(context);
                            _pickImage(ImageSource.gallery);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 32, color: const Color(0xFF1976D2)),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
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
              // Header
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: glassBox(isDark, radius: 12, highlight: true),
                        child: Icon(
                              Icons.arrow_back,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      appState.translate('Profile Settings', 'ตั้งค่าโปรไฟล์'),
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
                      // Profile Picture Section
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: glassBox(isDark, radius: 20, highlight: true),
                            child: Column(
                              children: [
                                Text(
                                  appState.translate('Profile Picture', 'รูปโปรไฟล์'),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Profile Picture Bounding Box
                                GestureDetector(
                                  onTap: _showImageSourceDialog,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                      child: Container(
                                        width: 150,
                                        height: 150,
                                        decoration: glassBox(isDark, radius: 20, highlight: true).copyWith(
                                          border: Border.all(
                                            color: (isDark ? Colors.white : Colors.black)
                                                .withOpacity(0.3),
                                            width: 3,
                                          ),
                                        ),
                                        child: _profileImage != null
                                            ? Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  Image.file(
                                                    _profileImage!,
                                                    fit: BoxFit.cover,
                                                  ),
                                                  Positioned(
                                                    bottom: 0,
                                                    right: 0,
                                                    child: Container(
                                                      width: 40,
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF1976D2),
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: Colors.white,
                                                          width: 2,
                                                        ),
                                                      ),
                                                      child: const Icon(
                                                        Icons.camera_alt,
                                                        color: Colors.white,
                                                        size: 20,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Container(
                                                decoration: glassCircle(isDark, highlight: true).copyWith(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      const Color(0xFF38BDF8).withOpacity(0.35),
                                                      const Color(0xFF6366F1).withOpacity(0.35),
                                                    ],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                ),
                                                child: Center(
                                                  child: Icon(
                                                    Icons.person,
                                                    size: 80,
                                                    color: const Color(0xFF1976D2),
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  appState.translate(
                                    'Tap the profile picture to change it',
                                    'แตะที่รูปโปรไฟล์เพื่อเปลี่ยน',
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                          child: InkWell(
                                            onTap: () => _pickImage(ImageSource.camera),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              decoration: glassBox(isDark, radius: 12, highlight: true),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: const [
                                                  Icon(Icons.photo_camera, size: 18, color: Color(0xFF2563EB)),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Take photo',
                                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                          child: InkWell(
                                            onTap: () => _pickImage(ImageSource.gallery),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              decoration: glassBox(isDark, radius: 12, highlight: true),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: const [
                                                  Icon(Icons.upload_file, size: 18, color: Color(0xFF22C55E)),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Upload image',
                                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Name Fields Section
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
                                Text(
                                  appState.translate('Personal Information', 'ข้อมูลส่วนตัว'),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // First Name Field
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                    child: Container(
                                      decoration: glassBox(isDark, radius: 12),
                                      child: TextField(
                                        controller: _firstNameController,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                        decoration: InputDecoration(
                                          labelText: appState.translate('First Name', 'ชื่อ'),
                                          labelStyle: TextStyle(
                                            color: isDark
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade700,
                                            fontSize: 14,
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.person_outline,
                                            color: Colors.grey,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Last Name Field
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                    child: Container(
                                      decoration: glassBox(isDark, radius: 12),
                                      child: TextField(
                                        controller: _lastNameController,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                        decoration: InputDecoration(
                                          labelText: appState.translate('Last Name', 'นามสกุล'),
                                          labelStyle: TextStyle(
                                            color: isDark
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade700,
                                            fontSize: 14,
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.person_outline,
                                            color: Colors.grey,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
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
                      ),
                      const SizedBox(height: 24),
                      // Save Button
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: ElevatedButton(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                              appState.setFirstName(_firstNameController.text);
                              appState.setLastName(_lastNameController.text);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    appState.translate(
                                      'Settings saved successfully!',
                                      'บันทึกการตั้งค่าสำเร็จ!',
                                    ),
                                  ),
                                  backgroundColor: const Color(0xFF1976D2),
                                ),
                              );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1976D2).withOpacity(0.9),
                                foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: Text(
                                appState.translate('Save Changes', 'บันทึกการเปลี่ยนแปลง'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
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
            ],
          ),
        ),
      ),
    );
  }
}

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
                                                        .withOpacity(0.3)
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
                                                        .withOpacity(0.3)
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
                                                .withOpacity(0.3),
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
                                                      color: Colors.black.withOpacity(0.2),
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
                          _settingsNavItem(Icons.home, 'Home', 0, isDark),
                          _settingsNavItem(Icons.dashboard, 'Dashboard', 1, isDark),
                          _settingsNavItem(Icons.notifications, 'Notification', 2, isDark),
                          _settingsNavItem(Icons.settings, 'Setting', 3, isDark),
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

  Widget _settingsNavItem(IconData icon, String label, int index, bool isDark) {
    final isSelected = _currentBottomNavIndex == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (index == _currentBottomNavIndex) return;
        if (index == 0) {
          _navigateTo(const HomePage(), 0);
        } else if (index == 2) {
          _navigateTo(const NotificationPage(), 2);
        } else if (index == 3) {
          // already here
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
        } else {
          // Placeholder for dashboard navigation
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
