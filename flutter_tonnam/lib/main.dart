import 'package:flutter/material.dart';
import 'package:camera/camera.dart'; // 1. Import camera
import 'CreateCase.dart';

// 2. สร้างตัวแปร global เพื่อเก็บรายการกล้อง
List<CameraDescription> cameras = [];

// 3. เปลี่ยน main เป็น async
Future<void> main() async {
  // 4. รอให้ Flutter engine พร้อมทำงาน
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 5. โหลดรายการกล้องที่มีในเครื่อง
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error in fetching the cameras: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'New Case App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // ใช้ Font ที่รองรับภาษาไทยสวยๆ ถ้ามี
      ),
      home: const NewCaseScreen(),
    );
  }
}