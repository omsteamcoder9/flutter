import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import 'otp_verification_screen.dart';
import 'login_screen.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/cart_drawer.dart';
import '../profile/profile_screen.dart';
import '../../services/api_service.dart';

class SignupScreen extends StatefulWidget {
  final String? guestId;

  const SignupScreen({super.key, this.guestId});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _showLoginOption = false;  // ✅ NEW: Show Login button
  int _currentIndex = 2;
  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCartCount();
  }

  Future<void> _loadCartCount() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final isLoggedIn = authProvider.isLoggedIn;
      final token = authProvider.token;
      
      final response = await ApiService.getCart(
        guestId: isLoggedIn ? null : widget.guestId,
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

  void _openCart() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    String? guestId = widget.guestId;
    if (guestId == null || guestId.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      guestId = prefs.getString('guest_id');
    }
    
    String? guestIdToUse = authProvider.isLoggedIn ? null : guestId;
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
    }
  }

  void _navigateToHome() {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

Future<void> _sendOtp() async {
  final phoneNumber = _phoneController.text.trim();
  
  if (phoneNumber.isEmpty) {
    setState(() {
      _errorMessage = 'Please enter phone number';
      _showLoginOption = false;
    });
    return;
  }
  
  if (phoneNumber.length < 10) {
    setState(() {
      _errorMessage = 'Please enter valid 10-digit phone number';
      _showLoginOption = false;
    });
    return;
  }

  setState(() {
    _isLoading = true;
    _errorMessage = null;
    _showLoginOption = false;
  });

  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  
  // ✅ FIX: Use sendSignupOtp for signup
  final result = await authProvider.sendSignupOtp(phoneNumber);

  setState(() {
    _isLoading = false;
  });

  // ✅ Handle response
  if (result['success'] == true) {
    // New user or inactive user - proceed with OTP
    final prefs = await SharedPreferences.getInstance();
    final hasPendingCheckout = prefs.getBool('pending_checkout') ?? false;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtpVerificationScreen(
          otpSessionId: result['otpSessionId'],
          phoneNumber: phoneNumber,
          isNewUser: result['isNewUser'] ?? true,
          hasInactiveUser: result['hasInactiveUser'] ?? false,
          guestId: widget.guestId,
          hasPendingCheckout: hasPendingCheckout,
        ),
      ),
    );
  } else if (result['exists'] == true && result['isActive'] == true) {
    // Account exists and is active - Show "Sign In" button
    setState(() {
      _errorMessage = 'Account already exists. Please login.';
      _showLoginOption = true;
    });
  } else {
    // Other error
    setState(() {
      _errorMessage = result['message'] ?? 'Something went wrong';
      _showLoginOption = false;
    });
  }
}

  void _goToLogin() {
    final phoneNumber = _phoneController.text.trim();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LoginScreen(guestId: widget.guestId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = Provider.of<CartProvider>(context).cartCount;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF5E0006)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Sign Up',
          style: TextStyle(
            color: Color(0xFF5E0006),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              
              const Center(
                child: Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5E0006),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Sign up with your phone number',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              
              const Text(
                'Phone Number',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5E0006),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: const Text(
                        '+91',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          hintText: 'Enter your number',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onChanged: (value) {
                          // ✅ Reset error when user types
                          if (_errorMessage != null) {
                            setState(() {
                              _errorMessage = null;
                              _showLoginOption = false;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              
              // ✅ Error Message with "Login" option
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _showLoginOption ? Colors.orange.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _showLoginOption ? Colors.orange.shade200 : Colors.red.shade200,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            _showLoginOption ? Icons.info_outline : Icons.error_outline,
                            color: _showLoginOption ? Colors.orange : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: _showLoginOption ? Colors.orange.shade700 : Colors.red.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // ✅ Show "Login" button when account exists
                      if (_showLoginOption) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _goToLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9B0F06),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E0006),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Sign Up with OTP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: _goToLogin,
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        color: Color(0xFF9B0F06),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
}