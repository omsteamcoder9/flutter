import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'widgets/hero_section.dart';
import 'package:http/http.dart' as http;
import 'widgets/product_card.dart';
import 'widgets/testimonials_section.dart';
import 'widgets/category_section.dart';
import 'widgets/header_section.dart';

void main() async {
  await dotenv.load();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SeaFood App',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'System',
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ============= API SERVICE =============
class ApiService {
  static String get baseUrl => dotenv.env['BASE_URL'] ?? '';
  
static String get imageBaseUrl {
  String url = baseUrl.replaceFirst('/api', '');
  if (url.endsWith('/api')) {
    url = url.replaceFirst('/api', '');
  }
  // Remove any trailing slash
  if (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  return url;
}
  static Future<dynamic> get(String endpoint) async {
    try {
      final url = '$baseUrl$endpoint';
      print('BASE_URL = $baseUrl');
      print('REQUEST URL: $url');
      
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      
      print('STATUS CODE: ${response.statusCode}');
      print('BODY: ${response.body}');
      
      return jsonDecode(response.body);
    } catch (e) {
      print('HTTP ERROR: $e');
      rethrow;
    }
  }
}

// ============= HOME SCREEN =============
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _products = [];
  List<dynamic> _filteredProducts = [];
  bool _isLoading = true;
  String _error = '';
  int _cartCount = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final response = await ApiService.get('/products');
      print('Response received: ${response['data']?.length ?? 0} products');
      setState(() {
        _products = response['data'] ?? [];
        _filteredProducts = _products;
        _isLoading = false;
      });
    } catch (e) {
      print('Error: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSearchQueryChanged(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredProducts = _products;
      } else {
        _filteredProducts = _products.where((product) {
          final name = product['name']?.toLowerCase() ?? '';
          return name.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  String _getTomorrowDate() {
    final tomorrow = DateTime.now().add(Duration(days: 1));
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[tomorrow.weekday - 1]}, ${months[tomorrow.month - 1]} ${tomorrow.day}';
  }

  void _addToCart(dynamic product) {
    setState(() {
      _cartCount++;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product['name']} added to cart'),
        duration: Duration(seconds: 1),
        backgroundColor: Color(0xFF9B0F06),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9B0F06)),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading fresh seafood...',
                    style: TextStyle(color: Color(0xFF5E0006).withOpacity(0.7)),
                  ),
                ],
              ),
            )
          : _error.isNotEmpty
              ? Center(child: Text('Error: $_error'))
              : _products.isEmpty
                  ? Center(child: Text('No products found'))
                  : Column(
                      children: [
                        _buildAppBar(),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                CategorySection(),
                                _buildDeliveryBanner(),
                                _buildHeroSection(),
                                _buildExploreSection(),
                                _buildWhyChooseUs(),
                                _buildTestimonialsSection(),
                                _buildFaqSection(),
                                SizedBox(height: 100),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildAppBar() {
    return HeaderSection(
      cartCount: _cartCount,
      onCartTap: () {},
      onSearchSubmit: () {
        print('Search submitted');
      },
      onSearchQueryChanged: _onSearchQueryChanged,
    );
  }
  
  // ============= DELIVERY BANNER =============
  Widget _buildDeliveryBanner() {
    final tomorrow = _getTomorrowDate();
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5E0006), Color(0xFF9B0F06), Color(0xFFD53E0F)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Order Today - Get Tomorrow',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 2),
          Text(
            '($tomorrow)',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Cutoff: 8:00 PM for next-day delivery',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  // ============= HERO SECTION =============
  Widget _buildHeroSection() {
    if (_products.isEmpty) return const SizedBox.shrink();
    return HeroSection(
      products: _products,
      imageBaseUrl: ApiService.imageBaseUrl,
    );
  }

  // ============= EXPLORE PRODUCTS SECTION =============
  Widget _buildExploreSection() {
    return Container(
      margin: EdgeInsets.only(top: 24, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Text(
                  'Explore Our Fresh Seafood Collection',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5E0006),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Discover premium quality sea fish, fresh from the harbour to your kitchen',
                  style: TextStyle(color: Color(0xFF5E0006).withOpacity(0.7), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Container(
                  width: 60,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Color(0xFF9B0F06),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              return GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.68,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _filteredProducts.length,
                itemBuilder: (context, index) {
                  return ProductCard(
                    product: _filteredProducts[index],
                    onAddToCart: () => _addToCart(_filteredProducts[index]),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
  
  // ============= WHY CHOOSE US SECTION =============
  Widget _buildWhyChooseUs() {
    final features = [
      {'icon': Icons.calendar_today, 'title': 'Next-Day Delivery', 'desc': 'Order today, get fresh seafood delivered tomorrow.', 'highlight': 'Tomorrow Delivery'},
      {'icon': Icons.local_shipping, 'title': 'Fast & Safe Delivery', 'desc': 'Quick and safe delivery with ice packing to your doorstep.', 'highlight': 'Ice Packed'},
      {'icon': Icons.verified, 'title': 'Premium Quality Fish', 'desc': '100% Fresh seafood sourced directly from harbour daily.', 'highlight': 'Certified Fresh'},
    ];

    return Container(
      margin: EdgeInsets.symmetric(vertical: 32),
      padding: EdgeInsets.symmetric(vertical: 24),
      color: Colors.white,
      child: Column(
        children: [
          Text(
            'Why Choose Our Fresh Seafood',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5E0006),
            ),
          ),
          SizedBox(height: 8),
          Container(
            width: 60,
            height: 3,
            decoration: BoxDecoration(
              color: Color(0xFF9B0F06),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Trusted quality seafood sourced directly from local fishermen',
            style: TextStyle(color: Color(0xFF5E0006).withOpacity(0.7), fontSize: 13),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: features.map((feature) {
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: feature == features.last ? 0 : 12),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 15,
                            offset: Offset(0, 5),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Color(0xFF9B0F06).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(feature['icon'] as IconData, color: Color(0xFF9B0F06), size: 24),
                          ),
                          SizedBox(height: 12),
                          Text(
                            feature['title'] as String,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF5E0006)),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 6),
                          Expanded(
                            child: Text(
                              feature['desc'] as String,
                              style: TextStyle(color: Color(0xFF5E0006).withOpacity(0.6), fontSize: 11, height: 1.3),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Color(0xFF9B0F06).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Color(0xFF9B0F06).withOpacity(0.2)),
                            ),
                            child: Text(
                              feature['highlight'] as String,
                              style: TextStyle(color: Color(0xFF9B0F06), fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============= TESTIMONIALS SECTION =============
  Widget _buildTestimonialsSection() {
    return const TestimonialsSection();
  }
  
  // ============= FAQ SECTION =============
  Widget _buildFaqSection() {
    final faqs = [
      {'q': 'How fresh is the sea fish you deliver?', 'a': 'Our sea fish is sourced daily from local fishermen and packed with ice. We ensure next-day delivery for maximum freshness.'},
      {'q': 'When will I receive my order?', 'a': 'We follow a next-day delivery policy. Orders placed today will be delivered tomorrow. This ensures you receive the freshest catch possible.'},
      {'q': 'Is the fish cleaned and cut before delivery?', 'a': 'Yes, we provide fresh cleaned and cut fish as per your preference. You can choose whole fish, fillets, or curry cuts.'},
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          Text(
            'Frequently Asked Questions',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5E0006),
            ),
          ),
          SizedBox(height: 8),
          Container(
            width: 60,
            height: 3,
            decoration: BoxDecoration(
              color: Color(0xFF9B0F06),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 24),
          ...faqs.map((faq) => _buildFaqItem(faq['q']!, faq['a']!)),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            question,
            style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF5E0006), fontSize: 14),
          ),
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                answer,
                style: TextStyle(color: Color(0xFF5E0006).withOpacity(0.7), fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============= BOTTOM NAVIGATION BAR =============
  Widget _buildBottomNavBar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Color(0xFF5E0006),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home_outlined, Icons.home, 'Home', true),
          _buildNavItem(Icons.search, Icons.search, 'Search', false),
          _buildNavItem(Icons.shopping_bag_outlined, Icons.shopping_bag, 'Cart', false),
          _buildNavItem(Icons.person_outline, Icons.person, 'Account', false),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, IconData activeIcon, String label, bool isActive) {
    return InkWell(
      onTap: () {},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? activeIcon : icon,
            color: isActive ? Color(0xFFD53E0F) : Color(0xFFEED9B9).withOpacity(0.7),
            size: 20,
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Color(0xFFD53E0F) : Color(0xFFEED9B9).withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

