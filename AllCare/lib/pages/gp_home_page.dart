import 'package:flutter/material.dart';

import 'home_page.dart';

/// General practice home page: same as HomePage but without labeling entry.
/// Use this for GP accounts by routing to this widget after login.
class GpHomePage extends StatelessWidget {
  const GpHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomePage(showLabeling: false);
  }
}

