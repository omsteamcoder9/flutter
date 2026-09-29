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

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  Map<String, dynamic>? _returns;
  bool _isLoading = true;
  String? _error;
  int _currentIndex = 2;
  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    _loadReturns();
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

  Future<void> _loadReturns() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final returns = await ApiService.getReturns();
      setState(() {
        _returns = returns;
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
          _returns?['title']?.toString().trim().isNotEmpty == true
              ? _returns!['title'].toString()
              : 'Returns & Refunds',
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
            Text('Loading Returns Info...'),
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
                onPressed: _loadReturns,
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

    if (_returns == null) {
      return const Center(
        child: Text('No returns info available'),
      );
    }

    final data = _returns!;
    final returnsPolicy = data['returnsPolicy'] ?? {};
    final returnSteps = (data['returnSteps'] ?? []) as List;
    final eligibleItems = (data['eligibleItems'] ?? []) as List;
    final nonEligibleItems = (data['nonEligibleItems'] ?? []) as List;
    final refundTimeline = (data['refundTimeline'] ?? []) as List;
    final contact = data['contact'] ?? {};

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

          if (returnsPolicy['title'] != null ||
              returnsPolicy['description'] != null) ...[
            _buildSection(
              returnsPolicy['title'] ?? 'Our Returns Policy',
              returnsPolicy['description'] ?? '',
              Icons.verified_outlined,
              sectionTitleSize,
              bodySize,
              iconSize,
            ),
            const SizedBox(height: 20),
          ],

          if (returnSteps.isNotEmpty) ...[
            _buildSectionHeader(
              'How to Request a Return',
              Icons.format_list_numbered_outlined,
              sectionTitleSize,
              iconSize,
            ),
            const SizedBox(height: 12),
            ...returnSteps.map((step) {
              final stepNumber = step['stepNumber'] ?? '';
              final title = step['title'] ?? '';
              final description = step['description'] ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFF07566B),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$stepNumber',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: bodySize - 0.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.toString(),
                            style: TextStyle(
                              fontSize: bodySize + 1,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF063B5C),
                            ),
                          ),
                          if (description.toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              description.toString(),
                              style: TextStyle(
                                fontSize: bodySize - 0.5,
                                height: 1.4,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
          ],

          if (eligibleItems.isNotEmpty) ...[
            _buildListSection(
              'Eligible for Return',
              eligibleItems.map((e) => e.toString()).toList(),
              Icons.check_circle_outline,
              sectionTitleSize,
              bodySize,
              iconSize,
            ),
            const SizedBox(height: 20),
          ],

          if (nonEligibleItems.isNotEmpty) ...[
            _buildListSection(
              'Not Eligible for Return',
              nonEligibleItems.map((e) => e.toString()).toList(),
              Icons.cancel_outlined,
              sectionTitleSize,
              bodySize,
              iconSize,
            ),
            const SizedBox(height: 20),
          ],

          if (refundTimeline.isNotEmpty) ...[
            _buildSectionHeader(
              'Refund Timeline',
              Icons.schedule_outlined,
              sectionTitleSize,
              iconSize,
            ),
            const SizedBox(height: 12),
            ...refundTimeline.map((row) {
              final method = row['method'] ?? '';
              final timeline = row['timeline'] ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        method.toString(),
                        style: TextStyle(
                          fontSize: bodySize,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF063B5C),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeline.toString(),
                      style: TextStyle(
                        fontSize: bodySize - 0.5,
                        color: const Color(0xFF07566B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
          ],

          if (contact['title'] != null ||
              contact['description'] != null) ...[
            _buildSection(
              contact['title'] ?? 'Need Help?',
              contact['description'] ?? '',
              Icons.support_agent_outlined,
              sectionTitleSize,
              bodySize,
              iconSize,
            ),
            const SizedBox(height: 20),
          ],

          const SizedBox(height: 30),

          Center(
            child: Text(
              'Not happy with your fish? We\'ll make it right.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: bodySize - 2,
                color: Colors.grey.shade500,
              ),
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

  Widget _buildSection(
    String title,
    String content,
    IconData icon,
    double sectionTitleSize,
    double bodySize,
    double iconSize,
  ) {
    if (content.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title, icon, sectionTitleSize, iconSize),
        const SizedBox(height: 12),
        Text(
          content,
          style: TextStyle(
            fontSize: bodySize,
            height: 1.5,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildListSection(
    String title,
    List<String> items,
    IconData icon,
    double sectionTitleSize,
    double bodySize,
    double iconSize,
  ) {
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
                  Text(
                    '• ',
                    style: TextStyle(
                      fontSize: bodySize,
                      color: const Color(0xFF07566B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: bodySize,
                        height: 1.4,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon,
    double sectionTitleSize,
    double iconSize,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                icon,
                size: iconSize,
                color: const Color(0xFF07566B),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: sectionTitleSize,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF063B5C),
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: 50,
          height: 2,
          decoration: BoxDecoration(
            color: const Color(0xFF07566B),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}