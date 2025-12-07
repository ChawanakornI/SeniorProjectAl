import 'package:flutter/material.dart';

import 'features/login/presentation/screens/login_screen.dart';
import 'features/login/presentation/screens/forgot_password_screen.dart';
import 'pages/gp_home_page.dart';
import 'pages/home_page.dart';

class Routes {
  static const login = '/login';
  static const home = '/home';
  static const gpHome = '/gp-home';
  static const forgotPassword = '/forgot-password';

  static final all = <String, WidgetBuilder>{
    login: (_) => const LoginScreen(),
    home: (_) => const HomePage(),
    gpHome: (_) => const GpHomePage(),
    forgotPassword: (_) => const ForgotPasswordScreen(),
  };
}
