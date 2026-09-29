// lib/screens/order_success_screen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/cart_drawer.dart';
import 'auth/signup_screen.dart';
import 'profile/profile_screen.dart';

class OrderSuccessScreen extends StatefulWidget {
  final String orderId;

  // Can receive either:
  // 1. Map<String, dynamic>
  // 2. Order
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
  Order? _order;

  bool _isLoading = true;
  int _cartCount = 0;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    _prepareOrder();
    _loadCartCount();
  }

  // ============================================================
  // PREPARE ORDER
  // ============================================================

  Future<void> _prepareOrder() async {
    try {
      /*
       * If Order object is already provided,
       * use it directly.
       */
      if (widget.orderData is Order) {
        if (!mounted) return;

        setState(() {
          _order = widget.orderData as Order;
          _isLoading = false;
        });

        return;
      }

      /*
       * If a Map is provided from checkout/payment response,
       * convert it into the Order model.
       */
      if (widget.orderData is Map) {
        final map = Map<String, dynamic>.from(widget.orderData as Map);

        final parsedOrder = Order.fromJson(map);

        if (!mounted) return;

        setState(() {
          _order = parsedOrder;
          _isLoading = false;
        });

        return;
      }

      /*
       * If neither Map nor Order was provided,
       * try loading the receipt/order from backend.
       */
      await _loadReceiptAsOrder();
    } catch (e, stackTrace) {
      debugPrint('ORDER SUCCESS SCREEN ERROR: $e');
      debugPrint('$stackTrace');

      /*
       * Last fallback:
       * fetch the order directly from backend.
       */
      await _loadReceiptAsOrder();
    }
  }

  // ============================================================
  // LOAD ORDER FROM BACKEND
  // ============================================================

  Future<void> _loadReceiptAsOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final token =
          prefs.getString('auth_token') ??
          prefs.getString('token');

      final response = await http.get(
        Uri.parse(
          '${ApiService.baseUrl}/orders/${widget.orderId}',
        ),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      );

      debugPrint(
        'ORDER FETCH STATUS: ${response.statusCode}',
      );

      debugPrint(
        'ORDER FETCH RESPONSE: ${response.body}',
      );

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        final data = jsonDecode(response.body);

        Map<String, dynamic>? orderJson;

        if (data is Map<String, dynamic>) {
          if (data['order'] is Map) {
            orderJson =
                Map<String, dynamic>.from(data['order']);
          } else if (data['data'] is Map) {
            orderJson =
                Map<String, dynamic>.from(data['data']);
          } else if (data['_id'] != null ||
              data['orderId'] != null) {
            orderJson = data;
          }
        }

        if (orderJson != null) {
          final parsedOrder = Order.fromJson(orderJson);

          if (!mounted) return;

          setState(() {
            _order = parsedOrder;
            _isLoading = false;
          });

          return;
        }
      }

      /*
       * If direct order endpoint does not return usable data,
       * try receipt endpoint.
       */
      await _loadReceiptFallback();
    } catch (e, stackTrace) {
      debugPrint(
        'DIRECT ORDER FETCH ERROR: $e',
      );

      debugPrint(
        '$stackTrace',
      );

      await _loadReceiptFallback();
    }
  }

  // ============================================================
  // RECEIPT FALLBACK
  // ============================================================

  Future<void> _loadReceiptFallback() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final token =
          prefs.getString('auth_token') ??
          prefs.getString('token');

      final response = await http.get(
        Uri.parse(
          '${ApiService.baseUrl}/orders/${widget.orderId}/receipt',
        ),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      );

      debugPrint(
        'RECEIPT STATUS: ${response.statusCode}',
      );

      debugPrint(
        'RECEIPT RESPONSE: ${response.body}',
      );

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        final data = jsonDecode(response.body);

        Map<String, dynamic>? receipt;

        if (data is Map<String, dynamic>) {
          if (data['receipt'] is Map) {
            receipt =
                Map<String, dynamic>.from(data['receipt']);
          } else if (data['order'] is Map) {
            receipt =
                Map<String, dynamic>.from(data['order']);
          } else if (data['data'] is Map) {
            receipt =
                Map<String, dynamic>.from(data['data']);
          }
        }

        if (receipt != null) {
          final parsedOrder = Order.fromJson(receipt);

          if (!mounted) return;

          setState(() {
            _order = parsedOrder;
            _isLoading = false;
          });

          return;
        }
      }

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint(
        'RECEIPT FALLBACK ERROR: $e',
      );

      debugPrint(
        '$stackTrace',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // CART COUNT
  // ============================================================

  Future<void> _loadCartCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final token =
          prefs.getString('auth_token') ??
          prefs.getString('token');

      final isLoggedIn =
          token != null && token.isNotEmpty;

      final response = await ApiService.getCart(
        guestId: null,
        token: isLoggedIn ? token : null,
      );

      if (response['success'] == true && mounted) {
        final data = response['data'];

        int count = 0;

        if (data is Map) {
          final totalItems = data['totalItems'];

          if (totalItems is int) {
            count = totalItems;
          } else if (totalItems is num) {
            count = totalItems.toInt();
          }
        }

        setState(() {
          _cartCount = count;
        });
      }
    } catch (e) {
      debugPrint(
        'ERROR LOADING CART COUNT: $e',
      );
    }
  }

  // ============================================================
  // OPEN CART
  // ============================================================

  void _openCart() {
    final authProvider =
        Provider.of<AuthProvider>(
      context,
      listen: false,
    );

    final String? token =
        authProvider.isLoggedIn
            ? authProvider.token
            : null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartScreen(
          guestId: null,
          token: token,
          onCartUpdate: () {
            _loadCartCount();
          },
        ),
      ),
    );
  }

  // ============================================================
  // AUTH
  // ============================================================

  void _showAuthDialog() {
    final authProvider =
        Provider.of<AuthProvider>(
      context,
      listen: false,
    );

    if (authProvider.isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SignupScreen(),
        ),
      );
    }
  }

  // ============================================================
  // HOME
  // ============================================================

  void _navigateToHome() {
    Navigator.popUntil(
      context,
      (route) => route.isFirst,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final cartCount =
        Provider.of<CartProvider>(
      context,
    ).cartCount;

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: const Text(
          'Order Confirmed',
        ),
        backgroundColor: Colors.white,
        foregroundColor:
            const Color(0xFF063B5C),
        elevation: 0,

        /*
         * Keep back button available.
         */
        automaticallyImplyLeading: true,
      ),

      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _order == null
              ? _buildErrorState()
              : _buildOrderContent(),

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

          if (mounted) {
            setState(() {
              _currentIndex = index;
            });
          }
        },
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 70,
              color: Colors.grey,
            ),

            const SizedBox(height: 20),

            const Text(
              'Order Confirmed',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'Order ID: ${widget.orderId}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Your payment was successful, but the order details could not be loaded.',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                });

                _loadReceiptAsOrder();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF063B5C),
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Retry',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ORDER CONTENT
  // ============================================================

  Widget _buildOrderContent() {
    final order = _order!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ======================================================
          // SUCCESS ICON
          // ======================================================

          const Icon(
            Icons.check_circle,
            size: 80,
            color: Color(0xFF063B5C),
          ),

          const SizedBox(height: 16),

          const Text(
            'Order Placed Successfully!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF063B5C),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Order ID: ${order.orderId.isNotEmpty ? order.orderId : widget.orderId}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 24),

          // ======================================================
          // ORDER SUMMARY
          // ======================================================

          _buildOrderSummary(order),

          const SizedBox(height: 24),

          // ======================================================
          // DELIVERY INFORMATION
          // ======================================================

          _buildDeliveryInformation(order),

          const SizedBox(height: 24),

          // ======================================================
          // PAYMENT INFORMATION
          // ======================================================

          _buildPaymentInformation(order),

          const SizedBox(height: 24),

          // ======================================================
          // CONTINUE SHOPPING
          // ======================================================

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.popUntil(
                  context,
                  (route) => route.isFirst,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF063B5C),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 14,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue Shopping',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ============================================================
  // ORDER SUMMARY
  // ============================================================

  Widget _buildOrderSummary(Order order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF063B5C),
            ),
          ),

          const SizedBox(height: 12),

          if (order.products.isEmpty)
            const Padding(
              padding:
                  EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'No product details available.',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),

          ...order.products.map(
            (item) {
              return Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 12,
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style:
                                const TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.w500,
                            ),
                          ),

                          if (item.variantName
                              .isNotEmpty)
                            Text(
                              item.variantName,
                              style:
                                  const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),

                          if (item.weight > 0)
                            Text(
                              item.getWeightDisplay(),
                              style:
                                  const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    Text(
                      'x${item.quantity}',
                      style:
                          const TextStyle(
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(width: 16),

                    Text(
                      '₹${item.totalPrice.toInt()}',
                      style:
                          const TextStyle(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Color(0xFF063B5C),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const Divider(),

          const SizedBox(height: 8),

          _buildSummaryRow(
            'Subtotal',
            order.totalAmount,
          ),

          _buildSummaryRow(
            'Tax (5%)',
            order.taxAmount,
          ),

          _buildSummaryRow(
            'Shipping',
            order.shippingFee,
          ),

          if (order.discountAmount > 0)
            _buildSummaryRow(
              'Discount',
              -order.discountAmount,
            ),

          const Divider(),

          _buildSummaryRow(
            'Total',
            order.finalAmount,
            isTotal: true,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DELIVERY INFORMATION
  // ============================================================

  Widget _buildDeliveryInformation(
    Order order,
  ) {
    final address = order.shippingAddress;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF063B5C),
            ),
          ),

          const SizedBox(height: 12),

          if (address.street.isNotEmpty)
            Text(
              'Address: ${address.street}',
            ),

          if (address.city.isNotEmpty)
            Text(
              'City: ${address.city}',
            ),

          if (address.state.isNotEmpty)
            Text(
              'State: ${address.state}',
            ),

          if (address.postalCode.isNotEmpty)
            Text(
              'PIN: ${address.postalCode}',
            ),

          if (address.phone.isNotEmpty)
            Text(
              'Phone: ${address.phone}',
            ),

          if (address.email.isNotEmpty)
            Text(
              'Email: ${address.email}',
            ),
        ],
      ),
    );
  }

  // ============================================================
  // PAYMENT INFORMATION
  // ============================================================

  Widget _buildPaymentInformation(
    Order order,
  ) {
    final isCod =
        order.paymentMethod.toLowerCase() ==
            'cod';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF063B5C),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Method: ${isCod ? 'Cash on Delivery' : 'Razorpay'}',
          ),

          const SizedBox(height: 4),

          Text(
            'Status: ${order.paymentStatus}',
          ),

          const SizedBox(height: 4),

          Text(
            'Order Status: ${order.getStatusText()}',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY ROW
  // ============================================================

  Widget _buildSummaryRow(
    String label,
    double amount, {
    bool isTotal = false,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize:
                  isTotal ? 16 : 14,
              fontWeight:
                  isTotal
                      ? FontWeight.bold
                      : FontWeight.normal,
            ),
          ),

          Text(
            '₹${amount.toInt()}',
            style: TextStyle(
              fontSize:
                  isTotal ? 16 : 14,
              fontWeight:
                  isTotal
                      ? FontWeight.bold
                      : FontWeight.normal,
              color: isTotal
                  ? const Color(0xFF063B5C)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}