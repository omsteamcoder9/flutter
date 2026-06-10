import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/hero_section.dart';
import 'widgets/product_card.dart';
import 'widgets/testimonials_section.dart';
import 'widgets/category_section.dart';
import 'widgets/header_section.dart';
import 'widgets/footer_section.dart';
import 'widgets/cart_drawer.dart';
import 'services/api_service.dart';
import 'providers/auth_provider.dart';
import 'screens/order_success_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/category_products_screen.dart';
import 'screens/auth/login_screen.dart'; 
import 'screens/auth/signup_screen.dart'; // Add this import

void main() async {
  await dotenv.load();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MyApp(),
    ),
  );
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
   routes: {
  '/product-detail': (context) => ProductDetailScreen(
    productId: ModalRoute.of(context)!.settings.arguments as String,
  ),
  '/checkout': (context) => CheckoutScreen(
    guestId: null,
    onOrderPlaced: () {},
  ),
    '/login': (context) => LoginScreen(),  // ✅ ADD THIS LINE
'/signup': (context) => SignupScreen(),

  '/category-products': (context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    return CategoryProductsScreen(
      categoryId: args['categoryId'],
      categoryName: args['categoryName'],
    );
  },
},
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  List<dynamic> _products = [];
  List<dynamic> _filteredProducts = [];
  bool _isLoading = true;
  String _error = '';
  int _cartCount = 0;
  String _searchQuery = '';
  String _guestId = '';
  Set<String> _cartProductIds = {}; // ✅ ADDED - Track products in cart

  @override
  void initState() {
    super.initState();
    _initializeApp();
    
    // Listen for auth changes (login/logout)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
authProvider.addListener(() {
  print('🔄 AuthProvider listener triggered - refreshing cart count');
  if (mounted) {
    _refreshCartCount();
  }
});
    });
  }

  Future<void> _initializeApp() async {
    await _loadGuestId();
    await _loadProducts();
    
    // Wait for auth to finish loading before fetching cart
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    int retries = 0;
    while (authProvider.isLoading && retries < 30) {
      await Future.delayed(Duration(milliseconds: 100));
      retries++;
    }
    
    await _refreshCartCount();
    await _checkPendingOrder();
  }

  Future<void> _checkPendingOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingOrderId = prefs.getString('pending_order_id');
    if (pendingOrderId != null && pendingOrderId.isNotEmpty) {
      await prefs.remove('pending_order_id');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OrderSuccessScreen(
                orderId: pendingOrderId,
                orderData: {'orderId': pendingOrderId},
              ),
            ),
          );
        }
      });
    }
  }

  Future<void> _loadGuestId() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedGuestId = prefs.getString('guest_id');
    
    if (savedGuestId == null) {
      savedGuestId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('guest_id', savedGuestId);
    }
    
    setState(() {
      _guestId = savedGuestId!;
    });
    print('🆔 Guest ID loaded: $_guestId');
  }

  Future<void> _refreshCartCount() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      print('🔄 _refreshCartCount - isLoggedIn: ${authProvider.isLoggedIn}');
      print('🔄 _refreshCartCount - token exists: ${authProvider.token != null}');
      
      String? guestIdToUse = authProvider.isLoggedIn ? null : _guestId;
      String? tokenToUse = authProvider.isLoggedIn ? authProvider.token : null;
      
      final response = await ApiService.getCart(guestId: guestIdToUse, token: tokenToUse);
      
      if (response['success'] == true && mounted) {
        final newCount = response['data']?['totalItems'] ?? 0;
        
        // ✅ Extract product IDs from cart items
        final items = response['data']?['items'] ?? [];
        final Set<String> productIds = {};
        for (var item in items) {
          if (item['product'] != null) {
            if (item['product'] is Map) {
              productIds.add(item['product']['_id'].toString());
            } else {
              productIds.add(item['product'].toString());
            }
          }
        }
        
        print('🛒 Cart count from API: $newCount');
        print('🛒 Products in cart: $productIds');
        
        setState(() {
          _cartCount = newCount;
          _cartProductIds = productIds;
        });
      }
    } catch (e) {
      print('Error refreshing cart: $e');
    }
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

  void _openCart() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    String? guestIdToUse = authProvider.isLoggedIn ? null : _guestId;
    String? tokenToUse = authProvider.isLoggedIn ? authProvider.token : null;
    
    print('🔵 _openCart called');
    print('   - isLoggedIn: ${authProvider.isLoggedIn}');
    print('   - tokenToUse: $tokenToUse');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartScreen(
          guestId: guestIdToUse,
          token: tokenToUse,
          onCartUpdate: () {
            _refreshCartCount();
          },
        ),
      ),
    );
  }

  void _addToCart(dynamic product) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      String? guestIdToUse = authProvider.isLoggedIn ? null : _guestId;
      String? tokenToUse = authProvider.isLoggedIn ? authProvider.token : null;
      
      String variantId = '';
      if (product['variants'] != null && product['variants'].isNotEmpty) {
        variantId = product['variants'][0]['_id'] ?? '';
      }
      
      final response = await ApiService.addToCart(
        product['_id'], 
        1, 
        variantId,
        guestId: guestIdToUse,
        token: tokenToUse,
      );
      
      if (response['success'] == true) {
        await _refreshCartCount();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product['name']} added to cart'),
            duration: Duration(seconds: 1),
            backgroundColor: Color(0xFF9B0F06),
          ),
        );
      } else {
        throw Exception('Failed to add to cart');
      }
    } catch (e) {
      print('Error adding to cart: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add to cart'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
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
                                _buildDeliveryBanner(),
                                _buildHeroSection(),
                                _buildExploreSection(),
                                _buildWhyChooseUs(),
                                _buildTestimonialsSection(),
                                _buildFaqSection(),
                                FooterSection(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildAppBar() {
    print('🛒 Building AppBar with cartCount: $_cartCount');
    return HeaderSection(
      cartCount: _cartCount,
      onCartTap: _openCart,
      onSearchSubmit: () {
        print('Search submitted');
      },
      onSearchQueryChanged: _onSearchQueryChanged,
    );
  }
  
  Widget _buildDeliveryBanner() {
    final tomorrow = _getTomorrowDate();
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
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
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 2),
          Text(
            '($tomorrow)',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            'Cutoff: 8:00 PM for next-day delivery',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeroSection() {
    if (_products.isEmpty) return const SizedBox.shrink();
    return HeroSection(
      products: _products,
      imageBaseUrl: ApiService.imageBaseUrl,
    );
  }

  Widget _buildExploreSection() {
    Map<String, List<dynamic>> productsByCategory = {};
    
    for (var product in _filteredProducts) {
      String categoryName = 'Other';
      if (product['category'] != null) {
        if (product['category'] is Map) {
          categoryName = product['category']['name'] ?? 'Other';
        }
      }
      
      if (!productsByCategory.containsKey(categoryName)) {
        productsByCategory[categoryName] = [];
      }
      productsByCategory[categoryName]!.add(product);
    }
    
    return Container(
      margin: EdgeInsets.only(top: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Text(
                  'Explore Our Fresh Seafood Collection',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5E0006),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6),
                Text(
                  'Discover premium quality sea fish, fresh from the harbour to your kitchen',
                  style: TextStyle(color: Color(0xFF5E0006).withOpacity(0.7), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Container(
                  width: 50,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Color(0xFF9B0F06),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          ...productsByCategory.entries.map((entry) {
            final categoryName = entry.key;
            final products = entry.value;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Text(
                      categoryName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5E0006),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.68,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      String? guestIdToUse = authProvider.isLoggedIn ? null : _guestId;
                      String? tokenToUse = authProvider.isLoggedIn ? authProvider.token : null;
                      
                      return ProductCard(
                        product: products[index],
                        onAddToCart: () => _addToCart(products[index]),
                        guestId: guestIdToUse,
                        token: tokenToUse,
                        onCartUpdate: _refreshCartCount,
                        cartProductIds: _cartProductIds, // ✅ ADDED - Pass cart product IDs
                      );
                    },
                  ),
                ),
                SizedBox(height: 20),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }
  
  Widget _buildWhyChooseUs() {
    final features = [
      {'icon': Icons.calendar_today, 'title': 'Next-Day Delivery', 'desc': 'Order today, get fresh seafood delivered tomorrow.', 'highlight': 'Tomorrow Delivery'},
      {'icon': Icons.local_shipping, 'title': 'Fast & Safe Delivery', 'desc': 'Quick and safe delivery with ice packing to your doorstep.', 'highlight': 'Ice Packed'},
      {'icon': Icons.verified, 'title': 'Premium Quality Fish', 'desc': '100% Fresh seafood sourced directly from harbour daily.', 'highlight': 'Certified Fresh'},
    ];

    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      padding: EdgeInsets.symmetric(vertical: 16),
      color: Colors.white,
      child: Column(
        children: [
          Text(
            'Why Choose Our Fresh Seafood',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5E0006),
            ),
          ),
          SizedBox(height: 6),
          Container(
            width: 50,
            height: 2,
            decoration: BoxDecoration(
              color: Color(0xFF9B0F06),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Trusted quality seafood sourced directly from local fishermen',
            style: TextStyle(color: Color(0xFF5E0006).withOpacity(0.7), fontSize: 12),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: features.map((feature) {
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: feature == features.last ? 0 : 10),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Color(0xFF9B0F06).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(feature['icon'] as IconData, color: Color(0xFF9B0F06), size: 20),
                          ),
                          SizedBox(height: 8),
                          Text(
                            feature['title'] as String,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5E0006)),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 4),
                          Expanded(
                            child: Text(
                              feature['desc'] as String,
                              style: TextStyle(color: Color(0xFF5E0006).withOpacity(0.6), fontSize: 10, height: 1.2),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Color(0xFF9B0F06).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Color(0xFF9B0F06).withOpacity(0.2)),
                            ),
                            child: Text(
                              feature['highlight'] as String,
                              style: TextStyle(color: Color(0xFF9B0F06), fontSize: 8, fontWeight: FontWeight.bold),
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

  Widget _buildTestimonialsSection() {
    return const TestimonialsSection();
  }
  
  Widget _buildFaqSection() {
    final faqs = [
      {'q': 'How fresh is the sea fish you deliver?', 'a': 'Our sea fish is sourced daily from local fishermen and packed with ice. We ensure next-day delivery for maximum freshness.'},
      {'q': 'When will I receive my order?', 'a': 'We follow a next-day delivery policy. Orders placed today will be delivered tomorrow. This ensures you receive the freshest catch possible.'},
      {'q': 'Is the fish cleaned and cut before delivery?', 'a': 'Yes, we provide fresh cleaned and cut fish as per your preference. You can choose whole fish, fillets, or curry cuts.'},
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          Text(
            'Frequently Asked Questions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5E0006),
            ),
          ),
          SizedBox(height: 6),
          Container(
            width: 50,
            height: 2,
            decoration: BoxDecoration(
              color: Color(0xFF9B0F06),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 16),
          ...faqs.map((faq) => _buildFaqItem(faq['q']!, faq['a']!)),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            question,
            style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF5E0006), fontSize: 13),
          ),
          children: [
            Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                answer,
                style: TextStyle(color: Color(0xFF5E0006).withOpacity(0.7), fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}