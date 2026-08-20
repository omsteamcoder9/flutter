// ========== FILE: lib/widgets/cart_drawer.dart ==========
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../screens/checkout_screen.dart';
import '../screens/auth/signup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/bottom_nav_bar.dart';
import '../screens/profile/profile_screen.dart';
class CartScreen extends StatefulWidget {
  final VoidCallback onCartUpdate;
  final String? guestId;
  final String? token;

  const CartScreen({
    super.key,
    required this.onCartUpdate,
    this.guestId,
    this.token,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Map<String, dynamic> _cart = {'items': [], 'totalItems': 0, 'totalPrice': 0};
  bool _isLoading = true;
  List<String> _removingItems = [];
  int _currentIndex = 1;

  @override
  void initState() {
    super.initState();
    _clearBuyNowOrder();
    _loadCart();
  }

  Future<void> _clearBuyNowOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('buy_now_order');
    await prefs.remove('pending_checkout');
  }

  Future<void> _loadCart() async {
    try {
      final response = await ApiService.getCart(guestId: widget.guestId, token: widget.token);
      setState(() {
        if (response['success'] == true) {
          _cart = response['data'] ?? {'items': [], 'totalItems': 0, 'totalPrice': 0};
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

Future<void> _updateQuantity(String itemId, int quantity) async {
  if (quantity < 1) return;
  
  // ✅ Update UI instantly
  setState(() {
    final itemIndex = _cart['items'].indexWhere((item) => item['_id'] == itemId);
    if (itemIndex != -1) {
      final item = _cart['items'][itemIndex];
      final oldQty = item['quantity'];
      final price = item['price'];
      
      item['quantity'] = quantity;
      _cart['totalItems'] = (_cart['totalItems'] ?? 0) - oldQty + quantity;
      _cart['totalPrice'] = (_cart['totalPrice'] ?? 0) - (price * oldQty) + (price * quantity);
    }
  });
  widget.onCartUpdate();
  
  // ✅ Send API in background
  try {
    await ApiService.updateCartItem(itemId, quantity, guestId: widget.guestId, token: widget.token);
    widget.onCartUpdate();
  } catch (e) {
    _loadCart();
    widget.onCartUpdate();
  }
}
Future<void> _removeItem(String itemId) async {
  // ✅ Update UI instantly
  setState(() {
    _cart['items'] = _cart['items'].where((item) => item['_id'] != itemId).toList();
    _cart['totalItems'] = (_cart['totalItems'] ?? 0) - 1;
  });
  widget.onCartUpdate();
  
  // ✅ Send API in background
  try {
    await ApiService.removeCartItem(itemId, guestId: widget.guestId, token: widget.token);
    widget.onCartUpdate();
  } catch (e) {
    _loadCart();
    widget.onCartUpdate();
  }
}

Future<void> _clearCart() async {
  // ✅ Update UI instantly
  setState(() {
    _cart = {'items': [], 'totalItems': 0, 'totalPrice': 0};
  });
  widget.onCartUpdate();
  
  // ✅ Send API in background
  try {
    await ApiService.clearCart(guestId: widget.guestId, token: widget.token);
    widget.onCartUpdate();
  } catch (e) {
    _loadCart();
    widget.onCartUpdate();
  }
} 
  String _formatPrice(double price) {
    return '₹${price.toStringAsFixed(0)}';
  }

  void _showAuthDialog() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (authProvider.isLoggedIn) {
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

  @override
  Widget build(BuildContext context) {
    final items = _cart['items'] ?? [];
    final itemCount = _cart['totalItems'] ?? 0;
    final subtotal = (_cart['totalPrice'] ?? 0).toDouble();
    final tax = subtotal * 0.05;
    final total = subtotal + tax;
    final cartCount = Provider.of<CartProvider>(context).cartCount;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'My Cart ($itemCount)',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5E0006),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF5E0006)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: _clearCart,
              child: const Text(
                'Clear All',
                style: TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9B0F06)),
              ),
            )
          : items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'Your cart is empty',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add items to get started',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5E0006),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text(
                          'Continue Shopping',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cart Items List
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final itemId = item['_id'];
                          final product = item['product'];
                          final productName = product is Map ? product['name'] : item['productName'];
                          final price = (item['price'] ?? 0).toDouble();
                          final quantity = item['quantity'] ?? 1;
                          final variantName = item['variantName'];
                          final isRemoving = _removingItems.contains(itemId);
                          String imageUrl = '';
                          if (item['productImage'] != null && item['productImage'].isNotEmpty) {
                            imageUrl = '${ApiService.imageBaseUrl}${item['productImage']}';
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade100,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: imageUrl.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Icon(Icons.image, color: Colors.grey.shade400, size: 40),
                                          ),
                                        )
                                      : Icon(Icons.image, color: Colors.grey.shade400, size: 40),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        productName ?? 'Product',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (variantName != null && variantName.isNotEmpty)
                                        Text(
                                          variantName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF5E0006),
                                          ),
                                        ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _formatPrice(price),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Color(0xFF5E0006),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => _updateQuantity(itemId, quantity - 1),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.grey.shade300),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Icon(Icons.remove, size: 18),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          quantity.toString(),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(width: 12),
                                        GestureDetector(
                                          onTap: () => _updateQuantity(itemId, quantity + 1),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.grey.shade300),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Icon(Icons.add, size: 18),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    GestureDetector(
                                      onTap: () => _removeItem(itemId),
                                      child: isRemoving
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Price Summary Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Subtotal', style: TextStyle(fontSize: 15)),
                                Text(_formatPrice(subtotal), style: const TextStyle(fontSize: 15)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Shipping', style: TextStyle(fontSize: 15)),
                                const Text('FREE', style: TextStyle(fontSize: 15, color: Color(0xFFD53E0F), fontWeight: FontWeight.w500)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Tax (5%)', style: TextStyle(fontSize: 15)),
                                Text(_formatPrice(tax), style: const TextStyle(fontSize: 15)),
                              ],
                            ),
                            const Divider(height: 24, thickness: 1),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text(_formatPrice(total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5E0006))),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Proceed to Checkout Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            // ✅ Clear buy now order before proceeding to checkout
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.remove('buy_now_order');
                            await prefs.remove('pending_checkout');
                            
                            final authProvider = Provider.of<AuthProvider>(context, listen: false);
                            
                            if (authProvider.isLoggedIn) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CheckoutScreen(
                                    guestId: null,
                                    onOrderPlaced: widget.onCartUpdate,
                                  ),
                                ),
                              );
                            } else {
                              await prefs.setBool('pending_checkout', true);
                              
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SignupScreen(guestId: widget.guestId),
                                ),
                              );
                              
                              if (authProvider.isLoggedIn) {
                                final hasPendingCheckout = prefs.getBool('pending_checkout') ?? false;
                                if (hasPendingCheckout) {
                                  await prefs.remove('pending_checkout');
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CheckoutScreen(
                                        guestId: null,
                                        onOrderPlaced: widget.onCartUpdate,
                                      ),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5E0006),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Proceed to Checkout',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        cartCount: cartCount,
        onTap: (index) {
          if (index == 0) {
            _navigateToHome();
          } else if (index == 1) {
            // Already on cart screen
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