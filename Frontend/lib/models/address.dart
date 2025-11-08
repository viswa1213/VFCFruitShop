class Address {
  final String? name;
  final String? phone;
  final String? address;
  final String? landmark;
  final String? city;
  final String? state;
  final String? pincode;
  final String? type; // e.g. home, work

  const Address({
    this.name,
    this.phone,
    this.address,
    this.landmark,
    this.city,
    this.state,
    this.pincode,
    this.type,
  });

  bool get isValidBasic =>
      (name != null && name!.isNotEmpty) &&
      (phone != null && RegExp(r'^\d{10,15}$').hasMatch(phone!)) &&
      (pincode != null && RegExp(r'^\d{6}$').hasMatch(pincode!));

  factory Address.fromJson(Map<String, dynamic> json) => Address(
    name: json['name']?.toString(),
    phone: json['phone']?.toString(),
    address: json['address']?.toString(),
    landmark: json['landmark']?.toString(),
    city: json['city']?.toString(),
    state: json['state']?.toString(),
    pincode: json['pincode']?.toString(),
    type: json['type']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (phone != null) 'phone': phone,
    if (address != null) 'address': address,
    if (landmark != null) 'landmark': landmark,
    if (city != null) 'city': city,
    if (state != null) 'state': state,
    if (pincode != null) 'pincode': pincode,
    if (type != null) 'type': type,
  };

  Address copyWith({
    String? name,
    String? phone,
    String? address,
    String? landmark,
    String? city,
    String? state,
    String? pincode,
    String? type,
  }) => Address(
    name: name ?? this.name,
    phone: phone ?? this.phone,
    address: address ?? this.address,
    landmark: landmark ?? this.landmark,
    city: city ?? this.city,
    state: state ?? this.state,
    pincode: pincode ?? this.pincode,
    type: type ?? this.type,
  );
}
