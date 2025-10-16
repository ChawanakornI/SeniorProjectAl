import 'package:flutter/material.dart';
import '../features/login/presentation/screens/login_screen.dart';

class Routes {
  static const login = '/login';
  static const home = '/home';

  static final all = <String, WidgetBuilder>{
    login: (_) => const LoginScreen(),
    
  };
}
