import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/privacy.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  PrivacyData? _privacy;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPrivacy();
  }

  Future<void> _loadPrivacy() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final privacy = await ApiService.getPrivacy();
      setState(() {
        _privacy = privacy;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            color: Color(0xFF5E0006),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9B0F06)),
              ),
            ),
            SizedBox(height: 16),
            Text('Loading Privacy Policy...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPrivacy,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B0F06),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_privacy == null) {
      return const Center(
        child: Text('No privacy policy available'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            _privacy!.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5E0006),
            ),
          ),
          const SizedBox(height: 8),
          
          // Last Updated
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF9B0F06).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Last Updated: ${_privacy!.lastUpdated}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9B0F06),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Version
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 20, color: Color(0xFF5E0006)),
                const SizedBox(width: 12),
                Text(
                  'Version ${_privacy!.version}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF5E0006),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Introduction
          _buildSection(
            'Introduction',
            _privacy!.introduction,
            Icons.info_outline,
          ),
          const SizedBox(height: 20),
          
          // Information We Collect
          _buildListSection(
            'Information We Collect',
            _privacy!.dataCollection,
            Icons.data_usage,
          ),
          const SizedBox(height: 20),
          
          // How We Use Your Information
          _buildListSection(
            'How We Use Your Information',
            _privacy!.dataUsage,
            Icons.analytics_outlined,
          ),
          const SizedBox(height: 20),
          
          // Information Sharing
          _buildListSection(
            'Information Sharing',
            _privacy!.dataSharing,
            Icons.share_outlined,
          ),
          const SizedBox(height: 20),
          
          // Data Security
          _buildSection(
            'Data Security',
            _privacy!.dataSecurity,
            Icons.security_outlined,
          ),
          const SizedBox(height: 20),
          
          // Your Rights
          _buildListSection(
            'Your Rights',
            _privacy!.userRights,
            Icons.assignment_ind_outlined,
          ),
          const SizedBox(height: 20),
          
          // Cookies
          _buildSection(
            'Cookies',
            _privacy!.cookies,
            Icons.cookie_outlined,
          ),
          const SizedBox(height: 20),
          
          // Third-Party Links
          _buildSection(
            'Third-Party Links',
            _privacy!.thirdPartyLinks,
            Icons.link_outlined,
          ),
          const SizedBox(height: 20),
          
          // Changes to This Policy
          _buildSection(
            'Changes to This Policy',
            _privacy!.policyChanges,
            Icons.update_outlined,
          ),
          const SizedBox(height: 20),
          
          // Contact Us
          _buildSection(
            'Contact Us',
            _privacy!.contactInfo,
            Icons.contact_mail_outlined,
          ),
          
          const SizedBox(height: 30),
          
          // Footer
          Center(
            child: Text(
              'We value your privacy and are committed to protecting your personal information.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content, IconData icon) {
    if (content.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 22, color: const Color(0xFF9B0F06)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5E0006),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: 50,
          height: 2,
          decoration: BoxDecoration(
            color: const Color(0xFF9B0F06),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildListSection(String title, List<String> items, IconData icon) {
    if (items.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 22, color: const Color(0xFF9B0F06)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5E0006),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: 50,
          height: 2,
          decoration: BoxDecoration(
            color: const Color(0xFF9B0F06),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '• ',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9B0F06),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
}