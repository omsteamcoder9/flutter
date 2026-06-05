// ========== FILE: lib/services/api_service.dart ==========
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static String get baseUrl => dotenv.env['BASE_URL'] ?? '';
  
  static String get imageBaseUrl {
    String url = baseUrl.replaceFirst('/api', '');
    if (url.endsWith('/api')) {
      url = url.replaceFirst('/api', '');
    }
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }
  
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
  
  static Future<dynamic> deleteWithBody(String endpoint, Map<String, dynamic>? body) async {
    final url = '$baseUrl$endpoint';
    final response = await http.delete(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: body != null ? jsonEncode(body) : null,
    ).timeout(const Duration(seconds: 10));
    return jsonDecode(response.body);
  }
  
  static Future<List<dynamic>> getCategories() async {
    try {
      final response = await get('/categories');
      return response['categories'] ?? [];
    } catch (e) {
      print('Error loading categories: $e');
      return [];
    }
  }
  
  static Future<List<dynamic>> searchProducts(String query, {int limit = 5}) async {
    try {
      final response = await get('/products/quick-search?q=${Uri.encodeComponent(query)}&limit=$limit');    
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
      final response = await get('/products/$slug');
      if (response['success'] == true) {
        return response['data'];
      } else if (response['product'] != null) {
        return response['product'];
      } else {
        return response;
      }
    } catch (e) {
      return null;
    }
  }
  
  static Future<Map<String, dynamic>?> getProductById(String id) async {
    try {
      final response = await get('/products/id/$id');
      if (response['success'] == true) {
        return response['data'];
      } else if (response['product'] != null) {
        return response['product'];
      } else {
        return response;
      }
    } catch (e) {
      return null;
    }
  }
  
  // ========== CART METHODS ==========
  
  static Future<dynamic> getCart({String? guestId}) async {
    try {
      String endpoint = '/cart';
      if (guestId != null && guestId.isNotEmpty) {
        endpoint = '/cart?guestId=$guestId';
      }
      final response = await get(endpoint);
      return response;
    } catch (e) {
      print('Error fetching cart: $e');
      return {'data': {'items': [], 'totalItems': 0, 'totalPrice': 0}};
    }
  }
  
  static Future<dynamic> updateCartItem(String itemId, int quantity, {String? guestId}) async {
    try {
      final Map<String, dynamic> body = {'quantity': quantity};
      if (guestId != null && guestId.isNotEmpty) {
        body['guestId'] = guestId;
      }
      final response = await put('/cart/items/$itemId', body);
      return response;
    } catch (e) {
      print('Error updating cart item: $e');
      rethrow;
    }
  }
  
  static Future<dynamic> removeCartItem(String itemId, {String? guestId}) async {
    try {
      final Map<String, dynamic>? body = guestId != null ? {'guestId': guestId} : null;
      final response = await deleteWithBody('/cart/items/$itemId', body);
      return response;
    } catch (e) {
      rethrow;
    }
  }
  
  static Future<dynamic> clearCart({String? guestId}) async {
    try {
      final Map<String, dynamic>? body = guestId != null ? {'guestId': guestId} : null;
      final response = await deleteWithBody('/cart', body);
      return response;
    } catch (e) {
      print('Error clearing cart: $e');
      rethrow;
    }
  }

  static Future<dynamic> addToCart(String productId, int quantity, String variantId, {String? guestId}) async {
    try {
      final Map<String, dynamic> body = {
        'productId': productId,
        'quantity': quantity,
        'variantId': variantId,
      };
      if (guestId != null && guestId.isNotEmpty) {
        body['guestId'] = guestId;
      }
      final response = await post('/cart', body);
      return response;
    } catch (e) {
      print('Error adding to cart: $e');
      rethrow;
    }
  }

  // ========== ORDER METHODS ==========
  
  static Future<dynamic> createOrder(Map<String, dynamic> orderData, {String? token}) async {
    try {
      final url = '$baseUrl/orders';
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(orderData),
      ).timeout(const Duration(seconds: 30));
      
      return jsonDecode(response.body);
    } catch (e) {
      print('Error creating order: $e');
      rethrow;
    }
  }

  static Future<dynamic> createRazorpayOrder(String orderId) async {
    try {
      final url = '$baseUrl/payments/create-order';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'orderId': orderId}),
      ).timeout(const Duration(seconds: 30));
      
      return jsonDecode(response.body);
    } catch (e) {
      print('Error creating Razorpay order: $e');
      rethrow;
    }
  }

  static Future<dynamic> verifyPayment(Map<String, dynamic> paymentData) async {
    try {
      final url = '$baseUrl/payments/verify-payment';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(paymentData),
      ).timeout(const Duration(seconds: 30));
      
      return jsonDecode(response.body);
    } catch (e) {
      print('Error verifying payment: $e');
      rethrow;
    }
  }

  static Future<dynamic> getOrderReceipt(String orderId, {String? token}) async {
    try {
      final url = '$baseUrl/orders/$orderId/receipt';
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 30));
      
      return jsonDecode(response.body);
    } catch (e) {
      print('Error getting receipt: $e');
      rethrow;
    }
  }
}