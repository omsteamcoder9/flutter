// lib/screens/checkout_screen.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'package:http/http.dart' as http;
import 'order_success_screen.dart';
import 'package:open_file/open_file.dart';

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
        // Razorpay payment - open external browser
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

    // Build Razorpay checkout page HTML
    final String razorpayHtml = '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <script src="https://checkout.razorpay.com/v1/checkout.js"></script>
        <style>
          body { margin: 0; padding: 0; }
          .loader-container { 
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            flex-direction: column;
          }
          .spinner {
            border: 4px solid #f3f3f3;
            border-top: 4px solid #D53E0F;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin-bottom: 20px;
          }
          @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
          }
        </style>
      </head>
      <body>
        <div class="loader-container">
          <div class="spinner"></div>
          <p>Loading payment gateway...</p>
        </div>
        <script>
          async function initPayment() {
            try {
              const response = await fetch('${ApiService.baseUrl}/payments/create-order', {
                method: 'POST',
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $token'
                },
                body: JSON.stringify({ orderId: '${order['orderId']}' })
              });
              
              const data = await response.json();
              
              if (data.success) {
                var options = {
                  key: data.key,
                  amount: ${(order['finalAmount'] * 100).toInt()},
                  currency: 'INR',
                  name: 'SeaFood',
                  description: 'Order ${order['orderId']}',
                  order_id: data.order.id,
                  prefill: {
                    name: '${_nameController.text.trim().replaceAll("'", "\\'")}',
                    email: '${_emailController.text.trim()}',
                    contact: '${_phoneController.text.trim()}'
                  },
                  theme: { color: '#D53E0F' },
                  handler: function(response) {
                    fetch('${ApiService.baseUrl}/payments/verify-payment', {
                      method: 'POST',
                      headers: { 'Content-Type': 'application/json' },
                      body: JSON.stringify({
                        razorpay_order_id: response.razorpay_order_id,
                        razorpay_payment_id: response.razorpay_payment_id,
                        razorpay_signature: response.razorpay_signature
                      })
                    })
                    .then(res => res.json())
                    .then(result => {
                      if (result.success) {
                        window.location.href = 'razorpay://payment/success?orderId=' + result.order.orderId;
                      } else {
                        window.location.href = 'razorpay://payment/failed?message=' + encodeURIComponent(result.message);
                      }
                    });
                  },
                  modal: {
                    ondismiss: function() {
                      window.location.href = 'razorpay://payment/cancelled';
                    }
                  }
                };
                var rzp = new Razorpay(options);
                rzp.open();
              } else {
                window.location.href = 'razorpay://payment/error?message=' + encodeURIComponent(data.message);
              }
            } catch (error) {
              window.location.href = 'razorpay://payment/error?message=' + encodeURIComponent(error.message);
            }
          }
          
          initPayment();
        </script>
      </body>
      </html>
    ''';
    
    // Save HTML to temporary file
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/razorpay_payment.html');
    await tempFile.writeAsString(razorpayHtml);
    
    // Open with default browser
    final result = await OpenFile.open(tempFile.path);
    
    if (result.type != ResultType.done) {
      setState(() {
        _errorMessage = 'Failed to open payment gateway';
        _isLoading = false;
      });
    } else {
      await _verifyOrderStatus(order['orderId']);
    }
  }

  Future<void> _verifyOrderStatus(String orderId) async {
    // Add a delay to allow payment processing
    await Future.delayed(const Duration(seconds: 3));
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/payments/status/$orderId'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      
      final data = jsonDecode(response.body);
      
      if (data['success'] && data['payment']['status'] == 'paid') {
        widget.onOrderPlaced();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OrderSuccessScreen(
                orderId: orderId,
                orderData: {'orderId': orderId},
              ),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Payment not completed. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to verify payment status';
        _isLoading = false;
      });
    }
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