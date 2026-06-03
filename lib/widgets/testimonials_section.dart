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
        'text': 'Sea Food has been my go-to for fresh seafood. The quality is exceptional and delivery is always on time. Their prawns and fish are incredibly fresh!',
        'project': 'Fresh Fish Delivery',
        },
        {
        'name': 'Priya Sharma',
        'location': 'Mumbai',
        'rating': 5,
        'text': 'Excellent quality seafood delivered right to my doorstep. The packaging is perfect and the fish stays fresh. Highly recommend their premium seafood selection.',
        'project': 'Premium Seafood Order',
        },
        {
        'name': 'Murugan Selvam',
        'location': 'Coimbatore',
        'rating': 4,
        'text': 'Great experience with Sea Food. Their tiger prawns and crabs are amazing. The delivery was prompt and customer service is excellent.',
        'project': 'Special Occasion Order',
        },
        {
        'name': 'Lakshmi Devi',
        'location': 'Bangalore',
        'rating': 5,
        'text': 'Finally found a reliable seafood supplier! The freshness is unmatched and the prices are reasonable. Their frozen section is also great.',
        'project': 'Regular Seafood Delivery',
        },
        {
        'name': 'Karthik Raman',
        'location': 'Hyderabad',
        'rating': 5,
        'text': 'Professional service with excellent seafood quality. Their selection of fish varieties is impressive. Will definitely order again!',
        'project': 'Family Seafood Order',
        },
    ];

    @override
    void initState() {
        super.initState();
        _pageController = PageController();
        _startAutoSlide();
    }

    void _startAutoSlide() {
        Future.delayed(Duration(seconds: 5), () {
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
            duration: Duration(milliseconds: 400),
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
            duration: Duration(milliseconds: 400),
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
            color: Color(0xFFFBBF24),
            size: 14,
            );
        }),
        );
    }

    @override
    Widget build(BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isDesktop = screenWidth >= 800;

        return Container(
        color: Color(0xFFFDF8F5),
        child: Column(
            children: [
            // Section Header
            Container(
                padding: EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                child: Column(
                children: [
                    Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: Color(0xFF9B0F06).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Color(0xFF9B0F06).withOpacity(0.3)),
                    ),
                    child: Text(
                        'CUSTOMER TESTIMONIALS',
                        style: TextStyle(
                        color: Color(0xFF5E0006),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        ),
                    ),
                    ),
                    SizedBox(height: 16),
                    Text(
                    'What Our',
                    style: TextStyle(
                        fontSize: isDesktop ? 32 : 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5E0006),
                    ),
                    ),
                    RichText(
                    text: TextSpan(
                        style: TextStyle(
                        fontSize: isDesktop ? 32 : 24,
                        fontWeight: FontWeight.bold,
                        ),
                        children: [
                        TextSpan(
                            text: ' Customers Say',
                            style: TextStyle(
                            color: Color(0xFF9B0F06),
                            ),
                        ),
                        ],
                    ),
                    ),
                    SizedBox(height: 12),
                    Container(
                    width: 60,
                    height: 3,
                    decoration: BoxDecoration(
                        color: Color(0xFF9B0F06),
                        borderRadius: BorderRadius.circular(2),
                    ),
                    ),
                    SizedBox(height: 16),
                    Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                        "Don't just take our word for it. Here's what our satisfied customers have to say about their experience getting fresh, premium quality seafood delivered by Sea Food.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                        fontSize: isDesktop ? 14 : 12,
                        color: Color(0xFF5E0006).withOpacity(0.7),
                        ),
                    ),
                    ),
                ],
                ),
            ),

            SizedBox(height: 20),

            // Responsive Layout: Desktop = Row, Mobile = Column
            Padding(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 40 : 16),
                child: isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Expanded(child: _buildTestimonialCard()),
                        SizedBox(width: 24),
                        Expanded(child: _buildImage()),
                        ],
                    )
                    : Column(
                        children: [
                        _buildTestimonialCard(),
                        SizedBox(height: 24),
                        _buildImage(),
                        ],
                    ),
            ),

            SizedBox(height: 40),

            // Additional Testimonials - 1 CARD PER ROW (Vertically Stacked)
            Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                children: [
                    Text(
                    'More Happy Customers',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5E0006),
                    ),
                    ),
                    SizedBox(height: 16),
                    Column(
                    children: _testimonials.take(3).map((t) {
                        return Container(
                        margin: EdgeInsets.only(bottom: 16),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Color(0xFF9B0F06).withOpacity(0.2)),
                            boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: Offset(0, 5),
                            ),
                            ],
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                _renderStars(t['rating']),
                                Icon(Icons.format_quote, size: 24, color: Color(0xFF9B0F06).withOpacity(0.3)),
                                ],
                            ),
                            SizedBox(height: 12),
                            Text(
                                '"${t['text']}"',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: Color(0xFF5E0006).withOpacity(0.8),
                                ),
                            ),
                            SizedBox(height: 12),
                            Text(
                                t['name'],
                                style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5E0006),
                                ),
                            ),
                            Text(
                                t['project'],
                                style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9B0F06),
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
            SizedBox(height: 40),
            ],
        ),
        );
    }

    Widget _buildTestimonialCard() {
        return Container(
        decoration: BoxDecoration(
            gradient: LinearGradient(
            colors: [Colors.white, Color(0xFF9B0F06).withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Color(0xFF9B0F06).withOpacity(0.2)),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Icon(Icons.format_quote, size: 40, color: Color(0xFF9B0F06).withOpacity(0.4)),
            SizedBox(height: 16),
            SizedBox(
                height: 100,
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
                        style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Color(0xFF5E0006),
                        fontStyle: FontStyle.italic,
                        ),
                    ),
                    );
                },
                ),
            ),
            SizedBox(height: 20),
            Divider(color: Color(0xFF9B0F06).withOpacity(0.2)),
            SizedBox(height: 16),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(
                        _testimonials[_currentIndex]['name'],
                        style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5E0006),
                        ),
                    ),
                    Text(
                        _testimonials[_currentIndex]['location'],
                        style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9B0F06),
                        ),
                    ),
                    ],
                ),
                _renderStars(_testimonials[_currentIndex]['rating']),
                ],
            ),
            SizedBox(height: 12),
            Row(
                children: [
                Text(
                    'Purchase: ',
                    style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5E0006).withOpacity(0.6),
                    ),
                ),
                Text(
                    _testimonials[_currentIndex]['project'],
                    style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5E0006),
                    ),
                ),
                ],
            ),
            SizedBox(height: 24),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                Row(
                    children: [
                    GestureDetector(
                        onTap: _prevSlide,
                        child: Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Color(0xFF9B0F06).withOpacity(0.2),
                            shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.chevron_left, size: 20, color: Color(0xFF5E0006)),
                        ),
                    ),
                    SizedBox(width: 12),
                    GestureDetector(
                        onTap: _nextSlide,
                        child: Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Color(0xFF9B0F06).withOpacity(0.2),
                            shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.chevron_right, size: 20, color: Color(0xFF5E0006)),
                        ),
                    ),
                    ],
                ),
                Row(
                    children: List.generate(_testimonials.length, (index) {
                    return GestureDetector(
                        onTap: () {
                        setState(() {
                            _currentIndex = index;
                            _pageController.animateToPage(
                            index,
                            duration: Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                            );
                        });
                        },
                        child: AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        margin: EdgeInsets.symmetric(horizontal: 4),
                        width: _currentIndex == index ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: _currentIndex == index
                                ? Color(0xFF9B0F06)
                                : Color(0xFF9B0F06).withOpacity(0.3),
                        ),
                        ),
                    );
                    }),
                ),
                ],
            ),
            ],
        ),
        );
    }

Widget _buildImage() {
  return ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: Image.asset(
      'assets/images/h1.png',
      height: 350,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: 350,
          color: Color(0xFF9B0F06).withOpacity(0.2),
          child: Center(
            child: Icon(Icons.image, size: 50, color: Color(0xFF9B0F06)),
          ),
        );
      },
    ),
  );
}
    }