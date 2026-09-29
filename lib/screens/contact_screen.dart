import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/cart_drawer.dart';
import 'profile/profile_screen.dart';
import 'auth/signup_screen.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isSubmitting = false;
  String? _successMessage;
  String? _errorMessage;

  // Contact info from settings
  String _contactEmail = 'support@MeenavanFresh.com';
  String _contactNumber = '+91 7200074221';
  String _companyAddress = '';
  String _siteName = 'MeenavanFresh';

  int _currentIndex = 2;
  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadCartCount();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await ApiService.getPublicSettings();
      if (mounted) {
        setState(() {
          _contactEmail = settings['contactEmail'] ?? _contactEmail;
          _contactNumber = settings['contactNumber'] ?? _contactNumber;
          _companyAddress = settings['companyAddress'] ?? _companyAddress;
          _siteName = settings['siteName'] ?? _siteName;
        });
      }
    } catch (e) {
      print('Error loading contact settings: $e');
    }
  }

  Future<void> _loadCartCount() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final isLoggedIn = authProvider.isLoggedIn;
      final token = authProvider.token;

      final response = await ApiService.getCart(
        guestId: isLoggedIn ? null : null,
        token: token,
      );

      if (response['success'] == true && mounted) {
        setState(() {
          _cartCount = response['data']?['totalItems'] ?? 0;
        });
      }
    } catch (e) {
      print('Error loading cart count: $e');
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _successMessage = null;
      _errorMessage = null;
    });

    try {
      final payload = {
        'name': _nameController.text.trim().isEmpty
            ? 'Anonymous'
            : _nameController.text.trim(),
        'email': _emailController.text.trim().isEmpty
            ? 'No email provided'
            : _emailController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty
            ? 'No phone provided'
            : _phoneController.text.trim(),
        'subject': _subjectController.text.trim(),
        'message': _messageController.text.trim(),
      };

      final response = await ApiService.submitContact(payload);

      if (!mounted) return;

      if (response['success'] == true) {
        setState(() {
          _successMessage = response['message'] ??
              'Thank you! We will get back to you soon.';
        });

        // Clear form
        _nameController.clear();
        _emailController.clear();
        _phoneController.clear();
        _subjectController.clear();
        _messageController.clear();
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to send message';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to send message: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _openCart() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    String? guestIdToUse = authProvider.isLoggedIn ? null : null;
    String? tokenToUse = authProvider.isLoggedIn ? authProvider.token : null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartScreen(
          guestId: guestIdToUse,
          token: tokenToUse,
          onCartUpdate: () {
            _loadCartCount();
          },
        ),
      ),
    );
  }

  void _showAuthDialog() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SignupScreen()),
      );
    }
  }

  void _navigateToHome() {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  // ============================================================
  // RESPONSIVE HELPERS
  // ============================================================

  double _hPad(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 360) return 14;
    if (w < 600) return 16;
    if (w < 900) return 24;
    return 32;
  }

  double _titleSize(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 360) return 20;
    if (w < 600) return 22;
    if (w < 900) return 24;
    return 26;
  }

  double _bodySize(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 360) return 12.5;
    if (w < 600) return 13;
    if (w < 900) return 14;
    return 14.5;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final cartCount = Provider.of<CartProvider>(context).cartCount;
    final horizontalPadding = _hPad(context);
    final titleSize = _titleSize(context);
    final bodySize = _bodySize(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Contact Us',
          style: TextStyle(
            color: Color(0xFF063B5C),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: horizontalPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================== HEADER ====================
            Text(
              'Contact Us',
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF063B5C),
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Have questions about our premium $_siteName products? We\'d love to hear from you.',
              style: TextStyle(
                fontSize: bodySize,
                height: 1.5,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 24),

            // ==================== CONTACT INFO CARDS ====================
            _buildContactInfoCard(
              icon: Icons.email_outlined,
              title: 'Email',
              value: _contactEmail,
              description: 'Send us an email anytime',
              bodySize: bodySize,
              onTap: () {},
            ),
            const SizedBox(height: 12),
            _buildContactInfoCard(
              icon: Icons.phone_outlined,
              title: 'Phone',
              value: _contactNumber,
              description: 'Mon–Fri from 9am to 6pm',
              bodySize: bodySize,
              onTap: () {},
            ),
            if (_companyAddress.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildContactInfoCard(
                icon: Icons.location_on_outlined,
                title: 'Address',
                value: _companyAddress,
                description: 'Visit our store',
                bodySize: bodySize,
                onTap: () {},
              ),
            ],

            const SizedBox(height: 28),

            // ==================== FORM ====================
            Text(
              'Send Us a Message',
              style: TextStyle(
                fontSize: titleSize - 4,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF063B5C),
              ),
            ),
            const SizedBox(height: 16),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    hint: 'Enter your full name',
                    icon: Icons.person_outline,
                    bodySize: bodySize,
                    isOptional: true,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    hint: 'your@email.com',
                    icon: Icons.email_outlined,
                    bodySize: bodySize,
                    isOptional: true,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v != null && v.trim().isNotEmpty) {
                        if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(v.trim())) {
                          return 'Enter a valid email';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    hint: 'Enter your phone number',
                    icon: Icons.phone_outlined,
                    bodySize: bodySize,
                    isOptional: true,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _subjectController,
                    label: 'Subject',
                    hint: 'What is this regarding?',
                    icon: Icons.subject_outlined,
                    bodySize: bodySize,
                    isRequired: true,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Subject is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _messageController,
                    label: 'Message',
                    hint: 'Tell us how we can help you...',
                    icon: Icons.message_outlined,
                    bodySize: bodySize,
                    isRequired: true,
                    maxLines: 5,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Message is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // ==================== SEND BUTTON ====================
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF063B5C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Send Message',
                              style: TextStyle(
                                fontSize: bodySize + 1,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  // ==================== SUCCESS / ERROR BANNER (BELOW BUTTON) ====================
                  if (_successMessage != null) ...[
                    const SizedBox(height: 16),
                    _buildBanner(
                      _successMessage!,
                      isSuccess: true,
                      bodySize: bodySize,
                    ),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    _buildBanner(
                      _errorMessage!,
                      isSuccess: false,
                      bodySize: bodySize,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 30),

            Center(
              child: Text(
                'We typically respond within 24 hours.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: bodySize - 2,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        cartCount: cartCount,
        onTap: (index) {
          if (index == 0) {
            _navigateToHome();
          } else if (index == 1) {
            _openCart();
          } else if (index == 2) {
            _showAuthDialog();
          }
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }

  // ==================== CONTACT INFO CARD ====================
  Widget _buildContactInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required String description,
    required double bodySize,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF07566B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF07566B), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: bodySize,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF063B5C),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: bodySize,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: bodySize - 2,
                        color: Colors.grey.shade600,
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
  }

  // ==================== TEXT FIELD ====================
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required double bodySize,
    bool isRequired = false,
    bool isOptional = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: bodySize,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF063B5C),
            ),
            children: [
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: Color(0xFF07566B)),
                ),
              if (isOptional)
                TextSpan(
                  text: ' (optional)',
                  style: TextStyle(
                    fontSize: bodySize - 2,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.normal,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: bodySize,
              color: Colors.grey.shade400,
            ),
            prefixIcon: maxLines == 1
                ? Icon(icon, color: const Color(0xFF07566B), size: 20)
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF07566B), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
          style: TextStyle(fontSize: bodySize, color: Colors.grey.shade800),
        ),
      ],
    );
  }

  // ==================== BANNER ====================
  Widget _buildBanner(String message, {required bool isSuccess, required double bodySize}) {
    final bgColor = isSuccess ? const Color(0xFF07566B).withOpacity(0.08) : Colors.red.shade50;
    final borderColor = isSuccess ? const Color(0xFF07566B).withOpacity(0.3) : Colors.red.shade200;
    final textColor = isSuccess ? const Color(0xFF063B5C) : Colors.red.shade700;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isSuccess ? Icons.check_circle_outline : Icons.error_outline,
            color: textColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: bodySize, color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}