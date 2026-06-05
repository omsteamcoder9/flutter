import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';

class ProductCard extends StatelessWidget {
  final dynamic product;
  final VoidCallback onAddToCart;

  const ProductCard({
    required this.product,
    required this.onAddToCart,
    super.key,
  });

  String _formatPrice(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

String _getImageUrl() {
  // PRIORITY 1: Get image from variants
  if (product['variants'] != null && product['variants'].isNotEmpty) {
    final variant = product['variants'][0];
    if (variant['images'] != null && variant['images'].isNotEmpty) {
      String imagePath = variant['images'][0]['image'];
      if (imagePath.startsWith('http')) return imagePath;
      if (imagePath.startsWith('/')) imagePath = imagePath.substring(1);
      // DO NOT remove 'uploads/' - keep the full path
      return '${ApiService.imageBaseUrl}/$imagePath';
    }
  }
  
  // PRIORITY 2: Fallback to ogImage
  if (product['ogImage'] != null && product['ogImage'].toString().isNotEmpty) {
    String imagePath = product['ogImage'];
    if (imagePath.startsWith('/')) imagePath = imagePath.substring(1);
    return '${ApiService.imageBaseUrl}/$imagePath';
  }
  
  return '';
}

  @override
  Widget build(BuildContext context) {
    final hasOffer = product['hasOffer'] == true;
    final basePrice = (product['basePrice'] ?? 0).toDouble();
    final originalPrice = (product['originalPrice'] ?? basePrice * 1.2).toDouble();
    final isOutOfStock = (product['stock'] ?? 0) <= 0;
    final imageUrl = _getImageUrl();
    
    String weightLabel = 'ESSENTIALS';
    if (product['variants'] != null && product['variants'].isNotEmpty) {
      final variant = product['variants'][0];
      if (variant['weight'] != null && variant['weightUnit'] != null) {
        weightLabel = 'NET WEIGHT • ${variant['weight']} ${variant['weightUnit']}';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image Section
          Container(
            margin: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFFF3F3F3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(Icons.image, color: Colors.grey.shade400, size: 40),
                          );
                        },
                      )
                    : Center(
                        child: Icon(Icons.image, color: Colors.grey.shade400, size: 40),
                      ),
              ),
            ),
          ),
          // Content Section
          Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Weight Label
                Text(
                  weightLabel,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade400,
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(height: 4),
                // Product Name - 2 lines supported
                Text(
                  product['name'] ?? 'Product',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 6),
                // Stock Status
                if (!isOutOfStock)
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Color(0xFFD53E0F),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'In Stock',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFFD53E0F),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: 8),
                Divider(height: 1, color: Colors.grey.shade50),
                SizedBox(height: 8),
                // Price & Button Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Price Column
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Price',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Row(
                          children: [
                            if (hasOffer && originalPrice > basePrice)
                              Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Text(
                                  '₹${_formatPrice(originalPrice)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade400,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ),
                            Text(
                              '₹${_formatPrice(basePrice)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Add To Cart Button
                    GestureDetector(
                      onTap: isOutOfStock ? null : onAddToCart,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isOutOfStock ? Colors.grey.shade400 : Color(0xFF9B0F06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              isOutOfStock ? 'OUT' : 'Add To Cart',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}