import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/glass.dart';
import '../../theme/glass_inline_dropdown.dart';
import '../../theme/customCheckBox.dart';

import 'add_photo.dart';
import 'case_service.dart';
import 'photo_preview_screen.dart';
import 'case_summary_screen.dart';

class NewCaseScreen extends StatefulWidget {
  const NewCaseScreen({
    super.key,
    this.initialCaseId,
    this.initialGender,
    this.initialAge,
    this.initialLocation,
    this.initialSymptoms,
    this.initialImagePaths = const [],
    this.initialPredictions = const [],
    this.isEditing = false,
    this.persistChanges = false,
  });

  final String? initialCaseId;
  final String? initialGender;
  final String? initialAge;
  final String? initialLocation;
  final List<String>? initialSymptoms;
  final List<String> initialImagePaths;
  final List<Map<String, dynamic>> initialPredictions;
  final bool isEditing;
  final bool persistChanges;

  @override
  State<NewCaseScreen> createState() => _NewCaseScreenState();
}

class _NewCaseScreenState extends State<NewCaseScreen> {
  // State for form fields
  String? _selectedGender;
  String? _selectedAge;
  String? _selectedSpecificLocation;
  late final TextEditingController _hashController;
  String? _caseId;
  bool _isCaseIdLoading = false;
  bool _isSaving = false;
  bool _releaseRequested = false;
  bool _releaseAfterLoad = false;

  // State for symptoms checkboxes
  final Map<String, bool> _symptoms = {
    'raised scar': false,
    'Red marks': false,
    'Sunbathe': false,
    'Fair skin': false,
    'The patient has a history of organ transplantation': false,
    'The patient has been exposed to arsenic': false,
    'The patient has photosensitivity': false,
    'The patient has a history of skin disease': false,
    'The patient has relatives who have had cancer.': false,
  };

  @override
  void initState() {
    super.initState();
    // Initialize form fields from widget parameters (for editing)
    _selectedGender = widget.initialGender;
    _selectedAge = widget.initialAge;
    _selectedSpecificLocation = widget.initialLocation;
    _caseId = widget.initialCaseId;
    
    // Set initial text. If caseId is missing, we'll fetch it.
    _hashController = TextEditingController(text: _caseId ?? 'Loading...');
    
    if (_caseId == null || _caseId!.isEmpty) {
      _loadCaseId();
    }

    // Set symptoms checkboxes based on initial symptoms
    if (widget.initialSymptoms != null) {
      for (final symptom in widget.initialSymptoms!) {
        if (_symptoms.containsKey(symptom)) {
          _symptoms[symptom] = true;
        }
      }
    }
  }

  @override
  void dispose() {
    _hashController.dispose();
    super.dispose();
  }

  bool get _canProceed =>
      !_isCaseIdLoading &&
      !_isSaving &&
      _caseId != null &&
      _caseId!.isNotEmpty;

  Future<void> _loadCaseId() async {
    setState(() {
      _isCaseIdLoading = true;
    });

    try {
      final caseId = await CaseService().fetchNextCaseId();
      if (_releaseAfterLoad) {
        try {
          await CaseService().releaseCaseId(caseId);
        } catch (_) {}
        return;
      }
      if (!mounted) return;
      setState(() {
        _caseId = caseId;
        _hashController.text = caseId;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hashController.text = 'Error';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isCaseIdLoading = false;
      });
    }
  }

  Future<void> _saveEdits() async {
    if (_caseId == null || _caseId!.isEmpty) return;

    final selectedSymptoms =
        _symptoms.entries.where((e) => e.value).map((e) => e.key).toList();

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.persistChanges) {
        await CaseService().updateCase(
          caseId: _caseId!,
          gender: _selectedGender,
          age: _selectedAge,
          location: _selectedSpecificLocation,
          symptoms: selectedSymptoms,
        );
      }
      if (!mounted) return;

