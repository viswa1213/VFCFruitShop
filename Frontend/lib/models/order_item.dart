class OrderItem {
  final String? name;
  final num? price;
  final int? quantity;
  final num? measure; // e.g., 1, 500
  final String? unit; // e.g., kg, g, ml
  final num? lineTotal;
  final String? image;

  const OrderItem({
    this.name,
    this.price,
    this.quantity,
    this.measure,
    this.unit,
    this.lineTotal,
    this.image,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    name: json['name']?.toString(),
    price: json['price'] is num
        ? json['price'] as num
        : num.tryParse(json['price']?.toString() ?? ''),
    quantity: json['quantity'] is int
        ? json['quantity'] as int
        : int.tryParse(json['quantity']?.toString() ?? ''),
    measure: json['measure'] is num
        ? json['measure'] as num
        : num.tryParse(json['measure']?.toString() ?? ''),
    unit: json['unit']?.toString(),
    lineTotal: json['lineTotal'] is num
        ? json['lineTotal'] as num
        : num.tryParse(json['lineTotal']?.toString() ?? ''),
    image: json['image']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (price != null) 'price': price,
    if (quantity != null) 'quantity': quantity,
    if (measure != null) 'measure': measure,
    if (unit != null) 'unit': unit,
    if (lineTotal != null) 'lineTotal': lineTotal,
    if (image != null) 'image': image,
  };
}
