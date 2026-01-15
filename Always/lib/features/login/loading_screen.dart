// import 'dart:math' as math;

// import 'package:flutter/material.dart';
// import 'package:vector_math/vector_math_64.dart' show Matrix4;

// import '../../../../routes.dart';

// class LoadingScreen extends StatefulWidget {
//   const LoadingScreen({super.key});

//   @override
//   State<LoadingScreen> createState() => _LoadingScreenState();
// }

// class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
//   late final AnimationController _controller;

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 2000),
//     )..repeat();
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   void _goToLogin() {
//     Navigator.of(context).pushReplacementNamed(Routes.login);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;

//     return GestureDetector(
//       onTap: _goToLogin,
//       child: Scaffold(
//         body: Stack(
//           children: [
//             Positioned.fill(
//               child: Image.asset(
//                 'assets/images/loadingbg.png',
//                 fit: BoxFit.cover,
//               ),
//             ),
//             Positioned.fill(
//               child: Container(
//                 color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.08),
//               ),
//             ),
//             Center(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   AnimatedBuilder(
//                     animation: _controller,
//                     builder: (context, child) {
//                       final pulse = 0.80 + 0.15 * math.sin(2 * math.pi * _controller.value);
//                       return Container(
//                         decoration: BoxDecoration(
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.white.withValues(alpha: 0.18 * pulse),
//                               blurRadius: 18 * pulse,
//                               spreadRadius: 2,
//                             ),
//                           ],
//                         ),
//                         child: Transform.scale(
//                           scale: 0.98 + 0.02 * pulse,
//                           child: Opacity(opacity: pulse, child: child),
//                         ),
//                       );
//                     },
//                     child: Image.asset(
//                       'assets/images/logo_loadingpage.png',
//                       height: 120,
//                     ),
//                   ),
//                   const SizedBox(height: 32),
//                   AnimatedBuilder(
//                     animation: _controller,
//                     builder: (context, child) {
//                       final slide = (_controller.value * 2) - 1; // -1 to 1 sweep
//                       final glow = 0.75 + 0.25 * math.sin(2 * math.pi * _controller.value);
//                       return ShaderMask(
//                         shaderCallback: (bounds) {
//                           return LinearGradient(
//                             begin: Alignment.centerLeft,
//                             end: Alignment.centerRight,
//                             colors: [
//                               Colors.white.withValues(alpha: 0.0),
//                               Colors.white.withValues(alpha: 0.55),
//                               Colors.white.withValues(alpha: 0.0),
//                             ],
//                             stops: const [0.20, 0.5, 0.80],
//                             transform: _SlidingGradientTransform(slide),
//                           ).createShader(bounds);
//                         },
//                         blendMode: BlendMode.srcATop,
//                         child: Opacity(opacity: glow, child: child),
//                       );
//                     },
//                     child: Image.asset(
//                       'assets/images/ALLCARE.png',
//                       height: 48,
//                       color: Colors.white.withValues(alpha: 0.7),
//                       colorBlendMode: BlendMode.srcIn,
//                     ),
//                   ),
//                   const SizedBox(height: 36),
//                   AnimatedBuilder(
//                     animation: _controller,
//                     builder: (context, child) {
//                       final flash = 0.55 + 0.45 * (0.5 + 0.5 * math.sin(2 * math.pi * _controller.value));
//                       return Opacity(opacity: flash, child: child);
//                     },
//                     child: Text(
//                       'Tap anywhere to continue',
//                       style: TextStyle(
//                         color: isDark ? Colors.white70 : Colors.black87,
//                         fontWeight: FontWeight.w600,
//                         letterSpacing: 0.2,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// /// Slide the shimmer gradient horizontally across the text.
// class _SlidingGradientTransform extends GradientTransform {
//   const _SlidingGradientTransform(this.slidePercent);

//   final double slidePercent;

//   @override
//   Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
//     return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
//   }
// }
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../routes.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flashController;

  @override
  void initState() {
    super.initState();

    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    Future.delayed(const Duration(seconds: 5), () async {
      if (!mounted) return;

      await _flashController.forward();
      _goToLogin();
    });
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacementNamed(Routes.login);
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/LoginBGJPEG.jpg',
              fit: BoxFit.cover,
            ),
          ),

          Positioned.fill(
            child: Container(
              color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.08),
            ),
          ),

          // Content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/images/LogoVector.svg',
                  height: 120,
                  colorFilter: ColorFilter.mode(
                    Colors.white.withValues(alpha: 0.9),
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(height: 32),
                SvgPicture.asset(
                  'assets/images/AllcareTextVector.svg',
                  height: 48,
                  colorFilter: ColorFilter.mode(
                    Colors.white.withValues(alpha: 0.7),
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(height: 36),
              ],
            ),
          ),

          Positioned.fill(
            child: FadeTransition(
              opacity: _flashController,
              child: Container(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
