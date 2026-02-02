import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'pages/home_page.dart';
import 'pages/gp_home_page.dart';
import 'routes.dart';
import 'features/case/camera_globals.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create AppState instance for async initialization
  final appStateInstance = AppState();

  // Set global accessor for services without BuildContext (hybrid approach)
  appState = appStateInstance;

  // Load global persisted settings (theme, language, etc.)
  // User-specific data (profile, names) is loaded after login
  await appStateInstance.loadPersistedData();

  // Camera plugin doesn't support macOS, so handle gracefully
  if (Platform.isMacOS) {
    debugPrint('Camera plugin not supported on macOS. Using empty camera list.');
    cameras = [];
  } else {
    try {
      cameras = await availableCameras();
    } on MissingPluginException catch (e) {
      debugPrint('Camera plugin not available: $e');
      cameras = [];
    } on CameraException catch (e) {
      debugPrint('Error in fetching the cameras: $e');
      cameras = [];
    } catch (e) {
      debugPrint('Unexpected error initializing cameras: $e');
      cameras = [];
    }
  }

  runApp(
    ChangeNotifierProvider.value(
      value: appStateInstance,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // context.watch rebuilds this widget when AppState.isDarkMode changes
    final isDark = context.watch<AppState>().isDarkMode;

    return MaterialApp(
      title: 'Alskin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.white,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFBFBFB),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0EA5E9),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF050A16),
        useMaterial3: true,
      ),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      initialRoute: Routes.loading,
      routes: {
        ...Routes.all,
        Routes.home: (_) => const HomePage(),
        Routes.gpHome: (_) => const GpHomePage(),
      },
    );
  }
}
