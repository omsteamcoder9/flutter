import 'package:flutter/material.dart';

class Order {
  final String id;
  final String orderId;
  final int sNo;
  final List<OrderProduct> products;
  final ShippingAddress shippingAddress;
  final int? wardId;
  final String? wardName;
  final String paymentMethod;
  final String paymentStatus;
  final String orderStatus;
  final double totalAmount;
  final double shippingFee;
  final double taxAmount;
  final double discountAmount;
  final double finalAmount;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;

  Order({
    required this.id,
    required this.orderId,
    required this.sNo,
    required this.products,
    required this.shippingAddress,
    this.wardId,
    this.wardName,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.orderStatus,
    required this.totalAmount,
    required this.shippingFee,
    required this.taxAmount,
    required this.discountAmount,
    required this.finalAmount,
    required this.createdAt,
    this.deliveredAt,
    this.cancelledAt,
    this.cancellationReason,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    List<OrderProduct> products = [];
    if (json['products'] != null) {
      products = (json['products'] as List)
          .map((p) => OrderProduct.fromJson(p))
          .toList();
    }

    return Order(
      id: json['_id'] ?? '',
      orderId: json['orderId'] ?? '',
      sNo: json['sNo'] ?? 0,
      products: products,
      shippingAddress: ShippingAddress.fromJson(json['shippingAddress'] ?? {}),
      wardId: json['wardId'],
      wardName: json['wardName'],
      paymentMethod: json['paymentMethod'] ?? '',
      paymentStatus: json['paymentStatus'] ?? '',
      orderStatus: json['orderStatus'] ?? '',
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      shippingFee: (json['shippingFee'] ?? 0).toDouble(),
      taxAmount: (json['taxAmount'] ?? 0).toDouble(),
      discountAmount: (json['discountAmount'] ?? 0).toDouble(),
      finalAmount: (json['finalAmount'] ?? 0).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      deliveredAt: json['deliveredAt'] != null ? DateTime.parse(json['deliveredAt']) : null,
      cancelledAt: json['cancelledAt'] != null ? DateTime.parse(json['cancelledAt']) : null,
      cancellationReason: json['cancellationReason'],
    );
  }

  String getStatusText() {
    switch (orderStatus) {
      case 'pending': return 'Pending';
      case 'confirmed': return 'Confirmed';
      case 'processing': return 'Processing';
      case 'shipped': return 'Shipped';
      case 'delivered': return 'Delivered';
      case 'cancelled': return 'Cancelled';
      default: return orderStatus;
    }
  }

  Color getStatusColor() {
    switch (orderStatus) {
      case 'pending': return Colors.orange;
      case 'confirmed': return Colors.blue;
      case 'processing': return Colors.purple;
      case 'shipped': return Colors.cyan;
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }
}

class OrderProduct {
  final String productId;
  final String? variantId;
  final String variantName;
  final int quantity;
  final double price;
  final double originalPrice;
  final int discountPercentage;
  final String name;
  final String? image;
  final double weight;
  final String weightUnit;

  OrderProduct({
    required this.productId,
    this.variantId,
    required this.variantName,
    required this.quantity,
    required this.price,
    required this.originalPrice,
    required this.discountPercentage,
    required this.name,
    this.image,
    required this.weight,
    required this.weightUnit,
  });

  factory OrderProduct.fromJson(Map<String, dynamic> json) {
    return OrderProduct(
      productId: json['product'] ?? '',
      variantId: json['variantId'],
      variantName: json['variantName'] ?? '',
      quantity: json['quantity'] ?? 0,
      price: (json['price'] ?? 0).toDouble(),
      originalPrice: (json['originalPrice'] ?? json['price'] ?? 0).toDouble(),
      discountPercentage: json['discountPercentage'] ?? 0,
      name: json['name'] ?? '',
      image: json['image'],
      weight: (json['weight'] ?? 0).toDouble(),
      weightUnit: json['weightUnit'] ?? 'gram',
    );
  }

  double get totalPrice => price * quantity;
  
  String getWeightDisplay() {
    if (weight <= 0) return '-';
    return weightUnit == 'gram' ? '${weight}g' : '${weight}kg';
  }
}

class ShippingAddress {
  final String street;
  final String city;
  final String state;
  final String postalCode;
  final String country;
  final String phone;
  final String email;

  ShippingAddress({
    required this.street,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
    required this.phone,
    required this.email,
  });

  factory ShippingAddress.fromJson(Map<String, dynamic> json) {
    return ShippingAddress(
      street: json['street'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      postalCode: json['postalCode'] ?? '',
      country: json['country'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
    );
  }

  String getFullAddress() {
    return '$street, $city, $state - $postalCode, $country';
  }
}