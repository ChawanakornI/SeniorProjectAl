import 'dart:convert'; // สำหรับ jsonDecode
// สำหรับ File operations
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Import http
import 'main.dart'; // Import เพื่อเรียกใช้ตัวแปร 'cameras'
import 'photo_preview_screen.dart'; // Import หน้า Preview (ต้องมีไฟล์นี้)

// Enum เพื่อกำหนดสถานะของกล้อง
enum CameraStatus {
  tooDark,
  tooBright,
  focusing,
  good,
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  // สถานะเริ่มต้น
  final CameraStatus _currentStatus = CameraStatus.good;
  bool _isTakingPicture = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  // --- 1. ฟังก์ชันเริ่มการทำงานกล้อง ---
  Future<void> _initCamera() async {
    if (cameras.isEmpty) {
      print('No cameras found');
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

    _initializeControllerFuture = _controller!.initialize().then((_) {
      if (!mounted) return;
      _controller!.setFocusMode(FocusMode.auto);
      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        print('Camera Error: ${e.code}');
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // --- 2. ฟังก์ชันส่งรูปไปเช็คกับ FastAPI (Logic ที่เพิ่มเข้ามา) ---
  Future<bool> _checkImageWithPython(String imagePath) async {
    // แสดง Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      // ⚠️⚠️⚠️ เปลี่ยน IP ตรงนี้ให้เป็น IP เครื่องที่รัน Python ⚠️⚠️⚠️
      // ตัวอย่าง: 'http://192.168.1.105:8000/check-image'
      var uri = Uri.parse('http://192.168.1.37:8000/check-image');

      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', imagePath));

      // ส่ง Request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      // ปิด Loading
      if (mounted) Navigator.of(context).pop();

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        print("Server Response: $jsonResponse");

        if (jsonResponse['status'] == 'success') {
          return true; // รูปผ่าน
        } else {
          // แจ้งเตือนถ้ารูปเบลอหรือไม่ผ่าน
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(jsonResponse['message'] ?? 'Image check failed'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return false;
        }
      } else {
        print("Server Error: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      // ปิด Loading กรณี Error
      if (mounted) Navigator.of(context).pop();
      print("Connection Error: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot connect to server. Check IP Address.')),
        );
      }
      return false; 
    }
  }

  // --- 3. ฟังก์ชันถ่ายรูป (แก้ไขให้เชื่อมโยงกัน) ---
  Future<void> _takePicture() async {
    if (_isTakingPicture || _controller == null || !_controller!.value.isInitialized) {
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
      bool isImageGood = await _checkImageWithPython(image.path);

      if (isImageGood) {
        // 3.3 ถ้าผ่าน -> ไปหน้า Preview (PhotoPreviewScreen)
        final bool? shouldSave = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PhotoPreviewScreen(imagePath: image.path),
          ),
        );

        // 3.4 ถ้าในหน้า Preview กด Save (shouldSave == true)
        if (shouldSave == true) {
          if (!mounted) return;
          // ส่ง path รูปกลับไปให้หน้า Add Photo
          Navigator.of(context).pop(image.path);
        } else {
          // ถ้ากด Retake ก็ไม่ต้องทำอะไร อยู่หน้ากล้องเหมือนเดิม
          print("User wants to retake");
        }
      } 
      // ถ้ารูปไม่ผ่าน (_checkImageWithPython return false) มันจะโชว์ SnackBar แจ้งเตือนเองแล้ว

    } catch (e) {
      print(e);
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
        return {'color': Colors.red, 'text': 'Too Dark', 'subtext': 'Please add more light.'};
      case CameraStatus.tooBright:
        return {'color': Colors.red, 'text': 'Too Bright', 'subtext': 'Please reduce light.'};
      case CameraStatus.focusing:
        return {'color': Colors.yellow, 'text': 'Focusing...', 'subtext': 'Keep device still.'};
      case CameraStatus.good:
      return {'color': Colors.green, 'text': 'Good', 'subtext': 'Ready to take picture.'};
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusInfo = _getStatusInfo();
    final statusColor = statusInfo['color'] as Color;
    final statusText = statusInfo['text'] as String;
    final statusSubtext = statusInfo['subtext'] as String;

    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && _controller != null) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // Layer 1: Camera Preview
                CameraPreview(_controller!),

                // Layer 2: Black Overlay with Hole
                ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Colors.black54,
                    BlendMode.srcOut,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          backgroundBlendMode: BlendMode.dstOut,
                        ),
                      ),
                      Center(
                        child: Container(
                          height: 250,
                          width: 250,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Layer 3: UI Controls & Status
                Column(
                  children: [
                    const SizedBox(height: 60),
                    const Text(
                      'Photo Skin Lesion',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    
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
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                statusSubtext,
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          )
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
                            border: Border.all(
                              color: statusColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Shutter Button
                    Container(
                      height: 150,
                      alignment: Alignment.center,
                      child: FloatingActionButton(
                        backgroundColor: Colors.white,
                        onPressed: _currentStatus == CameraStatus.good ? _takePicture : null,
                        child: _isTakingPicture
                            ? const CircularProgressIndicator(color: Colors.black)
                            : const Icon(Icons.camera_alt, color: Colors.black, size: 32),
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
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
        },
      ),
    );
  }
}