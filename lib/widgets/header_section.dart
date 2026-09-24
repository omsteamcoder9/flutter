import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'auth_widget.dart';
import '../screens/product_detail_screen.dart';

class HeaderSection extends StatefulWidget {
  final int cartCount;
  final VoidCallback onCartTap;
  final VoidCallback onSearchSubmit;
  final Function(String)? onSearchQueryChanged;

  const HeaderSection({
    required this.cartCount,
    required this.onCartTap,
    required this.onSearchSubmit,
    this.onSearchQueryChanged,
    super.key,
  });

  @override
  State<HeaderSection> createState() => _HeaderSectionState();
}

class _HeaderSectionState extends State<HeaderSection> {
  List<dynamic> _categories = [];
  final TextEditingController _searchController = TextEditingController();
  String _siteName = 'Meenavan Fresh'; // Default value

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await ApiService.getPublicSettings();
      if (mounted) {
        setState(() {
          _siteName = settings['siteName'] ?? 'MeenavanFresh';
        });
      }
    } catch (e) {
      // Keep default value if API fails
      print('Error loading settings: $e');
    }
  }

  Future<void> _loadCategories() async {
    final categories = await ApiService.getCategories();
    if (mounted) {
      setState(() {
        _categories = categories;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ✅ NEW: Navigate to Home page
  void _goToHome() {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _openSearchModal() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.5),
        transitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FullScreenSearchModal(
            searchController: _searchController,
            onSearchSubmit: () {
              widget.onSearchSubmit();
              Navigator.pop(context);
            },
            onSearchQueryChanged: widget.onSearchQueryChanged,
          );
        },
      ),
    ).then((_) {
      widget.onSearchSubmit();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,       
        children: [
          // ========== TOP HEADER (ONLY LOGO + SEARCH BAR) ==========
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // ✅ Logo + Site name — tapping either goes to Home
                GestureDetector(
                  onTap: _goToHome,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/logo.jpg',
                        width: 38,
                        height: 38,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _siteName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5E0006),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Search Bar (Expanded to take remaining space)
                Expanded(
                  child: GestureDetector(
                    onTap: _openSearchModal,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFE0E0E0),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(width: 16),
                          Icon(
                            Icons.search,
                            color: Color(0xFF5E0006),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Search here...',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // ========== CATEGORIES TABS WITH IMAGES ==========
          if (_categories.isNotEmpty)
            Container(
              color: Colors.white,
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _categories.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildCategoryTabWithImage('ALL', null, index == 0, categoryId: '');
                  } else if (index == _categories.length + 1) {
                    return const SizedBox(width: 12);
                  } else {
                    final category = _categories[index - 1];
                    final imageUrl = category['image'] != null && category['image'].toString().isNotEmpty
                        ? _getCategoryImageUrl(category['image'])
                        : null;
                    return _buildCategoryTabWithImage(
                      category['name'],
                      imageUrl,
                      false,
                      categoryId: category['_id'].toString(),
                    );
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
  
  String _getCategoryImageUrl(dynamic imageData) {
    String imagePath = '';
    if (imageData is String) {
      imagePath = imageData;
    } else if (imageData is Map && imageData.containsKey('image')) {
      imagePath = imageData['image'];
    }
    if (imagePath.isEmpty) return '';
    if (imagePath.startsWith('http')) return imagePath;
    
    if (imagePath.startsWith('/')) imagePath = imagePath.substring(1);
    
    return '${ApiService.imageBaseUrl}/$imagePath';
  }
  
  Widget _buildCategoryTabWithImage(String title, String? imageUrl, bool isActive, {required String categoryId}) {
    return GestureDetector(
      onTap: () {
        if (categoryId.isNotEmpty) {
          Navigator.pushNamed(
            context,
            '/category-products',
            arguments: {
              'categoryId': categoryId,
              'categoryName': title,
            },
          );
        } else if (title == 'ALL') {
          Navigator.pushNamed(context, '/products');
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Chip(
          avatar: imageUrl != null && imageUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    width: 24,
                    height: 24,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD53E0F).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.category,
                          size: 14,
                          color: Color(0xFFD53E0F),
                        ),
                      );
                    },
                  ),
                )
              : null,
          label: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : const Color(0xFF5E0006),
            ),
          ),
          backgroundColor: isActive ? const Color(0xFF5E0006) : const Color(0xFFF5F5F5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isActive ? const Color(0xFF5E0006) : Colors.transparent,
              width: 0,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
      ),
    );
  }
}

// ========== FULL SCREEN SEARCH MODAL ==========
class FullScreenSearchModal extends StatefulWidget {
  final TextEditingController searchController;
  final VoidCallback onSearchSubmit;
  final Function(String)? onSearchQueryChanged;
  final String? guestId;
  final String? token;

  const FullScreenSearchModal({
    super.key,
    required this.searchController,
    required this.onSearchSubmit,
    this.onSearchQueryChanged,
    this.guestId,
    this.token,
  });

  @override
  State<FullScreenSearchModal> createState() => _FullScreenSearchModalState();
}

class _FullScreenSearchModalState extends State<FullScreenSearchModal> {
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    widget.searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (widget.onSearchQueryChanged != null) {
      widget.onSearchQueryChanged!(widget.searchController.text);
    }
    _performSearch();
  }

  Future<void> _performSearch() async {
    final query = widget.searchController.text.trim();
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await ApiService.searchProducts(query);
      
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  void _handleSearchSubmit() {
    if (widget.searchController.text.trim().isNotEmpty) {
      widget.onSearchSubmit();
      Navigator.pop(context);
    }
  }

  void _clearSearch() {
    widget.searchController.clear();
    setState(() {
      _searchResults = [];
    });
  }

  void _navigateToProduct(dynamic product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(
          productId: product['_id'],
          guestId: widget.guestId,
          token: widget.token,
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onSearchChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFF5E0006),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFD53E0F).withOpacity(0.3),
                          ),
                        ),
                        child: TextField(
                          controller: widget.searchController,
                          focusNode: _focusNode,
                          autofocus: true,
                          style: const TextStyle(
                            color: Color(0xFFEED9B9),
                            fontSize: 16,
                          ),
                          onSubmitted: (_) => _handleSearchSubmit(),
                          decoration: InputDecoration(
                            hintText: 'Search products...',
                            hintStyle: TextStyle(
                              color: const Color(0xFFEED9B9).withOpacity(0.6),
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: const Color(0xFFD53E0F),
                              size: 22,
                            ),
                            suffixIcon: widget.searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      color: const Color(0xFFEED9B9).withOpacity(0.7),
                                      size: 20,
                                    ),
                                    onPressed: _clearSearch,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _handleSearchSubmit,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFD53E0F).withOpacity(0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.search,
                          color: Color(0xFFEED9B9),
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFD53E0F).withOpacity(0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Color(0xFFEED9B9),
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFD53E0F).withOpacity(0.3),
                    ),
                  ),
                  child: _buildResultsContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsContent() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD53E0F)),
            ),
            SizedBox(height: 16),
            Text(
              'Searching...',
              style: TextStyle(color: Color(0xFFEED9B9), fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty && widget.searchController.text.isNotEmpty) {
      return const Center(
        child: Text(
          'No products found',
          style: TextStyle(color: Color(0xFFEED9B9), fontSize: 14),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          'Start typing to search products',
          style: TextStyle(color: Color(0xFFEED9B9), fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final product = _searchResults[index];
        return _buildSearchResultItem(product);
      },
    );
  }

  Widget _buildSearchResultItem(dynamic product) {
    String? imageUrl;
    if (product['image'] != null) {
      String imagePath = product['image'];
      if (imagePath.startsWith('/')) {
        imagePath = imagePath.substring(1);
      }
      imageUrl = '${ApiService.imageBaseUrl}/$imagePath';
    }

    String categoryName = '';
    if (product['category'] is Map) {
      categoryName = product['category']['name'] ?? 'Category';
    } else if (product['category'] is String) {
      categoryName = product['category'];
    } else {
      categoryName = 'Category';
    }

    return GestureDetector(
      onTap: () => _navigateToProduct(product),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFD53E0F).withOpacity(0.3),
                ),
              ),
              child: imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.restaurant_menu,
                              color: Color(0xFFEED9B9),
                              size: 24,
                            ),
                          );
                        },
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.restaurant_menu,
                        color: Color(0xFFEED9B9),
                        size: 24,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] ?? 'Product Name',
                    style: const TextStyle(
                      color: Color(0xFFEED9B9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        categoryName,
                        style: const TextStyle(
                          color: Color(0xFFD53E0F),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '₹${product['price'] ?? product['basePrice'] ?? 0}',
                        style: const TextStyle(
                          color: Color(0xFFEED9B9),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}