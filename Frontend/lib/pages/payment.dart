import 'package:flutter/material.dart';

class PaymentPage extends StatefulWidget {
  final double totalAmount;
  final String paymentMethod;
  final String? upiId;
  final String? cardNumber;

  const PaymentPage({
    super.key,
    required this.totalAmount,
    required this.paymentMethod,
    this.upiId,
    this.cardNumber,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String referenceNumber = "TXN${DateTime.now().millisecondsSinceEpoch}";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Payment"),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Total amount
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: const Text(
                  "Total Amount",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: Text(
                  "₹${widget.totalAmount.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Payment details
            if (widget.paymentMethod == "UPI") ...[
              const Text(
                "Scan to Pay",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Image.asset("assets/images/QR.jpeg", height: 200, width: 200),
              const SizedBox(height: 10),
              Text("UPI ID: ${widget.upiId ?? 'Not provided'}"),
              Text(
                "Ref No: $referenceNumber",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ] else if (widget.paymentMethod == "Card") ...[
              const Text(
                "Pay with Card",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                "Card: **** **** **** ${widget.cardNumber?.substring(widget.cardNumber!.length - 4) ?? 'XXXX'}",
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                "Ref No: $referenceNumber",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ] else ...[
              const Text(
                "Cash on Delivery",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text("Pay the amount in cash when your order arrives."),
              Text(
                "Ref No: $referenceNumber",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],

            const Spacer(),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (widget.paymentMethod == "Cash on Delivery") {
                    _showSuccessCod(context);
                  } else {
                    _showSuccess(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Confirm Payment",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccess(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("🎉 Payment Successful"),
        content: Text(
          "You paid ₹${widget.totalAmount.toStringAsFixed(2)} "
          "via ${widget.paymentMethod}.\nRef No: $referenceNumber",
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showSuccessCod(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("🎉 Order Placed Successfully"),
        content: Text(
          "You paid ₹${widget.totalAmount.toStringAsFixed(2)} "
          "via ${widget.paymentMethod}.\nRef No: $referenceNumber",
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}
