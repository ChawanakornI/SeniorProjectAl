import 'dart:convert'; // สำหรับ jsonDecode
import 'dart:developer';
import 'dart:io'; // สำหรับ Platform check
// สำหรับ File operations
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Import http
import 'api_config.dart'; // Shared API configuration
import 'camera_globals.dart'; // Import เพื่อเรียกใช้ตัวแปร 'cameras'
import 'photo_preview_screen.dart'; // Import หน้า Preview (ต้องมีไฟล์นี้)
import '../../app_state.dart';

// Enum เพื่อกำหนดสถานะของกล้อง
enum CameraStatus { tooDark, tooBright, focusing, good }

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, this.caseId});

  final String? caseId;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  // สถานะเริ่มต้น
  final CameraStatus _currentStatus = CameraStatus.good;
  bool _isTakingPicture = false;

  // Multi-image support
  final List<String> _takenImages = [];
  final int _maxImages = 8;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  // --- 1. ฟังก์ชันเริ่มการทำงานกล้อง ---
  Future<void> _initCamera() async {
    if (cameras.isEmpty) {
      log('No cameras found', name: 'CameraScreen');
      return;
    }

    final firstCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      firstCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    _initializeControllerFuture = _controller!
        .initialize()
        .then((_) {
          if (!mounted) return;
          _controller!.setFocusMode(FocusMode.auto);
          setState(() {});
        })
        .catchError((Object e) {
          if (e is CameraException) {
            log(
              'Camera Error: ${e.code}',
              name: 'CameraScreen',
              error: e,
            );
          }
        });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // --- 2. ฟังก์ชันส่งรูปไปเช็คกับ FastAPI (Logic ที่เพิ่มเข้ามา) ---
  Future<Map<String, dynamic>?> _checkImageWithPython(String imagePath) async {
    // แสดง Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (c) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
    );

    try {
      final uri = _buildCheckUri();
      log(
        'DEBUG: Connecting to URI: $uri (scheme: ${uri.scheme})',
        name: 'CameraScreen',
      );

      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', imagePath));

      request.headers.addAll(
        ApiConfig.buildHeaders(
          userId: appState.userId,
          userRole: appState.userRole,
        ),
      );

      // ส่ง Request with timeout
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timed out. Server may be unreachable.');
        },
      );
      var response = await http.Response.fromStream(streamedResponse);

      // ปิด Loading
      if (mounted) Navigator.of(context).pop();

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        log('Server Response: $jsonResponse', name: 'CameraScreen');

        if (jsonResponse['status'] == 'success') {
          return jsonResponse;
        } else {
          // Blur check failed - show dialog asking user to retake
          if (mounted) {
            final blurScore = jsonResponse['blur_score'] as num?;
            await _showBlurErrorDialog(
              message: jsonResponse['message'] ?? 'Image is too blurry',
              blurScore: blurScore?.toDouble(),
            );
          }
          return null;
        }
      } else {
        log(
          'Server Error: ${response.statusCode} - ${response.body}',
          name: 'CameraScreen',
        );
        return null;
      }
    } catch (e) {
      // ปิด Loading กรณี Error
      if (mounted) Navigator.of(context).pop();
      log('Connection Error', name: 'CameraScreen', error: e);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot connect to server. Check IP Address.'),
          ),
        );
      }
      return null;
    }
  }

  // Show dialog when image is too blurry
  Future<void> _showBlurErrorDialog({
    required String message,
    double? blurScore,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.blur_on, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text(
                'Image Too Blurry',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: const TextStyle(fontSize: 16)),
              if (blurScore != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Blur Score: ${blurScore.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontFamily: 'monospace',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Please take a new picture with better focus and lighting.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Retake Photo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Uri _buildCheckUri() {
    // Use shared config which handles URL sanitization (fixes htp://, https://, etc.)
    final uri = ApiConfig.checkImageUri;
    final caseId = widget.caseId?.trim();
    final resolved =
        caseId == null || caseId.isEmpty
            ? uri
            : uri.replace(
              queryParameters: {...uri.queryParameters, 'case_id': caseId},
            );
    log(
      'DEBUG: Using API endpoint: $resolved (base: ${ApiConfig.baseUrl})',
      name: 'CameraScreen',
    );
    return resolved;
  }

  Future<String?> _showMultiImageOptions() async {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final isDark =
      Theme.of(dialogContext).brightness == Brightness.dark;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    '${_takenImages.length}/$_maxImages photos taken',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                const Icon(Icons.camera_alt, size: 48, color: Colors.blue),
                const SizedBox(height: 16),

                Text(
                  'Photo ${_takenImages.length} captured successfully!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),
                const Text(
                  'What would you like to do next?',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color.fromARGB(255, 145, 145, 145), // Colors.grey[600]
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Action buttons
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Continue taking photos (if not at limit)
                    if (_takenImages.length < _maxImages)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              () => Navigator.of(dialogContext).pop('continue'),
                          icon: const Icon(Icons.add_a_photo),
                          label: const Text('Take Another Photo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),

                    if (_takenImages.length < _maxImages)
                      const SizedBox(height: 12),

                    // Preview current photos
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            () => Navigator.of(dialogContext).pop('preview'),
                        icon: const Icon(Icons.preview),
                        label: const Text('Preview Photos'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Save current photos
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            () => Navigator.of(dialogContext).pop('save'),
                        icon: const Icon(Icons.save),
                        label: Text(
                          'Save ${_takenImages.length} Photo${_takenImages.length > 1 ? 's' : ''}',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
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

  // --- 3. ฟังก์ชันถ่ายรูป (แก้ไขให้เชื่อมโยงกัน) ---
  Future<void> _takePicture() async {
    if (_isTakingPicture ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }

    // Check if we've reached the limit
    if (_takenImages.length >= _maxImages) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Maximum 8 images reached')));
      return;
    }

    setState(() {
      _isTakingPicture = true;
    });

    try {
      await _initializeControllerFuture;

      // 3.1 ถ่ายรูป
      final XFile image = await _controller!.takePicture();

      if (!mounted) return;

      // 3.2 ส่งรูปไปเช็คกับ FastAPI
      final result = await _checkImageWithPython(image.path);

      if (result != null && result['status'] == 'success') {
        // Add image to collection
        _takenImages.add(image.path);

        // Show multi-image options
        final action = await _showMultiImageOptions();

        switch (action) {
          case 'continue':
            // Continue taking more photos (stay in camera)
            break;
          case 'save':
            // Save current images and return to add_photo
            if (!mounted) return;
            Navigator.of(context).pop(_takenImages);
            break;
          case 'preview':
            // Show preview of all images
            if (!mounted) return;
            final shouldSave = await Navigator.of(context).push(
              MaterialPageRoute(
                builder:
                    (context) => PhotoPreviewScreen(
                      imagePath: _takenImages.last, // Show the last taken image
                      caseId: result['case_id'] as String?,
                      isMultiImage: true,
                      imageCount: _takenImages.length,
                    ),
              ),
            );
            if (shouldSave == true) {
              if (!mounted) return;
              Navigator.of(context).pop(_takenImages);
            }
            break;
        }
      }
      // ถ้ารูปไม่ผ่าน (_checkImageWithPython return false) มันจะโชว์ SnackBar แจ้งเตือนเองแล้ว
    } catch (e) {
      log('Failed to take picture', name: 'CameraScreen', error: e);
    } finally {
      if (mounted) {
        setState(() {
          _isTakingPicture = false;
        });
      }
    }
  }

  // Helper function UI สถานะ
  Map<String, dynamic> _getStatusInfo() {
    switch (_currentStatus) {
      case CameraStatus.tooDark:
        return {
          'color': Colors.red,
          'text': 'Too Dark',
          'subtext': 'Please add more light.',
        };
      case CameraStatus.tooBright:
        return {
          'color': Colors.red,
          'text': 'Too Bright',
          'subtext': 'Please reduce light.',
        };
      case CameraStatus.focusing:
        return {
          'color': Colors.yellow,
          'text': 'Focusing...',
          'subtext': 'Keep device still.',
        };
      case CameraStatus.good:
        return {
          'color': Colors.green,
          'text': 'Good',
          'subtext': 'Ready to take picture.',
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show error message if no cameras available (e.g., on macOS)
    if (cameras.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.camera_alt_outlined,
                  size: 64,
                  color: Colors.white70,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Camera Not Available',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  Platform.isMacOS
                      ? 'The camera plugin does not support macOS.\nPlease use "Choose from Gallery" instead.'
                      : 'No cameras found on this device.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final statusInfo = _getStatusInfo();
    final statusColor = statusInfo['color'] as Color;
    final statusText = statusInfo['text'] as String;
    final statusSubtext = statusInfo['subtext'] as String;

    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              _controller != null) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // Layer 1: Camera Preview
                CameraPreview(_controller!),

                // Layer 2: Black Overlay with cutout
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CameraMaskPainter(
                      holeSize: 250,
                      borderRadius: 12,
                      overlayColor: Colors.black54,
                    ),
                  ),
                ),

                // Layer 3: UI Controls & Status
                Column(
                  children: [
                    const SizedBox(height: 60),
                    const Text(
                      'Photo Skin Lesion',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Progress counter for multi-image
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${_takenImages.length}/$_maxImages photos',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Status Indicators
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30.0),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                statusSubtext,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: Center(
                        // Border around the hole
                        child: Container(
                          height: 254,
                          width: 254,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: statusColor, width: 2),
                          ),
                        ),
                      ),
                    ),

                    // Shutter Button
                    Container(
                      height: 150,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_takenImages.length >= _maxImages)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Maximum photos reached',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          FloatingActionButton(
                            backgroundColor:
                                _takenImages.length >= _maxImages
                                    ? Colors.grey
                                    : Colors.white,
                            onPressed:
                                (_currentStatus == CameraStatus.good &&
                                        _takenImages.length < _maxImages)
                                    ? _takePicture
                                    : null,
                            child:
                                _isTakingPicture
                                    ? const CircularProgressIndicator(
                                      color: Colors.black,
                                    )
                                    : const Icon(
                                      Icons.camera_alt,
                                      color: Colors.black,
                                      size: 32,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),

                // Close Button
                Positioned(
                  top: 40,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
        },
      ),
    );
  }
}

class _CameraMaskPainter extends CustomPainter {
  _CameraMaskPainter({
    required this.holeSize,
    required this.borderRadius,
    required this.overlayColor,
  });

  final double holeSize;
  final double borderRadius;
  final Color overlayColor;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = overlayColor;
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final holeRect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: holeSize,
      height: holeSize,
    );
    final holeRRect = RRect.fromRectAndRadius(
      holeRect,
      Radius.circular(borderRadius),
    );
    final overlayPath = Path()..addRect(fullRect);
    final holePath = Path()..addRRect(holeRRect);
    final cutout = Path.combine(
      PathOperation.difference,
      overlayPath,
      holePath,
    );
    canvas.drawPath(cutout, overlayPaint);
  }

  @override
  bool shouldRepaint(covariant _CameraMaskPainter oldDelegate) {
    return holeSize != oldDelegate.holeSize ||
        borderRadius != oldDelegate.borderRadius ||
        overlayColor != oldDelegate.overlayColor;
  }
}
