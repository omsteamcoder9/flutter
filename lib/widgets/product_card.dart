import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../screens/product_detail_screen.dart';

class ProductCard extends StatelessWidget {
  final dynamic product;
  final VoidCallback onAddToCart;
  final String? guestId;
  final String? token;
  final VoidCallback? onCartUpdate;
  final Set<String>? cartProductIds;

  const ProductCard({
    required this.product,
    required this.onAddToCart,
    this.guestId,
    this.token,
    this.onCartUpdate,
    this.cartProductIds,
    super.key,
  });

  // ============================================================
  // PRICE FORMAT
  // ============================================================

  String _formatPrice(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }

  // ============================================================
  // IMAGE URL
  // ============================================================

  String _getImageUrl() {
    if (product['variants'] != null &&
        product['variants'].isNotEmpty) {
      final variant = product['variants'][0];

      if (variant['images'] != null &&
          variant['images'].isNotEmpty) {
        String imagePath = variant['images'][0]['image'];

        if (imagePath.startsWith('http')) {
          return imagePath;
        }

        if (imagePath.startsWith('/')) {
          imagePath = imagePath.substring(1);
        }

        return '${ApiService.imageBaseUrl}/$imagePath';
      }
    }

    if (product['ogImage'] != null &&
        product['ogImage'].toString().isNotEmpty) {
      String imagePath = product['ogImage'];

      if (imagePath.startsWith('http')) {
        return imagePath;
      }

      if (imagePath.startsWith('/')) {
        imagePath = imagePath.substring(1);
      }

      return '${ApiService.imageBaseUrl}/$imagePath';
    }

    return '';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final bool hasOffer = product['hasOffer'] == true;

    final double basePrice =
        (product['basePrice'] ?? 0).toDouble();

    final double originalPrice =
        (product['originalPrice'] ?? basePrice * 1.2).toDouble();

    final bool isOutOfStock =
        (product['stock'] ?? 0) <= 0;

    final String imageUrl = _getImageUrl();

    final bool isInCart =
        cartProductIds != null &&
        cartProductIds!.contains(product['_id']);

    // ============================================================
    // WEIGHT
    // ============================================================

    String weightLabel = 'ESSENTIALS';

    if (product['variants'] != null &&
        product['variants'].isNotEmpty) {
      final variant = product['variants'][0];

      if (variant['weight'] != null &&
          variant['weightUnit'] != null) {
        weightLabel =
            'NET WEIGHT • ${variant['weight']} ${variant['weightUnit']}';
      }
    }

    // ============================================================
    // RESPONSIVE
    // ============================================================

    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth = constraints.maxWidth;

        final bool extraSmall = cardWidth < 145;

        final bool small =
            cardWidth >= 145 && cardWidth < 175;

        final bool medium =
            cardWidth >= 175 && cardWidth < 220;

        // ========================================================
        // HORIZONTAL SPACING
        // ========================================================

        final double horizontalPadding = extraSmall
            ? 6
            : small
                ? 8
                : 10;

        final double imagePadding = extraSmall
            ? 4
            : small
                ? 5
                : 7;

        final double radius = extraSmall
            ? 12
            : small
                ? 15
                : medium
                    ? 17
                    : 19;

        final double imageRadius = extraSmall
            ? 8
            : small
                ? 10
                : 13;

        // ========================================================
        // TEXT
        // ========================================================

        final double weightSize = extraSmall
            ? 6.5
            : small
                ? 7
                : medium
                    ? 8
                    : 8.5;

        final double nameSize = extraSmall
            ? 9.5
            : small
                ? 10.5
                : medium
                    ? 12
                    : 13.5;

        final double stockSize = extraSmall
            ? 7.5
            : small
                ? 8
                : medium
                    ? 9
                    : 9.5;

        final double priceSize = extraSmall
            ? 12
            : small
                ? 13
                : medium
                    ? 15
                    : 16;

        final double buttonSize = extraSmall
            ? 7.5
            : small
                ? 8
                : medium
                    ? 9
                    : 10;

        // ========================================================
        // PRODUCT DETAIL
        // ========================================================

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailScreen(
                  productId: product['_id'],
                  productSlug: product['slug'],
                  guestId: guestId,
                  token: token,
                  onCartUpdate: onCartUpdate,
                ),
              ),
            );
          },

          // IMPORTANT:
          // Align prevents the card itself from stretching to the
          // full GridView cell height.
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: double.infinity,

              // DO NOT use height: double.infinity here.
              // The card now takes only the height required by
              // its actual content.

              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: const Color(0xFFE3EEF0),
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A07566B),
                    blurRadius: 9,
                    offset: Offset(0, 3),
                  ),
                ],
              ),

              child: Column(
                // IMPORTANT:
                // Do not force the Column to fill the GridView cell.
                mainAxisSize: MainAxisSize.min,

                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  // ==================================================
                  // IMAGE SECTION
                  // ==================================================

                  Padding(
                    padding: EdgeInsets.all(imagePadding),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(imageRadius),

                      child: AspectRatio(
                        aspectRatio: 1.55,

                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) {
                                  return Container(
                                    color:
                                        const Color(0xFFF3F3F3),
                                    child: Center(
                                      child: Icon(
                                        Icons.image,
                                        color:
                                            Colors.grey.shade400,
                                        size: 40,
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color:
                                    const Color(0xFFF3F3F3),
                                child: Center(
                                  child: Icon(
                                    Icons.image,
                                    color:
                                        Colors.grey.shade400,
                                    size: 40,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),

                  // ==================================================
                  // CONTENT
                  // ==================================================

                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      0,
                      horizontalPadding,
                      10,
                    ),

                    child: Column(
                      mainAxisSize: MainAxisSize.min,

                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [

                        // ==========================================
                        // WEIGHT
                        // ==========================================

                        SizedBox(
                          width: double.infinity,
                          height: 15,

                          child: Text(
                            weightLabel,
                            maxLines: 1,
                            softWrap: false,
                            overflow:
                                TextOverflow.ellipsis,

                            style: TextStyle(
                              fontSize: weightSize,
                              fontWeight:
                                  FontWeight.w600,
                              color:
                                  const Color(0xFF94A6AA),
                              letterSpacing: 0.35,
                            ),
                          ),
                        ),

                        const SizedBox(height: 2),

                        // ==========================================
                        // PRODUCT NAME
                        // ==========================================

                        SizedBox(
                          width: double.infinity,
                          height: 22,

                          child: Text(
                            product['name'] ??
                                'Product',

                            maxLines: 1,
                            softWrap: false,
                            overflow:
                                TextOverflow.ellipsis,

                            style: TextStyle(
                              fontSize: nameSize,
                              fontWeight:
                                  FontWeight.w500,
                              color:
                                  const Color(0xFF285966),
                              height: 1.2,
                            ),
                          ),
                        ),

                        const SizedBox(height: 4),

                        // ==========================================
                        // STOCK + PRICE
                        // ==========================================

                        SizedBox(
                          width: double.infinity,
                          height: 22,

                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.center,

                            children: [

                              // STOCK
                              Expanded(
                                child: isOutOfStock
                                    ? const SizedBox()
                                    : Row(
                                        mainAxisSize:
                                            MainAxisSize.min,

                                        children: [

                                          Container(
                                            width: 6,
                                            height: 6,

                                            decoration:
                                                const BoxDecoration(
                                              color:
                                                  Color(
                                                0xFF28A8BA,
                                              ),
                                              shape:
                                                  BoxShape
                                                      .circle,
                                            ),
                                          ),

                                          const SizedBox(
                                            width: 4,
                                          ),

                                          Flexible(
                                            child: Text(
                                              'In Stock',

                                              maxLines: 1,
                                              softWrap: false,
                                              overflow:
                                                  TextOverflow
                                                      .ellipsis,

                                              style:
                                                  TextStyle(
                                                fontSize:
                                                    stockSize,
                                                color:
                                                    const Color(
                                                  0xFF1591A5,
                                                ),
                                                fontWeight:
                                                    FontWeight
                                                        .w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),

                              // PRICE
                              Expanded(
                                child: FittedBox(
                                  fit:
                                      BoxFit.scaleDown,

                                  alignment:
                                      Alignment.centerRight,

                                  child: Row(
                                    mainAxisSize:
                                        MainAxisSize.min,

                                    children: [

                                      if (hasOffer &&
                                          originalPrice >
                                              basePrice)
                                        Padding(
                                          padding:
                                              const EdgeInsets
                                                  .only(
                                            right: 3,
                                          ),

                                          child: Text(
                                            '₹${_formatPrice(originalPrice)}',
                                            maxLines: 1,

                                            style:
                                                const TextStyle(
                                              fontSize: 8,
                                              color:
                                                  Color(
                                                0xFF9DAAAD,
                                              ),
                                              decoration:
                                                  TextDecoration
                                                      .lineThrough,
                                            ),
                                          ),
                                        ),

                                      Text(
                                        '₹${_formatPrice(basePrice)}',
                                        maxLines: 1,

                                        style:
                                            TextStyle(
                                          fontSize:
                                              priceSize,
                                          fontWeight:
                                              FontWeight.w700,
                                          color:
                                              const Color(
                                            0xFF07566B,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 7),

                        // ==========================================
                        // ADD TO CART
                        // ==========================================

                        SizedBox(
                          width: double.infinity,

                          height:
                              buttonHeightFor(cardWidth),

                          child: GestureDetector(
                            behavior:
                                HitTestBehavior.opaque,

                            onTap:
                                (isOutOfStock ||
                                        isInCart)
                                    ? null
                                    : onAddToCart,

                            child: Container(
                              width: double.infinity,
                              height: double.infinity,

                              decoration:
                                  BoxDecoration(
                                color: isOutOfStock
                                    ? const Color(
                                        0xFF9AA6A9,
                                      )
                                    : const Color(
                                        0xFF07566B,
                                      ),

                                borderRadius:
                                    BorderRadius.circular(
                                  extraSmall
                                      ? 7
                                      : 9,
                                ),
                              ),

                              child: Center(
                                child: FittedBox(
                                  fit:
                                      BoxFit.scaleDown,

                                  child: Row(
                                    mainAxisSize:
                                        MainAxisSize.min,

                                    children: [

                                      Icon(
                                        isInCart
                                            ? Icons.check
                                            : Icons
                                                .shopping_bag_outlined,

                                        color:
                                            Colors.white,

                                        size:
                                            extraSmall
                                                ? 11
                                                : 14,
                                      ),

                                      const SizedBox(
                                        width: 5,
                                      ),

                                      Text(
                                        isOutOfStock
                                            ? 'Out Of Stock'
                                            : isInCart
                                                ? 'In Cart'
                                                : 'Add to Cart',

                                        maxLines: 1,
                                        softWrap: false,

                                        style:
                                            TextStyle(
                                          color:
                                              Colors.white,
                                          fontSize:
                                              buttonSize + 2,
                                          fontWeight:
                                              FontWeight.w600,
                                          letterSpacing:
                                              0.1,
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
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // RESPONSIVE BUTTON HEIGHT
  // ============================================================

  double buttonHeightFor(double width) {
    if (width < 145) {
      return 32;
    }

    if (width < 175) {
      return 35;
    }

    if (width < 220) {
      return 38;
    }

    return 41;
  }

  // ============================================================
  // IMAGE PLACEHOLDER
  // ============================================================

  Widget _imagePlaceholder(double size) {
    return Center(
      child: Icon(
        Icons.image_outlined,
        color: const Color(0xFF9CB4BA),
        size: size,
      ),
    );
  }
}