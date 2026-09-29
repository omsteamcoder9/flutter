import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../widgets/product_card.dart';
import '../widgets/header_section.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/cart_drawer.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import 'dart:convert';
import '../screens/auth/signup_screen.dart';
import 'package:provider/provider.dart';
import '../screens/profile/profile_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final String? productId;
  final String? productSlug;
  final String? guestId;
  final String? token;
  final VoidCallback? onCartUpdate;

  const ProductDetailScreen({
    super.key,
    this.productId,
    this.productSlug,
    this.guestId,
    this.token,
    this.onCartUpdate,
  });

  @override
  State<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState
    extends State<ProductDetailScreen> {
  Map<String, dynamic>? _product;
  List<dynamic> _variants = [];
  Map<String, dynamic>? _selectedVariant;
  List<dynamic> _relatedProducts = [];
  bool _isLoading = true;
  String? _error;
  int _quantity = 1;
  int _selectedImageIndex = 0;
  bool _isAddingToCart = false;
  bool _showAddedMessage = false;

  String? _guestId;
  String? _authToken;
  int _cartCount = 0;
  int _currentIndex = 0;

  late CartProvider _cartProvider;
  late AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _loadGuestIdAndToken();
    _loadProduct();
    _refreshCartCount();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _cartProvider =
        Provider.of<CartProvider>(context, listen: false);

    _authProvider =
        Provider.of<AuthProvider>(context, listen: false);

    if (_guestId != null && _guestId!.isNotEmpty) {
      _cartProvider.initialize(
        guestId: _guestId!,
        token: _authProvider.isLoggedIn
            ? _authProvider.token
            : null,
        isLoggedIn: _authProvider.isLoggedIn,
      );

      _cartProvider.refreshCartCount();
    }
  }

  Future<void> _refreshCartCount() async {
    try {
      String? guestIdToUse =
          _authProvider.isLoggedIn ? null : _guestId;

      String? tokenToUse =
          _authProvider.isLoggedIn
              ? _authProvider.token
              : null;

      final response = await ApiService.getCart(
        guestId: guestIdToUse,
        token: tokenToUse,
      );

      if (response['success'] == true && mounted) {
        final newCount =
            response['data']?['totalItems'] ?? 0;

        setState(() {
          _cartCount = newCount;
        });
      }
    } catch (e) {
      print('Error refreshing cart: $e');
    }
  }

  Future<void> _loadGuestIdAndToken() async {
    final prefs =
        await SharedPreferences.getInstance();

    setState(() {
      _guestId = widget.guestId ??
          prefs.getString('guest_id') ??
          'guest_${DateTime.now().millisecondsSinceEpoch}';

      _authToken = widget.token ??
          prefs.getString('auth_token');
    });
  }

  Future<void> _loadProduct() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      Map<String, dynamic>? productData;

      if (widget.productSlug != null) {
        productData =
            await ApiService.getProductBySlug(
          widget.productSlug!,
        );
      } else if (widget.productId != null) {
        productData =
            await ApiService.getProductById(
          widget.productId!,
        );
      }

      if (productData != null) {
        setState(() {
          _product = productData;

          if (_product!['variants'] != null &&
              _product!['variants'].isNotEmpty) {
            _variants = _product!['variants'];
            _selectedVariant = _variants[0];
          }

          _isLoading = false;
        });

        await _loadRelatedProducts();
      } else {
        setState(() {
          _error = 'Product not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRelatedProducts() async {
    try {
      final response =
          await ApiService.getProducts(limit: 4);

      setState(() {
        _relatedProducts =
            response['products'];
      });
    } catch (e) {
      print('Error loading related products: $e');
    }
  }

  String _getImageUrl(dynamic imageData) {
    String imagePath = '';

    if (imageData is String) {
      imagePath = imageData;
    } else if (imageData is Map &&
        imageData.containsKey('image')) {
      imagePath = imageData['image'];
    }

    if (imagePath.isEmpty) return '';

    if (imagePath.startsWith('http')) {
      return imagePath;
    }

    if (imagePath.startsWith('/')) {
      imagePath = imagePath.substring(1);
    }

    if (imagePath.startsWith('uploads/')) {
      imagePath = imagePath.substring(8);
    }

    final baseUrl =
        dotenv.env['IMG_BASE_URL'] ??
            ApiService.imageBaseUrl;

    return '$baseUrl/$imagePath';
  }

  List<dynamic> _getCurrentImages() {
    if (_selectedVariant != null &&
        _selectedVariant!.containsKey('images') &&
        _selectedVariant!['images'] != null &&
        (_selectedVariant!['images'] as List).isNotEmpty) {
      return _selectedVariant!['images'];
    }

    if (_product != null &&
        _product!.containsKey('images') &&
        _product!['images'] != null &&
        (_product!['images'] as List).isNotEmpty) {
      return _product!['images'];
    }

    if (_product != null &&
        _product!['ogImage'] != null &&
        _product!['ogImage']
            .toString()
            .isNotEmpty) {
      return [
        {'image': _product!['ogImage']}
      ];
    }

    return [];
  }

  double _getCurrentPrice() {
    return _selectedVariant?['price']?.toDouble() ??
        _product?['basePrice']?.toDouble() ??
        0;
  }

  int _getCurrentStock() {
    return _selectedVariant?['stock'] ??
        _product?['stock'] ??
        0;
  }

  bool _isOutOfStock() {
    return _getCurrentStock() <= 0;
  }

  String _getWeightDisplay() {
    final weight = _selectedVariant?['weight'];
    final unit = _selectedVariant?['weightUnit'];

    if (weight != null &&
        unit != null &&
        weight > 0) {
      double displayWeight = weight.toDouble();
      String displayUnit = unit;

      if (unit == 'gram' && weight >= 1000) {
        displayWeight = weight / 1000;
        displayUnit = 'kg';
      }

      final formattedWeight =
          displayWeight ==
                  displayWeight.toInt().toDouble()
              ? displayWeight.toInt().toString()
              : displayWeight.toStringAsFixed(2);

      return '$formattedWeight $displayUnit';
    }

    return _selectedVariant?['variantName'] ?? '';
  }

  String _getCurrentDescription() {
    return _selectedVariant?['description'] ??
        _product?['description'] ??
        '';
  }

  List<String> _getCurrentFeatures() {
    if (_selectedVariant != null &&
        _selectedVariant!.containsKey('features') &&
        _selectedVariant!['features'] != null &&
        (_selectedVariant!['features'] as List)
            .isNotEmpty) {
      return List<String>.from(
        _selectedVariant!['features'],
      );
    }

    if (_product != null &&
        _product!.containsKey('keyFeatures') &&
        _product!['keyFeatures'] != null &&
        (_product!['keyFeatures'] as List)
            .isNotEmpty) {
      return List<String>.from(
        _product!['keyFeatures'],
      );
    }

    return [];
  }

  List<dynamic> _getSpecifications() {
    if (_product != null &&
        _product!.containsKey('specifications') &&
        _product!['specifications'] != null &&
        (_product!['specifications'] as List)
            .isNotEmpty) {
      return _product!['specifications'];
    }

    return [];
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  void _openCart() {
    String? guestIdToUse =
        _authProvider.isLoggedIn ? null : _guestId;

    String? tokenToUse =
        _authProvider.isLoggedIn
            ? _authProvider.token
            : null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartScreen(
          guestId: guestIdToUse,
          token: tokenToUse,
          onCartUpdate: () {
            _refreshCartCount();
            _cartProvider.refreshCartCount();
          },
        ),
      ),
    );
  }

  void _showAuthDialog() {
    if (_authProvider.isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ProfileScreen(),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const SignupScreen(),
        ),
      );
    }
  }

  void _navigateToHome() {
    Navigator.popUntil(
      context,
      (route) => route.isFirst,
    );
  }

  void _onSearchSubmit() {}

  void _onSearchQueryChanged(String query) {}

  // ============================================================
  // ADD TO CART
  // ============================================================

  Future<void> _addToCartProduct(
      dynamic product) async {
    if (_isOutOfStock()) return;

    // STEP 1: Optimistic Update
    _cartProvider.addItemLocally(product);

    setState(() {
      _showAddedMessage = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Added to cart!'),
        duration: Duration(seconds: 1),
        backgroundColor: Color(0xFF07566B),
      ),
    );

    if (widget.onCartUpdate != null) {
      widget.onCartUpdate!();
    }

    // STEP 2: API call in background
    try {
      String variantId = '';

      if (product['variants'] != null &&
          product['variants'].isNotEmpty) {
        variantId =
            product['variants'][0]['_id'] ?? '';
      }

      double price =
          product['price'] ?? _getCurrentPrice();

      final response =
          await ApiService.addToCart(
        product['_id'],

        // FIX:
        // Use selected quantity instead of always 1.
        _quantity,

        variantId,
        guestId: _guestId,
        token: _authToken,
      );

      if (response['success'] == true) {
        await _cartProvider.refreshCartCount();

        if (widget.onCartUpdate != null) {
          widget.onCartUpdate!();
        }
      } else {
        throw Exception(
          response['message'] ??
              'Failed to add to cart',
        );
      }
    } catch (e) {
      // STEP 3: Revert if failed
      _cartProvider.removeItemLocally(product);

      if (mounted) {
        setState(() {
          _showAddedMessage = false;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // Hide "Added!" message after 2 seconds
    Future.delayed(
      const Duration(seconds: 2),
      () {
        if (mounted) {
          setState(() {
            _showAddedMessage = false;
          });
        }
      },
    );
  }

  Future<void> _addToCart() async {
    if (_isOutOfStock()) return;

    await _addToCartProduct(_product!);
  }

  Future<void> _buyNow() async {
    if (_isOutOfStock()) return;

    setState(() {
      _isAddingToCart = true;
    });

    try {
      final prefs =
          await SharedPreferences.getInstance();

      final buyNowOrder = {
        'productId': _product!['_id'],
        'productName': _product!['name'],
        'quantity': _quantity,
        'variantId':
            _selectedVariant?['_id'] ?? '',
        'variantName':
            _selectedVariant?['variantName'] ?? '',
        'price': _getCurrentPrice(),
        'imageUrl': _getCurrentImages().isNotEmpty
            ? _getImageUrl(
                _getCurrentImages()[0],
              )
            : '',
      };

      await prefs.setString(
        'buy_now_order',
        jsonEncode(buyNowOrder),
      );

      await prefs.setBool(
        'pending_checkout',
        true,
      );

      final token =
          prefs.getString('auth_token');

      if (mounted) {
        if (token == null || token.isEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  SignupScreen(
                guestId: _guestId,
              ),
            ),
          );
        } else {
          Navigator.pushNamed(
            context,
            '/checkout',
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAddingToCart = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartCount =
        Provider.of<CartProvider>(context)
            .cartCount;

    final cartProductIds =
        Provider.of<CartProvider>(context)
            .cartProductIds;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          HeaderSection(
            cartCount: cartCount,
            onCartTap: _openCart,
            onSearchSubmit: _onSearchSubmit,
            onSearchQueryChanged:
                _onSearchQueryChanged,
          ),

          Expanded(
            child: _buildBody(
              cartProductIds,
            ),
          ),
        ],
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

  Widget _buildBody(
      Set<String> cartProductIds) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child:
                  CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(
                  Color(0xFF07566B),
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Loading product details...',
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProduct,
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF07566B),
              ),
              child:
                  const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_product == null) {
      return const Center(
        child: Text('Product not found'),
      );
    }

    final currentImages =
        _getCurrentImages();

    final currentPrice =
        _getCurrentPrice();

    final isOutOfStock =
        _isOutOfStock();

    final weightDisplay =
        _getWeightDisplay();

    final currentDescription =
        _getCurrentDescription();

    final currentFeatures =
        _getCurrentFeatures();

    final specifications =
        _getSpecifications();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildImageSection(
            currentImages,
          ),

          Padding(
            padding:
                const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  _product!['name'] ?? '',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight:
                        FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),

                if (weightDisplay.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    weightDisplay,
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          Colors.grey.shade600,
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                Text(
                  '₹${_formatPrice(currentPrice)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(0xFF07566B),
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(
                        color: isOutOfStock
                            ? Colors.red
                            : Colors.green,
                        shape:
                            BoxShape.circle,
                      ),
                    ),

                    const SizedBox(width: 6),

                    Text(
                      isOutOfStock
                          ? 'Out of Stock'
                          : 'In Stock',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOutOfStock
                            ? Colors.red
                            : Colors.green,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                if (_variants.length > 1)
                  _buildVariantSelection(),

                const SizedBox(height: 16),

                _buildQuantitySelector(
                  isOutOfStock,
                ),

                const SizedBox(height: 16),

                _buildActionButtons(
                  isOutOfStock,
                ),

                const SizedBox(height: 32),

                if (currentDescription
                    .isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildDescriptionSection(
                    currentDescription,
                  ),
                ],

                if (currentFeatures
                    .isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildKeyFeaturesSection(
                    currentFeatures,
                  ),
                ],

                if (specifications
                    .isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildSpecificationsSection(
                    specifications,
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),

          if (_relatedProducts.isNotEmpty)
            _buildRelatedProductsSection(
              cartProductIds,
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildImageSection(
      List<dynamic> images) {
    if (images.isEmpty) {
      return Container(
        height: 350,
        color: Colors.grey.shade100,
        child: const Center(
          child: Icon(
            Icons.image,
            size: 80,
            color: Colors.grey,
          ),
        ),
      );
    }

    final imageUrls = images
        .map((img) => _getImageUrl(img))
        .where(
          (url) => url.isNotEmpty,
        )
        .toList();

    if (imageUrls.isEmpty) {
      return Container(
        height: 350,
        color: Colors.grey.shade100,
        child: const Center(
          child: Icon(
            Icons.image_not_supported,
            size: 80,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          height: 350,
          color: Colors.white,
          child: Image.network(
            imageUrls[_selectedImageIndex],
            fit: BoxFit.contain,
            width: double.infinity,
            errorBuilder:
                (context, error, stackTrace) {
              return Container(
                color: Colors.grey.shade100,
                child: const Icon(
                  Icons.image_not_supported,
                  size: 50,
                ),
              );
            },
          ),
        ),

        if (imageUrls.length > 1)
          Container(
            height: 70,
            padding:
                const EdgeInsets.symmetric(
              vertical: 8,
            ),
            child: ListView.builder(
              scrollDirection:
                  Axis.horizontal,
              itemCount: imageUrls.length,
              itemBuilder:
                  (context, index) {
                final isSelected =
                    _selectedImageIndex ==
                        index;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedImageIndex =
                          index;
                    });
                  },
                  child: Container(
                    width: 60,
                    margin:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 4,
                    ),
                    decoration:
                        BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? const Color(
                                0xFF07566B,
                              )
                            : Colors.grey
                                .shade300,
                        width: 2,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius
                              .circular(6),
                      child: Image.network(
                        imageUrls[index],
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context,
                                error,
                                stackTrace) {
                          return Container(
                            color: Colors
                                .grey
                                .shade200,
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildVariantSelection() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Pack:',
          style: TextStyle(
            fontSize: 14,
            fontWeight:
                FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),

        const SizedBox(height: 8),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              _variants.map((variant) {
            String displayName = '';

            if (variant['weight'] != null &&
                variant['weightUnit'] != null) {
              double weight =
                  variant['weight'].toDouble();

              String unit =
                  variant['weightUnit'];

              if (unit == 'gram' &&
                  weight >= 1000) {
                weight = weight / 1000;
                unit = 'kg';
              }

              final formattedWeight =
                  weight ==
                          weight
                              .toInt()
                              .toDouble()
                      ? weight
                          .toInt()
                          .toString()
                      : weight.toStringAsFixed(
                          2,
                        );

              displayName =
                  '$formattedWeight $unit';
            } else {
              displayName =
                  variant['variantName'] ??
                      variant['name'] ??
                      '';
            }

            final isSelected =
                _selectedVariant != null &&
                    _selectedVariant!['_id'] ==
                        variant['_id'];

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedVariant =
                      variant;

                  _selectedImageIndex = 0;

                  _quantity = 1;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration:
                    BoxDecoration(
                  color: isSelected
                      ? const Color(
                          0xFF07566B,
                        )
                      : const Color(
                          0xFF063B5C,
                        ),
                  borderRadius:
                      BorderRadius.circular(
                    8,
                  ),
                  border: Border.all(
                    color: const Color(
                      0xFF07566B,
                    ),
                  ),
                ),
                child: Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : const Color(
                            0xFFE0F0F5,
                          ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQuantitySelector(
      bool isOutOfStock) {
    final stock =
        _getCurrentStock();

    return Row(
      children: [
        const Text(
          'Quantity:',
          style: TextStyle(
            fontSize: 14,
            fontWeight:
                FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),

        const SizedBox(width: 16),

        Container(
          decoration:
              BoxDecoration(
            border: Border.all(
              color:
                  Colors.grey.shade300,
            ),
            borderRadius:
                BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed:
                    _quantity > 1
                        ? () {
                            setState(() {
                              _quantity--;
                            });
                          }
                        : null,
                icon: const Icon(
                  Icons.remove,
                  size: 18,
                ),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
              ),

              SizedBox(
                width: 40,
                child: Text(
                  '$_quantity',
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ),

              IconButton(
                onPressed:
                    (!isOutOfStock &&
                            _quantity <
                                stock)
                        ? () {
                            setState(() {
                              _quantity++;
                            });
                          }
                        : null,
                icon: const Icon(
                  Icons.add,
                  size: 18,
                ),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
      bool isOutOfStock) {
    final bool isInCart =
        _cartProvider.cartProductIds
            .contains(
      _product?['_id'],
    );

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap:
                (isOutOfStock ||
                        isInCart)
                    ? null
                    : _addToCart,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                vertical: 14,
              ),
              decoration:
                  BoxDecoration(
                color: isOutOfStock
                    ? Colors.grey.shade400
                    : const Color(
                        0xFF07566B,
                      ),
                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
              ),
              child: Center(
                child: isInCart
                    ? const Row(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check,
                            color:
                                Colors.white,
                            size: 16,
                          ),
                          SizedBox(
                            width: 6,
                          ),
                          Text(
                            'In Cart ✓',
                            style:
                                TextStyle(
                              color:
                                  Colors.white,
                              fontSize: 13,
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                        ],
                      )
                    : (_isAddingToCart
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color:
                                  Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisSize:
                                MainAxisSize
                                    .min,
                            children: [
                              const Icon(
                                Icons
                                    .shopping_bag_outlined,
                                color:
                                    Colors.white,
                                size: 16,
                              ),
                              const SizedBox(
                                width: 6,
                              ),
                              Text(
                                isOutOfStock
                                    ? 'Out of Stock'
                                    : 'Add to Cart',
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.white,
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight
                                          .w600,
                                ),
                              ),
                            ],
                          )),
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: GestureDetector(
            onTap:
                isOutOfStock
                    ? null
                    : _buyNow,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                vertical: 14,
              ),
              decoration:
                  BoxDecoration(
                color: isOutOfStock
                    ? Colors.grey.shade300
                    : Colors.black,
                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Icon(
                      Icons
                          .shopping_cart_outlined,
                      color: isOutOfStock
                          ? Colors.grey
                              .shade500
                          : Colors.white,
                      size: 16,
                    ),
                    const SizedBox(
                      width: 6,
                    ),
                    Text(
                      'Buy Now',
                      style: TextStyle(
                        color: isOutOfStock
                            ? Colors.grey
                                .shade500
                            : Colors.white,
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection(
      String description) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(
            fontSize: 18,
            fontWeight:
                FontWeight.bold,
            color: Color(0xFF063B5C),
          ),
        ),

        const SizedBox(height: 12),

        Text(
          description,
          style: TextStyle(
            fontSize: 14,
            color:
                Colors.grey.shade700,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildKeyFeaturesSection(
      List<String> features) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Key Features',
          style: TextStyle(
            fontSize: 18,
            fontWeight:
                FontWeight.bold,
            color: Color(0xFF063B5C),
          ),
        ),

        const SizedBox(height: 12),

        ...features.map(
          (feature) => Padding(
            padding:
                const EdgeInsets.only(
              bottom: 12,
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  '✓  ',
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        Color(0xFF07566B),
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                Expanded(
                  child: Text(
                    feature,
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecificationsSection(
      List<dynamic> specifications) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Specifications',
          style: TextStyle(
            fontSize: 18,
            fontWeight:
                FontWeight.bold,
            color: Color(0xFF063B5C),
          ),
        ),

        const SizedBox(height: 12),

        ...specifications.map(
          (spec) => Padding(
            padding:
                const EdgeInsets.only(
              bottom: 12,
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 130,
                  child: Text(
                    spec['key'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          FontWeight.w600,
                      color:
                          Colors.grey.shade800,
                    ),
                  ),
                ),

                Expanded(
                  child: Text(
                    spec['value'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedProductsSection(
      Set<String> cartProductIds) {
    return Column(
      children: [
        const Padding(
          padding:
              EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Text(
            'You may also like',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),

        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection:
                Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 12,
            ),
            itemCount:
                _relatedProducts.length,
            itemBuilder:
                (context, index) {
              final product =
                  _relatedProducts[index];

              return Container(
                width: 160,
                margin:
                    const EdgeInsets.symmetric(
                  horizontal: 4,
                ),
                child: ProductCard(
                  product: product,
                  onAddToCart: () =>
                      _addToCartProduct(
                    product,
                  ),
                  guestId: _guestId,
                  token:
                      _authProvider.isLoggedIn
                          ? _authProvider.token
                          : null,
                  onCartUpdate: () {
                    _refreshCartCount();
                    _cartProvider
                        .refreshCartCount();
                  },
                  cartProductIds:
                      cartProductIds,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}