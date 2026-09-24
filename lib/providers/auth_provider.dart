import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../utils/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cart_provider.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  String? _token;
  bool _isLoading = false;

  UserModel? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;

  bool get isLoggedIn =>
      _token != null && _token!.isNotEmpty;

  AuthProvider() {
    print('🔵 AuthProvider Constructor Called');
    _loadAuthData();
  }

  // ─────────────────────────────────────────────
  // LOAD AUTH DATA
  // ─────────────────────────────────────────────

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

    print(
      '🟡 _loadAuthData END - isLoggedIn: $isLoggedIn',
    );
  }

  // ─────────────────────────────────────────────
  // LOAD USER DATA
  // ─────────────────────────────────────────────

  Future<void> loadUserData() async {
    print('🟡 loadUserData START');

    _token = await TokenStorage.getToken();

    final userMap = await TokenStorage.getUser();

    print('📦 User map from storage: $userMap');

    if (userMap != null) {
      try {
        _user = UserModel.fromJson(userMap);

        print(
          '✅ User data reloaded: '
          '${_user?.name}, ${_user?.phoneNumber}',
        );

        notifyListeners();
      } catch (e) {
        print('❌ Error loading user data: $e');
      }
    }
  }

  // ─────────────────────────────────────────────
  // SEND LOGIN OTP
  // ─────────────────────────────────────────────

  Future<Map<String, dynamic>> sendOtp(
    String phoneNumber,
  ) async {
    print('🔵 sendOtp called for: $phoneNumber');

    _isLoading = true;
    notifyListeners();

    try {
      final result =
          await AuthService.sendOtp(phoneNumber);

      print('📦 sendOtp raw result: $result');

      if (result['success'] == true &&
          result['exists'] == true) {
        return {
          'success': true,
          'exists': true,
          'otpSessionId': result['otpSessionId'],
          'isNewUser':
              result['isNewUser'] ?? false,
          'message':
              result['message'] ??
                  'OTP sent successfully',
        };
      } else if (result['exists'] == false) {
        return {
          'success': false,
          'exists': false,
          'message':
              result['message'] ??
                  'No account found with this phone number',
        };
      } else {
        return {
          'success': false,
          'exists': false,
          'message':
              result['message'] ??
                  'Failed to send OTP',
        };
      }
    } catch (e) {
      print('❌ Error sending OTP: $e');

      return {
        'success': false,
        'exists': false,
        'message':
            'Network error. Please try again.',
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // SEND SIGNUP OTP
  // ─────────────────────────────────────────────

  Future<Map<String, dynamic>> sendSignupOtp(
    String phoneNumber,
  ) async {
    print(
      '🔵 sendSignupOtp called for: $phoneNumber',
    );

    _isLoading = true;
    notifyListeners();

    try {
      final result =
          await AuthService.sendSignupOtp(phoneNumber);

      print(
        '📦 sendSignupOtp raw result: $result',
      );

      // Existing active user
      if (result['exists'] == true &&
          result['isActive'] == true) {
        return {
          'success': false,
          'exists': true,
          'isActive': true,
          'message':
              result['message'] ??
                  'Account already exists. Please login.',
        };
      }

      // New user / inactive user
      if (result['success'] == true) {
        return {
          'success': true,
          'exists': false,
          'isActive': false,
          'otpSessionId':
              result['otpSessionId'],
          'isNewUser':
              result['isNewUser'] ?? true,
          'hasInactiveUser':
              result['hasInactiveUser'] ?? false,
          'message':
              result['message'] ??
                  'OTP sent successfully',
        };
      }

      return {
        'success': false,
        'exists': false,
        'message':
            result['message'] ??
                'Failed to send OTP',
      };
    } catch (e) {
      print(
        '❌ Error sending signup OTP: $e',
      );

      return {
        'success': false,
        'exists': false,
        'message':
            'Network error. Please try again.',
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // VERIFY OTP
  // ─────────────────────────────────────────────

  Future<Map<String, dynamic>> verifyOtp(
    String otpSessionId,
    String otpCode, {
    String? guestId,
    BuildContext? context,
  }) async {
    print('🔵 verifyOtp START');

    print(
      '   - otpSessionId: $otpSessionId',
    );

    print(
      '   - otpCode: $otpCode',
    );

    print(
      '   - guestId: $guestId',
    );

    _isLoading = true;
    notifyListeners();

    try {
      final result =
          await AuthService.verifyOtp(
        otpSessionId,
        otpCode,
      );

      print(
        '📦 verifyOtp result success: '
        '${result['success']}',
      );

      if (result['success'] == true) {
        print('✅ Login successful!');

        print(
          '📦 Token from backend: '
          '${result['token']}',
        );

        print(
          '📦 User from backend: '
          '${result['user']}',
        );

        // ─────────────────────────────────────
        // SAVE NEW AUTH STATE
        // ─────────────────────────────────────

        _token = result['token'];

        _user = result['user'];

        print('📦 Parsed User object:');

        print(
          '   - Name: ${_user?.name}',
        );

        print(
          '   - Phone: ${_user?.phoneNumber}',
        );

        print(
          '   - Email: ${_user?.email}',
        );

        print(
          '   - Role: ${_user?.role}',
        );

        print(
          '   - ID: ${_user?.id}',
        );

        final userJsonString =
            jsonEncode(_user!.toJson());

        print(
          '📦 Saving user JSON: '
          '$userJsonString',
        );

        await TokenStorage.saveToken(
          _token!,
        );

        await TokenStorage.saveUser(
          userJsonString,
        );

        print(
          '✅ Token and user saved to storage',
        );

        // ─────────────────────────────────────
        // MERGE GUEST CART
        // ─────────────────────────────────────

        if (guestId != null &&
            guestId.isNotEmpty) {
          print(
            '🔄 Merging guest cart: $guestId',
          );

          await _mergeGuestCart(guestId);
        }

        // ─────────────────────────────────────
        // IMPORTANT:
        // SWITCH CART PROVIDER FROM GUEST
        // TO LOGGED-IN USER
        // ─────────────────────────────────────

        if (context != null &&
            context.mounted) {
          try {
            final cartProvider =
                Provider.of<CartProvider>(
              context,
              listen: false,
            );

            print(
              '🛒 Updating CartProvider after login',
            );

            await cartProvider.updateAuthState(
              token: _token,
              isLoggedIn: true,
            );

            print(
              '✅ CartProvider updated successfully',
            );
          } catch (e) {
            print(
              '❌ CartProvider update error: $e',
            );
          }
        }

        print(
          '✅ Login + cart synchronization complete',
        );
      } else {
        print(
          '❌ Login failed: '
          '${result['message']}',
        );
      }

      return result;
    } catch (e) {
      print(
        '❌ verifyOtp exception: $e',
      );

      return {
        'success': false,
        'message':
            'OTP verification failed. Please try again.',
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // MERGE GUEST CART
  // ─────────────────────────────────────────────

  Future<void> _mergeGuestCart(
    String guestId,
  ) async {
    try {
      print(
        '🔄 Merging cart for guestId: $guestId',
      );

      final url =
          '${ApiService.baseUrl}/cart/merge';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type':
              'application/json',
          'Authorization':
              'Bearer $_token',
        },
        body: jsonEncode({
          'guestId': guestId,
        }),
      );

      print(
        '📦 Cart merge response: '
        '${response.body}',
      );

      final data =
          jsonDecode(response.body);

      if (data['success'] == true) {
        print(
          '✅ Merge successful! '
          'Merged cart has '
          '${data['data']?['totalItems']} items',
        );
      } else {
        print(
          '❌ Merge failed: '
          '${data['message']}',
        );
      }

      // IMPORTANT:
      // Do NOT remove guest_id here.
      //
      // The guest ID can still be needed by
      // the application after logout.
    } catch (e) {
      print(
        '❌ Error merging cart: $e',
      );
    }
  }

  // ─────────────────────────────────────────────
  // LOGOUT
  // ─────────────────────────────────────────────

  Future<void> logout({
    BuildContext? context,
  }) async {
    print('🔵 logout called');

    if (_token != null) {
      await AuthService.logout(
        _token!,
      );
    }

    await TokenStorage.clearAuthData();

    _token = null;
    _user = null;

    // ─────────────────────────────────────
    // GET / CREATE GUEST ID
    // ─────────────────────────────────────

    final prefs =
        await SharedPreferences.getInstance();

    String guestId =
        prefs.getString('guest_id') ??
            'guest_${DateTime.now().millisecondsSinceEpoch}';

    if (prefs.getString('guest_id') == null) {
      await prefs.setString(
        'guest_id',
        guestId,
      );
    }

    // ─────────────────────────────────────
    // SWITCH CART PROVIDER BACK TO GUEST
    // ─────────────────────────────────────

    if (context != null &&
        context.mounted) {
      try {
        final cartProvider =
            Provider.of<CartProvider>(
          context,
          listen: false,
        );

        await cartProvider.updateAuthState(
          token: null,
          isLoggedIn: false,
        );

        cartProvider.setGuestId(
          guestId,
        );

        print(
          '✅ CartProvider switched to guest',
        );
      } catch (e) {
        print(
          '❌ CartProvider logout update error: $e',
        );
      }
    }

    notifyListeners();

    print(
      '✅ User logged out, data cleared',
    );
  }

  // ─────────────────────────────────────────────
  // UPDATE USER
  // ─────────────────────────────────────────────

  void updateUser(UserModel user) {
    print('🔵 updateUser called');

    _user = user;

    notifyListeners();
  }
}