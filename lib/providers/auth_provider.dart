import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../utils/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  String? _token;
  bool _isLoading = false;

  UserModel? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  AuthProvider() {
    print('🔵 AuthProvider Constructor Called');
    _loadAuthData();
  }

  Future<void> _loadAuthData() async {
    print('🟡 _loadAuthData START');
    _isLoading = true;
    notifyListeners();

    _token = await TokenStorage.getToken();
    print('📦 Token from storage: $_token');
    
    final userMap = await TokenStorage.getUser();
    print('📦 User map from storage: $userMap');
    
    if (userMap != null) {
      try {
        _user = UserModel.fromJson(userMap);
        print('✅ User loaded successfully:');
        print('   - Name: ${_user?.name}');
        print('   - Phone: ${_user?.phoneNumber}');
        print('   - Email: ${_user?.email}');
        print('   - Role: ${_user?.role}');
      } catch (e) {
        print('❌ Error loading user: $e');
      }
    } else {
      print('⚠️ No user data found in storage');
    }

    _isLoading = false;
    notifyListeners();
    print('🟡 _loadAuthData END - isLoggedIn: $isLoggedIn');
  }

  Future<void> loadUserData() async {
    print('🟡 loadUserData START');
    _token = await TokenStorage.getToken();
    final userMap = await TokenStorage.getUser();
    print('📦 User map from storage: $userMap');
    
    if (userMap != null) {
      try {
        _user = UserModel.fromJson(userMap);
        print('✅ User data reloaded: ${_user?.name}, ${_user?.phoneNumber}');
        notifyListeners();
      } catch (e) {
        print('❌ Error loading user data: $e');
      }
    }
  }

// In auth_provider.dart

// ✅ FIXED: sendOtp with proper exists handling
Future<Map<String, dynamic>> sendOtp(String phoneNumber) async {
  print('🔵 sendOtp called for: $phoneNumber');
  _isLoading = true;
  notifyListeners();

  try {
    final result = await AuthService.sendOtp(phoneNumber);
    print('📦 sendOtp raw result: $result');
    
    // ✅ Check if the response has 'exists' flag
    if (result['success'] == true && result['exists'] == true) {
      // User exists - OTP sent successfully
      return {
        'success': true,
        'exists': true,
        'otpSessionId': result['otpSessionId'],
        'isNewUser': result['isNewUser'] ?? false,
        'message': result['message'] ?? 'OTP sent successfully',
      };
    } else if (result['exists'] == false) {
      // ✅ User not found - NO OTP sent
      return {
        'success': false,
        'exists': false,
        'message': result['message'] ?? 'No account found with this phone number',
      };
    } else {
      // Other error
      return {
        'success': false,
        'exists': false,
        'message': result['message'] ?? 'Failed to send OTP',
      };
    }
  } catch (e) {
    print('❌ Error sending OTP: $e');
    return {
      'success': false,
      'exists': false,
      'message': 'Network error. Please try again.',
    };
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

// ✅ NEW: sendSignupOtp for signup screen
Future<Map<String, dynamic>> sendSignupOtp(String phoneNumber) async {
  print('🔵 sendSignupOtp called for: $phoneNumber');
  _isLoading = true;
  notifyListeners();

  try {
    final result = await AuthService.sendSignupOtp(phoneNumber);
    print('📦 sendSignupOtp raw result: $result');
    
    // ✅ If user exists and is active - redirect to login
    if (result['exists'] == true && result['isActive'] == true) {
      return {
        'success': false,
        'exists': true,
        'isActive': true,
        'message': result['message'] ?? 'Account already exists. Please login.',
      };
    }
    
    // New user or inactive user - OTP sent
    if (result['success'] == true) {
      return {
        'success': true,
        'exists': false,
        'isActive': false,
        'otpSessionId': result['otpSessionId'],
        'isNewUser': result['isNewUser'] ?? true,
        'hasInactiveUser': result['hasInactiveUser'] ?? false,
        'message': result['message'] ?? 'OTP sent successfully',
      };
    } else {
      return {
        'success': false,
        'exists': false,
        'message': result['message'] ?? 'Failed to send OTP',
      };
    }
  } catch (e) {
    print('❌ Error sending signup OTP: $e');
    return {
      'success': false,
      'exists': false,
      'message': 'Network error. Please try again.',
    };
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

  Future<Map<String, dynamic>> verifyOtp(String otpSessionId, String otpCode, {String? guestId}) async {
    print('🔵 verifyOtp START');
    print('   - otpSessionId: $otpSessionId');
    print('   - otpCode: $otpCode');
    print('   - guestId: $guestId');
    
    _isLoading = true;
    notifyListeners();

    final result = await AuthService.verifyOtp(otpSessionId, otpCode);
    print('📦 verifyOtp result success: ${result['success']}');
    
    if (result['success'] == true) {
      print('✅ Login successful!');
      print('📦 Token from backend: ${result['token']}');
      print('📦 User from backend: ${result['user']}');
      
      _token = result['token'];
      _user = result['user'];
      
      print('📦 Parsed User object:');
      print('   - Name: ${_user?.name}');
      print('   - Phone: ${_user?.phoneNumber}');
      print('   - Email: ${_user?.email}');
      print('   - Role: ${_user?.role}');
      print('   - ID: ${_user?.id}');
      
final userJsonString = jsonEncode(_user!.toJson());
      print('📦 Saving user JSON: $userJsonString');
      
      await TokenStorage.saveToken(_token!);
      await TokenStorage.saveUser(userJsonString);
      print('✅ Token and user saved to storage');
      
      if (guestId != null && guestId.isNotEmpty) {
        print('🔄 Merging guest cart: $guestId');
        await _mergeGuestCart(guestId);
        notifyListeners();  // ✅ ADD THIS LINE

      }
    } else {
      print('❌ Login failed: ${result['message']}');
    }
    
    _isLoading = false;
    notifyListeners();
    
    return result;
  }

Future<void> _mergeGuestCart(String guestId) async {
  try {
    print('🔄 Merging cart for guestId: $guestId');
    final url = '${ApiService.baseUrl}/cart/merge';
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode({'guestId': guestId}),
    );
    print('📦 Cart merge response: ${response.body}');
    
    final data = jsonDecode(response.body);
    if (data['success'] == true) {
      print('✅ Merge successful! Merged cart has ${data['data']?['totalItems']} items');
    } else {
      print('❌ Merge failed: ${data['message']}');
    }
    
    // ❌ REMOVE THIS LINE - DO NOT DELETE GUEST ID
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.remove('guest_id');
    
    notifyListeners();
    
  } catch (e) {
    print('❌ Error merging cart: $e');
  }
}
Future<void> logout() async {
  print('🔵 logout called');
  if (_token != null) {
    await AuthService.logout(_token!);
  }
  await TokenStorage.clearAuthData();
  _token = null;
  _user = null;
  
  // ✅ Get guestId from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  String guestId = prefs.getString('guest_id') ?? 'guest_${DateTime.now().millisecondsSinceEpoch}';
  
  // ✅ Save guest ID if not exists
  if (prefs.getString('guest_id') == null) {
    await prefs.setString('guest_id', guestId);
  }
  
  notifyListeners();
  print('✅ User logged out, data cleared');
}

  void updateUser(UserModel user) {
    print('🔵 updateUser called');
    _user = user;
    notifyListeners();
  }
}