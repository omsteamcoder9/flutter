// lib/screens/order_success_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class OrderSuccessScreen extends StatefulWidget {
  final String orderId;
  final dynamic orderData;

  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen> {
  Map<String, dynamic>? _receipt;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReceipt();
  }

  Future<void> _loadReceipt() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/orders/${widget.orderData['_id']}/receipt'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() {
          _receipt = data['receipt'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Order Confirmed'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF5E0006),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Success Icon
                  const Icon(
                    Icons.check_circle,
                    size: 80,
                    color: Color(0xFFD53E0F),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Order Placed Successfully!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5E0006),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Order ID: ${widget.orderId}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Order Summary Card
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
                          'Order Summary',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5E0006),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...?widget.orderData['products']?.map<Widget>((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'],
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      if (item['variantName'] != null && item['variantName'].isNotEmpty)
                                        Text(
                                          item['variantName'],
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      if (item['weight'] != null && item['weight'] > 0)
                                        Text(
                                          '${item['weight']} ${item['weightUnit']}',
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'x${item['quantity']}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  '₹${(item['price'] * item['quantity']).toInt()}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        const Divider(),
                        const SizedBox(height: 8),
                        _buildSummaryRow('Subtotal', (widget.orderData['totalAmount'] as num).toDouble()),
_buildSummaryRow('Tax (5%)', (widget.orderData['taxAmount'] as num).toDouble()),
_buildSummaryRow('Shipping', (widget.orderData['shippingFee'] ?? 0).toDouble()),
                        const Divider(),

_buildSummaryRow('Total', (widget.orderData['finalAmount'] as num).toDouble(), isTotal: true),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Delivery Info
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
                          'Delivery Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5E0006),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (widget.orderData['shippingAddress'] != null) ...[
                          Text('Name: ${widget.orderData['shippingAddress']['name'] ?? 'Customer'}'),
                          Text('Address: ${widget.orderData['shippingAddress']['street']}'),
                          Text('City: ${widget.orderData['shippingAddress']['city']}'),
                          Text('Phone: ${widget.orderData['shippingAddress']['phone']}'),
                          Text('Email: ${widget.orderData['shippingAddress']['email']}'),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Payment Info
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
                          'Payment Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5E0006),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('Method: ${widget.orderData['paymentMethod'] == 'cod' ? 'Cash on Delivery' : 'Razorpay'}'),
                        Text('Status: ${widget.orderData['paymentStatus']}'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Continue Shopping Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD53E0F),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Continue Shopping',
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
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '₹${amount.toInt()}',
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? const Color(0xFFD53E0F) : null,
            ),
          ),
        ],
      ),
    );
  }
}