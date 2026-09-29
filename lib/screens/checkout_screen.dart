import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/cart_drawer.dart';
import 'order_success_screen.dart';
import 'auth/signup_screen.dart';
import 'profile/profile_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final String? guestId;
  final VoidCallback onOrderPlaced;

  const CheckoutScreen({
    super.key,
    this.guestId,
    required this.onOrderPlaced,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _alternatePhoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController(text: 'Tamil Nadu');
  final _postalCodeController = TextEditingController();
  final _countryController = TextEditingController(text: 'India');
  final _landmarkController = TextEditingController();

  // Google Places suggestions are kept separate from the text field,
  // so the street input behaves like a normal Flutter TextField.
  final FocusNode _streetFocusNode = FocusNode();
  Timer? _streetSearchTimer;
  List<Prediction> _streetPredictions = [];
  bool _streetSearching = false;
  bool _showWebsiteMapControls = false;

  String _paymentMethod = 'cod';
  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic> _cart = {'items': [], 'totalItems': 0, 'totalPrice': 0};
  Map<String, dynamic>? _buyNowItem;
  bool _isBuyNowMode = false;

  int _currentIndex = 1;
  int _cartCount = 0;

  // Map state
  GoogleMapController? _mapController;
  LatLng? _pinPosition;
  bool _locating = false;
  String? _mapError;

  // Razorpay
  Razorpay? _razorpay;
  Map<String, dynamic>? _pendingOrder;
  bool _paymentHandled = false;

  static const LatLng _defaultCenter = LatLng(10.0667, 78.7833);

  @override
  void initState() {
    super.initState();
    _checkBuyNowOrder();
    _loadCartData();
    _loadCartCount();
    _prefillUser();

    _razorpay = Razorpay();
    _razorpay?.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay?.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay?.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _alternatePhoneController.dispose();
    _emailController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    _landmarkController.dispose();
    _streetFocusNode.dispose();
    _streetSearchTimer?.cancel();
    _mapController?.dispose();
    _razorpay?.clear();
    super.dispose();
  }

  // ============================================================
  // PREFILL
  // ============================================================

  void _prefillUser() {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      if (user == null) return;

      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        _phoneController.text = user.phoneNumber!;
      }
      if (user.email != null && user.email!.isNotEmpty) {
        _emailController.text = user.email!;
      }
      // Do NOT prefill name
    } catch (e) {
      debugPrint('Prefill error: $e');
    }
  }

  // ============================================================
  // RAZORPAY CALLBACKS
  // ============================================================

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint('✅ RAZORPAY SUCCESS: ${response.paymentId}');
    if (_paymentHandled) return;
    _paymentHandled = true;

    final razorpayOrderId = response.orderId;
    final razorpayPaymentId = response.paymentId;
    final razorpaySignature = response.signature;

    if (razorpayOrderId == null ||
        razorpayOrderId.isEmpty ||
        razorpayPaymentId == null ||
        razorpayPaymentId.isEmpty ||
        razorpaySignature == null ||
        razorpaySignature.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Payment completed, but verification data missing.';
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    Map<String, dynamic>? verificationResponse;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final result = await ApiService.verifyPayment({
          'razorpay_order_id': razorpayOrderId,
          'razorpay_payment_id': razorpayPaymentId,
          'razorpay_signature': razorpaySignature,
        });
        if (result is Map) {
          verificationResponse = Map<String, dynamic>.from(result);
        }
        if (verificationResponse?['success'] == true) break;
      } catch (e) {
        debugPrint('Attempt $attempt failed: $e');
      }
      if (attempt < 3) await Future.delayed(Duration(seconds: attempt * 2));
    }

    try {
      if (verificationResponse?['success'] != true) {
        await _recoverPayment(razorpayOrderId);
        return;
      }

      final verifiedOrderRaw = verificationResponse?['order'];
      if (verifiedOrderRaw is! Map) {
        throw Exception('Order details missing');
      }

      final successOrder = <String, dynamic>{};
      if (_pendingOrder != null) successOrder.addAll(_pendingOrder!);
      successOrder.addAll(Map<String, dynamic>.from(verifiedOrderRaw));

      final verifiedOrderId = successOrder['orderId']?.toString() ??
          _pendingOrder?['orderId']?.toString();

      if (verifiedOrderId == null || verifiedOrderId.isEmpty) {
        throw Exception('Order ID missing');
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });

      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OrderSuccessScreen(
            orderId: verifiedOrderId,
            orderData: successOrder,
          ),
        ),
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          widget.onOrderPlaced();
          final ap = Provider.of<AuthProvider>(context, listen: false);
          if (ap.isLoggedIn) ap.notifyListeners();
        } catch (_) {}
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _paymentHandled = false;
        _isLoading = false;
        _errorMessage = 'Payment verification failed. Check My Orders.';
      });
    }
  }

  Future<void> _recoverPayment(String? razorpayOrderId) async {
    try {
      if (razorpayOrderId == null || razorpayOrderId.isEmpty) {
        throw Exception('Missing razorpay order id');
      }
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      if (token == null || token.isEmpty) throw Exception('No token');

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/orders/razorpay/$razorpayOrderId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Recovery failed: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      if (data['success'] != true) throw Exception('Recovery error');

      final rawOrder = data['order'] ?? data['data'];
      if (rawOrder is! Map) throw Exception('Order missing');

      final recoveredOrder = Map<String, dynamic>.from(rawOrder);
      final paymentStatus = recoveredOrder['paymentStatus']?.toString().toLowerCase();
      final orderStatus = recoveredOrder['orderStatus']?.toString().toLowerCase();

      final ok = (paymentStatus == 'completed' ||
              paymentStatus == 'paid' ||
              paymentStatus == 'captured' ||
              paymentStatus == 'success') ||
          (orderStatus == 'confirmed' ||
              orderStatus == 'processing' ||
              orderStatus == 'shipped' ||
              orderStatus == 'delivered');

      if (!ok) throw Exception('Not confirmed');

      final successOrder = <String, dynamic>{};
      if (_pendingOrder != null) successOrder.addAll(_pendingOrder!);
      successOrder.addAll(recoveredOrder);

      final recoveredOrderId = successOrder['orderId']?.toString();
      if (recoveredOrderId == null || recoveredOrderId.isEmpty) {
        throw Exception('Recovered order id missing');
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });

      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OrderSuccessScreen(
            orderId: recoveredOrderId,
            orderData: successOrder,
          ),
        ),
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          widget.onOrderPlaced();
        } catch (_) {}
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _paymentHandled = false;
        _isLoading = false;
        _errorMessage = 'Payment may have completed. Check My Orders.';
      });
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('❌ RAZORPAY ERROR: ${response.message}');
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _paymentHandled = false;
      _errorMessage = 'Payment failed: ${response.message ?? 'Unknown error'}';
    });
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('🔵 WALLET: ${response.walletName}');
  }

  // ============================================================
  // MAP HANDLERS
  // ============================================================

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _pinPosition = position;
      _mapError = null;
    });
    _reverseGeocode(position);
  }

  Future<void> _reverseGeocode(
    LatLng position, {
    bool updateStreet = true,
  }) async {
    try {
      final placemarks = await geo.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) return;
      final p = placemarks.first;

      final streetParts = [
        p.street ?? '',
        p.subLocality ?? '',
      ].where((s) => s.trim().isNotEmpty).toList();

      final streetText = streetParts.join(', ');
      final city = p.locality ?? p.subAdministrativeArea ?? '';
      final state = p.administrativeArea ?? '';
      final postal = p.postalCode ?? '';
      final country = p.country ?? '';

      if (!mounted) return;
      setState(() {
        if (updateStreet && streetText.isNotEmpty) {
          _streetController.value = TextEditingValue(
            text: streetText,
            selection: TextSelection.collapsed(
              offset: streetText.length,
            ),
            composing: TextRange.empty,
          );
        }
        if (city.isNotEmpty) _cityController.text = city;
        if (state.isNotEmpty) _stateController.text = state;
        if (postal.isNotEmpty) _postalCodeController.text = postal;
        if (country.isNotEmpty) _countryController.text = country;
      });
    } catch (e) {
      debugPrint('Reverse geocode failed: $e');
    }
  }

  Future<void> _useMyLocation() async {
    try {
      setState(() {
        _locating = true;
        _mapError = null;
      });

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services disabled. Please enable them.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permanently denied. Enable in settings.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final latLng = LatLng(position.latitude, position.longitude);

      if (!mounted) return;
      setState(() {
        _pinPosition = latLng;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 17),
      );

      await _reverseGeocode(latLng);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mapError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ============================================================
  // DATA LOADING
  // ============================================================

  Future<void> _loadCartCount() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = authProvider.isLoggedIn;
      final token = prefs.getString('auth_token');

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
      debugPrint('Cart count error: $e');
    }
  }

  Future<void> _checkBuyNowOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final buyNowJson = prefs.getString('buy_now_order');
    if (buyNowJson != null && buyNowJson.isNotEmpty) {
      try {
        final data = jsonDecode(buyNowJson);
        setState(() {
          _buyNowItem = data;
          _isBuyNowMode = true;
        });
      } catch (e) {
        debugPrint('Buy now parse error: $e');
      }
    }
  }

  Future<void> _loadCartData() async {
    if (_isBuyNowMode) return;
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final isLoggedIn = authProvider.isLoggedIn;

      final response = await ApiService.getCart(
        guestId: isLoggedIn ? null : widget.guestId,
        token: token,
      );

      if (response['success'] == true && mounted) {
        setState(() {
          _cart = response['data'] ??
              {'items': [], 'totalItems': 0, 'totalPrice': 0};
        });
      }
    } catch (e) {
      debugPrint('Cart load error: $e');
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  double _getSubtotal() {
    if (_isBuyNowMode && _buyNowItem != null) {
      return (_buyNowItem!['price'] ?? 0) * (_buyNowItem!['quantity'] ?? 1);
    }
    return (_cart['totalPrice'] ?? 0).toDouble();
  }

  int _getItemCount() {
    if (_isBuyNowMode && _buyNowItem != null) {
      return _buyNowItem!['quantity'] ?? 1;
    }
    return _cart['totalItems'] ?? 0;
  }

  void _openCart() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    String? guestIdToUse = authProvider.isLoggedIn ? null : widget.guestId;
    String? tokenToUse = authProvider.isLoggedIn ? authProvider.token : null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartScreen(
          guestId: guestIdToUse,
          token: tokenToUse,
          onCartUpdate: () => _loadCartCount(),
        ),
      ),
    );
  }

  void _showAuthDialog() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfileScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SignupScreen()),
      );
    }
  }

  void _navigateToHome() {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // ============================================================
  // PLACE ORDER
  // ============================================================

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_streetController.text.trim().isEmpty ||
        _streetController.text.trim().length < 5) {
      _showError('Please enter a complete street address');
      return;
    }

    if (_cityController.text.trim().isEmpty) {
      _showError('Please enter city or pin your location on the map');
      return;
    }

    if (_phoneController.text.trim().length < 10) {
      _showError('Please enter a valid 10-digit phone number');
      return;
    }

    if (_pinPosition == null) {
      _showError('Please drop the pin on the map to mark your delivery location');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final isLoggedIn = authProvider.isLoggedIn;

      List<Map<String, dynamic>> products = [];

      if (_isBuyNowMode && _buyNowItem != null) {
        products = [
          {
            'product': _buyNowItem!['productId'],
            'variantId': _buyNowItem!['variantId'] ?? '',
            'variantName': _buyNowItem!['variantName'] ?? '',
            'price': _buyNowItem!['price'],
            'quantity': _buyNowItem!['quantity'],
          }
        ];
      } else {
        final cartResponse = await ApiService.getCart(
          guestId: widget.guestId,
          token: token,
        );

        if (cartResponse['success'] == true && cartResponse['data'] != null) {
          final cartItems = cartResponse['data']['items'] ?? [];
          for (var item in cartItems) {
            String productId = item['product'] is Map
                ? item['product']['_id']
                : item['product'].toString();

            products.add({
              'product': productId,
              'variantId': item['variantId'] ?? '',
              'variantName': item['variantName'] ?? '',
              'price': item['price'],
              'quantity': item['quantity'],
            });
          }
        }
      }

      if (products.isEmpty) throw Exception('No items to checkout');

      final orderData = {
        'shippingAddress': {
          'name': _nameController.text.trim(),
          'street': _streetController.text.trim(),
          'city': _cityController.text.trim(),
          'state': _stateController.text.trim(),
          'postalCode': _postalCodeController.text.trim(),
          'country': _countryController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'alternatePhone': _alternatePhoneController.text.trim(),
        },
        'alternatePhone': _alternatePhoneController.text.trim(),
        'paymentMethod': _paymentMethod,
        'products': products,
        'typedArea': _streetController.text.trim(),
        'landmark': _landmarkController.text.trim(),
        'customerPin': {
          'lat': _pinPosition!.latitude,
          'lng': _pinPosition!.longitude,
        },
      };

      if (_isBuyNowMode) {
        orderData['skipCartClear'] = true;
      }

      final url = '${ApiService.baseUrl}/orders';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (isLoggedIn && token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(orderData),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode != 201 || responseData['success'] != true) {
        throw Exception(responseData['message'] ?? 'Failed to create order');
      }

      final order = responseData['order'];
      final requiresPayment = responseData['requiresPayment'] ?? false;

      if (_isBuyNowMode) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('buy_now_order');
        await prefs.remove('pending_checkout');
      }

      if (!requiresPayment) {
        widget.onOrderPlaced();
        final authProviderRefresh =
            Provider.of<AuthProvider>(context, listen: false);
        if (authProviderRefresh.isLoggedIn) authProviderRefresh.notifyListeners();

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OrderSuccessScreen(
                orderId: order['orderId'],
                orderData: order,
              ),
            ),
          );
        }
      } else {
        _pendingOrder = Map<String, dynamic>.from(order);
        _paymentHandled = false;
        await _openRazorpayPayment(order);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _openRazorpayPayment(dynamic order) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null) {
      setState(() {
        _errorMessage = 'Please login to continue';
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/payments/create-order'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'orderId': order['orderId']}),
      );

      final data = jsonDecode(response.body);
      if (data['success'] != true) {
        throw Exception(data['message'] ?? 'Failed to create payment order');
      }

      final razorpayOrder = data['order'];
      final key = data['key'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('razorpay_order_id', order['orderId']);

      final options = {
        'key': key,
        'amount': razorpayOrder['amount'],
        'currency': razorpayOrder['currency'] ?? 'INR',
        'name': 'MeenavanFresh',
        'description': 'Order ${order['orderId']}',
        'order_id': razorpayOrder['id'],
        'prefill': {
          'contact': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
        },
        'theme': {'color': '#07566B'},
      };

      _razorpay?.open(options);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize payment: $e';
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // GOOGLE PLACES — NORMAL TEXT FIELD + SEPARATE SUGGESTIONS
  // ============================================================

  void _onStreetChanged(String value) {
    setState(() {});

    _streetSearchTimer?.cancel();

    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _streetPredictions = [];
        _streetSearching = false;
      });
      return;
    }

    _streetSearchTimer = Timer(const Duration(milliseconds: 400), () {
      _searchStreetPlaces(query);
    });
  }

  Future<void> _searchStreetPlaces(String query) async {
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

    if (apiKey.isEmpty) {
      setState(() {
        _streetPredictions = [];
        _streetSearching = false;
      });
      return;
    }

    if (!mounted) return;

    setState(() {
      _streetSearching = true;
    });

    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input': query,
          'key': apiKey,
          'components': 'country:in',
        },
      );

      final response = await http.get(uri);

      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() {
          _streetPredictions = [];
          _streetSearching = false;
        });
        return;
      }

      final data = jsonDecode(response.body);

      if (data['status'] == 'OK' && data['predictions'] is List) {
        final predictions = (data['predictions'] as List)
            .map((item) => Prediction.fromJson(item))
            .toList();

        // Ignore an old API response if the user has already typed something else.
        if (_streetController.text.trim() != query) return;

        setState(() {
          _streetPredictions = predictions;
          _streetSearching = false;
        });
      } else {
        setState(() {
          _streetPredictions = [];
          _streetSearching = false;
        });
      }
    } catch (e) {
      debugPrint('Street autocomplete error: $e');

      if (!mounted) return;

      setState(() {
        _streetPredictions = [];
        _streetSearching = false;
      });
    }
  }

  Future<void> _selectStreetPrediction(Prediction prediction) async {
    final description = prediction.description?.toString() ?? '';
    final placeId = prediction.placeId?.toString() ?? '';

    // Keep this a completely normal Flutter text-field edit.
    // Do not unfocus or manipulate the keyboard.
    _streetController.value = TextEditingValue(
      text: description,
      selection: TextSelection.collapsed(
        offset: description.length,
      ),
      composing: TextRange.empty,
    );

    setState(() {
      _streetPredictions = [];
      _streetSearching = false;
    });

    if (placeId.isEmpty) {
      return;
    }

    await _loadSelectedPlaceDetails(placeId);

    if (!mounted) return;

    // Keep the field behaving like a normal editable input.
    _streetFocusNode.requestFocus();
    _streetController.selection = TextSelection.collapsed(
      offset: _streetController.text.length,
    );
  }

  Future<void> _loadSelectedPlaceDetails(String placeId) async {
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

    if (apiKey.isEmpty) {
      debugPrint('Google Maps API key is missing.');
      return;
    }

    try {
      // Autocomplete predictions do not reliably contain geometry.
      // The website gets the selected place and then reads its geometry
      // and address components. Do the same here.
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/details/json',
        {
          'place_id': placeId,
          'fields': 'geometry,formatted_address,name,address_component',
          'key': apiKey,
        },
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        debugPrint(
          'Place details HTTP error: ${response.statusCode}',
        );
        return;
      }

      final data = jsonDecode(response.body);

      if (data['status'] != 'OK' || data['result'] == null) {
        debugPrint(
          'Place details failed: ${data['status']}',
        );
        return;
      }

      final result = data['result'] as Map<String, dynamic>;

      final geometry = result['geometry'];
      final location = geometry is Map
          ? geometry['location']
          : null;

      final lat = location is Map
          ? double.tryParse('${location['lat']}')
          : null;
      final lng = location is Map
          ? double.tryParse('${location['lng']}')
          : null;

      if (lat == null || lng == null) {
        debugPrint('Selected place has no valid geometry.');
        return;
      }

      final latLng = LatLng(lat, lng);

      String getComponent(String type) {
        final components = result['address_components'];
        if (components is! List) return '';

        for (final item in components) {
          if (item is! Map) continue;

          final types = item['types'];
          if (types is List && types.contains(type)) {
            return item['long_name']?.toString() ?? '';
          }
        }

        return '';
      }

      final city =
          getComponent('locality').isNotEmpty
              ? getComponent('locality')
              : getComponent('postal_town').isNotEmpty
                  ? getComponent('postal_town')
                  : getComponent('administrative_area_level_2');

      final state = getComponent('administrative_area_level_1');
      final postal = getComponent('postal_code');
      final country = getComponent('country');

      if (!mounted) return;

      setState(() {
        // This is the important part:
        // selecting "Bobiz Designer Studio..." moves the Flutter map
        // to that exact Google Place.
        _pinPosition = latLng;
        _mapError = null;

        if (city.isNotEmpty) {
          _cityController.value = TextEditingValue(
            text: city,
            selection: TextSelection.collapsed(offset: city.length),
          );
        }

        if (state.isNotEmpty) {
          _stateController.value = TextEditingValue(
            text: state,
            selection: TextSelection.collapsed(offset: state.length),
          );
        }

        if (postal.isNotEmpty) {
          _postalCodeController.value = TextEditingValue(
            text: postal,
            selection: TextSelection.collapsed(offset: postal.length),
          );
        }

        if (country.isNotEmpty) {
          _countryController.value = TextEditingValue(
            text: country,
            selection: TextSelection.collapsed(offset: country.length),
          );
        }
      });

      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 17),
      );
    } catch (e) {
      debugPrint('Selected place details error: $e');
    }
  }

  void _clearStreetSuggestions() {
    if (_streetPredictions.isEmpty) return;

    setState(() {
      _streetPredictions = [];
      _streetSearching = false;
    });
  }


  // ============================================================
  // WEBSITE-STYLE GOOGLE MAP CAMERA CONTROLS
  // ============================================================

  Future<void> _moveMapDirection(String direction) async {
    final controller = _mapController;
    if (controller == null) return;

    try {
      final bounds = await controller.getVisibleRegion();

      final latDelta =
          (bounds.northeast.latitude - bounds.southwest.latitude).abs();
      final lngDelta =
          (bounds.northeast.longitude - bounds.southwest.longitude).abs();

      final latStep = latDelta * 0.35;
      final lngStep = lngDelta * 0.35;

      final centerLat =
          (bounds.northeast.latitude + bounds.southwest.latitude) / 2;
      final centerLng =
          (bounds.northeast.longitude + bounds.southwest.longitude) / 2;

      double lat = centerLat;
      double lng = centerLng;

      switch (direction) {
        case 'up':
          lat += latStep;
          break;
        case 'down':
          lat -= latStep;
          break;
        case 'left':
          lng -= lngStep;
          break;
        case 'right':
          lng += lngStep;
          break;
      }

      await controller.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(lat, lng),
        ),
      );
    } catch (e) {
      debugPrint('Map camera control error: $e');
    }
  }

  Future<void> _websiteStyleZoomIn() async {
    if (_mapController == null) return;

    await _mapController!.animateCamera(
      CameraUpdate.zoomIn(),
    );
  }

  Future<void> _websiteStyleZoomOut() async {
    if (_mapController == null) return;

    await _mapController!.animateCamera(
      CameraUpdate.zoomOut(),
    );
  }

  Widget _websiteMapControl({
    Key? key,
    required Widget child,
    required VoidCallback onTap,
    double size = 40,
  }) {
    return Material(
      key: key,
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFE5E5E5),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }

  Widget _buildWebsiteMapControls() {
    const iconColor = Color(0xFF777777);

    return Positioned(
      top: 10,
      right: 10,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: !_showWebsiteMapControls
            ? _websiteMapControl(
                key: const ValueKey('map_expand'),
                size: 40,
                onTap: () {
                  setState(() {
                    _showWebsiteMapControls = true;
                  });
                },
                child: const Icon(
                  Icons.open_with,
                  size: 22,
                  color: iconColor,
                ),
              )
            : Column(
                key: const ValueKey('map_controls_open'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  // UP + ZOOM IN
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _websiteMapControl(
                        onTap: () => _moveMapDirection('up'),
                        child: const Icon(
                          Icons.keyboard_arrow_up,
                          size: 25,
                          color: iconColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _websiteMapControl(
                        onTap: _websiteStyleZoomIn,
                        child: const Icon(
                          Icons.add,
                          size: 25,
                          color: iconColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // LEFT + RIGHT
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _websiteMapControl(
                        onTap: () => _moveMapDirection('left'),
                        child: const Icon(
                          Icons.keyboard_arrow_left,
                          size: 25,
                          color: iconColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _websiteMapControl(
                        onTap: () => _moveMapDirection('right'),
                        child: const Icon(
                          Icons.keyboard_arrow_right,
                          size: 25,
                          color: iconColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // DOWN + ZOOM OUT
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _websiteMapControl(
                        onTap: () => _moveMapDirection('down'),
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          size: 25,
                          color: iconColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _websiteMapControl(
                        onTap: _websiteStyleZoomOut,
                        child: const Icon(
                          Icons.remove,
                          size: 25,
                          color: iconColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // COLLAPSE / EXPAND CONTROL
                  Align(
                    alignment: Alignment.centerRight,
                    child: _websiteMapControl(
                      onTap: () {
                        setState(() {
                          _showWebsiteMapControls = false;
                        });
                      },
                      child: const Icon(
                        Icons.open_with,
                        size: 22,
                        color: iconColor,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final subtotal = _getSubtotal();
    final tax = subtotal * 0.05;
    final total = subtotal + tax;
    final itemCount = _getItemCount();
    final cartItems = _cart['items'] as List? ?? [];
    final cartCount = Provider.of<CartProvider>(context).cartCount;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isBuyNowMode ? 'Buy Now' : 'Checkout'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF063B5C),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isBuyNowMode && _buyNowItem != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF07566B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF07566B).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flash_on,
                          color: Color(0xFF07566B), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '⚡ Buy Now Mode • ${_buyNowItem!['productName']}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF063B5C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              _buildOrderSummary(cartItems, subtotal, tax, total, itemCount),
              const SizedBox(height: 16),
              _buildShippingAddressSection(),
              const SizedBox(height: 16),
              _buildPaymentSection(),
              const SizedBox(height: 24),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _placeOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF063B5C),
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
                          'Place Order',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
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
          setState(() => _currentIndex = index);
        },
      ),
    );
  }

  // ============================================================
  // ORDER SUMMARY
  // ============================================================

  Widget _buildOrderSummary(
    List<dynamic> cartItems,
    double subtotal,
    double tax,
    double total,
    int itemCount,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF063B5C),
            ),
          ),
          const SizedBox(height: 12),

          if (_isBuyNowMode && _buyNowItem != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${_buyNowItem!['productName']} x ${_buyNowItem!['quantity']}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                Text(
                  '₹${(_buyNowItem!['price'] * _buyNowItem!['quantity']).toInt()}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            )
          else if (cartItems.isNotEmpty)
            Column(
              children: cartItems.map((item) {
                final productName = item['productName'] ??
                    (item['product'] is Map
                        ? item['product']['name']
                        : 'Product');
                final quantity = item['quantity'] ?? 1;
                final price = (item['price'] ?? 0).toDouble();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '$productName x $quantity',
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '₹${(price * quantity).toInt()}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              }).toList(),
            )
          else
            Text(
              '$itemCount item${itemCount != 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 14),
            ),

          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          _summaryRow('Subtotal', '₹${subtotal.toInt()}'),
          _summaryRow('Shipping', 'FREE', valueColor: const Color(0xFF063B5C)),
          _summaryRow('Tax (5%)', '₹${tax.toInt()}'),
          const Divider(),
          _summaryRow(
            'Total',
            '₹${total.toInt()}',
            bold: true,
            valueColor: const Color(0xFF063B5C),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: bold ? 16 : 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 16 : 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SHIPPING ADDRESS — MAP + AUTOCOMPLETE
  // ============================================================

  Widget _buildShippingAddressSection() {
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shipping Address',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF063B5C),
            ),
          ),
          const SizedBox(height: 16),

          // Name
          _buildTextField(_nameController, 'Full Name', Icons.person),
          const SizedBox(height: 12),

          // Phone
          _buildTextField(_phoneController, 'Phone Number', Icons.phone,
              keyboardType: TextInputType.phone),
          const SizedBox(height: 12),

          // Alternate phone
          _buildTextField(
            _alternatePhoneController,
            'Alternate Phone Number (optional)',
            Icons.phone_android,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),

          // Email
          _buildTextField(_emailController, 'Email Address', Icons.email,
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),

          // ✅ STREET — normal Flutter input + separate Google Places suggestions
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _streetController,
                focusNode: _streetFocusNode,
                keyboardType: TextInputType.streetAddress,
                textInputAction: TextInputAction.next,
                onChanged: _onStreetChanged,
                onTap: () {
                  if (_streetController.text.trim().isNotEmpty) {
                    _onStreetChanged(_streetController.text);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Door no, Area, Street',
                  prefixIcon: const Icon(
                    Icons.location_on,
                    color: Color(0xFF063B5C),
                  ),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide(color: Color(0xFF063B5C)),
                  ),
                ),
              ),

              if (_streetSearching)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),

              if (_streetPredictions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 8,
                        offset: Offset(0, 2),
                        color: Color(0x22000000),
                      ),
                    ],
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 260,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _streetPredictions.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: Colors.grey.shade200,
                      ),
                      itemBuilder: (context, index) {
                        final prediction = _streetPredictions[index];

                        return InkWell(
                          onTap: () => _selectStreetPrediction(prediction),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 1),
                                  child: Icon(
                                    Icons.location_on_outlined,
                                    size: 20,
                                    color: Color(0xFF063B5C),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    prediction.description ?? '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Start typing area or street — suggestions will appear',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),

          // ✅ MAP SECTION
          _buildMapSection(),

          const SizedBox(height: 16),

          // Landmark
          _buildTextField(
            _landmarkController,
            'Nearby Landmark (optional)',
            Icons.place,
          ),
          const SizedBox(height: 12),

          // City / State / PIN
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              if (isNarrow) {
                return Column(
                  children: [
                    _buildTextField(_cityController, 'City/Town', Icons.location_city),
                    const SizedBox(height: 12),
                    _buildTextField(_stateController, 'State', Icons.map),
                    const SizedBox(height: 12),
                    _buildTextField(_postalCodeController, 'Postal Code', Icons.code,
                        keyboardType: TextInputType.number),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                        _cityController, 'City/Town', Icons.location_city),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                        _stateController, 'State', Icons.map),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                        _postalCodeController, 'Postal Code', Icons.code,
                        keyboardType: TextInputType.number),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          // Country
          DropdownButtonFormField<String>(
            value: _countryController.text.trim().isEmpty
                ? 'India'
                : _countryController.text.trim(),
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Country',
              prefixIcon:
                  const Icon(Icons.public, color: Color(0xFF063B5C)),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: Color(0xFF063B5C)),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'India', child: Text('India')),
              DropdownMenuItem(
                  value: 'United States', child: Text('United States')),
              DropdownMenuItem(
                  value: 'United Kingdom', child: Text('United Kingdom')),
              DropdownMenuItem(value: 'Canada', child: Text('Canada')),
              DropdownMenuItem(value: 'Australia', child: Text('Australia')),
            ],
            onChanged: (value) {
              if (value != null) _countryController.text = value;
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MAP SECTION
  // ============================================================

  Widget _buildMapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '📍 Pin Your Exact Location *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF063B5C),
              ),
            ),
            if (_pinPosition != null)
              Text(
                '${_pinPosition!.latitude.toStringAsFixed(6)}, ${_pinPosition!.longitude.toStringAsFixed(6)}',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.green,
                  fontFamily: 'monospace',
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 260,
            child: Stack(
              children: [
                GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _pinPosition ?? _defaultCenter,
                zoom: 15,
              ),
              onTap: _onMapTap,
              markers: _pinPosition == null
                  ? {}
                  : {
                      Marker(
                        markerId: const MarkerId('delivery_pin'),
                        position: _pinPosition!,
                        draggable: true,
                        onDragEnd: (newPos) {
                          setState(() => _pinPosition = newPos);
                          _reverseGeocode(newPos);
                        },
                        infoWindow: const InfoWindow(title: 'Deliver here'),
                      ),
                    },
              zoomControlsEnabled: false,
              zoomGesturesEnabled: true,
              scrollGesturesEnabled: true,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              buildingsEnabled: false,
              indoorViewEnabled: false,
              trafficEnabled: false,
            ),
            _buildWebsiteMapControls(),
              ],
            ),
          ),
        ),

        if (_mapError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _mapError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),

        const SizedBox(height: 10),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _locating ? null : _useMyLocation,
            icon: _locating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF008FB8)),
                    ),
                  )
                : const Icon(Icons.my_location, color: Color(0xFF008FB8)),
            label: Text(
              _locating ? 'Locating...' : 'Use My Current Location',
              style: const TextStyle(color: Color(0xFF008FB8)),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: Color(0xFF008FB8)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),

        const SizedBox(height: 6),
        const Text(
          'Drag to move • Pinch to zoom • Tap to drop pin',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  // ============================================================
  // PAYMENT SECTION
  // ============================================================

  Widget _buildPaymentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Method',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF063B5C),
            ),
          ),
          const SizedBox(height: 12),
          RadioListTile<String>(
            title: const Text('Cash on Delivery'),
            value: 'cod',
            groupValue: _paymentMethod,
            onChanged: (value) => setState(() => _paymentMethod = value!),
            activeColor: const Color(0xFF063B5C),
          ),
          RadioListTile<String>(
            title: const Text('Razorpay (Card/UPI/NetBanking)'),
            value: 'razorpay',
            groupValue: _paymentMethod,
            onChanged: (value) => setState(() => _paymentMethod = value!),
            activeColor: const Color(0xFF063B5C),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TEXT FIELD BUILDER
  // ============================================================

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF063B5C)),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: Color(0xFF063B5C)),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          if (label.contains('optional')) return null;
          if (label == 'Email Address') return null;
          return 'Please enter $label';
        }
        if (label == 'Email Address' && !value.contains('@')) {
          return 'Enter valid email';
        }
        if (label == 'Phone Number' && value.length < 10) {
          return 'Enter valid phone number';
        }
        return null;
      },
    );
  }
}