import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../widgets/product_card.dart';
import '../widgets/header_section.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/cart_drawer.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import 'auth/signup_screen.dart';
import 'profile/profile_screen.dart';

class CategoryProductsScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const CategoryProductsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  List<dynamic> _products = [];
  bool _isLoading = true;
  String? _error;
  String _guestId = '';
  int _currentIndex = 0;
  bool _isInitialized = false;

  late CartProvider _cartProvider;
  late AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _loadGuestId();
    _loadProducts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cartProvider = Provider.of<CartProvider>(context, listen: false);
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (_guestId.isNotEmpty && !_isInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _cartProvider.initialize(
          guestId: _guestId,
          token: _authProvider.isLoggedIn ? _authProvider.token : null,
          isLoggedIn: _authProvider.isLoggedIn,
        );
        _cartProvider.refreshCartCount();
        _isInitialized = true;
      });
    }
  }

  Future<void> _loadGuestId() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedGuestId = prefs.getString('guest_id');
    
    if (savedGuestId == null) {
      savedGuestId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('guest_id', savedGuestId);
    }
    
    setState(() {
      _guestId = savedGuestId!;
    });
  }

  Future<void> _loadProducts() async {
    try {
      final response = await ApiService.getProducts(
        category: widget.categoryId,
      );
      setState(() {
        _products = response['products'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addToCart(dynamic product) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('buy_now_order');
      await prefs.remove('pending_checkout');
      
      await _cartProvider.addToCart(
        product,
        guestId: _guestId,
        token: _authProvider.isLoggedIn ? _authProvider.token : null,
        isLoggedIn: _authProvider.isLoggedIn,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product['name']} added to cart'),
          duration: const Duration(seconds: 1),
          backgroundColor: const Color(0xFF9B0F06),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add to cart'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openCart() {
    String? guestIdToUse = _authProvider.isLoggedIn ? null : _guestId;
    String? tokenToUse = _authProvider.isLoggedIn ? _authProvider.token : null;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartScreen(
          guestId: guestIdToUse,
          token: tokenToUse,
          onCartUpdate: () {
            _cartProvider.refreshCartCount();
          },
        ),
      ),
    );
  }

  void _showAuthDialog() {
    if (_authProvider.isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfileScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SignupScreen()),
      );
    }
  }

  void _navigateToHome() {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _onSearchSubmit() {}
  void _onSearchQueryChanged(String query) {}

  @override
  Widget build(BuildContext context) {
    final cartCount = Provider.of<CartProvider>(context).cartCount;
    final cartProductIds = Provider.of<CartProvider>(context).cartProductIds;
    
    // ✅ Responsive grid configuration
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount;
    double childAspectRatio;
    
    if (screenWidth < 400) {
      crossAxisCount = 2;
      childAspectRatio = 0.65;
    } else if (screenWidth < 600) {
      crossAxisCount = 2;
      childAspectRatio = 0.70;
    } else if (screenWidth < 900) {
      crossAxisCount = 3;
      childAspectRatio = 0.75;
    } else {
      crossAxisCount = 4;
      childAspectRatio = 0.80;
    }
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          HeaderSection(
            cartCount: cartCount,
            onCartTap: _openCart,
            onSearchSubmit: _onSearchSubmit,
            onSearchQueryChanged: _onSearchQueryChanged,
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF5E0006),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.categoryName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Error: $_error'))
                    : _products.isEmpty
                        ? const Center(child: Text('No products found'))
                        : GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              childAspectRatio: childAspectRatio,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: _products.length,
                            itemBuilder: (context, index) {
                              final product = _products[index];
                              
                              return ProductCard(
                                product: product,
                                onAddToCart: () => _addToCart(product),
                                guestId: _guestId,
                                token: _authProvider.isLoggedIn ? _authProvider.token : null,
                                onCartUpdate: () {
                                  _cartProvider.refreshCartCount();
                                },
                                cartProductIds: cartProductIds,
                              );
                            },
                          ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        cartCount: cartCount,
        onTap: (index) {
          if (index == 0) {
            _navigateToHome();
          } else if (index == 1) {
            _openCart();
          } else if (index == 2) {
            _showAuthDialog();
          }
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}