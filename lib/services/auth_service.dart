import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/user_model.dart';

class AuthService {
  static String get baseUrl => dotenv.env['BASE_URL'] ?? '';

  // Send OTP to phone number
  static Future<Map<String, dynamic>> sendOtp(String phoneNumber) async {
    try {
      final url = '$baseUrl/auth/send-otp';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': phoneNumber}),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'otpSessionId': data['otpSessionId'],
          'isNewUser': data['isNewUser'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to send OTP',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Verify OTP and login/signup
  static Future<Map<String, dynamic>> verifyOtp(String otpSessionId, String otpCode) async {
    try {
      final url = '$baseUrl/auth/verify-otp';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'otpSessionId': otpSessionId,
          'otpCode': otpCode,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'token': data['token'],
          'user': UserModel.fromJson(data['user']),
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Invalid OTP',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Get current user profile
  static Future<Map<String, dynamic>> getProfile(String token) async {
    try {
      final url = '$baseUrl/auth/profile';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'user': UserModel.fromJson(data['user']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get profile',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Logout
  static Future<Map<String, dynamic>> logout(String token) async {
    try {
      final url = '$baseUrl/auth/logout';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Logged out',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }
}