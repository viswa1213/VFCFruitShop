class PaymentInfo {
  final String? method; // COD, Razorpay, Card, UPI
  final String? status; // success, pending, failed
  final String? upiId;
  final String? cardLast4;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final String? razorpaySignature;

  const PaymentInfo({
    this.method,
    this.status,
    this.upiId,
    this.cardLast4,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.razorpaySignature,
  });

  factory PaymentInfo.fromJson(Map<String, dynamic> json) => PaymentInfo(
    method: json['method']?.toString(),
    status: json['status']?.toString(),
    upiId: json['upiId']?.toString(),
    cardLast4: json['cardLast4']?.toString(),
    razorpayOrderId: json['razorpayOrderId']?.toString(),
    razorpayPaymentId: json['razorpayPaymentId']?.toString(),
    razorpaySignature: json['razorpaySignature']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    if (method != null) 'method': method,
    if (status != null) 'status': status,
    if (upiId != null) 'upiId': upiId,
    if (cardLast4 != null) 'cardLast4': cardLast4,
    if (razorpayOrderId != null) 'razorpayOrderId': razorpayOrderId,
    if (razorpayPaymentId != null) 'razorpayPaymentId': razorpayPaymentId,
    if (razorpaySignature != null) 'razorpaySignature': razorpaySignature,
  };
}
