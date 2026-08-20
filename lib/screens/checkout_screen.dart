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
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../models/order.dart';
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
  
  Map<String, dynamic> _cart = {'items': [], 'totalItems': 0, 'totalPrice': 0};
  Map<String, dynamic>? _buyNowItem;
  bool _isBuyNowMode = false;
  
  int _currentIndex = 1;
  int _cartCount = 0;

  List<Map<String, dynamic>> _wards = [];
  int? _selectedWardId;
  List<String> _streetsForSelectedWard = [];
  String? _selectedStreet;
  bool _loadingWards = false;

  Razorpay? _razorpay;

  @override
  void initState() {
    super.initState();
    _checkBuyNowOrder();
    _loadCartData();
    _loadCartCount();
    _loadWards();
    
    _initializeRazorpay();
  }

void _initializeRazorpay() {
  _razorpay = Razorpay();

  _razorpay?.on(
    Razorpay.EVENT_PAYMENT_SUCCESS,
    _handlePaymentSuccess,
  );

  _razorpay?.on(
    Razorpay.EVENT_PAYMENT_ERROR,
    _handlePaymentError,
  );

  _razorpay?.on(
    Razorpay.EVENT_EXTERNAL_WALLET,
    _handleExternalWallet,
  );

  print('✅ Razorpay initialized successfully');
}

Future<void> _handlePaymentSuccess(
  PaymentSuccessResponse response,
) async {
  print('========================================');
  print('✅ RAZORPAY PAYMENT SUCCESS');
  print('========================================');
  print('Payment ID : ${response.paymentId}');
  print('Razorpay Order ID : ${response.orderId}');
  print('Signature : ${response.signature}');
  print('========================================');

  if (response.paymentId == null ||
      response.paymentId!.isEmpty ||
      response.orderId == null ||
      response.orderId!.isEmpty ||
      response.signature == null ||
      response.signature!.isEmpty) {
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _errorMessage =
          'Payment completed, but payment verification details are missing.';
    });

    return;
  }

  try {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final prefs = await SharedPreferences.getInstance();

    // This is YOUR Mongo/custom order ID.
    final mongoOrderId =
        prefs.getString('razorpay_order_id');

    if (mongoOrderId == null || mongoOrderId.isEmpty) {
      throw Exception(
        'Order ID was not found after successful payment.',
      );
    }

    print('Mongo Order ID: $mongoOrderId');

    // ============================================================
    // IMPORTANT:
    // DO NOT call widget.onOrderPlaced() here.
    // DO NOT navigate Home here.
    // DO NOT wait 10 seconds for webhook.
    // ============================================================

    // The Razorpay plugin has already reported a successful payment.
    // Give the backend/webhook a short amount of time to update MongoDB.
    //
    // We retry a few times instead of doing one request that can
    // timeout and send the user away from the success screen.
    Order? fullOrder;

    const maxAttempts = 5;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        print(
          '🔍 Checking confirmed order '
          '($attempt/$maxAttempts)...',
        );

        final result =
            await ApiService.getOrderById(mongoOrderId);

        if (result != null) {
          final paymentStatus =
              result.paymentStatus.toLowerCase();

          final orderStatus =
              result.orderStatus.toLowerCase();

          print(
            'Payment Status: $paymentStatus',
          );

          print(
            'Order Status: $orderStatus',
          );

          fullOrder = result;

          // Backend/webhook has confirmed the payment.
          if (paymentStatus == 'paid' ||
              paymentStatus == 'completed' ||
              paymentStatus == 'captured' ||
              orderStatus == 'confirmed') {
            print('✅ ORDER PAYMENT CONFIRMED');
            break;
          }
        }
      } catch (e) {
        print(
          '⚠️ Order status check failed: $e',
        );
      }

      if (attempt < maxAttempts) {
        await Future.delayed(
          const Duration(seconds: 1),
        );
      }
    }

    // ============================================================
    // If webhook/API has not updated yet, we still know Razorpay
    // reported success. Fetch the order one final time if possible.
    // ============================================================

    if (fullOrder == null) {
      try {
        fullOrder =
            await ApiService.getOrderById(mongoOrderId);
      } catch (e) {
        print(
          '⚠️ Final order fetch failed: $e',
        );
      }
    }

    if (fullOrder == null) {
      throw Exception(
        'Payment was successful, but the order could not be loaded.',
      );
    }

    print('========================================');
    print('🎉 FINAL ORDER');
    print('Order ID: ${fullOrder.orderId}');
    print('Payment Status: ${fullOrder.paymentStatus}');
    print('Order Status: ${fullOrder.orderStatus}');
    print('========================================');

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    // ============================================================
    // OPEN SUCCESS SCREEN
    // ============================================================

    print('🚀 Opening Order Success Screen...');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => OrderSuccessScreen(
          orderId: fullOrder!.orderId,
          orderData: fullOrder,
        ),
      ),
    );

    // ============================================================
    // IMPORTANT:
    // DO NOT call widget.onOrderPlaced() before navigation.
    //
    // If your parent needs refreshing, do it after the success
    // screen, not before it.
    // ============================================================
  } catch (e, stackTrace) {
    print('========================================');
    print('❌ PAYMENT SUCCESS HANDLING ERROR');
    print('========================================');
    print('Error: $e');
    print('StackTrace: $stackTrace');
    print('========================================');

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _errorMessage =
          'Payment was successful, but we could not load your order. '
          'Please check My Orders.';
    });
  }
}