      final imagePaths = widget.initialImagePaths;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (_) => CaseSummaryScreen(
                caseId: _caseId!,
                gender: _selectedGender,
                age: _selectedAge,
                location: _selectedSpecificLocation,
                symptoms: selectedSymptoms,
                imagePaths: imagePaths,
                imagePath: imagePaths.isNotEmpty ? imagePaths.first : '',
                predictions: widget.initialPredictions,
                isPrePrediction: !widget.persistChanges,
              ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update case: $e')));
    }
  }

  Future<void> _releaseCaseIdIfNeeded() async {
    if (widget.isEditing || _releaseRequested) return;

    final caseId = _caseId;
    if (caseId == null || caseId.isEmpty) {
      if (_isCaseIdLoading) {
        _releaseAfterLoad = true;
        _releaseRequested = true;
      }
      return;
    }

    _releaseRequested = true;
    try {
      await CaseService().releaseCaseId(caseId);
    } catch (_) {}
  }

  Future<void> _handleCancel() async {
    await _releaseCaseIdIfNeeded();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<bool> _onWillPop() async {
    await _releaseCaseIdIfNeeded();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: isDark
        ? const Color(0xFF0F0F0F)
        : const Color(0xFFFBFBFB),
        appBar: _buildAppBar(isDark),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 42),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Visit Data', isDark),
                const SizedBox(height: 15),

                _buildGlassSection(
                  isDark: isDark,
                  child: Column(
                    children: [
                      _buildTextField(
                        label: 'Hash No.',
                        controller: _hashController,
                        isReadOnly: true,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: GlassInlineDropdown(
                              label: 'Gender',
                              hint: 'Select',
                              value: _selectedGender,
                              items: const ['M', 'W'],
                              isDark: isDark,
                              onChanged:
                                  (v) => setState(() => _selectedGender = v),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: GlassInlineDropdown(
                              label: 'Age',
                              hint: 'Select',
                              value: _selectedAge,
                              items: List.generate(130, (i) => '${i + 1}'),
                              isDark: isDark,
                              onChanged: (v) => setState(() => _selectedAge = v),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),
                _sectionTitle('Symptoms', isDark),
                const SizedBox(height: 10),

                _buildGlassSection(
                  isDark: isDark,
                  padding: const EdgeInsets.all(12),
                  child: _buildSymptomCheckboxes(isDark),
                ),

                const SizedBox(height: 25),
                _sectionTitle('Location', isDark),
                const SizedBox(height: 15),

                _buildGlassSection(
                  isDark: isDark,
                  child: Column(
                    children: [
                      GlassInlineDropdown(
                        label: 'Specific Location',
                        hint: 'Select Specific Location',
                        value: _selectedSpecificLocation,
                        items: const ['Face', 'Arm', 'Leg', 'Back'],
                        isDark: isDark,
                        onChanged:
                            (v) => setState(() => _selectedSpecificLocation = v),
                      ),
                      const SizedBox(height: 20),
                      _bodyMapPlaceholder(isDark),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                _bottomButtons(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }


  PreferredSizeWidget _buildAppBar(bool isDark) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Stack(
        children: [
          Container(
            height: kToolbarHeight,
            decoration: BoxDecoration(
              color: isDark
            ? Color(0xFF000000)
            :Color(0xFFFBFBFB),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.35 : 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
          ),

          AppBar(
            title: Text(
              widget.isEditing ? 'Edit Case' : 'New Case',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: BackButton(
              color: isDark ? Colors.white : Colors.black,
              onPressed: _handleCancel,
            ),
            flexibleSpace: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: isDark
                      ? Colors.black.withOpacity(0.45)
                      : const Color(0xFFFBFBFB),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _sectionTitle(String text, bool isDark) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : const Color(0xFF282828),
      ),
    );
  }

  Widget _buildGlassSection({
    required bool isDark,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(20),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: glassBoxSection(isDark, radius: 16),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool isReadOnly = false,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white70 : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: isReadOnly,
          decoration: InputDecoration(
            filled: true,
            fillColor:
                isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildSymptomCheckboxes(bool isDark) {
    return Column(
      children:
          _symptoms.keys.map((key) {
            return customCheckboxRow(
              label: key,
              value: _symptoms[key]!,
              isDark: isDark,
              onChanged: (v) => setState(() => _symptoms[key] = v),
            );
          }).toList(),
    );
  }

  Widget _bodyMapPlaceholder(bool isDark) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
        ),
        child: const Center(child: Text('[Body Map]')),
      ),
    );
  }

  void _showGlassSnackBar(String message, {bool isError = true}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Use a Dialog for center positioning
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Notification',
      barrierColor: Colors.transparent, // Transparent to look like a toast
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, _, __) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: ModalRoute.of(context)!.animation!,
                curve: Curves.easeOutBack,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 280),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: glassBox(isDark, radius: 30).copyWith(
                      color: isError 
                          ? (isDark ? Colors.red.withOpacity(0.2) : Colors.red.withOpacity(0.1))
                          : (isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.8)),
                      border: isError
                          ? Border.all(color: Colors.red.withOpacity(0.4), width: 1.2)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isError ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                          color: isDark 
                              ? (isError ? Colors.redAccent : Colors.white) 
                              : (isError ? Colors.red[700] : Colors.black87),
                              
                          size: 28,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          message,
                          style: GoogleFonts.inter(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    // Auto-dismiss after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  bool _validateInputs() {
    if (_selectedGender == null || _selectedGender!.isEmpty) {
      _showGlassSnackBar('Please select Gender');
      return false;
    }
    if (_selectedAge == null || _selectedAge!.isEmpty) {
      _showGlassSnackBar('Please select Age');
      return false;
    }
    final hasSymptoms = _symptoms.values.any((val) => val);
    if (!hasSymptoms) {
      _showGlassSnackBar('Please select at least one symptom');
      return false;
    }
    if (_selectedSpecificLocation == null ||
        _selectedSpecificLocation!.isEmpty) {
      _showGlassSnackBar('Please select Specific Location');
      return false;
    }
    return true;
  }

  Widget _bottomButtons(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: OutlinedButton(
                onPressed: _handleCancel,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(
                    color:
                        isDark
                            ? Colors.white.withOpacity(0.5)
                            : Colors.grey.shade400,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  foregroundColor:
                      isDark ? Colors.white70 : Colors.grey.shade700,
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: ElevatedButton(
                onPressed: () {
                    // 1. Validate inputs
                    if (!_validateInputs()) return;

                    // 2. Proceed based on mode
                    if (widget.isEditing) {
                        _showConfirmDialog(context); // Will lead to _saveEdits
                    } else if (_canProceed) {
                        _showConfirmDialog(context); // Will lead to AddPhoto
                    } else {
                        // Case ID not loaded or saving in progress
                         _showGlassSnackBar('Please wait for Case ID generation...', isError: false);
                    }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor:
                      isDark ? Colors.white.withOpacity(0.9) : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  widget.isEditing ? 'Save Changes' : 'Finalize',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showConfirmDialog(BuildContext context) {
    showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: const Color.fromARGB(255, 223, 223, 223).withOpacity(0.25),
        builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;

        return Stack(
            children: [
            BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(color: Colors.transparent),
            ),
            Center(
                child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(horizontal: 28),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF282828)
                            : Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                            BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.45 : 0.25),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                            ),
                        ],
                        ),
                        child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            Icon(
                            widget.isEditing ? Icons.edit_outlined : Icons.location_on_outlined,
                            size: 42,
                            color: isDark ? const Color(0xFFFBFBFB) : const Color(0xFF282828),
                            ),
                            const SizedBox(height: 14),
                            Text(
                            widget.isEditing ? 'Save changes?' : 'Confirm this location?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF282828),
                            ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                            widget.isEditing
                                ? 'Update this case information.'
                                : 'You are going to take photo of a lesion',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14,
                                color: isDark ? const Color(0xFFB8B8B8) : const Color(0xFF6B6B6B),
                            ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                            children: [
                                Expanded(
                                child: ElevatedButton(
                                    onPressed: () => Navigator.of(dialogContext).pop(),
                                    style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? const Color(0xFF1F1F1F) : Colors.black,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                    ),
                                    ),
                                    child: const Text(
                                    'Cancel',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                child: ElevatedButton(
                                    onPressed: () async {
                                        Navigator.of(dialogContext).pop();
                                        
                                        if (widget.isEditing) {
                                            await _saveEdits();
                                            return;
                                        }

                                        // Open Add Photo Dialog with Blur Stack
                                        final List<String>? result = await showDialog<List<String>>(
                                            context: context,
                                            barrierDismissible: false,
                                            barrierColor: const Color.fromARGB(255, 223, 223, 223).withOpacity(0.25),
                                            builder: (_) {
                                            return Stack(
                                                children: [
                                                BackdropFilter(
                                                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                                    child: Container(color: Colors.transparent),
                                                ),
                                                const Center(child: AddPhotoDialog()),
                                                ],
                                            );
                                            },
                                        );

                                        if (result == null || result.isEmpty) return;
                                        if (!context.mounted) return;

                                        // Ensure we have a case ID (should be loaded by initState)
                                        final caseId = _caseId ?? 'Unknown';

                                        final selectedSymptoms = _symptoms.entries
                                            .where((e) => e.value)
                                            .map((e) => e.key)
                                            .toList();

                                        // Navigate to Photo Preview
                                        final bool? shouldSave = await Navigator.of(context).push<bool>(
                                            MaterialPageRoute(
                                            builder: (_) => PhotoPreviewScreen(
                                                imagePath: result.first,
                                                imagePaths: result,
                                                caseId: caseId,
                                                isMultiImage: result.length > 1,
                                                imageCount: result.length,
                                            ),
                                            ),
                                        );

                                        if (shouldSave == true && context.mounted) {
                                            await Navigator.of(context).push(
                                            MaterialPageRoute(
                                                builder: (_) => CaseSummaryScreen(
                                                caseId: caseId,
                                                gender: _selectedGender,
                                                age: _selectedAge,
                                                location: _selectedSpecificLocation,
                                                symptoms: selectedSymptoms,
                                                imagePaths: result,
                                                imagePath: result.first,
                                                isPrePrediction: true,
                                                ),
                                            ),
                                            );
                                        }
                                    },
                                    style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF007AFF),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                    ),
                                    ),
                                    child: Text(
                                        widget.isEditing ? 'Save' : 'Confirm',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
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
                ),
            ),
            ],
        );
        },
    );
  }
}
