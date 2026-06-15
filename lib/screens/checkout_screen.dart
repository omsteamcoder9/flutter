import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import 'package:http/http.dart' as http;
import 'order_success_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/cart_drawer.dart';
import 'auth/signup_screen.dart';
import 'profile/profile_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final String? guestId;
  final VoidCallback onOrderPlaced;

  const CheckoutScreen({
    super.key,
    this.guestId,
    required this.onOrderPlaced,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Shipping Address Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController(text: 'Karaikudi');
  final _stateController = TextEditingController(text: 'Tamil Nadu');
  final _postalCodeController = TextEditingController();
  final _countryController = TextEditingController(text: 'India');
  
  String _paymentMethod = 'cod';
  bool _isLoading = false;
  String? _errorMessage;
  
  // Cart data
  Map<String, dynamic> _cart = {'items': [], 'totalItems': 0, 'totalPrice': 0};
  
  // Buy Now state
  Map<String, dynamic>? _buyNowItem;
  bool _isBuyNowMode = false;
  
  int _currentIndex = 1; // Cart tab selected
  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    _checkBuyNowOrder();
    _loadCartData();
    _loadCartCount();
  }

  Future<void> _loadCartCount() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final isLoggedIn = authProvider.isLoggedIn;
      final token = authProvider.token;
      
      final response = await ApiService.getCart(
        guestId: isLoggedIn ? null : widget.guestId,
        token: token,
      );
      
      if (response['success'] == true && mounted) {
        setState(() {
          _cartCount = response['data']?['totalItems'] ?? 0;
        });
      }
    } catch (e) {
      print('Error loading cart count: $e');
    }
  }

  Future<void> _checkBuyNowOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final buyNowJson = prefs.getString('buy_now_order');
    
    if (buyNowJson != null && buyNowJson.isNotEmpty) {
      try {
        final buyNowData = jsonDecode(buyNowJson);
        setState(() {
          _buyNowItem = buyNowData;
          _isBuyNowMode = true;
        });
        print('✅ Buy Now mode detected: ${_buyNowItem?['productName']}');
      } catch (e) {
        print('Error parsing buy now order: $e');
      }
    }
  }

  Future<void> _loadCartData() async {
    if (_isBuyNowMode) return;
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final isLoggedIn = authProvider.isLoggedIn;
      
      final response = await ApiService.getCart(
        guestId: isLoggedIn ? null : widget.guestId,
        token: token,
      );
      
      if (response['success'] == true && mounted) {
        setState(() {
          _cart = response['data'] ?? {'items': [], 'totalItems': 0, 'totalPrice': 0};
        });
      }
    } catch (e) {
      print('Error loading cart: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  double _getSubtotal() {
    if (_isBuyNowMode && _buyNowItem != null) {
      return (_buyNowItem!['price'] ?? 0) * (_buyNowItem!['quantity'] ?? 1);
    }
    return (_cart['totalPrice'] ?? 0).toDouble();
  }

  int _getItemCount() {
    if (_isBuyNowMode && _buyNowItem != null) {
      return _buyNowItem!['quantity'] ?? 1;
    }
    return _cart['totalItems'] ?? 0;
  }

  void _openCart() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    String? guestIdToUse = authProvider.isLoggedIn ? null : widget.guestId;
    String? tokenToUse = authProvider.isLoggedIn ? authProvider.token : null;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartScreen(
          guestId: guestIdToUse,
          token: tokenToUse,
          onCartUpdate: () {
            _loadCartCount();
          },
        ),
      ),
    );
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
        MaterialPageRoute(builder: (context) => SignupScreen()),
      );
    }
  }

  void _navigateToHome() {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    // City validation - Karaikudi only
    final city = _cityController.text.trim().toLowerCase();
    final allowedCities = ['karaikudi', 'karaikudi.', 'karaikudi,', 'karaikudi '];
    bool isDeliverable = allowedCities.any((allowed) => city.contains(allowed));
    
    if (!isDeliverable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('We only deliver to Karaikudi and surrounding areas.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Street validation
    final street = _streetController.text.trim();
    if (street.isEmpty || street.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a complete street address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Phone validation
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit phone number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final isLoggedIn = authProvider.isLoggedIn;

      // Prepare products array based on Buy Now mode
      List<Map<String, dynamic>> products = [];
      
      if (_isBuyNowMode && _buyNowItem != null) {
        // Buy Now mode - Use only the selected product
        products = [
          {
            'product': _buyNowItem!['productId'],
            'variantId': _buyNowItem!['variantId'] ?? '',
            'variantName': _buyNowItem!['variantName'] ?? '',
            'price': _buyNowItem!['price'],
            'quantity': _buyNowItem!['quantity'],
          }
        ];
        print('🛒 Buy Now mode - Ordering 1 product: ${_buyNowItem!['productName']}');
      } else {
        // Normal checkout - Fetch cart items from API
        print('🛒 Normal checkout - Fetching cart items');
        final cartResponse = await ApiService.getCart(
          guestId: widget.guestId,
          token: token,
        );
        
        if (cartResponse['success'] == true && cartResponse['data'] != null) {
          final cartItems = cartResponse['data']['items'] ?? [];
          for (var item in cartItems) {
            String productId;
            if (item['product'] is Map) {
              productId = item['product']['_id'];
            } else {
              productId = item['product'].toString();
            }
            
            products.add({
              'product': productId,
              'variantId': item['variantId'] ?? '',
              'variantName': item['variantName'] ?? '',
              'price': item['price'],
              'quantity': item['quantity'],
            });
          }
        }
      }
      
      if (products.isEmpty) {
        throw Exception('No items to checkout');
      }

      final orderData = {
        'shippingAddress': {
          'name': _nameController.text.trim(),
          'street': _streetController.text.trim(),
          'city': _cityController.text.trim(),
          'state': _stateController.text.trim(),
          'postalCode': _postalCodeController.text.trim(),
          'country': _countryController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
        },
        'paymentMethod': _paymentMethod,
        'products': products,
      };
      
      // Add skipCartClear for Buy Now mode
      if (_isBuyNowMode) {
        orderData['skipCartClear'] = true;
      }

      final url = '${ApiService.baseUrl}/orders';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (isLoggedIn && token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(orderData),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode != 201 || responseData['success'] != true) {
        final errorMsg = responseData['message'] ?? 'Failed to create order';
        
        if (responseData['code'] == 'STREET_NOT_FOUND') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('We could not verify your street address. Please enter a valid street in Karaikudi.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        throw Exception(errorMsg);
      }

      final order = responseData['order'];
      final requiresPayment = responseData['requiresPayment'] ?? false;

      // Clear Buy Now order from SharedPreferences after successful order
      if (_isBuyNowMode) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('buy_now_order');
        await prefs.remove('pending_checkout');
      }

      if (!requiresPayment) {
        // COD order
        print('🔵 Calling widget.onOrderPlaced() for COD order');
        widget.onOrderPlaced();
        print('🔵 widget.onOrderPlaced() completed');
        
        // Force refresh cart count
        final authProviderRefresh = Provider.of<AuthProvider>(context, listen: false);
        if (authProviderRefresh.isLoggedIn) {
          authProviderRefresh.notifyListeners();
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OrderSuccessScreen(
                orderId: order['orderId'],
                orderData: order,
              ),
            ),
          );
        }
      } else {
        // Razorpay payment - open browser
        await _openRazorpayPayment(order);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openRazorpayPayment(dynamic order) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    
    if (token == null) {
      setState(() {
        _errorMessage = 'Please login to continue';
        _isLoading = false;
      });
      return;
    }

    // Open payment page in browser
    final paymentUrl = '${ApiService.baseUrl}/payment-page/${order['orderId']}';
    final uri = Uri.parse(paymentUrl);
    
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    
    if (!launched) {
      setState(() {
        _errorMessage = 'Failed to open payment gateway';
        _isLoading = false;
      });
    } else {
      // Wait for user to complete payment and return
      await _checkPaymentAfterReturn(order['orderId']);
    }
  }

  Future<void> _checkPaymentAfterReturn(String orderId) async {
    print('🔵 _checkPaymentAfterReturn START for order: $orderId');
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    
    await Future.delayed(const Duration(seconds: 3));
    
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }
    
    bool paymentCompleted = false;
    
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(seconds: 2));
      print('🔵 Checking payment status attempt ${i+1}...');
      
      try {
        final response = await http.get(
          Uri.parse('${ApiService.baseUrl}/payments/status/$orderId'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        );
        
        final data = jsonDecode(response.body);
        print('🔵 Payment status response: $data');
        
        if (data['success'] && data['payment']['status'] == 'paid') {
          paymentCompleted = true;
          print('🔵 Payment COMPLETED!');
          break;
        }
      } catch (e) {
        print('🔵 Verification attempt $i failed: $e');
      }
    }
    
    if (mounted) {
      Navigator.pop(context); // Close loading
    }
    
    if (paymentCompleted && mounted) {
      print('🔵 NAVIGATING TO ORDER SUCCESS SCREEN');
      widget.onOrderPlaced();
      
      // Force refresh cart count
      final authProviderRefresh = Provider.of<AuthProvider>(context, listen: false);
      if (authProviderRefresh.isLoggedIn) {
        authProviderRefresh.notifyListeners();
      }
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderSuccessScreen(
            orderId: orderId,
            orderData: {'orderId': orderId},
          ),
        ),
      );
    } else if (mounted) {
      print('🔵 PAYMENT NOT COMPLETED');
      setState(() {
        _errorMessage = 'Payment not completed. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = _getSubtotal();
    final tax = subtotal * 0.05;
    final total = subtotal + tax;
    final itemCount = _getItemCount();
    final cartItems = _cart['items'] as List? ?? [];
    final cartCount = Provider.of<CartProvider>(context).cartCount;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isBuyNowMode ? 'Buy Now' : 'Checkout'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF5E0006),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Buy Now Banner
              if (_isBuyNowMode && _buyNowItem != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9B0F06).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF9B0F06).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flash_on, color: Color(0xFF9B0F06), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '⚡ Buy Now Mode • Checking out: ${_buyNowItem!['productName']}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF5E0006),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Order Summary Section
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5E0006),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    if (_isBuyNowMode && _buyNowItem != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${_buyNowItem!['productName']} x ${_buyNowItem!['quantity']}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Text(
                            '₹${(_buyNowItem!['price'] * _buyNowItem!['quantity']).toInt()}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ],
                      )
                    else if (cartItems.isNotEmpty)
                      Column(
                        children: cartItems.map((item) {
                          final productName = item['productName'] ?? 
                              (item['product'] is Map ? item['product']['name'] : 'Product');
                          final quantity = item['quantity'] ?? 1;
                          final price = (item['price'] ?? 0).toDouble();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '$productName x $quantity',
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '₹${(price * quantity).toInt()}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      )
                    else
                      Text(
                        '${itemCount} item${itemCount != 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal'),
                        Text('₹${subtotal.toInt()}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Shipping'),
                        const Text('FREE', style: TextStyle(color: Color(0xFFD53E0F))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tax (5%)'),
                        Text('₹${tax.toInt()}'),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '₹${total.toInt()}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF9B0F06)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Shipping Address Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shipping Address',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5E0006),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(_nameController, 'Full Name', Icons.person),
                    const SizedBox(height: 12),
                    _buildTextField(_phoneController, 'Phone Number', Icons.phone, keyboardType: TextInputType.phone),
                    const SizedBox(height: 12),
                    _buildTextField(_emailController, 'Email Address', Icons.email, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    _buildTextField(_streetController, 'Street Address', Icons.location_on),
                    const SizedBox(height: 12),
                    _buildTextField(_cityController, 'City', Icons.location_city),
                    const SizedBox(height: 12),
                    _buildTextField(_stateController, 'State', Icons.map),
                    const SizedBox(height: 12),
                    _buildTextField(_postalCodeController, 'Postal Code', Icons.code, keyboardType: TextInputType.number),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Payment Method Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Method',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5E0006),
                      ),
                    ),
                    const SizedBox(height: 12),
                    RadioListTile<String>(
                      title: const Text('Cash on Delivery'),
                      value: 'cod',
                      groupValue: _paymentMethod,
                      onChanged: (value) {
                        setState(() {
                          _paymentMethod = value!;
                        });
                      },
                      activeColor: const Color(0xFFD53E0F),
                    ),
                    RadioListTile<String>(
                      title: const Text('Razorpay (Card/UPI/NetBanking)'),
                      value: 'razorpay',
                      groupValue: _paymentMethod,
                      onChanged: (value) {
                        setState(() {
                          _paymentMethod = value!;
                        });
                      },
                      activeColor: const Color(0xFFD53E0F),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              const SizedBox(height: 24),

              // Place Order Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _placeOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD53E0F),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Place Order',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
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

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFD53E0F)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD53E0F)),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        if (label == 'Email Address' && !value.contains('@')) {
          return 'Enter valid email';
        }
        if (label == 'Phone Number' && value.length < 10) {
          return 'Enter valid phone number';
        }
        return null;
      },
    );
  }
}