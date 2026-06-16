import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CartProvider extends ChangeNotifier {
  int _cartCount = 0;
  String _guestId = '';
  String? _token;
  bool _isLoggedIn = false;
  Set<String> _cartProductIds = {};

  int get cartCount => _cartCount;
  Set<String> get cartProductIds => _cartProductIds;
  String get guestId => _guestId;

  void initialize({required String guestId, String? token, bool isLoggedIn = false}) {
    _guestId = guestId;
    _token = token;
    _isLoggedIn = isLoggedIn;
  }

  // ✅ ADD THIS METHOD
  void resetToGuest(String guestId) {
    _guestId = guestId;
    _token = null;
    _isLoggedIn = false;
    refreshCartCount();
  }

  Future<void> refreshCartCount() async {
    try {
      String? guestIdToUse = _isLoggedIn ? null : _guestId;
      String? tokenToUse = _isLoggedIn ? _token : null;
      
      final response = await ApiService.getCart(guestId: guestIdToUse, token: tokenToUse);
      
      if (response['success'] == true) {
        _cartCount = response['data']?['totalItems'] ?? 0;
        
        final items = response['data']?['items'] ?? [];
        final Set<String> productIds = {};
        for (var item in items) {
          if (item['product'] != null) {
            if (item['product'] is Map) {
              productIds.add(item['product']['_id'].toString());
            } else {
              productIds.add(item['product'].toString());
            }
          }
        }
        _cartProductIds = productIds;
      }
      
      notifyListeners();
      
    } catch (e) {
      print('Error refreshing cart: $e');
      notifyListeners();
    }
  }

  Future<void> addToCart(dynamic product, {required String guestId, String? token, bool isLoggedIn = false}) async {
    try {
      String? guestIdToUse = isLoggedIn ? null : guestId;
      String? tokenToUse = isLoggedIn ? token : null;
      
      String variantId = '';
      if (product['variants'] != null && product['variants'].isNotEmpty) {
        variantId = product['variants'][0]['_id'] ?? '';
      }
      
      final response = await ApiService.addToCart(
        product['_id'], 
        1, 
        variantId,
        guestId: guestIdToUse,
        token: tokenToUse,
      );
      
      if (response['success'] == true) {
        await refreshCartCount();
      }
    } catch (e) {
      print('Error adding to cart: $e');
      rethrow;
    }
  }

  void updateAuthState({String? token, bool isLoggedIn = false}) {
    _token = token;
    _isLoggedIn = isLoggedIn;
    refreshCartCount();
  }
  
  void setGuestId(String guestId) {
    _guestId = guestId;
  }
}