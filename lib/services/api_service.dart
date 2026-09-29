import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order.dart';
import '../models/terms.dart';
import '../models/privacy.dart';

class ApiService {
  // ============================================================
  // 🌐 API BASE URL — from .env
  // ============================================================
  static String get baseUrl {
    final url = dotenv.env['BASE_URL'] ?? '';
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  // ============================================================
  // 🖼️ IMAGE BASE URL — from .env (Cloudflare R2)
  // ============================================================
  static String get imageBaseUrl {
    final url = dotenv.env['IMG_BASE_URL'] ?? '';
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  // ============================================================
  // HTTP HELPERS
  // ============================================================

  // GET with optional auth
  static Future<dynamic> getWithAuth(String endpoint, {String? token}) async {
    try {
      final url = '$baseUrl$endpoint';
      print('BASE_URL = $baseUrl');
      print('REQUEST URL: $url');

      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 10));

      print('STATUS CODE: ${response.statusCode}');
      print('BODY: ${response.body}');

      try {
        final decoded = jsonDecode(response.body);
        return decoded;
      } catch (e) {
        return response.body;
      }
    } catch (e) {
      print('HTTP ERROR: $e');
      rethrow;
    }
  }

  // POST with optional auth
  static Future<dynamic> postWithAuth(String endpoint, dynamic data,
      {String? token}) async {
    try {
      final url = '$baseUrl$endpoint';
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .post(Uri.parse(url), headers: headers, body: jsonEncode(data))
          .timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      print('POST ERROR: $e');
      rethrow;
    }
  }

  // PUT with optional auth
  static Future<dynamic> putWithAuth(String endpoint, dynamic data,
      {String? token}) async {
    try {
      final url = '$baseUrl$endpoint';
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .put(Uri.parse(url), headers: headers, body: jsonEncode(data))
          .timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      print('PUT ERROR: $e');
      rethrow;
    }
  }

  // DELETE with optional auth and body
  static Future<dynamic> deleteWithAuth(String endpoint,
      {Map<String, dynamic>? body, String? token}) async {
    try {
      final url = '$baseUrl$endpoint';
      final Map<String, String> headers = {};

      if (body != null) {
        headers['Content-Type'] = 'application/json';
      }

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final request = http.Request('DELETE', Uri.parse(url));
      request.headers.addAll(headers);
      if (body != null) {
        request.body = jsonEncode(body);
      }

      final response = await request.send().timeout(const Duration(seconds: 10));
      final responseBody = await response.stream.bytesToString();

      return jsonDecode(responseBody);
    } catch (e) {
      print('DELETE ERROR: $e');
      rethrow;
    }
  }

  // Plain GET
  static Future<dynamic> get(String endpoint) async {
    try {
      final url = '$baseUrl$endpoint';
      print('BASE_URL = $baseUrl');
      print('REQUEST URL: $url');

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      print('STATUS CODE: ${response.statusCode}');
      print('BODY: ${response.body}');

      try {
        final decoded = jsonDecode(response.body);
        return decoded;
      } catch (e) {
        return response.body;
      }
    } catch (e) {
      print('HTTP ERROR: $e');
      rethrow;
    }
  }

  // Plain POST
  static Future<dynamic> post(String endpoint, dynamic data) async {
    try {
      final url = '$baseUrl$endpoint';
      final response = await http
          .post(Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(data))
          .timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      print('POST ERROR: $e');
      rethrow;
    }
  }

  // Plain PUT
  static Future<dynamic> put(String endpoint, dynamic data) async {
    try {
      final url = '$baseUrl$endpoint';
      final response = await http
          .put(Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(data))
          .timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      print('PUT ERROR: $e');
      rethrow;
    }
  }

