// lib/screens/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'order_success_screen.dart';

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
  late Razorpay _razorpay;
  
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

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
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

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final isLoggedIn = authProvider.isLoggedIn;

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
      };

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
        throw Exception(responseData['message'] ?? 'Failed to create order');
      }

      final order = responseData['order'];
      final requiresPayment = responseData['requiresPayment'] ?? false;

      if (!requiresPayment) {
        // COD order
        widget.onOrderPlaced();
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
        // Razorpay payment - create Razorpay order
        await _createRazorpayOrder(order);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createRazorpayOrder(dynamic order) async {
    try {
      final url = '${ApiService.baseUrl}/payments/create-order';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'orderId': order['orderId']}),
      );

      final responseData = jsonDecode(response.body);

      if (responseData['success'] != true) {
        throw Exception(responseData['message'] ?? 'Failed to create payment order');
      }

      final razorpayOrder = responseData['order'];
      final razorpayKey = responseData['key'];

      // Open Razorpay checkout
      _openRazorpayCheckout(razorpayOrder, razorpayKey, order);
      
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _openRazorpayCheckout(dynamic razorpayOrder, String razorpayKey, dynamic order) {
    var options = {
      'key': razorpayKey,
      'amount': (order['finalAmount'] * 100).toInt(), // Convert to paise
      'name': 'SeaFood',
      'description': 'Order ${order['orderId']}',
      'order_id': razorpayOrder['id'],
      'prefill': {
        'contact': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'name': _nameController.text.trim(),
      },
      'theme': {
        'color': '#D53E0F',
      },
    };

    _razorpay.open(options);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    print("Payment Success: ${response.paymentId}");
    
    // Verify payment with backend
    try {
      final verifyResponse = await ApiService.verifyPayment({
        'razorpay_order_id': response.orderId,
        'razorpay_payment_id': response.paymentId,
        'razorpay_signature': response.signature,
      });

      if (verifyResponse['success'] == true) {
        widget.onOrderPlaced();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OrderSuccessScreen(
                orderId: verifyResponse['order']['orderId'],
                orderData: verifyResponse['order'],
              ),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = verifyResponse['message'] ?? 'Payment verification failed';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Payment verification failed: $e';
        _isLoading = false;
      });
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print("Payment Error: ${response.code} - ${response.message}");
    setState(() {
      _errorMessage = response.message ?? 'Payment failed. Please try again.';
      _isLoading = false;
    });
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print("External Wallet: ${response.walletName}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF5E0006),
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        RadioListTile(
                          title: const Text('Cash on Delivery'),
                          value: 'cod',
                          groupValue: _paymentMethod,
                          onChanged: (value) {
                            setState(() {
                              _paymentMethod = value.toString();
                            });
                          },
                          activeColor: const Color(0xFFD53E0F),
                        ),
                        RadioListTile(
                          title: const Text('Razorpay (Card/UPI/NetBanking)'),
                          value: 'razorpay',
                          groupValue: _paymentMethod,
                          onChanged: (value) {
                            setState(() {
                              _paymentMethod = value.toString();
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
        ],
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