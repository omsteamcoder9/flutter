import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/terms.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  TermsData? _terms;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  Future<void> _loadTerms() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final terms = await ApiService.getTerms();
      setState(() {
        _terms = terms;
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
          'Terms & Conditions',
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
            Text('Loading Terms & Conditions...'),
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
              onPressed: _loadTerms,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B0F06),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_terms == null) {
      return const Center(
        child: Text('No terms available'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            _terms!.title,
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
              'Last Updated: ${_terms!.lastUpdated}',
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
                  'Version ${_terms!.version}',
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
          
          // Important Notice
          _buildSection(
            'Important Notice',
            _terms!.importantNotice,
            Icons.warning_amber_rounded,
          ),
          const SizedBox(height: 20),
          
          // User Requirements
          _buildRequirementsSection(),
          const SizedBox(height: 20),
          
          // Main Sections
          ..._terms!.sections.map((section) => Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _buildSection(
              '${section.number}. ${section.title}',
              section.content,
              Icons.description_outlined,
            ),
          )),
          
          // Intellectual Property
          _buildSection(
            'Intellectual Property',
            _terms!.intellectualProperty,
            Icons.copyright_outlined,
          ),
          const SizedBox(height: 20),
          
          // Limitation of Liability
          _buildSection(
            'Limitation of Liability',
            _terms!.limitationLiability,
            Icons.gavel_outlined,
          ),
          const SizedBox(height: 20),
          
          // Changes to Terms
          _buildSection(
            'Changes to Terms',
            _terms!.changesNotice,
            Icons.update_outlined,
          ),
          const SizedBox(height: 20),
          
          // Contact Information
          _buildSection(
            'Contact Information',
            _terms!.contactInfo,
            Icons.contact_mail_outlined,
          ),
          
          const SizedBox(height: 30),
          
          // Footer
          Center(
            child: Text(
              'By using our service, you agree to these terms.',
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
            Icon(icon, size: 20, color: const Color(0xFF9B0F06)),
            const SizedBox(width: 8),
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
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 3,
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

  Widget _buildRequirementsSection() {
    if (_terms!.userRequirements.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.verified_user_outlined, size: 20, color: Color(0xFF9B0F06)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'User Requirements',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5E0006),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 3,
          decoration: BoxDecoration(
            color: const Color(0xFF9B0F06),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 12),
        ..._terms!.userRequirements.map((requirement) => Padding(
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
                  requirement,
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