import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CategorySection extends StatefulWidget {
  const CategorySection({super.key});

  @override
  State<CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<CategorySection> with SingleTickerProviderStateMixin {
  List<dynamic> _categories = [];
  bool _isLoading = true;
  late AnimationController _controller;
  ScrollController _scrollController = ScrollController();
  double _scrollSpeed = 0.8;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    
    _controller.addListener(() {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.offset;
        
        if (currentScroll >= maxScroll - 10) {
          _scrollController.jumpTo(0);
        } else {
          _scrollController.jumpTo(currentScroll + _scrollSpeed);
        }
      }
    });
    
    _controller.repeat();
  }

  Future<void> _loadCategories() async {
    final categories = await ApiService.getCategories();
    setState(() {
      _categories = categories;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  double _getSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1024) return 80;
    if (width >= 768) return 64;
    return 56;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9B0F06)),
            ),
          ),
        ),
      );
    }

    if (_categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final size = _getSize(context);
    final gap = 20.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
   
        const SizedBox(height: 8),
        SizedBox(
          height: size + 35,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categories.length * 4,
            itemBuilder: (context, index) {
              final category = _categories[index % _categories.length];
              
              String imageUrl = '';
              if (category['image'] != null && category['image'].isNotEmpty) {
                imageUrl = '${ApiService.imageBaseUrl}${category['image']}';
              }
              
              return Container(
                width: size,
                margin: EdgeInsets.only(right: gap),
                child: GestureDetector(
                  onTap: () {
                    print('Category tapped: ${category['name']}');
                  },
                  child: Column(
                    children: [
                      Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF9B0F06).withOpacity(0.08),
                          image: imageUrl.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(imageUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: imageUrl.isEmpty
                            ? Icon(
                                Icons.category,
                                color: const Color(0xFF9B0F06),
                                size: size * 0.42,
                              )
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        category['name'] ?? '',
                        style: TextStyle(
                          fontSize: size * 0.16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF5E0006),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}