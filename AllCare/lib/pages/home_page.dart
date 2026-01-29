import 'dart:async';
import 'dart:developer';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../theme/glass.dart';
import '../features/case/create_case.dart';
import '../widgets/calendar_widget.dart';
import '../widgets/glass_bottom_nav.dart';
import 'overviewlabel.dart';
import '../features/case/case_service.dart';
import '../features/case/case_summary_screen.dart';
import 'dashboard_page.dart';
import 'notification_page.dart';
import 'profile_settings_page.dart';
import 'settings_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.showLabeling});

  /// When false, hides the labeling action so GPs only start new cases.
  /// If null, it defaults based on AppState user role.
  final bool? showLabeling;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  DateTime? _selectedDate;
  int _currentBottomNavIndex = 0;
  bool _showPatientTypeModal = false;
  String _selectedCaseStatus = 'All'; // All, Confirmed, Uncertain, Rejected
  final String _searchQuery = '';
  final GlobalKey _caseFilterKey = GlobalKey();

  // Current time display
  // DateTime _currentTime = DateTime.now();
  Timer? _timeTimer;

  late bool _shouldShowLabeling;

  // Dynamic case records from backend
  List<CaseRecord> _caseRecords = [];
  bool _isLoadingCases = false;
  String? _casesError;

  @override
  void initState() {
    super.initState();
    // Determine effective showLabeling: prefer widget arg, fallback to AppState role
    if (widget.showLabeling != null) {
      _shouldShowLabeling = widget.showLabeling!;
    } else {
      _shouldShowLabeling = appState.userRole.toLowerCase() != 'gp';
    }
    appState.addListener(_onAppStateChanged);

    // Start timer to update time every minute
    // _timeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
    //   if (mounted) {
    //     setState(() {
    //       _currentTime = DateTime.now();
    //     });
    //   }
    // });

    // Load cases from backend
    _loadCases();
  }

  /// Load cases from backend
  Future<void> _loadCases() async {
    if (_isLoadingCases) return;

    setState(() {
      _isLoadingCases = true;
      _casesError = null;
    });

    try {
      final cases = await CaseService().fetchCases();
      if (mounted) {
        setState(() {
          _caseRecords = cases;
          _isLoadingCases = false;
        });
      }
    } catch (e) {
      log('Failed to load cases: $e', name: 'HomePage');
      if (mounted) {
        setState(() {
          _casesError = e.toString();
          _isLoadingCases = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _timeTimer?.cancel();
    appState.removeListener(_onAppStateChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload cases when dependencies change (including when returning to this page)
    if (!_isLoadingCases && _caseRecords.isEmpty) {
      _loadCases();
    }
  }

  /// Public method to refresh cases - can be called after returning from other screens
  void refreshCases() {
    _loadCases();
  }

  void _onAppStateChanged() {
    if (mounted) {
      if (widget.showLabeling == null) {
        _shouldShowLabeling = appState.userRole != 'gp';
      }
      setState(() {});
    }
  }

  void _navigateWithFade(Widget page, {bool replace = true}) {
    final route = PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );

    if (replace) {
      Navigator.pushReplacement(context, route);
    } else {
      Navigator.push(context, route);
    }
  }


  /// Check if a given date has at least one case
  bool _hasCase(DateTime date) {
    return _caseRecords.any((record) {
      if (record.createdAt == null) return false;
      try {
        final caseDate = DateTime.parse(record.createdAt!);
        return caseDate.year == date.year &&
               caseDate.month == date.month &&
               caseDate.day == date.day;
      } catch (e) {
        return false;
      }
    });
  }

  List<CaseRecord> get _filteredCaseRecords {
    return _caseRecords.where((record) {
      // Filter by status
      final recordStatus = record.status;
      final normalizedStatus =
          recordStatus.toLowerCase() == 'pending'
              ? 'uncertain'
              : recordStatus.toLowerCase();
      final statusMatch =
          _selectedCaseStatus.toLowerCase() == 'all'
              ? true
              : normalizedStatus == _selectedCaseStatus.toLowerCase();

      // Filter by search query (case ID, prediction, or location)
      final caseId = record.caseId;
      final prediction = record.topPredictionLabel;
      final location = record.location ?? '';
      final searchMatch =
          _searchQuery.isEmpty ||
          caseId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          prediction.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          location.toLowerCase().contains(_searchQuery.toLowerCase());

      // Filter by selected date (if any)
      bool dateMatch = true;
      if (_selectedDate != null) {
        if (record.createdAt == null) {
          dateMatch = false;
        } else {
          try {
            final recordDate = DateTime.parse(record.createdAt!).toLocal();
            dateMatch =
                recordDate.year == _selectedDate!.year &&
                recordDate.month == _selectedDate!.month &&
                recordDate.day == _selectedDate!.day;
          } catch (_) {
            dateMatch = false;
          }
        }
      }

      return statusMatch && searchMatch && dateMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? Color.fromARGB(255, 0, 0, 0) : const Color(0xFFFBFBFB);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadCases,
                    color: isDark ? Colors.white : Colors.blue,
                    backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Section
                          _buildHeader(isDark),

                          // Action Cards Section
                          _buildActionCards(isDark),

                          // Calendar Section
                          CalendarWidget(
                            selectedDate: _selectedDate,
                            onDateSelected: (date) {
                              setState(() {
                                _selectedDate = date;
                              });
                            },
                            hasIndicatorForDate: _hasCase,
                            isDark: isDark,
                          ),

                          // Case Record Section
                          _buildCaseRecordSection(isDark),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                // Bottom Navigation Bar
                GlassBottomNav(
                  currentIndex: _currentBottomNavIndex,
                  onTap: (index) {
                    if (index == _currentBottomNavIndex) return;
                    if (index == 3) {
                      _navigateWithFade(const SettingsPage());
                    } else if (index == 2) {
                      _navigateWithFade(const NotificationPage());
                    } else if (index == 1) {
                      _navigateWithFade(const DashboardPage());
                    } else {
                      setState(() => _currentBottomNavIndex = index);
                    }
                  },
                ),
              ],
            ),
            // Patient Type Selection Modal
            if (_showPatientTypeModal) _buildPatientTypeModal(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Hi, ${appState.displayName}',
                      style: GoogleFonts.inter(
                        fontSize: 28,

                        fontWeight: FontWeight.bold,
                        color: isDark ? Color(0xFFFBFBFB) : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Welcome to ALLCARE',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color:
                            isDark
                                ? Color(0xFFFBFBFB)
                                : const Color.fromARGB(255, 0, 0, 0),
                      ),
                    ),
                  ],
                ),
              ),

              ListenableBuilder(
                listenable: appState,
                builder: (context, _) {
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileSettingsPage(),
                        ),
                      );
                    },
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: glassCircle(isDark, highlight: true),
                          child: appState.profileImageFile != null
                              ? ClipOval(
                                  child: Image.file(
                                    appState.profileImageFile!,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Icon(
                                  Icons.person,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 58,
            child: Stack(
              alignment: Alignment.centerRight,
              children: [
                // 🔍 Search box
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      height: 58,
                      padding: const EdgeInsets.only(right: 60),
                      decoration: glassSearchBox(isDark: isDark),
                      child: TextField(
                        controller: _searchController,
                        textAlignVertical: TextAlignVertical.center,
                        style: TextStyle(
                          color:
                              isDark ? const Color(0xFFEFEFEF) : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search patient name or ID...',
                          border: InputBorder.none,
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(16),
                            child: SvgPicture.asset(
                              'assets/images/Magnifying.svg',
                              width: 25,
                              height: 25,
                              colorFilter: ColorFilter.mode(
                                Theme.of(context).iconTheme.color ??
                                    (isDark ? Colors.white : Colors.black87),
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 🎛 Filter button
                Positioned(
                  right: 6,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              isDark
                                  ? Colors.black.withValues(alpha: 0.27)
                                  : Colors.black.withValues(alpha: 0.1),
                              
                          blurRadius: isDark? 15:12,
                          spreadRadius: 2,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: glassSearchFilter(isDark: isDark),
                          child: Material(
                            color: Colors.transparent,
                            child: IconButton(
                              icon: SvgPicture.asset(
                                'assets/images/FilterIcon.svg',
                                width: 22,
                                height: 22,
                              ),
                              onPressed: () {},
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
        ],
      ),
    );
  }

  Widget _buildActionCards(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  icon: Icons.camera_alt,
                  title: 'Start New Case',
                  description: 'Capture patient skin images for diagnosis',
                  buttonText: 'Start New Case',
                  isDark: isDark,
                  bgAsset: 'assets/images/NewCaseCard.png',
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      _showPatientTypeModal = true;
                    });
                  },
                ),
              ),
              if (_shouldShowLabeling) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.bookmark,
                    title: 'Labeling Case',
                    description:
                        'Active learning selection for doctor labeling',
                    buttonText: 'Start Labeling Case',
                    isDark: isDark,
                    bgAsset: 'assets/images/LabelingCard.png',
                  onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LabelPage(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          );
        },
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
    required String bgAsset,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Positioned.fill(child: Image.asset(bgAsset, fit: BoxFit.cover)),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Color(0xFFFBFBFB),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: const Color.fromARGB(255, 0, 0, 0),
                    size: 30,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF282828),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Color(0xFF282828),
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25), // shadow color
                          blurRadius: 2.5, // softness
                          offset: const Offset(0, 2), // vertical shadow
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF282828),
                        foregroundColor: Colors.white,
                        elevation: 0, //
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        buttonText,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
              Flexible(
                child: Text(
                  'Case record',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: GestureDetector(
                  key: _caseFilterKey,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    final RenderBox? renderBox =
                        _caseFilterKey.currentContext?.findRenderObject()
                            as RenderBox?;
                    if (renderBox == null) return;
                    final Offset offset = renderBox.localToGlobal(Offset.zero);
                    final Size size = renderBox.size;
                    final double horizontalPadding = 20;
                    final double screenWidth =
                        MediaQuery.of(context).size.width;
                    final double menuWidth =
                        screenWidth - (horizontalPadding * 2);
                    final double menuLeft = horizontalPadding;
                    final double menuTop = offset.dy + size.height + 8;

                    showGeneralDialog<String>(
                      context: context,
                      barrierDismissible: true,
                      barrierLabel: 'Case status filter',
                      barrierColor: Colors.transparent,
                      transitionDuration: const Duration(milliseconds: 200),
                      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
                      transitionBuilder: (
                        context,
                        animation,
                        secondaryAnimation,
                        child,
                      ) {
                        return SizedBox.expand(
                          child: Stack(
                            children: [
                              Positioned(
                                left: menuLeft,
                                top: menuTop,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: Tween<double>(
                                      begin: 0.95,
                                      end: 1.0,
                                    ).animate(
                                      CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeOut,
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(
                                            sigmaX: 20,
                                            sigmaY: 20,
                                          ),
                                          child: Container(
                                            width: menuWidth,
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 
                                                0.5,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.white.withValues(alpha: 
                                                  0.7,
                                                ),
                                                width: 1.5,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.15),
                                                  blurRadius: 20,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children:
                                                  [
                                                    'All',
                                                    'Confirmed',
                                                    'Uncertain',
                                                    'Rejected',
                                                  ].map((String value) {
                                                    final isSelected =
                                                        _selectedCaseStatus ==
                                                        value;
                                                    return GestureDetector(
                                                      onTap: () {
                                                        HapticFeedback.lightImpact();
                                                        Navigator.pop(
                                                          context,
                                                          value,
                                                        );
                                                      },
                                                      child: Container(
                                                        width: double.infinity,
                                                        margin:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 2,
                                                              vertical: 2,
                                                            ),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 12,
                                                              horizontal: 16,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              isSelected
                                                                  ? Colors.blue
                                                                      .withValues(alpha: 
                                                                        0.3,
                                                                      )
                                                                  : Colors
                                                                      .transparent,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          border:
                                                              isSelected
                                                                  ? Border.all(
                                                                    color: Colors
                                                                        .blue
                                                                        .withValues(alpha: 
                                                                          0.5,
                                                                        ),
                                                                    width: 1.5,
                                                                  )
                                                                  : null,
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            if (isSelected)
                                                              const Icon(
                                                                Icons
                                                                    .check_circle,
                                                                size: 18,
                                                                color:
                                                                    Colors.blue,
                                                              ),
                                                            if (isSelected)
                                                              const SizedBox(
                                                                width: 10,
                                                              ),
                                                            Text(
                                                              value,
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    isSelected
                                                                        ? FontWeight
                                                                            .bold
                                                                        : FontWeight
                                                                            .w600,
                                                                color:
                                                                    Colors
                                                                        .black87,
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
                        constraints: const BoxConstraints(maxWidth: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: glassFilter(
                          isDark,
                          radius: 12,
                          highlight: true,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                _selectedCaseStatus,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.tune,
                              size: 18,
                              color: isDark ? Colors.white : Colors.black87,
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
          const SizedBox(height: 12),
          // Loading state
          if (_isLoadingCases)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      color: isDark ? Colors.white70 : Colors.blueAccent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading cases...',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          // Error state
          else if (_casesError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_off,
                      size: 48,
                      color: isDark ? Colors.red.shade300 : Colors.red.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Could not load cases',
                      style: TextStyle(
                        fontSize: 16,
                        color:
                            isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _loadCases,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          // Empty state
          else if (_filteredCaseRecords.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 48,
                      color:
                          isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _selectedDate != null
                          ? 'No cases found for this date'
                          : 'No cases found',
                      style: TextStyle(
                        fontSize: 16,
                        color:
                            isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedDate != null
                          ? 'Try another date'
                          : 'Try adjusting your filters or search',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._filteredCaseRecords.map(
              (record) => _buildCaseRecordItem(record, isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildCaseRecordItem(CaseRecord record, bool isDark) {
    final String rawStatus = record.status;
    final String status =
        rawStatus.toLowerCase() == 'pending' ? 'Uncertain' : rawStatus;
    final statusLower = status.toLowerCase();
    Color statusColor;
    IconData statusIcon;

    switch (statusLower) {
      case 'confirmed':
        statusColor = const Color(0xFF10B981); // Emerald green
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444); // Soft red
        statusIcon = Icons.cancel;
        break;
      case 'uncertain':
        statusColor = const Color(0xFFF59E0B); // Amber
        statusIcon = Icons.hourglass_empty;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }
    final isPending = statusLower == 'uncertain';

    // Format created_at time
    String timeDisplay = 'N/A';
    if (record.createdAt != null) {
      try {
        final dt = DateTime.parse(record.createdAt!);
        final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
        final period = dt.hour >= 12 ? 'P.M.' : 'A.M.';
        timeDisplay =
            '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period';
      } catch (_) {
        timeDisplay = 'N/A';
      }
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => CaseSummaryScreen(
                  caseId: record.caseId,
                  gender: record.gender ?? 'Unknown',
                  age: record.age?.toString() ?? 'Unknown',
                  location: record.location ?? 'Unknown',
                  symptoms: record.symptoms,
                  imagePaths: record.imagePaths,
                  predictions: record.predictions,
                  createdAt: record.createdAt,
                  updatedAt: record.updatedAt,
                  isPrePrediction: false, // Already has predictions
                ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: glassCase(isDark, radius: 12, highlight: true),
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
                            const Color(0xFF1976D2).withValues(alpha: 0.9),
                            const Color(0xFF1565C0).withValues(alpha: 0.9),
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              record.caseId,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        record.location ?? 'Unknown Location',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$timeDisplay • ${record.gender ?? 'N/A'}, ${record.age ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade400 : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Predict: ${record.topPredictionLabel}',
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
                if (isPending)
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
                          backgroundColor: statusColor.withValues(alpha: 0.9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
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
                              'Pending',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 11,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget figmaCloseButtonExact({
  required VoidCallback onTap,
  required bool isDark,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? const Color(0xFF282828)
            : const Color(0xFFF7F7F7),

        boxShadow: isDark
            ? [
                // Dark mode – outer glow + depth
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 18,
                  offset: const Offset(4, 4),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(-3, -3),
                ),
              ]
            : [
                // Light mode – classic neumorphism
                BoxShadow(
                  color: const Color(0xFFCBCBCB),
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(4, 4),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.9),
                  blurRadius: 15,
                  spreadRadius: 1,
                  offset: const Offset(-4, -4),
                ),
              ],
      ),
      child: Center(
        child: Icon(
          Icons.close,
          size: 22,
          color: isDark
              ? const Color(0xFFFBFBFB)
              : const Color(0xFF282828),
        ),
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
      child: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(color: const Color.fromARGB(255, 223, 223, 223).withValues(alpha: 0.25),
),
          ),

          Center(
            child: GestureDetector(
              onTap: () {},
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Modal box
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(24),
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                    ),
                    decoration: modalBox(isDark),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            'Select Skin Condition',
                            style: GoogleFonts.inter(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color:
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF282828),
                            ),
                          ),

                          const SizedBox(height: 1),

                          Text(
                            'Please Choose the primary condition for this case to guide analysis',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color:
                                  isDark
                                      ? Colors.grey.shade400
                                      : Color(0xFF282828),
                            ),
                          ),

                          const SizedBox(height: 15),

                          _buildPatientTypeCard(
                            icon: Icons.healing,
                            title: 'Skin Lesion',
                            description:
                                'For evaluating suspicious or changing skin lesions.',
                            isDark: isDark,
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              _navigateWithFade(
                                const NewCaseScreen(),
                                replace: false,
                              );
                              Future.delayed(
                                const Duration(milliseconds: 300),
                                () {
                                  if (mounted) {
                                    setState(() {
                                      _showPatientTypeModal = false;
                                    });
                                  }
                                },
                              );
                            },
                          ),

                          const SizedBox(height: 18),

                          _buildPatientTypeCard(
                            icon: Icons.face,
                            title: 'Acne',
                            description:
                                'For assessing acne severity and inflammation.',
                            isDark: isDark,
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              _navigateWithFade(
                                const NewCaseScreen(),
                                replace: false,
                              );
                              Future.delayed(
                                const Duration(milliseconds: 300),
                                () {
                                  if (mounted) {
                                    setState(() {
                                      _showPatientTypeModal = false;
                                    });
                                  }
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  Positioned(
                    top: 15,
                    right: 35,
                    child: figmaCloseButtonExact(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _showPatientTypeModal = false;
                        });
                      }, isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Color.fromARGB(255, 59, 59, 59): Color(0xFFFBFBFB),

        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            
        color: isDark ? Color.fromARGB(62, 255, 255, 255): Colors.black.withValues(alpha: 0.08),
            
            blurRadius: 5,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),

                  child: Image.asset(
                    title.contains('Rural')
                        ? 'assets/images/RHsBG.png'
                        : 'assets/images/HsBG.png',
                    height: 80,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 38, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 4),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color:
                              isDark
                                ? Color(0xFFFBFBFB)
                                : Color(0xFF282828),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            description,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              height: 1.4,
                              
                              color:isDark
                                ? Color(0xFFFBFBFB)
                                : Color(0xFF686868),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 5),

                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          height: 28,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFFFBFBFB)
                                : const Color(0xFF282828),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                ?const Color.fromARGB(255, 255, 255, 255).withValues(alpha: 0.15)
                                :const Color.fromARGB(255, 0, 0, 0).withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Create',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                ? const Color(0xFF282828)
                                : const Color(0xFFFBFBFB),
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          
          Positioned(
            top: 80 - 32, 
            left: 18,
            child: Container(
              width: 65,
              height: 65,
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                                ? Color.fromARGB(255, 59, 59, 59)
                                : Color(0xFFFBFBFB),
                  width: 6),
              ),
              child: Icon(icon, size: 35, color: const Color(0xFF1976D2)),
            ),
          ),
        ],
      ),
    );
  }
}
