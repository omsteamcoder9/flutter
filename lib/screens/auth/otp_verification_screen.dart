import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../checkout_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String otpSessionId;
  final String phoneNumber;
  final bool isNewUser;
  final bool hasInactiveUser;
  final String? guestId;
  final bool hasPendingCheckout;

  const OtpVerificationScreen({
    super.key,
    required this.otpSessionId,
    required this.phoneNumber,
    required this.isNewUser,
    this.hasInactiveUser = false,
    this.guestId,
    this.hasPendingCheckout = false,
  });

  @override
  State<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState
    extends State<OtpVerificationScreen> {
  final TextEditingController _otpController =
      TextEditingController();

  final FocusNode _otpFocusNode = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;

  int _resendTimer = 30;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();

    _otpController.addListener(_onOtpChanged);

    _startResendTimer();

    // Open keyboard immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _otpFocusNode.requestFocus();
      }
    });
  }

  // ─────────────────────────────────────────────
  // OTP CHANGED
  // ─────────────────────────────────────────────

  void _onOtpChanged() {
    final value = _otpController.text;

    // Keep only numbers.
    final digits = value.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    // Maximum 6 digits.
    final otp = digits.length > 6
        ? digits.substring(0, 6)
        : digits;

    // If formatter/input method produced unwanted text,
    // normalize it.
    if (_otpController.text != otp) {
      _otpController.value = TextEditingValue(
        text: otp,
        selection: TextSelection.collapsed(
          offset: otp.length,
        ),
      );
      return;
    }

    if (mounted) {
      setState(() {
        _errorMessage = null;
      });
    }

    // Automatically verify immediately after
    // the sixth digit is entered.
    if (otp.length == 6 && !_isLoading) {
      _verifyOtp();
    }
  }

  // ─────────────────────────────────────────────
  // OTP CODE
  // ─────────────────────────────────────────────

  String get _otpCode {
    return _otpController.text;
  }

  // ─────────────────────────────────────────────
  // RESEND TIMER
  // ─────────────────────────────────────────────

  void _startResendTimer() {
    Future.delayed(
      const Duration(seconds: 1),
      () {
        if (!mounted) return;

        if (_resendTimer > 0) {
          setState(() {
            _resendTimer--;
          });

          _startResendTimer();
        } else {
          setState(() {
            _canResend = true;
          });
        }
      },
    );
  }

  // ─────────────────────────────────────────────
  // VERIFY OTP
  // ─────────────────────────────────────────────

  Future<void> _verifyOtp() async {
    if (_isLoading) return;

    if (_otpCode.length != 6) {
      setState(() {
        _errorMessage = 'Please enter 6-digit OTP';
      });
      return;
    }

    // Hide keyboard before API request.
    _otpFocusNode.unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider =
          Provider.of<AuthProvider>(
        context,
        listen: false,
      );

      final result = await authProvider.verifyOtp(
        widget.otpSessionId,
        _otpCode,
        guestId: widget.guestId,
        context: context,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        String successMessage;

        if (widget.hasInactiveUser) {
          successMessage = 'Account Reactivated!';
        } else if (widget.isNewUser) {
          successMessage = 'Account Created!';
        } else {
          successMessage = 'Login Successful!';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );

        final prefs =
            await SharedPreferences.getInstance();

        if (!mounted) return;

        final hasPendingCheckout =
            prefs.getBool('pending_checkout') ?? false;

        if (hasPendingCheckout) {
          await prefs.remove('pending_checkout');

          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => CheckoutScreen(
                guestId: null,
                onOrderPlaced: () {},
              ),
            ),
          );
        } else {
          Navigator.pushReplacementNamed(
            context,
            '/',
          );
        }
      } else {
        setState(() {
          _errorMessage =
              result['message'] ??
                  'OTP verification failed';

          // Put focus back so the user can immediately
          // correct the OTP.
          _otpFocusNode.requestFocus();
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Something went wrong. Please try again.';
      });

      _otpFocusNode.requestFocus();
    }
  }

  // ─────────────────────────────────────────────
  // RESEND OTP
  // ─────────────────────────────────────────────

  Future<void> _resendOtp() async {
    if (!_canResend || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _canResend = false;
      _resendTimer = 30;
    });

    try {
      final authProvider =
          Provider.of<AuthProvider>(
        context,
        listen: false,
      );

      final result =
          await authProvider.sendOtp(
        widget.phoneNumber,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        _otpController.clear();

        _startResendTimer();

        _otpFocusNode.requestFocus();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'OTP resent successfully',
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage =
              result['message'] ??
                  'Failed to resend OTP';

          _canResend = true;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Failed to resend OTP';
        _canResend = true;
      });
    }
  }

  // ─────────────────────────────────────────────
  // DISPOSE
  // ─────────────────────────────────────────────

  @override
  void dispose() {
    _otpController.removeListener(
      _onOtpChanged,
    );

    _otpController.dispose();
    _otpFocusNode.dispose();

    super.dispose();
  }

  // ─────────────────────────────────────────────
  // OTP BOX
  // ─────────────────────────────────────────────

  Widget _buildOtpBox(int index) {
    final otp = _otpController.text;

    final String digit =
        index < otp.length ? otp[index] : '';

    final bool isActive =
        index == otp.length &&
            otp.length < 6;

    return AnimatedContainer(
      duration: const Duration(
        milliseconds: 80,
      ),
      width: 50,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? const Color(0xFF5E0006)
              : digit.isNotEmpty
                  ? const Color(0xFF5E0006)
                  : Colors.grey.shade300,
          width: isActive || digit.isNotEmpty
              ? 2
              : 1,
        ),
      ),
      child: Text(
        digit,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF5E0006),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Color(0xFF5E0006),
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),

      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            _otpFocusNode.requestFocus();
          },

          child: Padding(
            padding:
                const EdgeInsets.all(24),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                const Text(
                  'Verify OTP',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(0xFF5E0006),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Enter the 6-digit code sent to ${widget.phoneNumber}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 32),

                // ─────────────────────────
                // OTP DISPLAY
                // ─────────────────────────

                Stack(
                  children: [
                    // Visible OTP boxes
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        6,
                        (index) {
                          return _buildOtpBox(
                            index,
                          );
                        },
                      ),
                    ),

                    // ONE real TextField.
                    //
                    // It receives all keyboard input.
                    // This makes typing/backspace
                    // extremely smooth.
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.01,
                        child: TextField(
                          controller:
                              _otpController,
                          focusNode:
                              _otpFocusNode,
                          autofocus: true,
                          keyboardType:
                              TextInputType.number,
                          textInputAction:
                              TextInputAction.done,
                          maxLength: 6,

                          inputFormatters: [
                            FilteringTextInputFormatter
                                .digitsOnly,
                            LengthLimitingTextInputFormatter(
                              6,
                            ),
                          ],

                          decoration:
                              const InputDecoration(
                            border:
                                InputBorder.none,
                            counterText: '',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      _errorMessage!,
                      style:
                          const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                      textAlign:
                          TextAlign.center,
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // ─────────────────────────
                // VERIFY BUTTON
                // ─────────────────────────

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _isLoading
                            ? null
                            : _verifyOtp,

                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(
                        0xFF5E0006,
                      ),
                      foregroundColor:
                          Colors.white,

                      padding:
                          const EdgeInsets
                              .symmetric(
                        vertical: 16,
                      ),

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          12,
                        ),
                      ),
                    ),

                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Text(
                            'Verify & Continue',
                            style:
                                TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // ─────────────────────────
                // RESEND
                // ─────────────────────────

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Didn't receive code? ",
                      style:
                          TextStyle(
                        color: Colors.grey,
                      ),
                    ),

                    GestureDetector(
                      onTap:
                          _canResend &&
                                  !_isLoading
                              ? _resendOtp
                              : null,

                      child: Text(
                        _canResend
                            ? 'Resend OTP'
                            : 'Resend in ${_resendTimer}s',

                        style:
                            TextStyle(
                          color: _canResend
                              ? const Color(
                                  0xFFD53E0F,
                                )
                              : Colors.grey,

                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}