import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../constants/app_colors.dart';

class AuthProvider with ChangeNotifier {
  String? _token;
  String? _userType;
  final _storage = FlutterSecureStorage();

  String? get token => _token;
  String? get userType => _userType;

  AuthProvider() {
    _loadAuthData();
  }

  Future<void> _loadAuthData() async {
    try {
      _token = await _storage.read(key: 'jwt_token');
      _userType = await _storage.read(key: 'user_type');
      if (_token != null && _userType != null) {
        print('Loaded token: $_token');
        print('Loaded userType: $_userType');
        final isValid = await _validateToken();
        print('Token validation result: $isValid');
        if (!isValid) {
          print('Token invalid, logging out');
          await logout();
        }
      } else {
        print('No token or userType found');
      }
      notifyListeners();
    } catch (e) {
      print('Error loading auth data: $e');
      await logout();
    }
  }

  Future<bool> _validateToken() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/categories'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );
      print('Token validation response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 422) {
        return false; // Token is invalid
      }
      return response.statusCode == 200;
    } catch (e) {
      print('Token validation error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> login(String userType, String identifier, String password) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': identifier,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);
      print('Login response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200 && data['status'] == 'success') {
        _token = data['token'];
        _userType = data['user_type'];
        await _storage.write(key: 'jwt_token', value: _token);
        await _storage.write(key: 'user_type', value: _userType);
        print('Login successful, token: $_token, userType: $_userType');
        notifyListeners();
        return {'status': 'success', 'message': 'Login successful'};
      } else {
        return {'status': 'error', 'message': data['message']};
      }
    } catch (e) {
      print('Login error: $e');
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  Future<void> logout() async {
    print('Logging out');
    _token = null;
    _userType = null;
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_type');
    notifyListeners();
  }
}