void _handlePaymentError(
  PaymentFailureResponse response,
) {
  print('');
  print('========================================');
  print('❌ RAZORPAY PAYMENT ERROR');
  print('========================================');
  print('Code    : ${response.code}');
  print('Message : ${response.message}');
  print('========================================');

  if (mounted) {
    setState(() {
      _isLoading = false;
      _errorMessage =
          response.message?.toString() ??
          'Payment failed. Please try again.';
    });
  }
}

void _handleExternalWallet(
  ExternalWalletResponse response,
) {
  print('');
  print('========================================');
  print('💳 RAZORPAY EXTERNAL WALLET');
  print('========================================');
  print('Wallet: ${response.walletName}');
  print('========================================');
}

  Future<void> _loadWards() async {
    setState(() => _loadingWards = true);
    try {
      final wards = await ApiService.getWards();
      setState(() => _wards = wards);
    } catch (e) {
      print('Error loading wards: $e');
    } finally {
      setState(() => _loadingWards = false);
    }
  }

  Future<void> _loadStreetsForWard(int wardId) async {
    try {
      final streets = await ApiService.getStreetsByWard(wardId);
      setState(() => _streetsForSelectedWard = streets);
    } catch (e) {
      print('Error loading streets: $e');
      setState(() => _streetsForSelectedWard = []);
    }
  }

  Future<void> _loadCartCount() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = authProvider.isLoggedIn;
      final token = prefs.getString('auth_token');
      
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
    _razorpay?.clear();
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

      List<Map<String, dynamic>> products = [];
      
      if (_isBuyNowMode && _buyNowItem != null) {
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

      if (_isBuyNowMode) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('buy_now_order');
        await prefs.remove('pending_checkout');
      }

      // ✅ Save order ID for verification
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('razorpay_order_id', order['orderId']);

      if (!requiresPayment) {
        print('🔵 Calling widget.onOrderPlaced() for COD order');
        widget.onOrderPlaced();
        
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
        print('🔵 Opening Razorpay payment for order: ${order['orderId']}');
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
  try {
    final authProvider =
        Provider.of<AuthProvider>(context, listen: false);

    final token = authProvider.token;

    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Please login to continue';
          _isLoading = false;
        });
      }
      return;
    }

    print('📡 Creating Razorpay order...');

    final response = await http.post(
      Uri.parse(
        '${ApiService.baseUrl}/payments/create-order',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'orderId': order['orderId'],
      }),
    );

    print('📡 Create order HTTP status: ${response.statusCode}');
    print('📡 Create order body: ${response.body}');

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        'Payment order creation failed (${response.statusCode})',
      );
    }

    final data = jsonDecode(response.body);

    print('📡 Razorpay order response: $data');

    if (data['success'] != true) {
      throw Exception(
        data['message'] ??
            'Failed to create payment order',
      );
    }

    final razorpayOrder = data['order'];
    final key = data['key'];

    if (razorpayOrder == null) {
      throw Exception(
        'Razorpay order data is missing',
      );
    }

    if (key == null ||
        key.toString().trim().isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Payment key not found. Please try again.';
          _isLoading = false;
        });
      }
      return;
    }

    final razorpayOrderId =
        razorpayOrder['id']?.toString();

    if (razorpayOrderId == null ||
        razorpayOrderId.isEmpty) {
      throw Exception(
        'Razorpay order ID is missing',
      );
    }

    // -------------------------------------------------------
    // Save payment/order IDs locally
    // -------------------------------------------------------

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      'razorpay_order_id',
      order['orderId'].toString(),
    );

    if (order['_id'] != null) {
      await prefs.setString(
        'razorpay_mongo_id',
        order['_id'].toString(),
      );
    }

    await prefs.setString(
      'razorpay_razorpay_order_id',
      razorpayOrderId,
    );

    // -------------------------------------------------------
    // Initialize Razorpay
    // -------------------------------------------------------

    if (_razorpay == null) {
      _razorpay = Razorpay();

      _razorpay!.on(
        Razorpay.EVENT_PAYMENT_SUCCESS,
        _handlePaymentSuccess,
      );

      _razorpay!.on(
        Razorpay.EVENT_PAYMENT_ERROR,
        _handlePaymentError,
      );

      _razorpay!.on(
        Razorpay.EVENT_EXTERNAL_WALLET,
        _handleExternalWallet,
      );

      print('✅ Razorpay initialized');
    }

    // -------------------------------------------------------
    // STANDARD RAZORPAY OPTIONS
    // -------------------------------------------------------
    //
    // IMPORTANT:
    // Do NOT add:
    //   method
    //   show_payment_methods
    //   show_upi_apps
    //   bank_ifsc_code
    //   bank_name
    //   modal.ondismiss = "redirect"
    //   disable_sounds
    //   disable_animation
    //
    // We are intentionally using the standard options.
    // -------------------------------------------------------

    final options = {
      'key': key.toString(),
      'amount': razorpayOrder['amount'],
      'currency':
          razorpayOrder['currency'] ?? 'INR',
      'name': 'MeenavanFresh',
      'description':
          'Order ${order['orderId']}',
      'order_id': razorpayOrderId,

 'prefill': {
  'contact': '+91${_phoneController.text.trim()}',
  'email': _emailController.text.trim(),
},

      'theme': {
        'color': '#5E0006',
      },

      'notes': {
        'orderId':
            order['orderId'].toString(),
        'mongoId':
            order['_id']?.toString() ?? '',
        'type': 'checkout',
      },
    };

    // -------------------------------------------------------
    // Debug logs
    // -------------------------------------------------------

    print('');
    print('======================================');
    print('🔵 OPENING RAZORPAY');
    print('======================================');
    print('Key: ${key.toString()}');
    print('Razorpay Order ID: $razorpayOrderId');
    print(
      'Amount: ${razorpayOrder['amount']}',
    );
    print(
      'Currency: ${razorpayOrder['currency'] ?? 'INR'}',
    );
    print(
      'Customer Phone: ${_phoneController.text.trim()}',
    );
    print(
      'Customer Email: ${_emailController.text.trim()}',
    );
    print('======================================');
    print('');

    // -------------------------------------------------------
    // Open Razorpay
    // -------------------------------------------------------

    _razorpay!.open(options);
  } catch (e, stackTrace) {
    print('');
    print('======================================');
    print('❌ PAYMENT INITIALIZATION ERROR');
    print('======================================');
    print('Error: $e');
    print('StackTrace: $stackTrace');
    print('======================================');
    print('');

    if (mounted) {
      setState(() {
        _errorMessage =
            'Failed to initialize payment: $e';
        _isLoading = false;
      });
    }
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
                        const Text('FREE', style: TextStyle(color: Color(0xFF5E0006))),
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
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF5E0006)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
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
                    
                    DropdownButtonFormField<int>(
                      value: _selectedWardId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Select Ward *',
                        prefixIcon: const Icon(Icons.map, color: Color(0xFF5E0006)),
                        suffixIcon: const Icon(Icons.arrow_drop_down, color: Color(0xFF5E0006)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          borderSide: BorderSide(color: Color(0xFF5E0006)),
                        ),
                      ),
                      items: _wards.map((ward) {
                        return DropdownMenuItem<int>(
                          value: ward['wardId'],
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.75,
                            child: Text(
                              'Ward ${ward['wardId']} - ${ward['wardName']}',
                              overflow: TextOverflow.ellipsis,
                              softWrap: true,
                              maxLines: 2,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: _loadingWards ? null : (value) {
                        setState(() {
                          _selectedWardId = value;
                          _selectedStreet = null;
                          _streetController.clear();
                          if (value != null) {
                            _loadStreetsForWard(value);
                          } else {
                            _streetsForSelectedWard = [];
                          }
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a ward';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: _selectedStreet,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Street Address *',
                        prefixIcon: const Icon(Icons.location_on, color: Color(0xFF5E0006)),
                        suffixIcon: const Icon(Icons.arrow_drop_down, color: Color(0xFF5E0006)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          borderSide: BorderSide(color: Color(0xFF5E0006)),
                        ),
                      ),
                      items: _streetsForSelectedWard.map((street) {
                        return DropdownMenuItem<String>(
                          value: street,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.75,
                            child: Text(
                              street,
                              overflow: TextOverflow.ellipsis,
                              softWrap: true,
                              maxLines: 2,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: _selectedWardId == null ? null : (value) {
                        setState(() {
                          _selectedStreet = value;
                          _streetController.text = value ?? '';
                        });
                      },
                      validator: (value) {
                        if (_selectedWardId == null) {
                          return 'Please select a ward first';
                        }
                        if (value == null || value.isEmpty) {
                          return 'Please select a street';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _cityController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'City *',
                        prefixIcon: const Icon(Icons.location_city, color: Color(0xFF5E0006)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          borderSide: BorderSide(color: Color(0xFF5E0006)),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    _buildTextField(_stateController, 'State', Icons.map),
                    const SizedBox(height: 12),
                    _buildTextField(_postalCodeController, 'Postal Code', Icons.code, keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    _buildTextField(_countryController, 'Country', Icons.public),
                  ],
                ),
              ),

              const SizedBox(height: 24),

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
                      activeColor: const Color(0xFF5E0006),
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
                      activeColor: const Color(0xFF5E0006),
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

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _placeOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E0006),
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
        prefixIcon: Icon(icon, color: const Color(0xFF5E0006)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: Color(0xFF5E0006)),
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