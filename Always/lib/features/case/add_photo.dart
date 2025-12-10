import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'camera_screen.dart'; // ตรวจสอบว่า import ไฟล์นี้ถูกต้องตามโปรเจกต์คุณ

class AddPhotoDialog extends StatefulWidget {
  const AddPhotoDialog({super.key});

  @override
  State<AddPhotoDialog> createState() => _AddPhotoDialogState();
}

class _AddPhotoDialogState extends State<AddPhotoDialog> {
  final List<String> _selectedImages = [];
  final int _maxImages = 8;

  // ฟังก์ชันเพิ่มรูปเข้า List
  void _addImage(String path) {
    if (_selectedImages.length < _maxImages) {
      setState(() {
        _selectedImages.add(path);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 8 images reached.')),
      );
    }
  }

  // ฟังก์ชันลบรูปออกจาก List
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  // ตรวจสอบความเบลอเบื้องต้นและเพิ่มรูป
  Future<void> _validateAndAddImage(String path) async {
    final isBlurry = await _isImageBlurry(path);
    if (isBlurry) {
      _showBlurDialog();
      return;
    }
    _addImage(path);
  }

  Future<bool> _isImageBlurry(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return false;

      // Convert to grayscale for faster processing
      final gray = img.grayscale(decoded);
      final w = gray.width;
      final h = gray.height;
      if (w < 3 || h < 3) return false;

      double laplacianSumSq = 0;
      int count = 0;

      // Simple variance of Laplacian (4-neighbor) to detect blur
      for (int y = 1; y < h - 1; y++) {
        for (int x = 1; x < w - 1; x++) {
          final center = gray.getPixel(x, y).luminance;
          final top = gray.getPixel(x, y - 1).luminance;
          final bottom = gray.getPixel(x, y + 1).luminance;
          final left = gray.getPixel(x - 1, y).luminance;
          final right = gray.getPixel(x + 1, y).luminance;
          final lap = (top + bottom + left + right) - 4 * center;
          laplacianSumSq += lap * lap;
          count++;
        }
      }

      final variance = laplacianSumSq / count;
      // Lower variance implies blur. Threshold tuned for mobile photos.
      return variance < 70;
    } catch (_) {
      return false;
    }
  }

  void _showBlurDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Image looks blurry'),
          content: const Text('Please retake or choose a clearer image.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // ฟังก์ชันแสดงตัวเลือก (Camera / Gallery)
  void _showImageSourceActionSheet(BuildContext context) {
    if (_selectedImages.length >= _maxImages) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                child: Text('Select Image Source',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800])),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Take Photo (Smart Camera)'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  // ตรวจสอบว่า CameraScreen ส่งค่ากลับมาเป็น String (path) หรือไม่
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (context) => const CameraScreen()),
                  );
                  if (result != null && result is String) {
                    await _validateAndAddImage(result);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final ImagePicker picker = ImagePicker();
                  final XFile? image =
                      await picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    await _validateAndAddImage(image.path);
                  }
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // --- NEW: ฟังก์ชันสำหรับกดปุ่ม Cancel หรือ ปิดหน้า ---
  void _handleCancel() {
    if (_selectedImages.isEmpty) {
      // ถ้าไม่มีรูปเลย ให้ปิดหน้าได้เลย ไม่ต้องถาม
      Navigator.of(context).pop();
    } else {
      // ถ้ามีรูปค้างอยู่ ให้ถามก่อน
      _showConfirmationDialog(
        icon: Icons.add_alert_outlined, // หรือ Icons.warning_amber_rounded
        title: "Confirm Leave Add photo?",
        subtitle: "After confirm your image will lost",
        confirmText: "Confirm",
        isConfirmAction: false, // เป็นปุ่มแดงหรือปุ่มปกติ (ใช้แยกสีถ้าต้องการ)
        onConfirm: () {
          Navigator.of(context).pop(); // ปิดหน้า AddPhotoDialog
        },
      );
    }
  }

  // --- NEW: ฟังก์ชันสำหรับกดปุ่ม Save ---
  void _handleSave() {
    if (_selectedImages.isEmpty) return; // กันกด Save ตอนไม่มีรูป

    _showConfirmationDialog(
      icon: Icons.save_as_outlined,
      title: "Confirm saving the image?",
      subtitle: "You are going to save this photo to your case.",
      confirmText: "Confirm",
      isConfirmAction: true,
      onConfirm: () {
        // ส่ง List รูปภาพกลับไปหน้าหลัก
        Navigator.of(context).pop(_selectedImages);
      },
    );
  }

  // --- NEW: ฟังก์ชันสร้าง Dialog Pop-up (ตามดีไซน์) ---
  void _showConfirmationDialog({
    required IconData icon,
    required String title,
    required String subtitle,
    required String confirmText,
    required VoidCallback onConfirm,
    bool isConfirmAction = true,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 48, color: Colors.black87),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    // ปุ่ม Cancel (สีดำ)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop(); // ปิด Dialog
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // ปุ่ม Confirm (สีฟ้า)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop(); // ปิด Dialog ก่อน
                          onConfirm(); // ทำคำสั่งที่ส่งมา
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(confirmText),
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Header & Counter ---
                  Row(
                    children: [
                      const Text('Add Photo',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12)),
                        child: Text('${_selectedImages.length}/$_maxImages',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Upload lesion photos to predict the result',
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 20),

                  // --- Image Area ---
                  Expanded(
                    child: _selectedImages.isEmpty
                        ? _buildEmptyState()
                        : _buildImageGrid(),
                  ),

                  const SizedBox(height: 20),

                  // --- Buttons ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // ปุ่ม Cancel ล่างซ้าย
                      OutlinedButton(
                        onPressed: _handleCancel, // เรียกใช้ฟังก์ชันใหม่ตรงนี้
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(color: Colors.grey)),
                      ),
                      const SizedBox(width: 12),
                      // ปุ่ม Save ล่างขวา
                      ElevatedButton(
                        onPressed: _selectedImages.isEmpty
                            ? null
                            : _handleSave, // เรียกใช้ฟังก์ชันใหม่ตรงนี้
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedImages.isNotEmpty
                              ? Colors.black
                              : Colors.grey.shade200,
                          foregroundColor: _selectedImages.isNotEmpty
                              ? Colors.white
                              : Colors.grey,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey.shade300)),
                        ),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ปุ่ม X มุมขวาบน
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.black54),
                onPressed: _handleCancel, // เรียกใช้ฟังก์ชันใหม่ตรงนี้เช่นกัน
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget 1: แสดงตอนยังไม่มีรูป
  Widget _buildEmptyState() {
    return Center(
      child: GestureDetector(
        onTap: () => _showImageSourceActionSheet(context),
        child: Container(
          height: 160,
          width: 160,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined,
                  size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'Tap to take photo\nor select from gallery',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget 2: แสดงตอนมีรูปแล้ว (Grid)
  Widget _buildImageGrid() {
    return GridView.builder(
      itemCount: _selectedImages.length +
          (_selectedImages.length < _maxImages ? 1 : 0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        if (index == _selectedImages.length) {
          return GestureDetector(
            onTap: () => _showImageSourceActionSheet(context),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Icon(Icons.add, size: 30, color: Colors.grey.shade600),
            ),
          );
        }

        final imagePath = _selectedImages[index];
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: FileImage(File(imagePath)),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: -5,
              right: -5,
              child: GestureDetector(
                onTap: () => _removeImage(index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}