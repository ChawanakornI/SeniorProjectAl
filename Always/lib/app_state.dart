import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  String _language = 'English';
  bool _isDarkMode = false;
  String _firstName = 'Dr.';
  String _lastName = 'Strange';
  String _userId = '';
  String _userRole = ''; // 'gp', 'doctor', etc.

  String get language => _language;
  bool get isDarkMode => _isDarkMode;
  String get firstName => _firstName;
  String get lastName => _lastName;
  String get userId => _userId;
  String get userRole => _userRole;
  String get displayName {
    final parts = [firstName.trim(), lastName.trim()].where((p) => p.isNotEmpty).toList();
    return parts.isEmpty ? 'Doctor' : parts.join(' ');
  }

  void setUserRole(String role) {
    _userRole = role;
    notifyListeners();
  }

  void setUserId(String value) {
    _userId = value;
    notifyListeners();
  }

  void setLanguage(String lang) {
    _language = lang;
    notifyListeners();
  }

  void setDarkMode(bool isDark) {
    _isDarkMode = isDark;
    notifyListeners();
  }

  void setFirstName(String value) {
    _firstName = value;
    notifyListeners();
  }

  void setLastName(String value) {
    _lastName = value;
    notifyListeners();
  }

  // Localization helper
  String translate(String en, String th) {
    return _language == 'English' ? en : th;
  }
}

final appState = AppState();
