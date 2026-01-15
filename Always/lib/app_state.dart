import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class AppState extends ChangeNotifier {
  String _language = 'English';
  bool _isDarkMode = false;
  String _firstName = '';
  String _lastName = '';
  String _userId = '';
  String _userRole = ''; // 'gp', 'doctor', etc.
  String? _profileImagePath;
  String? _accessToken; // JWT access token

  String get language => _language;
  bool get isDarkMode => _isDarkMode;
  String get firstName => _firstName;
  String get lastName => _lastName;
  String get userId => _userId;
  String get userRole => _userRole;
  String? get profileImagePath => _profileImagePath;
  String? get accessToken => _accessToken;
  File? get profileImageFile => _profileImagePath != null ? File(_profileImagePath!) : null;
  String get displayName {
    final parts = [firstName.trim(), lastName.trim()].where((p) => p.isNotEmpty).toList();
    return parts.isEmpty ? 'Doctor' : parts.join(' ');
  }

  // Helper to get user-specific preference key
  String _userKey(String key) => '${_userId}_$key';

  void setUserRole(String role) {
    _userRole = role;
    notifyListeners();
  }

  void setUserId(String value) {
    _userId = value;
    notifyListeners();
  }

  void setAccessToken(String? token) {
    _accessToken = token;
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

  /// Clear current user session data (call before switching users)
  void clearUserSession() {
    _firstName = '';
    _lastName = '';
    _userId = '';
    _userRole = '';
    _profileImagePath = null;
    _accessToken = null;
    notifyListeners();
  }

  /// Load user-specific persisted data (call after setting userId)
  Future<void> loadUserData() async {
    if (_userId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    // Load user-specific profile image path
    final savedPath = prefs.getString(_userKey('profile_image_path'));
    if (savedPath != null && File(savedPath).existsSync()) {
      _profileImagePath = savedPath;
    } else {
      _profileImagePath = null;
    }

    // Load user-specific names (these override CSV values if user edited them)
    final savedFirstName = prefs.getString(_userKey('first_name'));
    if (savedFirstName != null) {
      _firstName = savedFirstName;
    }

    final savedLastName = prefs.getString(_userKey('last_name'));
    if (savedLastName != null) {
      _lastName = savedLastName;
    }

    notifyListeners();
  }

  /// Initialize and load persisted data (legacy - loads global settings only)
  Future<void> loadPersistedData() async {
    // Load global settings like language and theme if needed
    // User-specific data is now loaded via loadUserData()
  }

  /// Save profile image and persist the path (user-specific)
  Future<void> setProfileImage(File imageFile) async {
    if (_userId.isEmpty) {
      debugPrint('Error: Cannot save profile image without userId');
      return;
    }

    try {
      // Get app documents directory with user-specific subdirectory
      final appDir = await getApplicationDocumentsDirectory();
      final profileDir = Directory('${appDir.path}/profile/$_userId');

      // Create user-specific profile directory if it doesn't exist
      if (!profileDir.existsSync()) {
        profileDir.createSync(recursive: true);
      }

      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last;
      final newPath = '${profileDir.path}/profile_$timestamp.$extension';

      // Delete old profile image if exists
      if (_profileImagePath != null) {
        final oldFile = File(_profileImagePath!);
        if (oldFile.existsSync()) {
          oldFile.deleteSync();
        }
      }

      // Copy image to app documents
      final savedFile = await imageFile.copy(newPath);

      // Update state and persist path with user-specific key
      _profileImagePath = savedFile.path;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey('profile_image_path'), savedFile.path);

      notifyListeners();
    } catch (e) {
      debugPrint('Error saving profile image: $e');
      rethrow;
    }
  }

  /// Delete profile image (user-specific)
  Future<void> deleteProfileImage() async {
    if (_profileImagePath == null) return;
    if (_userId.isEmpty) return;

    try {
      // Delete the file
      final file = File(_profileImagePath!);
      if (file.existsSync()) {
        file.deleteSync();
      }

      // Clear from state and shared preferences with user-specific key
      _profileImagePath = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey('profile_image_path'));

      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting profile image: $e');
      rethrow;
    }
  }

  /// Persist name changes (user-specific)
  Future<void> persistNames() async {
    if (_userId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey('first_name'), _firstName);
    await prefs.setString(_userKey('last_name'), _lastName);
  }

  // Localization helper
  String translate(String en, String th) {
    return _language == 'English' ? en : th;
  }
}

final appState = AppState();
