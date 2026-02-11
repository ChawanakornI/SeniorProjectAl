import 'dart:convert';
import 'dart:developer';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../features/case/api_config.dart';

/// User information from login response.
class UserInfo {
  final String userId;
  final String firstName;
  final String lastName;
  final String role;

  UserInfo({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.role,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      userId: json['user_id'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      role: json['role'] ?? '',
    );
  }
}

/// Login response containing token and user info.
class LoginResponse {
  final String accessToken;
  final String tokenType;
  final UserInfo user;

  LoginResponse({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['access_token'] ?? '',
      tokenType: json['token_type'] ?? 'bearer',
      user: UserInfo.fromJson(json['user'] ?? {}),
    );
  }
}

/// Authentication service for handling login, logout, and token management.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const _tokenKey = 'access_token';
  static const _userKey = 'user_info';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  String? _cachedToken;
  UserInfo? _cachedUser;

  /// Login with username and password.
  /// Returns LoginResponse on success, throws exception on failure.
  Future<LoginResponse> login(String username, String password) async {
    final uri = ApiConfig.authLoginUri;
    log('[AuthService] Logging in to $uri', name: 'AuthService');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final loginResponse = LoginResponse.fromJson(data);

        // Store token and user info securely
        await _storage.write(key: _tokenKey, value: loginResponse.accessToken);
        await _storage.write(key: _userKey, value: jsonEncode(data['user']));

        // Cache in memory
        _cachedToken = loginResponse.accessToken;
        _cachedUser = loginResponse.user;

        log('[AuthService] Login successful for ${loginResponse.user.userId}',
            name: 'AuthService');
        return loginResponse;
      } else if (response.statusCode == 401) {
        throw Exception('Invalid username or password');
      } else {
        log('[AuthService] Login failed: ${response.statusCode} ${response.body}',
            name: 'AuthService');
        throw Exception('Login failed: ${response.statusCode}');
      }
    } catch (e) {
      log('[AuthService] Login error: $e', name: 'AuthService');
      rethrow;
    }
  }

  /// Get the stored access token.
  Future<String?> getToken() async {
    if (_cachedToken != null) {
      return _cachedToken;
    }
    _cachedToken = await _storage.read(key: _tokenKey);
    return _cachedToken;
  }

  /// Get the stored user info.
  Future<UserInfo?> getUser() async {
    if (_cachedUser != null) {
      return _cachedUser;
    }
    final userJson = await _storage.read(key: _userKey);
    if (userJson != null) {
      try {
        _cachedUser = UserInfo.fromJson(jsonDecode(userJson));
        return _cachedUser;
      } catch (e) {
        log('[AuthService] Failed to parse user info: $e', name: 'AuthService');
      }
    }
    return null;
  }

  /// Check if user is logged in (has a valid token).
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Logout - clear stored token and user info.
  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    _cachedToken = null;
    _cachedUser = null;
    log('[AuthService] Logged out', name: 'AuthService');
  }

  /// Clear cached data (useful when app restarts).
  void clearCache() {
    _cachedToken = null;
    _cachedUser = null;
  }
}
