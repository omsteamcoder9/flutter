import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui' as ui;

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
  
  // PRIORITY 1: Get image from variants (FIRST)
  if (product['variants'] != null && product['variants'].isNotEmpty) {
    final variant = product['variants'][0];
    if (variant['images'] != null && variant['images'].isNotEmpty) {
      String imagePath = variant['images'][0]['image'];
      if (imagePath.startsWith('http')) return imagePath;
      if (imagePath.startsWith('/')) imagePath = imagePath.substring(1);
      // DO NOT remove 'uploads/'
      return '$imgBaseUrl/$imagePath';
    }
  }
  
  // PRIORITY 2: Fallback to ogImage
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
        height: 400,
        color: const Color(0xFF5E0006),
        child: const Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
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
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // IMAGE SECTION - Top Center
              AnimatedOpacity(
                opacity: _entranceAnimationDone ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 800),
                child: AnimatedSlide(
                  offset: _entranceAnimationDone ? Offset.zero : const Offset(0, -0.1),
                  duration: const Duration(milliseconds: 800),
                  child: _buildCircularImage(imageUrl, _currentSlide),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // CONTENT SECTION - Pill Container with Backdrop Blur (Full rounded)
              AnimatedOpacity(
                opacity: _entranceAnimationDone ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 800),
                child: AnimatedSlide(
                  offset: _entranceAnimationDone ? Offset.zero : const Offset(0, 0.1),
                  duration: const Duration(milliseconds: 800),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF9B0F06).withOpacity(0.8),
                          border: Border.all(
                            color: const Color(0xFFD53E0F).withOpacity(0.3),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Animated Text Content
                              _buildAnimatedText(
                                productName: productName,
                                discountedPrice: discountedPrice,
                                currentSlide: _currentSlide,
                              ),
                              const SizedBox(height: 20),
                              // Dot Indicators
                              _buildDotIndicators(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircularImage(String imageUrl, int slideIndex) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow effect
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD53E0F).withOpacity(0.15),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
          // Border
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFEED9B9).withOpacity(0.2),
                width: 4,
              ),
            ),
            child: ClipOval(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 800),
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
                                size: 40,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: const Color(0xFF9B0F06),
                          child: const Icon(
                            Icons.image,
                            color: Color(0xFFD53E0F),
                            size: 40,
                          ),
                        ),
                ),
              ),
            ),
          ),
          // Fresh badge (100%)
          Positioned(
            bottom: -8,
            left: -8,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF5E0006).withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD53E0F).withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD53E0F)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FRESH',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD53E0F),
                        ),
                      ),
                      Text(
                        '100%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD53E0F),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedText({
    required String productName,
    required double discountedPrice,
    required int currentSlide,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // "Fresh & Delicious" - Slide animation
        TweenAnimationBuilder(
          key: ValueKey('subtitle_$currentSlide'),
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: const Text(
            'Fresh & Delicious',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w300,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),

        // "SEAFOOD" - Slide animation
        TweenAnimationBuilder(
          key: ValueKey('title_$currentSlide'),
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: const Text(
            'SEAFOOD',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
              letterSpacing: 1,
              color: Color(0xFFEED9B9),
              fontFamily: 'Georgia',
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Description - Slide animation
        TweenAnimationBuilder(
          key: ValueKey('desc_$currentSlide'),
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: Text(
            'Enjoy premium ocean-fresh seafood with healthy delicious ${productName.toLowerCase()} from ${_formatPrice(discountedPrice)}.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFFEED9B9),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // View More Button - Slide animation
        TweenAnimationBuilder(
          key: ValueKey('button_$currentSlide'),
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHoveringButton = true),
            onExit: (_) => setState(() => _isHoveringButton = false),
            child: GestureDetector(
              onTap: () {
                // Navigate to product detail
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                transform: _isHoveringButton ? Matrix4.translationValues(0, -2, 0) : Matrix4.identity(),
                child: Container(
                  padding: const EdgeInsets.only(left: 20, right: 8, top: 8, bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5E0006),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: const Color(0xFFD53E0F).withOpacity(0.3)),
                    boxShadow: _isHoveringButton
                        ? [
                            BoxShadow(
                              color: const Color(0xFFD53E0F).withOpacity(0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'VIEW MORE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: Color(0xFFEED9B9),
                        ),
                      ),
                      const SizedBox(width: 10),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isHoveringButton ? Colors.white : const Color(0xFFD53E0F),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.arrow_forward,
                          size: 12,
                          color: const Color(0xFF5E0006),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _currentSlide == index ? 24 : 8,
            height: 4,
            decoration: BoxDecoration(
              color: _currentSlide == index
                  ? const Color(0xFFD53E0F)
                  : const Color(0xFFD53E0F).withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}