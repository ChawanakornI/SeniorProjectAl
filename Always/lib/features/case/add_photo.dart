import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'camera_screen.dart'; // ตรวจสอบว่า import ไฟล์นี้ถูกต้องตามโปรเจกต์คุณ

class AddPhotoDialog extends StatefulWidget {
  const AddPhotoDialog({
    super.key,
    this.caseId,
    this.initialImages = const [],
    this.title,
    this.subtitle,
  });

  final String? caseId;
  final List<String> initialImages;
  final String? title;
  final String? subtitle;

  @override
  State<AddPhotoDialog> createState() => _AddPhotoDialogState();
}

class _AddPhotoDialogState extends State<AddPhotoDialog> {
  final List<String> _selectedImages = [];
  final int _maxImages = 8;
  late final List<String> _initialImages;

  @override
  void initState() {
    super.initState();
    _initialImages = _normalizeImages(widget.initialImages);
    if (_initialImages.isNotEmpty) {
      _selectedImages.addAll(_initialImages.take(_maxImages));
    }
  }

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

  List<String> _normalizeImages(List<String> paths) {
    final normalized = <String>[];
    final seen = <String>{};
    for (final path in paths) {
      final trimmed = path.trim();
      if (trimmed.isEmpty) continue;
      if (seen.add(trimmed)) {
        normalized.add(trimmed);
      }
    }
    return normalized;
  }

  bool get _hasChanges {
    if (_initialImages.length != _selectedImages.length) return true;
    final initialSet = _initialImages.toSet();
    for (final path in _selectedImages) {
      if (!initialSet.contains(path)) return true;
    }
    return false;
  }

  bool _isNetworkPath(String path) {
    final lower = path.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  Widget _buildThumbnailPlaceholder(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade200,
      child: Icon(
        Icons.broken_image_outlined,
        color: isDark ? Colors.white54 : Colors.grey.shade500,
        size: 24,
      ),
    );
  }

  Widget _buildThumbnail(String path, bool isDark) {
    final placeholder = _buildThumbnailPlaceholder(isDark);
    if (_isNetworkPath(path)) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }
    final file = File(path);
    if (!file.existsSync()) return placeholder;
    return Image.file(
      file,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }

