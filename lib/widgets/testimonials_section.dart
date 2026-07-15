// ============= TESTIMONIALS SECTION =============
// File: lib/widgets/testimonials_section.dart

import 'package:flutter/material.dart';

class TestimonialsSection extends StatefulWidget {
  const TestimonialsSection({super.key});

  @override
  State<TestimonialsSection> createState() => _TestimonialsSectionState();
}

class _TestimonialsSectionState extends State<TestimonialsSection> {
  int _currentIndex = 0;
  late PageController _pageController;

  final List<Map<String, dynamic>> _testimonials = [
    {
      'name': 'Rajesh Kumar',
      'location': 'Chennai',
      'rating': 5,
      'text': 'Sea Food has been my go-to for fresh MeenavanFresh. The quality is exceptional and delivery is always on time.',
    },
    {
      'name': 'Priya Sharma',
      'location': 'Mumbai',
      'rating': 5,
      'text': 'Excellent quality MeenavanFresh delivered right to my doorstep. The packaging is perfect and the fish stays fresh.',
    },
    {
      'name': 'Murugan Selvam',
      'location': 'Coimbatore',
      'rating': 4,
      'text': 'Great experience with Sea Food. Their tiger prawns and crabs are amazing. Delivery was prompt.',
    },
    {
      'name': 'Lakshmi Devi',
      'location': 'Bangalore',
      'rating': 5,
      'text': 'Finally found a reliable MeenavanFresh supplier! The freshness is unmatched and the prices are reasonable.',
    },
    {
      'name': 'Karthik Raman',
      'location': 'Hyderabad',
      'rating': 5,
      'text': 'Professional service with excellent MeenavanFresh quality. Their selection of fish varieties is impressive.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _nextSlide();
      }
    });
  }

  void _nextSlide() {
    if (mounted) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % _testimonials.length;
        _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
      _startAutoSlide();
    }
  }

  void _prevSlide() {
    setState(() {
      _currentIndex = (_currentIndex - 1 + _testimonials.length) % _testimonials.length;
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _renderStars(int rating) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: const Color(0xFFFBBF24),
          size: 14,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          // Section Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Text(
                  'What Our Customers Say',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5E0006),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Real experiences from our happy customers',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Main Testimonial Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFDF8F5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF9B0F06).withOpacity(0.15)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Quote Icon
                  Icon(
                    Icons.format_quote,
                    size: 36,
                    color: const Color(0xFF9B0F06).withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  
                  // Testimonial Text
                  SizedBox(
                    height: 80,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                      itemCount: _testimonials.length,
                      itemBuilder: (context, index) {
                        final t = _testimonials[index];
                        return Center(
                          child: Text(
                            '"${t['text']}"',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: Color(0xFF5E0006),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Stars
                  _renderStars(_testimonials[_currentIndex]['rating']),
                  
                  const SizedBox(height: 12),
                  
                  // Name
                  Text(
                    _testimonials[_currentIndex]['name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5E0006),
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Location
                  Text(
                    _testimonials[_currentIndex]['location'],
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF9B0F06),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Navigation Arrows & Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _prevSlide,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9B0F06).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chevron_left,
                            size: 20,
                            color: Color(0xFF5E0006),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Row(
                        children: List.generate(_testimonials.length, (index) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _currentIndex = index;
                                _pageController.animateToPage(
                                  index,
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeInOut,
                                );
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: _currentIndex == index ? 20 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                color: _currentIndex == index
                                    ? const Color(0xFF9B0F06)
                                    : const Color(0xFF9B0F06).withOpacity(0.3),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: _nextSlide,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9B0F06).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: Color(0xFF5E0006),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Additional Testimonials (Simple List)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const Text(
                  'More Happy Customers',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5E0006),
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  children: _testimonials.take(3).map((t) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF8F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF9B0F06).withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _renderStars(t['rating']),
                              Icon(
                                Icons.format_quote,
                                size: 20,
                                color: const Color(0xFF9B0F06).withOpacity(0.2),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '"${t['text']}"',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: Color(0xFF5E0006),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            t['name'],
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5E0006),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}