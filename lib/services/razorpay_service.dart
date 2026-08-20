// lib/services/razorpay_service.dart

import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayService {
  final Razorpay _razorpay = Razorpay();

  void initialize({
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onError,
    required Function(ExternalWalletResponse) onExternalWallet,
  }) {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, onExternalWallet);
  }

  void openPayment({
    required String razorpayKey,
    required String razorpayOrderId,
    required double amount,
    required String name,
    required String email,
    required String phone,
    String description = 'MeenavanFresh Order',
  }) {
    final options = {
      'key': razorpayKey,
      'amount': (amount * 100).round(),
      'currency': 'INR',
      'name': 'MeenavanFresh',
      'description': description,
      'order_id': razorpayOrderId,
      'prefill': {
        'name': name,
        'email': email,
        'contact': phone,
      },
      'theme': {
        'color': '#5E0006',
      },
      'retry': {
        'enabled': true,
        'max_count': 2,
      },
      'send_sms_hash': true,
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      print('RAZORPAY OPEN ERROR: $e');
      rethrow;
    }
  }

  void dispose() {
    _razorpay.clear();
  }
}