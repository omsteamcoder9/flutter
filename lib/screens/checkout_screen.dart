// lib/screens/checkout_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'package:http/http.dart' as http;
import 'order_success_screen.dart';
import 'package:url_launcher/url_launcher.dart';

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
        // Show backend error message
        final errorMsg = responseData['message'] ?? 'Failed to create order';
        
        // Check for street not found error
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