  // Plain DELETE
  static Future<dynamic> delete(String endpoint) async {
    try {
      final url = '$baseUrl$endpoint';
      final response = await http
          .delete(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      print('DELETE ERROR: $e');
      rethrow;
    }
  }

  // DELETE with body
  static Future<dynamic> deleteWithBody(
      String endpoint, Map<String, dynamic>? body) async {
    final url = '$baseUrl$endpoint';
    final response = await http.delete(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: body != null ? jsonEncode(body) : null,
    ).timeout(const Duration(seconds: 10));
    return jsonDecode(response.body);
  }

  // ============================================================
  // CATEGORIES & PRODUCTS
  // ============================================================

  static Future<List<dynamic>> getCategories() async {
    try {
      final response = await get('/categories');
      return response['categories'] ?? [];
    } catch (e) {
      print('Error loading categories: $e');
      return [];
    }
  }

  static Future<List<dynamic>> searchProducts(String query,
      {int limit = 5}) async {
    try {
      final response = await get(
          '/products/quick-search?q=${Uri.encodeComponent(query)}&limit=$limit');
      if (response is Map<String, dynamic>) {
        if (response['data'] is List) {
          return response['data'];
        }
      }
      if (response is List) {
        return response;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> getProducts({
    String? category,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final List<String> params = [];
      if (category != null && category.isNotEmpty) {
        params.add('category=${Uri.encodeComponent(category)}');
      }
      if (search != null && search.isNotEmpty) {
        params.add('search=${Uri.encodeComponent(search)}');
      }
      params.add('page=$page');
      params.add('limit=$limit');

      final endpoint = '/products?${params.join('&')}';
      final response = await get(endpoint);

      return {
        'products': response['products'] ?? response['data'] ?? [],
        'total': response['total'] ?? 0,
        'page': response['page'] ?? page,
        'totalPages': response['totalPages'] ?? 1,
      };
    } catch (e) {
      return {
        'products': [],
        'total': 0,
        'page': 1,
        'totalPages': 1,
      };
    }
  }

  static Future<Map<String, dynamic>?> getProductBySlug(String slug) async {
    try {
      final response = await get('/products/slug/$slug');
      if (response['success'] == true) {
        return response['data'];
      }
      return null;
    } catch (e) {
      print('Error fetching product by slug: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getProductById(String id) async {
    try {
      final response = await get('/products/$id');
      if (response['success'] == true) {
        return response['data'];
      }
      return null;
    } catch (e) {
      print('Error fetching product by ID: $e');
      return null;
    }
  }

  // ============================================================
  // CART
  // ============================================================

  static Future<dynamic> getCart({String? guestId, String? token}) async {
    try {
      String endpoint = '/cart';

      print('🛒 getCart - token exists: ${token != null}');
      print('🛒 getCart - guestId: $guestId');

      if (token != null && token.isNotEmpty) {
        endpoint = '/cart';
        print('🛒 Using authenticated endpoint: $endpoint');
      } else {
        if (guestId != null && guestId.isNotEmpty) {
          endpoint = '/cart?guestId=$guestId';
          print('🛒 Using guest endpoint: $endpoint');
        }
      }

      final response = await getWithAuth(endpoint, token: token);
      return response;
    } catch (e) {
      print('Error fetching cart: $e');
      return {
        'data': {'items': [], 'totalItems': 0, 'totalPrice': 0}
      };
    }
  }

  static Future<dynamic> updateCartItem(String itemId, int quantity,
      {String? guestId, String? token}) async {
    try {
      final Map<String, dynamic> body = {'quantity': quantity};
      if (guestId != null &&
          guestId.isNotEmpty &&
          (token == null || token.isEmpty)) {
        body['guestId'] = guestId;
      }
      final response =
          await putWithAuth('/cart/items/$itemId', body, token: token);
      return response;
    } catch (e) {
      print('Error updating cart item: $e');
      rethrow;
    }
  }

  static Future<dynamic> removeCartItem(String itemId,
      {String? guestId, String? token}) async {
    try {
      if (token != null && token.isNotEmpty) {
        final response =
            await deleteWithAuth('/cart/items/$itemId', body: null, token: token);
        return response;
      }

      final Map<String, dynamic>? body =
          (guestId != null && guestId.isNotEmpty) ? {'guestId': guestId} : null;
      final response =
          await deleteWithAuth('/cart/items/$itemId', body: body, token: null);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  static Future<dynamic> clearCart({String? guestId, String? token}) async {
    try {
      if (token != null && token.isNotEmpty) {
        final response = await deleteWithAuth('/cart', body: null, token: token);
        return response;
      }

      final Map<String, dynamic>? body =
          (guestId != null && guestId.isNotEmpty) ? {'guestId': guestId} : null;
      final response = await deleteWithAuth('/cart', body: body, token: null);
      return response;
    } catch (e) {
      print('Error clearing cart: $e');
      rethrow;
    }
  }

  static Future<dynamic> addToCart(String productId, int quantity, String variantId,
      {String? guestId, String? token}) async {
    try {
      final Map<String, dynamic> body = {
        'productId': productId,
        'quantity': quantity,
        'variantId': variantId,
      };
      if (guestId != null &&
          guestId.isNotEmpty &&
          (token == null || token.isEmpty)) {
        body['guestId'] = guestId;
      }

      final response = await postWithAuth('/cart', body, token: token);
      return response;
    } catch (e) {
      print('Error adding to cart: $e');
      rethrow;
    }
  }

  // ============================================================
  // ORDERS
  // ============================================================

  static Future<dynamic> createOrder(Map<String, dynamic> orderData,
      {String? token}) async {
    try {
      final url = '$baseUrl/orders';
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .post(Uri.parse(url), headers: headers, body: jsonEncode(orderData))
          .timeout(const Duration(seconds: 30));

      return jsonDecode(response.body);
    } catch (e) {
      print('Error creating order: $e');
      rethrow;
    }
  }

  static Future<dynamic> createRazorpayOrder(String orderId) async {
    try {
      final url = '$baseUrl/payments/create-order';
      final response = await http
          .post(Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'orderId': orderId}))
          .timeout(const Duration(seconds: 30));

      return jsonDecode(response.body);
    } catch (e) {
      print('Error creating Razorpay order: $e');
      rethrow;
    }
  }

  static Future<dynamic> verifyPayment(Map<String, dynamic> paymentData) async {
    try {
      final url = '$baseUrl/payments/verify-payment';
      final response = await http
          .post(Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(paymentData))
          .timeout(const Duration(seconds: 30));

      return jsonDecode(response.body);
    } catch (e) {
      print('Error verifying payment: $e');
      rethrow;
    }
  }

  // ============================================================
  // USER ORDERS
  // ============================================================

  static Future<List<Order>> getUserOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) throw Exception('Not authenticated');

    final response = await getWithAuth('/orders/my-orders', token: token);

    if (response['success'] == true) {
      final ordersData = response['orders'] as List? ?? [];
      return ordersData.map((data) => Order.fromJson(data)).toList();
    }
    throw Exception(response['message'] ?? 'Failed to fetch orders');
  }

  static Future<Order> getOrderById(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) throw Exception('Not authenticated');

    final response = await getWithAuth('/orders/$orderId', token: token);

    if (response['success'] == true) {
      return Order.fromJson(response['order']);
    }
    throw Exception(response['message'] ?? 'Failed to fetch order');
  }

  static Future<Map<String, dynamic>> cancelOrder(String orderId,
      {String? reason}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) throw Exception('Not authenticated');

    final body = reason != null ? {'cancellationReason': reason} : {};
    return await putWithAuth('/orders/$orderId/cancel', body, token: token);
  }

  static Future<Uint8List?> downloadOrderReceiptPDF(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) throw Exception('Not authenticated');

    final url = '$baseUrl/orders/$orderId/receipt/pdf';
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    return null;
  }

  // ============================================================
  // TERMS & PRIVACY
  // ============================================================

  static Future<TermsData> getTerms() async {
    try {
      final response = await get('/terms');

      if (response['success'] == true) {
        return TermsData.fromJson(response['data']);
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch terms');
      }
    } catch (e) {
      print('Error fetching terms: $e');
      rethrow;
    }
  }

  static Future<PrivacyData> getPrivacy() async {
    try {
      final response = await get('/privacy');

      if (response['success'] == true) {
        return PrivacyData.fromJson(response['data']);
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch privacy policy');
      }
    } catch (e) {
      print('Error fetching privacy policy: $e');
      rethrow;
    }
  }

  // ============================================================
  // WARDS
  // ============================================================

  static Future<List<Map<String, dynamic>>> getWards() async {
    try {
      final response = await get('/wards');
      print('🔍 Wards API response: $response');

      if (response['success'] == true) {
        final data = response['data'];
        if (data is Map && data.containsKey('wards')) {
          return List<Map<String, dynamic>>.from(data['wards']);
        }
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching wards: $e');
      return [];
    }
  }

  static Future<List<String>> getStreetsByWard(int wardId) async {
    try {
      final response = await get('/wards/$wardId/streets');
      print('🔍 Streets API response: $response');

      if (response['success'] == true) {
        final data = response['data'];
        if (data is Map && data.containsKey('streets')) {
          return List<String>.from(data['streets']);
        }
        if (data is List) {
          return List<String>.from(data);
        }
      }
      return [];
    } catch (e) {
      print('Error fetching streets: $e');
      return [];
    }
  }
  static Future<Map<String, dynamic>?> getShipping() async {
  try {
    final response = await get('/shipping');
    if (response['success'] == true) return response['data'];
    return null;
  } catch (e) {
    print('Error fetching shipping: $e');
    return null;
  }
}

static Future<Map<String, dynamic>?> getReturns() async {
  try {
    final response = await get('/returns');
    if (response['success'] == true) return response['data'];
    return null;
  } catch (e) {
    print('Error fetching returns: $e');
    return null;
  }
}
// ============================================================
// CONTACT
// ============================================================

static Future<Map<String, dynamic>> submitContact(
    Map<String, dynamic> data) async {
  try {
    final url = '$baseUrl/contacts';

    // ✅ 45-second timeout: backend sends 2 emails (admin + user confirmation)
    // Gmail SMTP can take 20-30s to complete
    final response = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 45));

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {
      'success': false,
      'message': 'Unexpected response from server',
    };
  } catch (e) {
    print('Error submitting contact: $e');
    return {
      'success': false,
      'message': 'Failed to send message: $e',
    };
  }
}

  // ============================================================
  // PUBLIC SETTINGS
  // ============================================================

  static Future<Map<String, dynamic>> getPublicSettings() async {
    try {
      final response = await get('/settings/public');
      return response['data'] ?? {};
    } catch (e) {
      throw Exception('Failed to load settings: $e');
    }
  }
}