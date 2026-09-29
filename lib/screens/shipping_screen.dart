import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/cart_drawer.dart';
import 'profile/profile_screen.dart';
import 'auth/signup_screen.dart';
import 'contact_screen.dart';

class ShippingScreen extends StatefulWidget {
  const ShippingScreen({super.key});

  @override
  State<ShippingScreen> createState() => _ShippingScreenState();
}

class _ShippingScreenState extends State<ShippingScreen> {
  Map<String, dynamic>? _shipping;
  bool _isLoading = true;
  String? _error;
  int _currentIndex = 2;
  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    _loadShipping();
    _loadCartCount();
  }

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

  Future<void> _loadShipping() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final shipping = await ApiService.getShipping();
      setState(() {
        _shipping = shipping;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
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
          _shipping?['title']?.toString().trim().isNotEmpty == true
              ? _shipping!['title'].toString()
              : 'Shipping Info',
          style: const TextStyle(
            color: Color(0xFF063B5C),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _buildBody(context),
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

  double _hPad(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 360) return 14;
    if (w < 600) return 16;
    if (w < 900) return 24;
    return 32;
  }

  double _sectionTitleSize(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 360) return 15;
    if (w < 600) return 16;
    if (w < 900) return 17;
    return 18;
  }

  double _bodyTextSize(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 360) return 12.5;
    if (w < 600) return 13;
    if (w < 900) return 14;
    return 14.5;
  }

  double _iconSize(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 360) return 18;
    if (w < 600) return 20;
    if (w < 900) return 22;
    return 24;
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF07566B)),
              ),
            ),
            SizedBox(height: 16),
            Text('Loading Shipping Info...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(_hPad(context)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: _iconSize(context) * 3,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: _bodyTextSize(context)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadShipping,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF07566B),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_shipping == null) {
      return const Center(
        child: Text('No shipping info available'),
      );
    }

    final data = _shipping!;
    final deliveryPromise = data['deliveryPromise'] ?? {};
    final deliveryAreas = (data['deliveryAreas'] ?? []) as List;
    final charges = data['shippingCharges'] ?? {};
    final packaging = data['packaging'] ?? {};
    final packagingItems = (packaging['items'] ?? []) as List;
    final tracking = data['orderTracking'] ?? {};

    final horizontalPadding = _hPad(context);
    final sectionTitleSize = _sectionTitleSize(context);
    final bodySize = _bodyTextSize(context);
    final iconSize = _iconSize(context);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: horizontalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data['headerBadge'] != null &&
              data['headerBadge'].toString().isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF07566B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                data['headerBadge'].toString(),
                style: TextStyle(
                  fontSize: bodySize - 1.5,
                  color: const Color(0xFF07566B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 20),

          if (data['headerSubtitle'] != null &&
              data['headerSubtitle'].toString().isNotEmpty)
            Text(
              data['headerSubtitle'].toString(),
              style: TextStyle(
                fontSize: bodySize,
                height: 1.5,
                color: Colors.grey.shade700,
              ),
            ),
          const SizedBox(height: 24),

          if (deliveryPromise['title'] != null ||
              deliveryPromise['description'] != null) ...[
            _buildSection(
              deliveryPromise['title'] ?? 'Delivery Promise',
              deliveryPromise['description'] ?? '',
              Icons.local_shipping_outlined,
              sectionTitleSize,
              bodySize,
              iconSize,
            ),
            const SizedBox(height: 20),
          ],

          if (deliveryAreas.isNotEmpty) ...[
            _buildSectionHeader(
              'Delivery Areas & Timings',
              Icons.location_on_outlined,
              sectionTitleSize,
              iconSize,
            ),
            const SizedBox(height: 12),
            ...deliveryAreas.map((area) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.arrow_right, color: const Color(0xFF07566B), size: iconSize),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (area['areaName'] != null)
                              Text(area['areaName'].toString(),
                                  style: TextStyle(fontSize: bodySize + 1, fontWeight: FontWeight.w600, color: const Color(0xFF063B5C))),
                            if (area['timing'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(area['timing'].toString(),
                                    style: TextStyle(fontSize: bodySize - 0.5, color: Colors.grey.shade700)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 20),
          ],

          if (charges['isFree'] == true) ...[
            _buildSectionHeader('Shipping Charges', Icons.currency_rupee_outlined, sectionTitleSize, iconSize),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF07566B).withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF07566B).withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline, color: const Color(0xFF07566B), size: iconSize),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(charges['freeShippingMessage'] ?? 'FREE Shipping on All Orders',
                            style: TextStyle(fontSize: bodySize + 2, fontWeight: FontWeight.bold, color: const Color(0xFF063B5C))),
                        if (charges['freeShippingDescription'] != null) ...[
                          const SizedBox(height: 6),
                          Text(charges['freeShippingDescription'].toString(),
                              style: TextStyle(fontSize: bodySize - 0.5, height: 1.4, color: Colors.grey.shade700)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          if (packagingItems.isNotEmpty) ...[
            _buildListSection(
              packaging['title'] ?? 'How We Pack Your Order',
              packagingItems.map((e) => e.toString()).toList(),
              Icons.inventory_2_outlined,
              sectionTitleSize,
              bodySize,
              iconSize,
            ),
            const SizedBox(height: 20),
          ],

          if (tracking['title'] != null && tracking['title'].toString().isNotEmpty) ...[
            _buildSection(
              tracking['title'].toString(),
              tracking['description'] ?? '',
              Icons.track_changes_outlined,
              sectionTitleSize,
              bodySize,
              iconSize,
            ),
            if (tracking['highlight'] != null && tracking['highlight'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF07566B).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF07566B).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bolt, color: const Color(0xFF07566B), size: iconSize - 2),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(tracking['highlight'].toString(),
                          style: TextStyle(fontSize: bodySize - 0.5, fontWeight: FontWeight.w500, color: const Color(0xFF063B5C))),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],

          const SizedBox(height: 30),

          Center(
            child: Text(
              'Fresh seafood delivered with care — every single day.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: bodySize - 2, color: Colors.grey.shade500),
            ),
          ),

          // ✅ CONTACT US BUTTON
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ContactScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.support_agent_outlined, color: Colors.white, size: 20),
              label: const Text(
                'Contact Us',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF063B5C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content, IconData icon, double sectionTitleSize, double bodySize, double iconSize) {
    if (content.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title, icon, sectionTitleSize, iconSize),
        const SizedBox(height: 12),
        Text(content, style: TextStyle(fontSize: bodySize, height: 1.5, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _buildListSection(String title, List<String> items, IconData icon, double sectionTitleSize, double bodySize, double iconSize) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title, icon, sectionTitleSize, iconSize),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(fontSize: bodySize, color: const Color(0xFF07566B), fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(item, style: TextStyle(fontSize: bodySize, height: 1.4, color: Colors.grey.shade700)),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, double sectionTitleSize, double iconSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: iconSize, color: const Color(0xFF07566B)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                  style: TextStyle(fontSize: sectionTitleSize, fontWeight: FontWeight.bold, color: const Color(0xFF063B5C), height: 1.25)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: 50,
          height: 2,
          decoration: BoxDecoration(color: const Color(0xFF07566B), borderRadius: BorderRadius.circular(2)),
        ),
      ],
    );
  }
}