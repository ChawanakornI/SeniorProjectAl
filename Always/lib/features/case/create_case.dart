import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/glass.dart';
import 'add_photo.dart';

class NewCaseScreen extends StatefulWidget {
  const NewCaseScreen({super.key});

  @override
  State<NewCaseScreen> createState() => _NewCaseScreenState();
}

class _NewCaseScreenState extends State<NewCaseScreen> {
  // State for form fields
  String? _selectedGender;
  String? _selectedAge;
  String? _selectedSpecificLocation;
  
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

  // ฟังก์ชันสร้างเลข Hash No. (วัน-เดือน-ปี + ลำดับ)
  String _generateHashNo() {
    final now = DateTime.now();
    final day = now.day.toString();
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString();
    const sequence = '01'; // ในการใช้งานจริงควรดึงเลขลำดับล่าสุดจาก Database
    return '$day$month$year$sequence';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF1C1C1C);

    // Gradient background colors (bluish to match Home/Dashboard style)
    final gradientColors = isDark
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

    // สร้าง Controller เพื่อแสดงค่า Hash No. อัตโนมัติ
    final hashController = TextEditingController(text: _generateHashNo());

    return Scaffold(
      extendBodyBehindAppBar: true, // For gradient to go behind app bar
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'New Case',
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
            child: Container(color: (isDark ? Colors.black : Colors.white).withOpacity(0.5)),
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
          _buildGlassBlob(alignment: Alignment.topRight, color: const Color(0xFF67E8F9)),
          _buildGlassBlob(alignment: Alignment.bottomLeft, color: const Color(0xFF60A5FA), size: 240, blur: 36),
          _buildGlassBlob(alignment: Alignment.centerLeft, color: const Color(0xFFA5B4FC), size: 180, blur: 28, opacity: 0.18),
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
                          hintText: '',
                          isDropdown: false,
                          controller: hashController,
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
                                onChanged: (val) => setState(() => _selectedGender = val),
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _buildInputField(
                                label: 'Age',
                                hintText: 'Select',
                                isDropdown: true,
                                dropdownItems: List.generate(130, (index) => (index + 1).toString()),
                                value: _selectedAge,
                                onChanged: (val) => setState(() => _selectedAge = val),
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
                          onChanged: (val) => setState(() => _selectedSpecificLocation = val),
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
                                      (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                                      (isDark ? Colors.white : Colors.black).withOpacity(0.02),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                                ),
                                child: Center(
                                  child: Text(
                                    "[Image of Human Body Map]",
                                    style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF555555)),
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
                                side: BorderSide(color: isDark ? Colors.white54 : Colors.grey.shade400),
                                foregroundColor: isDark ? Colors.white70 : Colors.grey.shade700,
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
                                backgroundColor: isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.9),
                                foregroundColor: isDark ? Colors.black : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                elevation: 0,
                              ),
                              child: const Text('Save'),
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

  // --- Pop-up Dialog (แก้ไขเฉพาะฟังก์ชันนี้) ---
  void _showConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) { // เปลี่ยนชื่อตัวแปรเป็น dialogContext เพื่อไม่งง
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                const Icon(Icons.location_on_outlined, size: 40, color: Colors.black87),
                const SizedBox(height: 15),
                const Text(
                  'Confirm Select this location?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You are going to take photo of a lesion',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        // --- 2. แก้ไขปุ่ม Confirm ตรงนี้ ---
                        onPressed: () {
                          Navigator.of(dialogContext).pop(); // ปิด Pop-up ยืนยัน
                          
                          // เปิด Pop-up ถ่ายรูป (AddPhotoDialog)
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (BuildContext context) {
                              return const AddPhotoDialog(); // เรียกใช้ไฟล์ใหม่
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Confirm'),
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
    final sheen = isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.55);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: glassBox(isDark, radius: radius, highlight: true).copyWith(
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.08),
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
                isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.03),
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
    final inputBgColor = isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF9F9F9).withOpacity(0.8);
    final borderColor = isDark ? Colors.white.withOpacity(0.2) : const Color(0xFFDCDCDC);
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white38 : const Color(0xFF999999);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : const Color(0xFF555555))),
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
                    icon: Icon(Icons.keyboard_arrow_down, color: isDark ? Colors.white54 : Colors.grey),
                    dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    style: TextStyle(color: textColor, fontSize: 16),
                    items: (dropdownItems ?? []).map((String itemValue) {
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
                style: TextStyle(color: isReadOnly ? textColor.withOpacity(0.7) : textColor),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(color: hintColor),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  fillColor: isReadOnly ? (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200) : inputBgColor,
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
                    borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
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
      children: _symptoms.keys.map((String key) {
        return CheckboxListTile(
          title: Text(key, style: TextStyle(fontSize: 16, color: textColor)),
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