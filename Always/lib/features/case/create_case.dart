import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/glass.dart';
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
  String? _caseIdError;
  bool _isCaseIdLoading = false;
  bool _isSaving = false;

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
    _hashController = TextEditingController(text: _caseId ?? '');
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
      _caseIdError = null;
    });

    try {
      final caseId = await CaseService().fetchNextCaseId();
      if (!mounted) return;
      setState(() {
        _caseId = caseId;
        _hashController.text = caseId;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _caseIdError = 'Unable to load case number';
        _hashController.text = '';
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF1C1C1C);

    // Gradient background colors (bluish to match Home/Dashboard style)
    final gradientColors =
        isDark
            ? [
              const Color(0xFF07162A),
              const Color(0xFF0B2142),
              const Color(0xFF0F2E56),
            ]
            : [
              const Color(0xFFE8F3FF),
              const Color(0xFFD9E9FF),
              const Color(0xFFF2F7FF),
            ];

    return Scaffold(
      extendBodyBehindAppBar: true, // For gradient to go behind app bar
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          widget.isEditing ? 'Edit Case' : 'New Case',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: isDark ? Colors.white : primaryColor,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent, // Transparent for glass effect
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: (isDark ? Colors.black : Colors.white).withOpacity(0.5),
            ),
          ),
        ),
      ),

      // --- 2. Body Content ---
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
            ),
          ),
          // Floating frosted blobs to amplify glassmorphism
          _buildGlassBlob(
            alignment: Alignment.topRight,
            color: const Color(0xFF67E8F9),
          ),
          _buildGlassBlob(
            alignment: Alignment.bottomLeft,
            color: const Color(0xFF60A5FA),
            size: 240,
            blur: 36,
          ),
          _buildGlassBlob(
            alignment: Alignment.centerLeft,
            color: const Color(0xFFA5B4FC),
            size: 180,
            blur: 28,
            opacity: 0.18,
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 42.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 15),

                  Text(
                    'Visit Data',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : primaryColor,
                    ),
                  ),
                  const SizedBox(height: 15),

                  _buildGlassSection(
                    isDark: isDark,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hash No.
                        _buildInputField(
                          label: 'Hash No.',
                          hintText:
                              _caseIdError ??
                              (_isCaseIdLoading ? 'Loading...' : ''),
                          isDropdown: false,
                          controller: _hashController,
                          isReadOnly: true,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 15),

                        // Gender & Age
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: _buildInputField(
                                label: 'Gender',
                                hintText: 'Select',
                                isDropdown: true,
                                dropdownItems: ['M', 'W'],
                                value: _selectedGender,
                                onChanged:
                                    (val) =>
                                        setState(() => _selectedGender = val),
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _buildInputField(
                                label: 'Age',
                                hintText: 'Select',
                                isDropdown: true,
                                dropdownItems: List.generate(
                                  130,
                                  (index) => (index + 1).toString(),
                                ),
                                value: _selectedAge,
                                onChanged:
                                    (val) => setState(() => _selectedAge = val),
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Symptoms
                  Text(
                    'Symptoms',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : primaryColor,
                    ),
                  ),
                  const SizedBox(height: 10),

                  _buildGlassSection(
                    isDark: isDark,
                    padding: const EdgeInsets.all(12),
                    child: _buildSymptomCheckboxes(isDark),
                  ),

                  const SizedBox(height: 25),

                  // Location
                  Text(
                    'Location',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : primaryColor,
                    ),
                  ),
                  const SizedBox(height: 15),

                  _buildGlassSection(
                    isDark: isDark,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildInputField(
                          label: 'Specific Location',
                          hintText: 'Select Specific Location',
                          isDropdown: true,
                          dropdownItems: ['Face', 'Arm', 'Leg', 'Back'],
                          value: _selectedSpecificLocation,
                          onChanged:
                              (val) => setState(
                                () => _selectedSpecificLocation = val,
                              ),
                          isDark: isDark,
                        ),
                        const SizedBox(height: 20),
                        // Body Map Placeholder
                        AspectRatio(
                          aspectRatio: 1.0,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      (isDark ? Colors.white : Colors.black)
                                          .withOpacity(0.06),
                                      (isDark ? Colors.white : Colors.black)
                                          .withOpacity(0.02),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color:
                                        isDark
                                            ? Colors.white24
                                            : Colors.grey.shade300,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    "[Image of Human Body Map]",
                                    style: TextStyle(
                                      color:
                                          isDark
                                              ? Colors.white70
                                              : const Color(0xFF555555),
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

                  const SizedBox(height: 30),

                  // --- Bottom Buttons (Cancel / Save) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _buildGlassSection(
                          isDark: isDark,
                          radius: 25,
                          padding: EdgeInsets.zero,
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                side: BorderSide(
                                  color:
                                      isDark
                                          ? Colors.white54
                                          : Colors.grey.shade400,
                                ),
                                foregroundColor:
                                    isDark
                                        ? Colors.white70
                                        : Colors.grey.shade700,
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildGlassSection(
                          isDark: isDark,
                          radius: 25,
                          padding: EdgeInsets.zero,
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () {
                                _showConfirmDialog(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isDark
                                        ? Colors.white.withOpacity(0.9)
                                        : Colors.black.withOpacity(0.9),
                                foregroundColor:
                                    isDark ? Colors.black : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                widget.isEditing ? 'Save Changes' : 'Finalize',
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
        ],
      ),
    );
  }

  // --- Pop-up Dialog ---
  void _showConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final isEditing = widget.isEditing;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Icon(
                  isEditing ? Icons.edit_outlined : Icons.location_on_outlined,
                  size: 40,
                  color: Colors.black87,
                ),
                const SizedBox(height: 15),
                Text(
                  isEditing ? 'Save changes?' : 'Confirm Select this location?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isEditing
                      ? 'Update this case information.'
                      : 'You are going to take photo of a lesion',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            !_canProceed
                                ? null
                                : () async {
                          Navigator.of(
                            dialogContext,
                          ).pop(); // Close confirm dialog
                          if (isEditing) {
                            await _saveEdits();
                            return;
                          }

                          // Open Add Photo dialog
                          final List<String>? result =
                              await showDialog<List<String>>(
                                context: context,
                                barrierDismissible: false,
                                builder: (BuildContext context) {
                                  return const AddPhotoDialog();
                                },
                              );

                          if (result != null && result.isNotEmpty) {
                            if (!context.mounted) return;

                            // Generate case ID
                            final caseId = _caseId!;

                            // Gather selected symptoms
                            final selectedSymptoms =
                                _symptoms.entries
                                    .where((e) => e.value)
                                    .map((e) => e.key)
                                    .toList();

                            // Show Photo Preview for save confirmation
                            final bool? shouldSave = await Navigator.of(
                              context,
                            ).push<bool>(
                              MaterialPageRoute(
                                builder:
                                    (_) => PhotoPreviewScreen(
                                      imagePath: result.first,
                                      imagePaths:
                                          result, // Pass all images for carousel
                                      caseId: caseId,
                                      isMultiImage: result.length > 1,
                                      imageCount: result.length,
                                    ),
                              ),
                            );

                            // If user confirmed save, go to Case Summary (pre-prediction mode)
                            if (shouldSave == true && context.mounted) {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                    (_) => CaseSummaryScreen(
                                      caseId: caseId,
                                      gender: _selectedGender,
                                      age: _selectedAge,
                                      location: _selectedSpecificLocation,
                                        symptoms: selectedSymptoms,
                                        imagePaths: result,
                                        imagePath: result.first,
                                        isPrePrediction:
                                            true, // NEW: Show Edit/Run Prediction buttons
                                      ),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(isEditing ? 'Save' : 'Confirm'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Helper: Reusable glass section wrapper ---
  Widget _buildGlassSection({
    required bool isDark,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
    double radius = 16,
  }) {
    final sheen =
        isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.white.withOpacity(0.55);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: glassBox(
            isDark,
            radius: radius,
            highlight: true,
          ).copyWith(
            border: Border.all(
              color:
                  isDark
                      ? Colors.white.withOpacity(0.18)
                      : Colors.black.withOpacity(0.08),
              width: 1.2,
            ),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                sheen,
                Colors.transparent,
                Colors.transparent,
                isDark
                    ? Colors.white.withOpacity(0.02)
                    : Colors.black.withOpacity(0.03),
              ],
              stops: const [0.0, 0.35, 0.7, 1],
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  // --- Helper: Ambient glassy blobs behind content ---
  Widget _buildGlassBlob({
    required Alignment alignment,
    required Color color,
    double size = 210,
    double blur = 32,
    double opacity = 0.22,
  }) {
    return Align(
      alignment: alignment,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withOpacity(opacity),
                color.withOpacity(opacity * 0.35),
                Colors.transparent,
              ],
              stops: const [0, 0.55, 1],
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper: Input Field ---
  Widget _buildInputField({
    required String label,
    required String hintText,
    required bool isDropdown,
    List<String>? dropdownItems,
    TextEditingController? controller,
    bool isReadOnly = false,
    String? value,
    Function(String?)? onChanged,
    required bool isDark,
  }) {
    // Glassmorphism input style
    final inputBgColor =
        isDark
            ? Colors.white.withOpacity(0.08)
            : const Color(0xFFF9F9F9).withOpacity(0.8);
    final borderColor =
        isDark ? Colors.white.withOpacity(0.2) : const Color(0xFFDCDCDC);
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white38 : const Color(0xFF999999);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white70 : const Color(0xFF555555),
          ),
        ),
        const SizedBox(height: 5),
        isDropdown
            ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: inputBgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: value,
                  hint: Text(hintText, style: TextStyle(color: hintColor)),
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                  dropdownColor:
                      isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  style: TextStyle(color: textColor, fontSize: 16),
                  items:
                      (dropdownItems ?? []).map((String itemValue) {
                        return DropdownMenuItem<String>(
                          value: itemValue,
                          child: Text(itemValue),
                        );
                      }).toList(),
                  onChanged: onChanged,
                  menuMaxHeight: 300,
                ),
              ),
            )
            : TextField(
              controller: controller,
              readOnly: isReadOnly,
              style: TextStyle(
                color: isReadOnly ? textColor.withOpacity(0.7) : textColor,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: hintColor),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                fillColor:
                    isReadOnly
                        ? (isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.shade200)
                        : inputBgColor,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Colors.blueAccent,
                    width: 2,
                  ),
                ),
              ),
            ),
      ],
    );
  }

  // --- Helper: Checkbox ---
  Widget _buildSymptomCheckboxes(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final uncheckedColor = isDark ? Colors.white54 : Colors.black54;

    return Column(
      children:
          _symptoms.keys.map((String key) {
            return CheckboxListTile(
              title: Text(
                key,
                style: TextStyle(fontSize: 16, color: textColor),
              ),
              value: _symptoms[key],
              activeColor: Colors.blueAccent,
              checkColor: Colors.white,
              side: BorderSide(color: uncheckedColor),
              onChanged: (bool? val) {
                setState(() {
                  _symptoms[key] = val!;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              contentPadding: EdgeInsets.zero,
            );
          }).toList(),
    );
  }
}