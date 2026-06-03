import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
  bool _isMenuOpen = false;
  bool _showDesktopSearch = false;
  bool _showMobileSearch = false;
  List<dynamic> _categories = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (widget.onSearchQueryChanged != null) {
      widget.onSearchQueryChanged!(_searchController.text);
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
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return Container(
      color: const Color(0xFF5E0006),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ========== TOP HEADER (Desktop only) ==========
            if (isDesktop)
              Container(
                height: 40,
                color: const Color(0xFF9B0F06),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.email_outlined, color: Color(0xFFEED9B9), size: 12),
                            const SizedBox(width: 6),
                            const Text(
                              'contact@seafood.com',
                              style: TextStyle(
                                color: Color(0xFFEED9B9),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 24),
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined, color: Color(0xFFEED9B9), size: 12),
                            const SizedBox(width: 6),
                            const Text(
                              '+91 98765 43210',
                              style: TextStyle(
                                color: Color(0xFFEED9B9),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {},
                          child: const Text(
                            'Contact',
                            style: TextStyle(
                              color: Color(0xFFEED9B9),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        const Icon(Icons.facebook, color: Color(0xFFEED9B9), size: 12),
                        const SizedBox(width: 12),
                        const Icon(Icons.camera_alt, color: Color(0xFFEED9B9), size: 12),
                        const SizedBox(width: 12),
                        const Icon(Icons.chat_bubble_outline, color: Color(0xFFEED9B9), size: 12),
                      ],
                    ),
                  ],
                ),
              ),

            // ========== MAIN NAVBAR ==========
            Container(
              height: isDesktop ? 72 : 60,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo
                  Row(
                    children: [
                      Container(
                        width: isDesktop ? 40 : 32,
                        height: isDesktop ? 40 : 32,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD53E0F), Color(0xFF9B0F06)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text('🐟', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'SeaFood',
                        style: TextStyle(
                          fontSize: isDesktop ? 24 : 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFEED9B9),
                        ),
                      ),
                    ],
                  ),

                  // ========== DESKTOP MENU (Center) ==========
                  if (isDesktop && _categories.isNotEmpty)
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ..._categories.map((category) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: GestureDetector(
                              onTap: () {},
                              child: Text(
                                category['name'].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                  color: Color(0xFFEED9B9),
                                ),
                              ),
                            ),
                          )),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'ABOUT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                                color: Color(0xFFEED9B9),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'CONTACT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                                color: Color(0xFFEED9B9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ========== RIGHT ICONS ==========
                  Row(
                    children: [
                      // Search Icon
                      IconButton(
                        icon: Icon(Icons.search, color: const Color(0xFFEED9B9).withOpacity(0.8), size: 20),
                        onPressed: () {
                          if (isDesktop) {
                            setState(() {
                              _showDesktopSearch = !_showDesktopSearch;
                            });
                          } else {
                            setState(() {
                              _showMobileSearch = !_showMobileSearch;
                            });
                          }
                        },
                      ),
                      // Cart Icon with Badge
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: Icon(Icons.shopping_bag_outlined, color: const Color(0xFFEED9B9).withOpacity(0.8), size: 20),
                            onPressed: widget.onCartTap,
                          ),
                          if (widget.cartCount > 0)
                            Positioned(
                              right: 4,
                              top: 4,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFD53E0F),
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                child: Text(
                                  widget.cartCount > 9 ? '9+' : '${widget.cartCount}',
                                  style: const TextStyle(
                                    color: Color(0xFFEED9B9),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      // Desktop Login Button
                      if (isDesktop)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFD53E0F), width: 0.5),
                              borderRadius: BorderRadius.circular(40),
                              color: Colors.white.withOpacity(0.05),
                            ),
                            child: const Center(
                              child: Text(
                                'LOGIN',
                                style: TextStyle(
                                  color: Color(0xFFEED9B9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Mobile Hamburger Menu Button
                      if (!isDesktop)
                        IconButton(
                          icon: Icon(
                            _isMenuOpen ? Icons.close : Icons.menu,
                            color: const Color(0xFFEED9B9).withOpacity(0.8),
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _isMenuOpen = !_isMenuOpen;
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // ========== DESKTOP SEARCH BAR ==========
            if (isDesktop && _showDesktopSearch)
              Container(
                color: const Color(0xFF5E0006),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: const TextStyle(color: Colors.black),
                          onSubmitted: (value) {
                            setState(() {
                              _showDesktopSearch = false;
                            });
                            widget.onSearchSubmit();
                          },
                          decoration: const InputDecoration(
                            hintText: 'Search products...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showDesktopSearch = false;
                          _searchController.clear();
                        });
                      },
                      child: const Icon(Icons.close, color: Color(0xFFEED9B9), size: 24),
                    ),
                  ],
                ),
              ),

            // ========== MOBILE SEARCH BAR ==========
            if (!isDesktop && _showMobileSearch)
              Container(
                color: const Color(0xFF5E0006),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: const TextStyle(color: Colors.black),
                          onSubmitted: (value) {
                            setState(() {
                              _showMobileSearch = false;
                            });
                            widget.onSearchSubmit();
                          },
                          decoration: const InputDecoration(
                            hintText: 'Search products...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showMobileSearch = false;
                          _searchController.clear();
                        });
                      },
                      child: const Icon(Icons.close, color: Color(0xFFEED9B9), size: 24),
                    ),
                  ],
                ),
              ),

            // ========== MOBILE MENU DRAWER ==========
            if (!isDesktop && _isMenuOpen)
              Container(
                color: const Color(0xFF5E0006),
                child: Column(
                  children: [
                    const Divider(color: Color(0xFFD53E0F), thickness: 1),
                    SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          _buildMenuItem('HOME', () {
                            setState(() => _isMenuOpen = false);
                          }),
                          if (_categories.isNotEmpty)
                            ..._categories.map((category) => _buildMenuItem(
                              category['name'].toUpperCase(),
                              () {
                                setState(() => _isMenuOpen = false);
                              },
                            )),
                          _buildMenuItem('ABOUT', () {
                            setState(() => _isMenuOpen = false);
                          }),
                          _buildMenuItem('CONTACT', () {
                            setState(() => _isMenuOpen = false);
                          }),
                          const SizedBox(height: 20),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            child: OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFD53E0F)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                minimumSize: const Size(double.infinity, 45),
                              ),
                              child: const Text(
                                'LOGIN',
                                style: TextStyle(
                                  color: Color(0xFFEED9B9),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: Color(0xFFEED9B9),
          ),
        ),
      ),
    );
  }
}
