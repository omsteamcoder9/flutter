import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  static Future<void> saveToken(String token) async {
    print('🔵 TokenStorage.saveToken called');
    print('   - Token: $token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    print('✅ Token saved successfully');
  }

  static Future<void> saveUser(String userJson) async {
    print('🔵 TokenStorage.saveUser called');
    print('   - User JSON: $userJson');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, userJson);
    print('✅ User saved successfully');
  }

  static Future<String?> getToken() async {
    print('🔵 TokenStorage.getToken called');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    print('   - Retrieved token: $token');
    return token;
  }

  static Future<Map<String, dynamic>?> getUser() async {
    print('🔵 TokenStorage.getUser called');
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.get(_userKey);
    print('   - Retrieved raw value type: ${value.runtimeType}');
    print('   - Retrieved raw value: $value');
    
    if (value == null) return null;
    
    if (value is Map) {
      print('⚠️ Found Map, converting to Map<String, dynamic>');
      return Map<String, dynamic>.from(value);
    }
    
    if (value is String && value.isNotEmpty) {
      try {
        return jsonDecode(value);
      } catch (e) {
        print('Error parsing JSON: $e');
        return null;
      }
    }
    
    return null;
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    print('🔵 TokenStorage.isLoggedIn: ${token != null && token.isNotEmpty}');
    return token != null && token.isNotEmpty;
  }

  static Future<void> clearAuthData() async {
    print('🔵 TokenStorage.clearAuthData called');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    print('✅ Auth data cleared');
  }
}