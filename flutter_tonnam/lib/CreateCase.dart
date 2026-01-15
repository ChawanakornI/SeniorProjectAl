import 'package:flutter/material.dart';
import 'add_photo.dart';
class NewCaseScreen extends StatelessWidget {
  const NewCaseScreen({super.key});

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
    const primaryColor = Color(0xFF1C1C1C);
    
    // สร้าง Controller เพื่อแสดงค่า Hash No. อัตโนมัติ
    final hashController = TextEditingController(text: _generateHashNo());

    return Scaffold(
      backgroundColor: Colors.white,
      // --- 1. App Bar ---
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            // Navigator.pop(context); // ใช้เมื่อมีการเชื่อมต่อหลายหน้า
          },
        ),
        title: const Text(
          'New Case',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: primaryColor,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      
      // --- 2. Body Content ---
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 15),

            const Text(
              'Visit Data',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 15),

            // Hash No.
            _buildInputField(
              label: 'Hash No.',
              hintText: '',
              isDropdown: false,
              controller: hashController,
              isReadOnly: true,
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
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildInputField(
                    label: 'Age',
                    hintText: 'Select',
                    isDropdown: true,
                    dropdownItems: List.generate(130, (index) => (index + 1).toString()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            // Symptoms
            const Text(
              'Symptoms',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 10),
            _buildSymptomCheckboxes(),
            const SizedBox(height: 25),

            // Location
            const Text(
              'Location',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 15),
            _buildInputField(
              label: 'Specific Location',
              hintText: 'Select Specific Location',
              isDropdown: true,
              dropdownItems: ['Face', 'Arm', 'Leg', 'Back'],
            ),
            const SizedBox(height: 30),

            // Body Map Placeholder
            const AspectRatio(
              aspectRatio: 1.0,
              child: Placeholder(
                color: Color(0xFFE0E0E0),
                strokeWidth: 1,
                child: Center(
                  child: Text(
                    "[Image of Human Body Map]",
                    style: TextStyle(color: Color(0xFF777777)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // --- Bottom Buttons (Cancel / Save) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 45,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      side: const BorderSide(color: Colors.grey),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: 100,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: () {
                      _showConfirmDialog(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text('Save', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 50),
          ],
        ),
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

  // --- Helper: Input Field ---
  Widget _buildInputField({
    required String label,
    required String hintText,
    required bool isDropdown,
    List<String>? dropdownItems,
    TextEditingController? controller,
    bool isReadOnly = false,
  }) {
    const inputBgColor = Color(0xFFF9F9F9);
    const borderColor = Color(0xFFDCDCDC);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF555555))),
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
                    value: null,
                    hint: Text(hintText, style: const TextStyle(color: Color(0xFF999999))),
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                    items: (dropdownItems ?? []).map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (val) {},
                    menuMaxHeight: 300,
                  ),
                ),
              )
            : TextField(
                controller: controller,
                readOnly: isReadOnly,
                style: isReadOnly ? const TextStyle(color: Colors.black54) : null,
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: const TextStyle(color: Color(0xFF999999)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  fillColor: isReadOnly ? Colors.grey.shade200 : inputBgColor,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: borderColor),
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
  Widget _buildSymptomCheckboxes() {
    final List<String> symptoms = [
      'raised scar',
'Red marks',
'Sunbathe',
'Fair skin',
'The patient has a history of organ transplantation',
'The patient has been exposed to arsenic',
'The patient has photosensitivity',
'The patient has a history of skin disease',
'The patient has relatives who have had cancer.',
    ];

    return Column(
      children: symptoms.map((symptom) {
        return StatefulBuilder(
          builder: (context, setState) {
            bool isChecked = false;
            return CheckboxListTile(
              title: Text(symptom, style: const TextStyle(fontSize: 16)),
              value: isChecked,
              onChanged: (val) {
                setState(() => isChecked = val!);
              },
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              contentPadding: EdgeInsets.zero,
            );
          },
        );
      }).toList(),
    );
  }
}