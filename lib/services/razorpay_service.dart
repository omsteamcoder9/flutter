// lib/services/razorpay_service.dart
import 'package:custom_tabs/custom_tabs.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class RazorpayService {
  static Future<bool> startPayment({
    required String orderId,
    required double amount,
    required String name,
    required String email,
    required String phone,
    required String token,
  }) async {
    try {
      // Step 1: Create Razorpay order
      final createOrderUrl = '${ApiService.baseUrl}/payments/create-order';
      final createResponse = await http.post(
        Uri.parse(createOrderUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'orderId': orderId}),
      );

      final createData = jsonDecode(createResponse.body);
      
      if (createData['success'] != true) {
        return false;
      }

      final razorpayKey = createData['key'];
      final razorpayOrder = createData['order'];

      // Step 2: Build Razorpay checkout URL
      final paymentUrl = Uri.parse(
        'https://checkout.razorpay.com/v1/checkout.js'
      );

      // Step 3: Open in Chrome Custom Tab
      final success = await CustomTabs.launch(
        paymentUrl,
        customTabsOption: CustomTabsOption(
          toolbarColor: const Color(0xFF5E0006),
          enableDefaultShare: false,
          instantAppsEnabled: true,
          showTitle: true,
          urlBarHidingEnabled: true,
        ),
        safariVCOption: SafariVCOption(
          barCollapsingEnabled: true,
          preferredBarTintColor: const Color(0xFF5E0006),
          preferredControlTintColor: Colors.white,
        ),
      );

      return success;
    } catch (e) {
      print('Razorpay service error: $e');
      return false;
    }
  }
}