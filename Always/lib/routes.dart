import 'package:flutter/material.dart';

import 'features/login/loading_screen.dart';
import 'features/login/login_screen.dart';
import 'features/login/forgot_password_screen.dart';
import 'pages/gp_home_page.dart';
import 'pages/home_page.dart';
import 'pages/admin.dart';


class Routes {
  static const loading = '/';
  static const login = '/login';
  static const home = '/home';
  static const gpHome = '/gp-home';
  static const forgotPassword = '/forgot-password';
  static const admin = '/admin';

  static final all = <String, WidgetBuilder>{
    loading: (_) => const LoadingScreen(),
    login: (_) => const LoginScreen(),
    home: (_) => const HomePage(),
    gpHome: (_) => const GpHomePage(),
    forgotPassword: (_) => const ForgotPasswordScreen(),
    admin: (_) => const AdminPage(),
  };
}
