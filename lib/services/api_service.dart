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
      
      return jsonDecode(response.body);
    } catch (e) {
      print('HTTP ERROR: $e');
      rethrow;
    }
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
}