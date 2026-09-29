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
import 'widgets/bottom_nav_bar.dart';
import 'services/api_service.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'screens/order_success_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/category_products_screen.dart';
import 'screens/auth/login_screen.dart'; 
import 'screens/auth/signup_screen.dart';
import 'screens/profile/profile_screen.dart';

void main() async {
  await dotenv.load();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
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
        primarySwatch: MaterialColor(0xFF07566B, {
          50: Color(0xFFE0F0F5),
          100: Color(0xFFB3DDE8),
          200: Color(0xFF80C7D9),
          300: Color(0xFF4DB1CA),
          400: Color(0xFF269FBC),
          500: Color(0xFF07566B),
          600: Color(0xFF064F62),
          700: Color(0xFF054658),
          800: Color(0xFF043C4D),
          900: Color(0xFF032B38),
        }),
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
        '/login': (context) => LoginScreen(),
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
  String _searchQuery = '';
  String _guestId = '';
  int _currentIndex = 0;
  bool _isInitialized = false;

  late CartProvider _cartProvider;
  late AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.addListener(() {
        print('🔄 AuthProvider listener triggered - isLoggedIn: ${authProvider.isLoggedIn}');
        if (mounted) {
          if (authProvider.isLoggedIn) {
            _cartProvider.initialize(
              guestId: _guestId,
              token: authProvider.token,
              isLoggedIn: true,
            );
          } else {
            _cartProvider.initialize(
              guestId: _guestId,
              token: null,
              isLoggedIn: false,
            );
          }
          _cartProvider.refreshCartCount();
          setState(() {});
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cartProvider = Provider.of<CartProvider>(context, listen: false);
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
  }

  Future<void> _initializeApp() async {
    await _loadGuestId();
    await _loadProducts();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitialized) {
        _cartProvider.initialize(
          guestId: _guestId,
          token: _authProvider.isLoggedIn ? _authProvider.token : null,
          isLoggedIn: _authProvider.isLoggedIn,
        );
        _cartProvider.refreshCartCount();
        _isInitialized = true;
      }
    });
    
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

  Future<void> _loadProducts() async {
    try {
      final response = await ApiService.get('/products');
      setState(() {
        _products = response['data'] ?? [];
        _filteredProducts = _products;
        _isLoading = false;
      });
    } catch (e) {
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
    String? guestIdToUse = _authProvider.isLoggedIn ? null : _guestId;
    String? tokenToUse = _authProvider.isLoggedIn ? _authProvider.token : null;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartScreen(
          guestId: guestIdToUse,
          token: tokenToUse,
          onCartUpdate: () {
            _cartProvider.refreshCartCount();
          },
        ),
      ),
    );
  }

