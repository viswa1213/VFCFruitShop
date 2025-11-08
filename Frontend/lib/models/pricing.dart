class Pricing {
  final num? subtotal;
  final num? discount;
  final num? deliveryFee;
  final num? total;

  const Pricing({this.subtotal, this.discount, this.deliveryFee, this.total});

  factory Pricing.fromJson(Map<String, dynamic> json) => Pricing(
    subtotal: json['subtotal'] is num
        ? json['subtotal'] as num
        : num.tryParse(json['subtotal']?.toString() ?? ''),
    discount: json['discount'] is num
        ? json['discount'] as num
        : num.tryParse(json['discount']?.toString() ?? ''),
    deliveryFee: json['deliveryFee'] is num
        ? json['deliveryFee'] as num
        : num.tryParse(json['deliveryFee']?.toString() ?? ''),
    total: json['total'] is num
        ? json['total'] as num
        : num.tryParse(json['total']?.toString() ?? ''),
  );

  Map<String, dynamic> toJson() => {
    if (subtotal != null) 'subtotal': subtotal,
    if (discount != null) 'discount': discount,
    if (deliveryFee != null) 'deliveryFee': deliveryFee,
    if (total != null) 'total': total,
  };
}
