import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CartProvider extends ChangeNotifier {
  int _cartCount = 0;

  String _guestId = '';

  String? _token;

  bool _isLoggedIn = false;

  Set<String> _cartProductIds = {};

  // ─────────────────────────────────────────────
  // GETTERS
  // ─────────────────────────────────────────────

  int get cartCount => _cartCount;

  Set<String> get cartProductIds => _cartProductIds;

  String get guestId => _guestId;

  bool get isLoggedIn => _isLoggedIn;

  String? get token => _token;

  // ─────────────────────────────────────────────
  // INITIALIZE
  // ─────────────────────────────────────────────

  void initialize({
    required String guestId,
    String? token,
    bool isLoggedIn = false,
  }) {
    _guestId = guestId;
    _token = token;
    _isLoggedIn = isLoggedIn;
  }

  // ─────────────────────────────────────────────
  // RESET TO GUEST
  // ─────────────────────────────────────────────

  void resetToGuest(String guestId) {
    _guestId = guestId;
    _token = null;
    _isLoggedIn = false;

    // Clear previous logged-in cart state
    _cartCount = 0;
    _cartProductIds = {};

    notifyListeners();

    refreshCartCount();
  }

  // ─────────────────────────────────────────────
  // UPDATE AUTH STATE
  // ─────────────────────────────────────────────

  Future<void> updateAuthState({
    String? token,
    bool isLoggedIn = false,
  }) async {
    print('🛒 CartProvider: updateAuthState');
    print('🛒 isLoggedIn: $isLoggedIn');
    print('🛒 token exists: ${token != null && token.isNotEmpty}');

    _token = token;
    _isLoggedIn = isLoggedIn;

    // IMPORTANT:
    // Remove old guest cart count immediately.
    // Otherwise bottom navbar can continue showing
    // the old guest cart count after login.
    _cartCount = 0;
    _cartProductIds = {};

    notifyListeners();

    // Now load the cart belonging to the new auth state.
    await refreshCartCount();
  }

  // ─────────────────────────────────────────────
  // ADD ITEM LOCALLY
  // ─────────────────────────────────────────────

  void addItemLocally(dynamic product) {
    final productId = product['_id']?.toString();

    if (productId == null) return;

    if (!_cartProductIds.contains(productId)) {
      _cartProductIds.add(productId);
      _cartCount++;

      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // REMOVE ITEM LOCALLY
  // ─────────────────────────────────────────────

  void removeItemLocally(dynamic product) {
    final productId = product['_id']?.toString();

    if (productId == null) return;

    if (_cartProductIds.contains(productId)) {
      _cartProductIds.remove(productId);

      _cartCount--;

      if (_cartCount < 0) {
        _cartCount = 0;
      }

      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // REFRESH CART COUNT
  // ─────────────────────────────────────────────

  Future<void> refreshCartCount() async {
    try {
      print('🛒 refreshCartCount START');
      print('🛒 logged in: $_isLoggedIn');
      print('🛒 token exists: ${_token != null && _token!.isNotEmpty}');
      print('🛒 guestId: $_guestId');

      final String? guestIdToUse =
          _isLoggedIn ? null : _guestId;

      final String? tokenToUse =
          _isLoggedIn ? _token : null;

      print(
        '🛒 Using ${_isLoggedIn ? 'user' : 'guest'} cart',
      );

      final response = await ApiService.getCart(
        guestId: guestIdToUse,
        token: tokenToUse,
      );

      print('🛒 Cart response: $response');

      if (response['success'] == true) {
        final data = response['data'];

        // Get total items
        _cartCount = data?['totalItems'] ?? 0;

        // Get cart items
        final items = data?['items'] ?? [];

        final Set<String> productIds = {};

        for (final item in items) {
          if (item['product'] != null) {
            if (item['product'] is Map) {
              final productId = item['product']['_id'];

              if (productId != null) {
                productIds.add(
                  productId.toString(),
                );
              }
            } else {
              productIds.add(
                item['product'].toString(),
              );
            }
          }
        }

        _cartProductIds = productIds;

        print('🛒 Cart count updated: $_cartCount');
        print(
          '🛒 Cart product IDs: $_cartProductIds',
        );
      } else {
        // If API says no cart / unsuccessful response,
        // treat it as empty.
        _cartCount = 0;
        _cartProductIds = {};

        print('🛒 Cart empty or unsuccessful response');
      }

      notifyListeners();

      print('🛒 refreshCartCount END');
    } catch (e) {
      print('❌ Error refreshing cart: $e');

      // Keep UI consistent if cart request fails.
      _cartCount = 0;
      _cartProductIds = {};

      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // ADD TO CART
  // ─────────────────────────────────────────────

  Future<void> addToCart(
    dynamic product, {
    required String guestId,
    String? token,
    bool isLoggedIn = false,
    int quantity = 1,
  }) async {
    try {
      final String? guestIdToUse =
          isLoggedIn ? null : guestId;

      final String? tokenToUse =
          isLoggedIn ? token : null;

      String variantId = '';

      if (product['variants'] != null &&
          product['variants'].isNotEmpty) {
        variantId =
            product['variants'][0]['_id'] ?? '';
      }

      final response = await ApiService.addToCart(
        product['_id'],
        quantity,
        variantId,
        guestId: guestIdToUse,
        token: tokenToUse,
      );

      if (response['success'] == true) {
        // Refresh from backend so navbar and cart
        // always use the same source of truth.
        await refreshCartCount();
      }
    } catch (e) {
      print('❌ Error adding to cart: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // UPDATE CART COUNT MANUALLY
  // ─────────────────────────────────────────────

  void updateCartCount(int newCount) {
    _cartCount = newCount;

    if (newCount == 0) {
      _cartProductIds = {};
    }

    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // SET GUEST ID
  // ─────────────────────────────────────────────

  void setGuestId(String guestId) {
    _guestId = guestId;
  }
}