void _addToCart(dynamic product) async {
  // ✅ STEP 1: OPTIMISTIC UPDATE - Update UI IMMEDIATELY
  final productId = product['_id'];
  
  // Add to cart provider locally (instant)
  _cartProvider.addItemLocally(product);
  
  // Update UI instantly
  if (mounted) {
    setState(() {});
  }
  
  // Show snackbar instantly
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('${product['name']} added to cart'),
      duration: const Duration(seconds: 1),
      backgroundColor: const Color(0xFF07566B),
    ),
  );
  
  // ✅ STEP 2: SEND API REQUEST IN BACKGROUND
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('buy_now_order');
    await prefs.remove('pending_checkout');
    
    await _cartProvider.addToCart(
      product,
      guestId: _guestId,
      token: _authProvider.isLoggedIn ? _authProvider.token : null,
      isLoggedIn: _authProvider.isLoggedIn,
    );
    
    // ✅ STEP 3: CONFIRM - Keep as is (already showing "In Cart")
    // Just refresh count to be safe
    _cartProvider.refreshCartCount();
    
  } catch (e) {
    // ❌ STEP 4: REVERT IF FAILED
    _cartProvider.removeItemLocally(product);
    if (mounted) {
      setState(() {});
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Failed to add to cart'),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  void _showAuthDialog() {
    if (_authProvider.isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SignupScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = Provider.of<CartProvider>(context).cartCount;
    final cartProductIds = Provider.of<CartProvider>(context).cartProductIds;
    
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
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF07566B)),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading Meenavan Fresh...',
                    style: TextStyle(color: Color(0xFF063B5C).withOpacity(0.7)),
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
                        _buildAppBar(cartCount),
                        Expanded(
                          child: IndexedStack(
                            index: _currentIndex,
                            children: [
                              SingleChildScrollView(
                                child: Column(
                                  children: [
                                    _buildDeliveryBanner(),
                                    _buildHeroSection(),
                                    _buildExploreSection(cartProductIds),
                                    _buildWhyChooseUs(),
                                    _buildTestimonialsSection(),
                                    _buildFaqSection(),
                                  ],
                                ),
                              ),
                              const SizedBox.shrink(),
                              const SizedBox.shrink(),
                            ],
                          ),
                        ),
                      ],
                    ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        cartCount: cartCount,
        onTap: (index) {
          if (index == 1) {
            _openCart();
          } else if (index == 2) {
            _showAuthDialog();
          } else {
            setState(() {
              _currentIndex = index;
            });
          }
        },
      ),
    );
  }

  Widget _buildAppBar(int cartCount) {
    return HeaderSection(
      cartCount: cartCount,
      onCartTap: _openCart,
      onSearchSubmit: () {},
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
          colors: [Color(0xFF063B5C), Color(0xFF07566B), Color(0xFF28A8BA)],
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

  Widget _buildExploreSection(Set<String> cartProductIds) {
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
    
    // ✅ Responsive grid configuration
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount;
    double childAspectRatio;
    
    if (screenWidth < 400) {
      crossAxisCount = 2;
      childAspectRatio = 0.65;
    } else if (screenWidth < 600) {
      crossAxisCount = 2;
      childAspectRatio = 0.7;
    } else if (screenWidth < 900) {
      crossAxisCount = 3;
      childAspectRatio = 0.75;
    } else {
      crossAxisCount = 4;
      childAspectRatio = 0.8;
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
                    color: Color(0xFF063B5C),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6),
                Text(
                  'Discover premium quality sea fish, fresh from the harbour to your kitchen',
                  style: TextStyle(color: Color(0xFF063B5C).withOpacity(0.7), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Container(
                  width: 50,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Color(0xFF07566B),
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
                        color: Color(0xFF063B5C),
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
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: childAspectRatio,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      return ProductCard(
                        product: products[index],
                        onAddToCart: () => _addToCart(products[index]),
                        guestId: _guestId,
                        token: _authProvider.isLoggedIn ? _authProvider.token : null,
                        onCartUpdate: () {
                          _cartProvider.refreshCartCount();
                        },
                        cartProductIds: cartProductIds,
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
    {
      'icon': Icons.calendar_today_rounded,
      'title': 'Next-Day Delivery',
      'desc': 'Order today, get fresh seafood delivered tomorrow.',
      'highlight': 'Tomorrow Delivery',
    },
    {
      'icon': Icons.local_shipping_rounded,
      'title': 'Fast & Safe Delivery',
      'desc': 'Quick and safe delivery with ice packing to your doorstep.',
      'highlight': 'Ice Packed',
    },
    {
      'icon': Icons.verified_rounded,
      'title': 'Premium Quality Fish',
      'desc': '100% Fresh seafood sourced directly from harbour daily.',
      'highlight': 'Certified Fresh',
    },
  ];

  return Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 16),
    padding: const EdgeInsets.symmetric(vertical: 18),
    color: Colors.white,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        // Responsive outer spacing
        final horizontalPadding = screenWidth >= 1200
            ? 48.0
            : screenWidth >= 700
                ? 32.0
                : 12.0;

        // Space between cards
        final cardGap = screenWidth >= 700 ? 14.0 : 8.0;

        // Responsive card padding
        final cardPadding = screenWidth >= 900
            ? 16.0
            : screenWidth >= 600
                ? 12.0
                : 8.0;

        // Responsive icon size
        final iconSize = screenWidth >= 900
            ? 22.0
            : screenWidth >= 600
                ? 20.0
                : 17.0;

        final iconPadding = screenWidth >= 700 ? 9.0 : 7.0;

        // Description font
        final descFontSize = screenWidth >= 900
            ? 11.0
            : screenWidth >= 600
                ? 10.0
                : 8.5;

        // Highlight font
        final highlightFontSize = screenWidth >= 900
            ? 9.0
            : screenWidth >= 600
                ? 8.0
                : 7.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ----------------------------------------------------------
            // SECTION TITLE
            // ----------------------------------------------------------
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
              ),
              child: Column(
                children: [
                  Text(
                    'Why Choose Our Fresh Seafood',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: screenWidth >= 900
                          ? 22
                          : screenWidth >= 600
                              ? 21
                              : 19,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF063B5C),
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 7),

                  Container(
                    width: 52,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFF07566B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'Trusted quality seafood sourced directly from local fishermen',
                    textAlign: TextAlign.center,
                    softWrap: true,
                    style: TextStyle(
                      color: const Color(0xFF063B5C).withOpacity(0.65),
                      fontSize: screenWidth >= 700 ? 13 : 11,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ----------------------------------------------------------
            // THREE CARDS - ALWAYS ONE ROW
            // ----------------------------------------------------------
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: List.generate(
                    features.length,
                    (index) {
                      final feature = features[index];

                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: index == features.length - 1
                                ? 0
                                : cardGap,
                          ),
                          child: Container(
                            padding: EdgeInsets.all(cardPadding),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF07566B)
                                    .withOpacity(0.09),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF063B5C)
                                      .withOpacity(0.05),
                                  blurRadius: 14,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment:
                                  CrossAxisAlignment.center,
                              children: [
                                // ------------------------------------------------
                                // ICON
                                // ------------------------------------------------
                                Container(
                                  padding: EdgeInsets.all(iconPadding),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF07566B)
                                        .withOpacity(0.09),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    feature['icon'] as IconData,
                                    color: const Color(0xFF07566B),
                                    size: iconSize,
                                  ),
                                ),

                                const SizedBox(height: 9),

                                // ------------------------------------------------
                                // TITLE
                                // ALWAYS ONE LINE
                                // ------------------------------------------------
                                SizedBox(
                                  width: double.infinity,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      feature['title'] as String,
                                      maxLines: 1,
                                      softWrap: false,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF063B5C),
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 6),

                                // ------------------------------------------------
                                // DESCRIPTION
                                // ------------------------------------------------
                                Text(
                                  feature['desc'] as String,
                                  textAlign: TextAlign.center,
                                  softWrap: true,
                                  style: TextStyle(
                                    color: const Color(0xFF063B5C)
                                        .withOpacity(0.60),
                                    fontSize: descFontSize,
                                    fontWeight: FontWeight.w400,
                                    height: 1.4,
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // ------------------------------------------------
                                // HIGHLIGHT
                                // ------------------------------------------------
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal:
                                        screenWidth >= 700 ? 9 : 6,
                                    vertical:
                                        screenWidth >= 700 ? 5 : 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF07566B)
                                        .withOpacity(0.08),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFF07566B)
                                          .withOpacity(0.16),
                                    ),
                                  ),
                                  child: Text(
                                    feature['highlight'] as String,
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.visible,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color:
                                          const Color(0xFF07566B),
                                      fontSize: highlightFontSize,
                                      fontWeight: FontWeight.w800,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
              color: Color(0xFF063B5C),
            ),
          ),
          SizedBox(height: 6),
          Container(
            width: 50,
            height: 2,
            decoration: BoxDecoration(
              color: Color(0xFF07566B),
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
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text(
                question,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF063B5C),
                  fontSize: 13,
                ),
              ),
              children: [
                Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    answer,
                    style: TextStyle(
                      color: Color(0xFF063B5C).withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}