  void _showBlurDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
    if (_selectedImages.length >= _maxImages) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Maximum 8 images reached')));
      return;
    }

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
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 20,
                ),
                child: Text(
                  'Select Image Source',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                leading: Icon(
                  Icons.camera_alt,
                  color:
                      _selectedImages.length >= _maxImages
                          ? Colors.grey
                          : Colors.blue,
                ),
                title: Text(
                  'Take Photo (Smart Camera) (${_maxImages - _selectedImages.length} remaining)',
                  style: TextStyle(
                    color:
                        _selectedImages.length >= _maxImages
                            ? Colors.grey
                            : null,
                  ),
                ),
                enabled: _selectedImages.length < _maxImages,
                onTap: () async {
                  Navigator.of(ctx).pop();
                  // CameraScreen now returns List<String> (multiple paths) or String (single path)
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CameraScreen(caseId: widget.caseId),
                    ),
                  );
                  if (result != null) {
                    if (result is List<String>) {
                      // Handle multiple images from camera
                      for (final path in result) {
                        await _validateAndAddImage(path);
                        if (_selectedImages.length >= _maxImages) break;
                      }
                    } else if (result is String) {
                      // Handle single image (backward compatibility)
                      await _validateAndAddImage(result);
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: Text(
                  'Choose from Gallery (${_maxImages - _selectedImages.length} remaining)',
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final ImagePicker picker = ImagePicker();
                  final List<XFile> images = await picker.pickMultiImage(
                    limit: _maxImages - _selectedImages.length,
                    imageQuality: 90,
                  );
                  if (images.isNotEmpty) {
                    // Process multiple images with blur check
                    for (final image in images) {
                      await _validateAndAddImage(image.path);
                      // Stop if we've reached the limit
                      if (_selectedImages.length >= _maxImages) break;
                    }
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
    if (!_hasChanges) {
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
    barrierDismissible: false,
    barrierColor: Colors.transparent, // สำคัญ
    builder: (BuildContext dialogContext) {
      final isDark =
          Theme.of(dialogContext).brightness == Brightness.dark;

      return Stack(
        children: [
          // 🔹 BLUR + OVERLAY BACKGROUND
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              color: const Color.fromARGB(255, 223, 223, 223)
                  .withValues(alpha: isDark ? 0.15 : 0.25),
            ),
          ),

          // 🔹 DIALOG CONTENT
          Center(
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
              backgroundColor:
                  isDark ? const Color(0xFF282828) : const Color(0xFFFBFBFB),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      icon,
                      size: 48,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    const SizedBox(height: 16),

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
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            isDark ? Colors.white70 : Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        // Cancel
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isDark ? const Color(0xFF1F1F1F) : Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "Cancel",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Confirm
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              onConfirm();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              confirmText,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
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
        ],
      );
    },
  );
}


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogTitle = widget.title ?? 'Add Photo';
    final dialogSubtitle =
        widget.subtitle ?? 'Upload lesion photos to predict the result';

    return Dialog(
      backgroundColor: Colors.transparent, // สำคัญ
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color:
              isDark
                  ? const Color(0xFF1C1C1E) // dark mode
                  : const Color(0xFFFEFEFE), // light mode (medical gray)
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.25),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        dialogTitle,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                isDark ? Colors.white24 : Colors.grey.shade400,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_selectedImages.length}/$_maxImages',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isDark ? Colors.white70 : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Text(
                    dialogSubtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ---------- Image Area ----------
                  Expanded(
                    child:
                        _selectedImages.isEmpty
                            ? _buildEmptyState()
                            : _buildImageGrid(isDark),
                  ),

                  const SizedBox(height: 20),

                  // ---------- Buttons ----------
                  Row(
  children: [
    Expanded(
      child: OutlinedButton(
        onPressed: _handleCancel,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          foregroundColor: isDark ? Colors.white70 : Colors.grey,
        ),
        child: const Text(
          'Cancel',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: ElevatedButton(
        onPressed: _selectedImages.isEmpty ? null : _handleSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: _selectedImages.isNotEmpty
              ? Colors.black
              : Colors.grey.shade300,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          'Save',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    ),
  ],
),

                ],
              ),
            ),

            // ---------- Close button ----------
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Icon(
                  Icons.close,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                onPressed: _handleCancel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget 1: แสดงตอนยังไม่มีรูป
  Widget _buildEmptyState() {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return Align(
    alignment: Alignment.topLeft,
    child: GestureDetector(
      onTap: () => _showImageSourceActionSheet(context),
      child: Container(
        height: 130,
        width: 130,
        decoration: BoxDecoration(
          color: isDark
              ? Color(0xFF282828)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white24
                : Colors.grey.shade300,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_a_photo_outlined,
              size: 48,
              color: isDark ? Colors.white54 : Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'Tap to take photo\nor select from gallery',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}


  // Widget 2: แสดงตอนมีรูปแล้ว (Grid)
  Widget _buildImageGrid(bool isDark) {
    return GridView.builder(
      itemCount:
          _selectedImages.length +
          (_selectedImages.length < _maxImages ? 1 : 0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        if (index == _selectedImages.length) {
          return GestureDetector(
            onTap: () => _showImageSourceActionSheet(context),
            child: Container(
              decoration: BoxDecoration(
                color: isDark? Color(0xFF282828)
                :Colors.grey.shade50,
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
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox.expand(
                child: _buildThumbnail(imagePath, isDark),
              ),
            ),
            Positioned(
              top: -8,
              right: -8,
              child: GestureDetector(
                onTap: () => _removeImage(index),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
