import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/user_model.dart';

class AuthService {
  static String get baseUrl => dotenv.env['BASE_URL'] ?? '';

  // Send OTP to phone number - ✅ FIXED with exists flag
  static Future<Map<String, dynamic>> sendOtp(String phoneNumber) async {
    try {
      final url = '$baseUrl/auth/send-otp';
      print('📤 SEND OTP - URL: $url');
      print('📤 Phone: $phoneNumber');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': phoneNumber}),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: $data');
      
      // ✅ Check if user exists
      if (response.statusCode == 200 && data['success'] == true) {
        // User exists - OTP sent
        return {
          'success': true,
          'exists': true,  // ✅ Add exists flag
          'otpSessionId': data['sessionId'] ?? data['otpSessionId'],
          'isNewUser': data['isNewUser'] ?? false,
          'message': data['message'] ?? 'OTP sent successfully',
        };
      } else if (response.statusCode == 404 && data['exists'] == false) {
        // ✅ User not found - NO OTP sent
        return {
          'success': false,
          'exists': false,  // ✅ Add exists flag
          'message': data['message'] ?? 'No account found with this phone number',
        };
      } else {
        // Other error
        return {
          'success': false,
          'exists': false,
          'message': data['message'] ?? 'Failed to send OTP',
        };
      }
    } catch (e) {
      print('❌ Error in sendOtp: $e');
      return {
        'success': false,
        'exists': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Verify OTP and login/signup
  static Future<Map<String, dynamic>> verifyOtp(String otpSessionId, String otpCode) async {
    try {
      final url = '$baseUrl/auth/verify-otp';
      print('📤 VERIFY OTP - URL: $url');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sessionId': otpSessionId,  // ✅ Use 'sessionId' to match backend
          'otpCode': otpCode,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: $data');
      
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'token': data['token'],
          'user': UserModel.fromJson(data['user']),
          'message': data['message'] ?? 'Verification successful',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Invalid OTP',
        };
      }
    } catch (e) {
      print('❌ Error in verifyOtp: $e');
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

  // ✅ NEW: Send OTP for Signup (allows new users)
  static Future<Map<String, dynamic>> sendSignupOtp(String phoneNumber) async {
    try {
      final url = '$baseUrl/auth/send-signup-otp';
      print('📤 SEND SIGNUP OTP - URL: $url');
      print('📤 Phone: $phoneNumber');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': phoneNumber}),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: $data');
      
      // ✅ Check if user already exists
      if (response.statusCode == 400 && data['exists'] == true && data['isActive'] == true) {
        // User exists and is active - redirect to login
        return {
          'success': false,
          'exists': true,
          'isActive': true,
          'message': data['message'] ?? 'Account already exists. Please login.',
        };
      }
      
      // New user or inactive user - OTP sent
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'exists': false,
          'isActive': false,
          'otpSessionId': data['sessionId'] ?? data['otpSessionId'],
          'isNewUser': data['isNewUser'] ?? true,
          'hasInactiveUser': data['hasInactiveUser'] ?? false,
          'message': data['message'] ?? 'OTP sent successfully',
        };
      } else {
        return {
          'success': false,
          'exists': false,
          'message': data['message'] ?? 'Failed to send OTP',
        };
      }
    } catch (e) {
      print('❌ Error in sendSignupOtp: $e');
      return {
        'success': false,
        'exists': false,
        'message': 'Network error: $e',
      };
    }
  }
}