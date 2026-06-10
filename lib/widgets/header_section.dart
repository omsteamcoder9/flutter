import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'auth_widget.dart';

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

  @override
  void initState() {
    super.initState();
    _loadCategories();
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
    );
  }

  @override
  Widget build(BuildContext context) {
    print('🛒 HeaderSection build - cartCount: ${widget.cartCount}');

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ========== MAIN HEADER ==========
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo Left
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD53E0F), Color(0xFF5E0006)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text('🐟', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'SeaFood',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5E0006),
                        ),
                      ),
                    ],
                  ),
                  
                  // Right Icons: Search, Profile, Cart
                  Row(
                    children: [
                      // Search Icon
                      GestureDetector(
                        onTap: _openSearchModal,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF5E0006).withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.search,
                            color: Color(0xFF5E0006),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // Profile Icon - Using AuthIconWidget
                      const AuthIconWidget(),
                      
                      const SizedBox(width: 8),
                      
                      // Cart Icon with Badge
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          GestureDetector(
                            onTap: widget.onCartTap,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF5E0006).withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.shopping_bag_outlined,
                                color: const Color(0xFF5E0006),
                                size: 20,
                              ),
                            ),
                          ),
                          if (widget.cartCount > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFD53E0F),
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                child: Text(
                                  widget.cartCount > 9 ? '9+' : '${widget.cartCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // ========== CATEGORIES TABS ==========
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
                      return _buildCategoryTab('ALL', index == 0, categoryId: '');
                    } else if (index == _categories.length + 1) {
                      return const SizedBox(width: 12);
                    } else {
                      final category = _categories[index - 1];
                      // ✅ FIX: Pass the categoryId
                      return _buildCategoryTab(
                        category['name'].toUpperCase(),
                        false,
                        categoryId: category['_id'].toString(),
                      );
                    }
                  },
                ),
              ),
            
            // ========== BOTTOM NAVIGATION BAR (Desktop) ==========
            if (isDesktop)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBottomNavItem(Icons.home, 'Home', 0),
                    _buildBottomNavItem(Icons.search, 'Explore', 0),
                    _buildBottomNavItem(Icons.shopping_bag, 'Cart', widget.cartCount),
                    _buildBottomNavItem(Icons.person, 'Profile', 0),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // ✅ UPDATED: _buildCategoryTab with categoryId parameter
  Widget _buildCategoryTab(String title, bool isActive, {required String categoryId}) {
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
          // Navigate to all products page
          Navigator.pushNamed(context, '/products');
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Chip(
          label: Text(
            title,
            style: TextStyle(
              fontSize: 13,
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
  
  Widget _buildBottomNavItem(IconData icon, String label, int badgeCount) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              icon,
              color: const Color(0xFF5E0006).withOpacity(0.7),
              size: 22,
            ),
            if (badgeCount > 0)
              Positioned(
                right: -8,
                top: -8,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(0xFFD53E0F),
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: const Color(0xFF5E0006).withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ========== FULL SCREEN SEARCH MODAL ==========
class FullScreenSearchModal extends StatefulWidget {
  final TextEditingController searchController;
  final VoidCallback onSearchSubmit;
  final Function(String)? onSearchQueryChanged;

  const FullScreenSearchModal({
    super.key,
    required this.searchController,
    required this.onSearchSubmit,
    this.onSearchQueryChanged,
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
              // Top bar with search input and buttons
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Search input field
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
                    
                    // Search button
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
                    
                    // Close button
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
              
              // Search results area
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
      itemCount: _searchResults.length + 1,
      itemBuilder: (context, index) {
        if (index == _searchResults.length) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: GestureDetector(
              onTap: _handleSearchSubmit,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFD53E0F).withOpacity(0.3),
                  ),
                ),
                child: Center(
                  child: Text(
                    'View all results for "${widget.searchController.text}"',
                    style: const TextStyle(
                      color: Color(0xFFEED9B9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        }

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

    // Get category name safely
    String categoryName = '';
    if (product['category'] is Map) {
      categoryName = product['category']['name'] ?? 'Category';
    } else if (product['category'] is String) {
      categoryName = product['category'];
    } else {
      categoryName = 'Category';
    }

    return GestureDetector(
      onTap: () {
        widget.onSearchSubmit();
        Navigator.pop(context);
      },
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