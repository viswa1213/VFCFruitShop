import 'address.dart';
import 'order_item.dart';
import 'pricing.dart';
import 'payment_info.dart';

class OrderModel {
  final String? id;
  final List<OrderItem> items;
  final Pricing? pricing;
  final PaymentInfo? payment;
  final Address? address;
  final String? deliverySlot;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? status; // optional computed/tracking status

  const OrderModel({
    this.id,
    this.items = const [],
    this.pricing,
    this.payment,
    this.address,
    this.deliverySlot,
    this.createdAt,
    this.updatedAt,
    this.status,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final itemsRaw = (json['items'] as List?) ?? const [];
    return OrderModel(
      id: json['id']?.toString() ?? json['_id']?.toString(),
      items: itemsRaw
          .whereType<Map>()
          .map((e) => OrderItem.fromJson(e.cast<String, dynamic>()))
          .toList(),
      pricing: json['pricing'] is Map
          ? Pricing.fromJson((json['pricing'] as Map).cast<String, dynamic>())
          : null,
      payment: json['payment'] is Map
          ? PaymentInfo.fromJson(
              (json['payment'] as Map).cast<String, dynamic>(),
            )
          : null,
      address: json['address'] is Map
          ? Address.fromJson((json['address'] as Map).cast<String, dynamic>())
          : null,
      deliverySlot: json['deliverySlot']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      status: json['status']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'items': items.map((e) => e.toJson()).toList(),
    if (pricing != null) 'pricing': pricing!.toJson(),
    if (payment != null) 'payment': payment!.toJson(),
    if (address != null) 'address': address!.toJson(),
    if (deliverySlot != null) 'deliverySlot': deliverySlot,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    if (status != null) 'status': status,
  };
}
