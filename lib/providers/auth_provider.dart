import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../utils/token_storage.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  String? _token;
  bool _isLoading = false;

  UserModel? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  AuthProvider() {
    _loadAuthData();
  }

  Future<void> _loadAuthData() async {
    _isLoading = true;
    notifyListeners();

    _token = await TokenStorage.getToken();
    final userJson = await TokenStorage.getUser();
    
    if (userJson != null && userJson.isNotEmpty) {
      try {
        final Map<String, dynamic> userMap = Map<String, dynamic>.from(
          (userJson as Map).cast<String, dynamic>()
        );
        _user = UserModel.fromJson(userMap);
      } catch (e) {
        print('Error loading user: $e');
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadUserData() async {
    _token = await TokenStorage.getToken();
    final userJson = await TokenStorage.getUser();
    
    if (userJson != null && userJson.isNotEmpty) {
      try {
        final Map<String, dynamic> userMap = Map<String, dynamic>.from(
          (userJson as Map).cast<String, dynamic>()
        );
        _user = UserModel.fromJson(userMap);
        notifyListeners();
      } catch (e) {
        print('Error loading user data: $e');
      }
    }
  }

  Future<Map<String, dynamic>> sendOtp(String phoneNumber) async {
    _isLoading = true;
    notifyListeners();

    final result = await AuthService.sendOtp(phoneNumber);
    
    _isLoading = false;
    notifyListeners();
    
    return result;
  }

  Future<Map<String, dynamic>> verifyOtp(String otpSessionId, String otpCode, {String? guestId}) async {
    _isLoading = true;
    notifyListeners();

    final result = await AuthService.verifyOtp(otpSessionId, otpCode);
    
    if (result['success'] == true) {
      _token = result['token'];
      _user = result['user'];
      await TokenStorage.saveToken(_token!);
      await TokenStorage.saveUser(_user!.toJson().toString());
      
      if (guestId != null && guestId.isNotEmpty) {
        await _mergeGuestCart(guestId);
      }
    }
    
    _isLoading = false;
    notifyListeners();
    
    return result;
  }

  Future<void> _mergeGuestCart(String guestId) async {
    try {
      final url = '${ApiService.baseUrl}/cart/merge';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({'guestId': guestId}),
      );
      print('Cart merged: ${response.body}');
    } catch (e) {
      print('Error merging cart: $e');
    }
  }

  Future<void> logout() async {
    if (_token != null) {
      await AuthService.logout(_token!);
    }
    await TokenStorage.clearAuthData();
    _token = null;
    _user = null;
    notifyListeners();
  }

  void updateUser(UserModel user) {
    _user = user;
    notifyListeners();
  }
}