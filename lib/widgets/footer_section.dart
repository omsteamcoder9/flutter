import 'package:flutter/material.dart';
import '../services/api_service.dart';

class FooterSection extends StatefulWidget {
  const FooterSection({super.key});

  @override
  State<FooterSection> createState() => _FooterSectionState();
}

class _FooterSectionState extends State<FooterSection> {
  String _siteName = 'Sea Food';
  String _contactEmail = 'support@seafood.com';
  String _contactNumber = '+91 98765 43210';
  String _companyAddress = 'Mumbai, India';
  String _footerText = '';
  List<dynamic> _categories = [];
  Map<String, String> _socialMedia = {
    'facebook': '',
    'instagram': '',
    'twitter': '',
    'youtube': '',
    'linkedin': '',
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    await Future.wait([
      _fetchSettings(),
      _fetchCategories(),
    ]);
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchSettings() async {
    try {
      final response = await ApiService.get('/settings/public');
      if (response['success'] == true) {
        final data = response['data'];
        if (data['siteName'] != null) _siteName = data['siteName'];
        if (data['contactEmail'] != null) _contactEmail = data['contactEmail'];
        if (data['contactNumber'] != null) _contactNumber = data['contactNumber'];
        if (data['companyAddress'] != null) _companyAddress = data['companyAddress'];
        if (data['footerText'] != null) _footerText = data['footerText'];
        if (data['socialMedia'] != null) {
          _socialMedia = {
            'facebook': data['socialMedia']['facebook'] ?? '',
            'instagram': data['socialMedia']['instagram'] ?? '',
            'twitter': data['socialMedia']['twitter'] ?? '',
            'youtube': data['socialMedia']['youtube'] ?? '',
            'linkedin': data['socialMedia']['linkedin'] ?? '',
          };
        }
      }
    } catch (e) {
      print('Error fetching settings: $e');
    }
  }

  Future<void> _fetchCategories() async {
    _categories = await ApiService.getCategories();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: const Color(0xFF5E0006),
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD53E0F)),
            ),
          ),
        ),
      );
    }

    final copyrightText = _footerText.isNotEmpty
        ? _footerText
        : '© ${DateTime.now().year} $_siteName. All rights reserved.';

    // Active social icons
    final List<Map<String, dynamic>> activeSocial = [];
    if (_socialMedia['facebook'] != null && _socialMedia['facebook']!.isNotEmpty) {
      activeSocial.add({'icon': Icons.facebook, 'url': _socialMedia['facebook']});
    }
    if (_socialMedia['twitter'] != null && _socialMedia['twitter']!.isNotEmpty) {
      activeSocial.add({'icon': Icons.chat_bubble_outline, 'url': _socialMedia['twitter']});
    }
    if (_socialMedia['instagram'] != null && _socialMedia['instagram']!.isNotEmpty) {
      activeSocial.add({'icon': Icons.camera_alt, 'url': _socialMedia['instagram']});
    }
    if (_socialMedia['youtube'] != null && _socialMedia['youtube']!.isNotEmpty) {
      activeSocial.add({'icon': Icons.play_circle_outline, 'url': _socialMedia['youtube']});
    }
    if (_socialMedia['linkedin'] != null && _socialMedia['linkedin']!.isNotEmpty) {
      activeSocial.add({'icon': Icons.work_outline, 'url': _socialMedia['linkedin']});
    }

    return Container(
      color: const Color(0xFF5E0006),
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ========== LOGO (Centered) ==========
          Text(
            _siteName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFFD53E0F),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // ========== DESCRIPTION (Centered) ==========
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              "India's fastest growing seafood platform. Get the freshest catches delivered instantly at minimal cost.",
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFFEED9B9),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),

          // ========== SOCIAL ICONS (Centered) ==========
          if (activeSocial.isNotEmpty)
            Wrap(
              spacing: 20,
              alignment: WrapAlignment.center,
              children: activeSocial.map((social) {
                return InkWell(
                  onTap: () {},
                  child: Icon(
                    social['icon'] as IconData,
                    size: 20,
                    color: const Color(0xFFEED9B9),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 40),

          // ========== DIVIDER ==========
          const Divider(color: Color(0xFFD53E0F), thickness: 0.5),
          const SizedBox(height: 30),

          // ========== QUICK LINKS SECTION ==========
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Quick Links',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFD53E0F),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLink('Home'),
                  _buildLink('About'),
                  _buildLink('Contact'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),

          // ========== LEGAL SECTION ==========
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Legal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFD53E0F),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLink('Terms'),
                  _buildLink('Privacy Policy'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),

          // ========== CATEGORIES SECTION ==========
          if (_categories.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Categories',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD53E0F),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _categories.map((cat) => _buildLink(cat['name'] ?? '')).toList(),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],

          // ========== CONTACT US SECTION ==========
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Contact Us',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFD53E0F),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _contactEmail,
                    style: const TextStyle(fontSize: 13, color: Color(0xFFEED9B9)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _contactNumber,
                    style: const TextStyle(fontSize: 13, color: Color(0xFFEED9B9)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _companyAddress,
                    style: const TextStyle(fontSize: 13, color: Color(0xFFEED9B9)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),

          // ========== DIVIDER ==========
          const Divider(color: Color(0xFFD53E0F), thickness: 0.5),
          const SizedBox(height: 20),

          // ========== COPYRIGHT (Centered) ==========
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              copyrightText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFEED9B9),
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLink(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {},
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFFEED9B9),
          ),
        ),
      ),
    );
  }
}