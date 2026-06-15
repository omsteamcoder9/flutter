import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui' as ui;
import '../screens/product_detail_screen.dart';

class HeroSection extends StatefulWidget {
  final List<dynamic> products;
  final String imageBaseUrl;

  const HeroSection({
    required this.products,
    required this.imageBaseUrl,
    super.key,
  });

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection> with TickerProviderStateMixin {
  int _currentSlide = 0;
  late Timer _timer;
  final Map<int, bool> _imageErrors = {};
  bool _entranceAnimationDone = false;
  bool _isHoveringButton = false;
  int _animationTrigger = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _entranceAnimationDone = true;
          _animationTrigger++;
        });
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (widget.products.isNotEmpty && mounted) {
        setState(() {
          _currentSlide = (_currentSlide + 1) % widget.products.length;
          _animationTrigger++;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _getImageUrl(dynamic product) {
    final imgBaseUrl = widget.imageBaseUrl;
    
    if (product['variants'] != null && product['variants'].isNotEmpty) {
      final variant = product['variants'][0];
      if (variant['images'] != null && variant['images'].isNotEmpty) {
        String imagePath = variant['images'][0]['image'];
        if (imagePath.startsWith('http')) return imagePath;
        if (imagePath.startsWith('/')) imagePath = imagePath.substring(1);
        return '$imgBaseUrl/$imagePath';
      }
    }
    
    if (product['ogImage'] != null && product['ogImage'].toString().isNotEmpty) {
      String imagePath = product['ogImage'];
      if (imagePath.startsWith('/')) imagePath = imagePath.substring(1);
      return '$imgBaseUrl/$imagePath';
    }
    
    return '';
  }

  String _getProductName(dynamic product) {
    String name = product['name'] ?? 'Seafood';
    if (name.length > 25) {
      name = name.substring(0, 22) + '...';
    }
    return name;
  }

  Map<String, dynamic> _getProductOfferInfo(dynamic product) {
    final basePrice = (product['basePrice'] ?? 0).toDouble();

    if (product['variants'] != null && product['variants'].isNotEmpty) {
      final variant = product['variants'][0];
      final price = (variant['price'] ?? basePrice).toDouble();
      final originalPrice = variant['originalPrice'] != null
          ? (variant['originalPrice'] as num).toDouble()
          : null;

      if (originalPrice != null && originalPrice > price) {
        return {
          'hasOffer': true,
          'originalPrice': originalPrice,
          'discountedPrice': price,
        };
      }
      return {
        'hasOffer': false,
        'originalPrice': price,
        'discountedPrice': price,
      };
    }

    return {
      'hasOffer': false,
      'originalPrice': basePrice,
      'discountedPrice': basePrice,
    };
  }

  String _formatPrice(double price) {
    return '₹${price.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) {
      return Container(
        height: 350,
        color: const Color(0xFF5E0006),
        child: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD53E0F)),
            ),
          ),
        ),
      );
    }

    final currentProduct = widget.products[_currentSlide];
    final imageUrl = _getImageUrl(currentProduct);
    final productName = _getProductName(currentProduct);
    final offerInfo = _getProductOfferInfo(currentProduct);
    final discountedPrice = offerInfo['discountedPrice'] as double;

    return Container(
      width: double.infinity,
      color: const Color(0xFF5E0006),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image Section
          AnimatedOpacity(
            opacity: _entranceAnimationDone ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 600),
            child: _buildCircularImage(imageUrl, _currentSlide),
          ),
          
          const SizedBox(height: 16),
          
          // Content Card
          AnimatedOpacity(
            opacity: _entranceAnimationDone ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 600),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Product Name
                  TweenAnimationBuilder(
                    key: ValueKey('name_${_currentSlide}_${_animationTrigger}'),
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 10 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      productName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5E0006),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Price
                  TweenAnimationBuilder(
                    key: ValueKey('price_${_currentSlide}_${_animationTrigger}'),
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 10 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      _formatPrice(discountedPrice),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD53E0F),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Description
                  TweenAnimationBuilder(
                    key: ValueKey('desc_${_currentSlide}_${_animationTrigger}'),
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 10 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      'Fresh premium quality seafood delivered to your doorstep',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // View More Button
                  TweenAnimationBuilder(
                    key: ValueKey('button_${_currentSlide}_${_animationTrigger}'),
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 10 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductDetailScreen(
                              productId: currentProduct['_id'],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5E0006),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'VIEW DETAILS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward,
                              size: 14,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Dot Indicators
                  _buildDotIndicators(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularImage(String imageUrl, int slideIndex) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD53E0F).withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 3,
              ),
            ),
            child: ClipOval(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                child: KeyedSubtree(
                  key: ValueKey(slideIndex),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFF9B0F06),
                              child: const Icon(
                                Icons.image_not_supported,
                                color: Color(0xFFD53E0F),
                                size: 35,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: const Color(0xFF9B0F06),
                          child: const Icon(
                            Icons.image,
                            color: Color(0xFFD53E0F),
                            size: 35,
                          ),
                        ),
                ),
              ),
            ),
          ),
          // Fresh Badge
          Positioned(
            bottom: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD53E0F),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fiber_manual_record, size: 8, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'FRESH',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDotIndicators() {
    final visibleCount = widget.products.length > 5 ? 5 : widget.products.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(visibleCount, (index) {
        return GestureDetector(
          onTap: () {
            setState(() {
              _currentSlide = index;
              _animationTrigger++;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _currentSlide == index ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: _currentSlide == index
                  ? const Color(0xFFD53E0F)
                  : const Color(0xFFD53E0F).withOpacity(0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}