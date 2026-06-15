import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../../services/api_service.dart';
import '../../models/order.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/cart_drawer.dart';
import '../auth/signup_screen.dart';
import '../profile/profile_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final Order order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _isDownloadingPDF = false;
  int _currentIndex = 2;
  int _cartCount = 0;
  Order? _freshOrder;

  @override
  void initState() {
    super.initState();
    _loadCartCount();
    _refreshOrderDetails();
    
    for (var item in widget.order.products) {
      print('Product: ${item.name}, Image: ${item.image}');
    }
  }

Future<void> _refreshOrderDetails() async {
  try {
    final orderData = await ApiService.getOrderById(widget.order.id);
    if (orderData != null && mounted) {
      setState(() {
        _freshOrder = orderData;
      });
    }
  } catch (e) {
    print('Error refreshing order: $e');
  }
}

  Order get _currentOrder => _freshOrder ?? widget.order;

  Future<void> _loadCartCount() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final isLoggedIn = authProvider.isLoggedIn;
      final token = authProvider.token;
      
      final response = await ApiService.getCart(
        guestId: isLoggedIn ? null : null,
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

  void _openCart() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    String? guestIdToUse = authProvider.isLoggedIn ? null : null;
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

  String _getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    if (imagePath.startsWith('http')) return imagePath;
    String cleanPath = imagePath;
    if (cleanPath.startsWith('/')) cleanPath = cleanPath.substring(1);
    return '${ApiService.imageBaseUrl}/$cleanPath';
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = Provider.of<CartProvider>(context).cartCount;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Order #${_currentOrder.orderId}',
          style: const TextStyle(
            color: Color(0xFF5E0006),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long, color: Color(0xFF9B0F06)),
            onPressed: _downloadReceiptPDF,
            tooltip: 'Download Receipt PDF',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildOrderInfoCard(),
            const SizedBox(height: 16),
            _buildShippingAddressCard(),
            const SizedBox(height: 16),
            _buildItemsCard(),
            const SizedBox(height: 16),
            _buildPaymentSummaryCard(),
            const SizedBox(height: 24),
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

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5E0006), Color(0xFF9B0F06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getStatusIcon(),
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order ${_currentOrder.getStatusText()}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getStatusMessage(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                if (_currentOrder.deliveredAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Delivered on: ${_formatDate(_currentOrder.deliveredAt!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
                if (_currentOrder.cancelledAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Cancelled on: ${_formatDate(_currentOrder.cancelledAt!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  if (_currentOrder.cancellationReason != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Reason: ${_currentOrder.cancellationReason}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Order Information',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow('Order ID', _currentOrder.orderId),
            _buildInfoRow('Order Date', _formatDateTime(_currentOrder.createdAt)),
            _buildInfoRow('Payment Method', _currentOrder.paymentMethod.toUpperCase()),
            _buildInfoRow('Payment Status', _currentOrder.paymentStatus),
            if (_currentOrder.wardName != null)
              _buildInfoRow('Ward', _currentOrder.wardName!),
          ],
        ),
      ),
    );
  }

  Widget _buildShippingAddressCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Delivery Address',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              _currentOrder.shippingAddress.street,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              '${_currentOrder.shippingAddress.city}, ${_currentOrder.shippingAddress.state}',
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              '${_currentOrder.shippingAddress.postalCode}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Phone', _currentOrder.shippingAddress.phone),
            _buildInfoRow('Email', _currentOrder.shippingAddress.email),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_bag_outlined, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Order Items (${_currentOrder.products.length})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _currentOrder.products.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _currentOrder.products[index];
                return _buildOrderItem(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(OrderProduct item) {
    final imageUrl = _getImageUrl(item.image);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: imageUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.image_not_supported, size: 24, color: Colors.grey);
                    },
                  ),
                )
              : const Icon(Icons.fastfood, size: 24, color: Colors.grey),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              if (item.variantName.isNotEmpty)
                Text(
                  'Variant: ${item.variantName}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              Text(
                'Weight: ${item.getWeightDisplay()}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                'Qty: ${item.quantity} × ₹${item.price.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${item.totalPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9B0F06),
              ),
            ),
            if (item.originalPrice > item.price) ...[
              const SizedBox(height: 2),
              Text(
                '₹${item.originalPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 11,
                  decoration: TextDecoration.lineThrough,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentSummaryCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_outlined, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Payment Summary',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildSummaryRow('Subtotal', '₹${_currentOrder.totalAmount.toStringAsFixed(2)}'),
            _buildSummaryRow('Shipping Fee', '₹${_currentOrder.shippingFee.toStringAsFixed(2)}'),
            _buildSummaryRow('Tax (5%)', '₹${_currentOrder.taxAmount.toStringAsFixed(2)}'),
            if (_currentOrder.discountAmount > 0)
              _buildSummaryRow('Discount', '-₹${_currentOrder.discountAmount.toStringAsFixed(2)}'),
            const Divider(height: 16),
            _buildSummaryRow(
              'Total',
              '₹${_currentOrder.finalAmount.toStringAsFixed(2)}',
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 15 : 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? const Color(0xFF5E0006) : Colors.grey.shade700,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: isTotal ? 16 : 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? const Color(0xFF9B0F06) : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (_currentOrder.orderStatus) {
      case 'pending': return Icons.pending_outlined;
      case 'confirmed': return Icons.check_circle_outline;
      case 'processing': return Icons.hourglass_empty;
      case 'shipped': return Icons.local_shipping;
      case 'delivered': return Icons.home;
      case 'cancelled': return Icons.cancel_outlined;
      default: return Icons.shopping_bag_outlined;
    }
  }

  String _getStatusMessage() {
    switch (_currentOrder.orderStatus) {
      case 'pending': return 'Your order is being processed';
      case 'confirmed': return 'Your order has been confirmed';
      case 'processing': return 'Your order is being prepared';
      case 'shipped': return 'Your order is on the way';
      case 'delivered': return 'Your order has been delivered';
      case 'cancelled': return 'This order has been cancelled';
      default: return '';
    }
  }

  Future<void> _downloadReceiptPDF() async {
    setState(() {
      _isDownloadingPDF = true;
    });

    try {
      final pdfBytes = await ApiService.downloadOrderReceiptPDF(_currentOrder.id);
      
      if (pdfBytes != null && mounted) {
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/receipt_${_currentOrder.orderId}.pdf');
        await file.writeAsBytes(pdfBytes);
        
        await OpenFile.open(file.path);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt downloaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to download PDF');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingPDF = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}