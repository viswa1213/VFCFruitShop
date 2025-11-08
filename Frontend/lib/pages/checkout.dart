import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fruit_shop/pages/payment.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:fruit_shop/services/address_storage.dart';
import 'map_picker.dart';
import 'package:fruit_shop/widgets/app_snackbar.dart';

class CheckoutPage extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;

  const CheckoutPage({super.key, required this.cartItems});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController stateController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController cardNumberController = TextEditingController();
  final TextEditingController upiIdController = TextEditingController();
  final TextEditingController landmarkController = TextEditingController();

  String paymentMethod = "Cash on Delivery";
  final TextEditingController couponController = TextEditingController();
  String appliedCoupon = '';
  double discountAmount = 0.0;
  String deliverySlot = 'Today, 6-9 PM';
  bool showSummary = true;
  String addressType = 'Home';
  bool saveAddress = true;
  bool setDefaultAddress = true;

  double get subtotal => widget.cartItems.fold<double>(
    0,
    (sum, item) => sum + (item["price"] as num) * (item["quantity"] as num),
  );
  double get deliveryFee => subtotal >= 499 ? 0 : 29;
  double get total =>
      (subtotal - discountAmount + deliveryFee).clamp(0, double.infinity);

  void applyCoupon() {
    final code = couponController.text.trim().toUpperCase();
    double newDiscount = 0.0;
    if (code == 'VFC10') {
      newDiscount = subtotal * 0.10;
    } else if (code == 'FRESH50') {
      newDiscount = 50.0;
    } else if (code.isEmpty) {
      newDiscount = 0.0;
    } else {
      AppSnack.showError(context, 'Invalid coupon code');
      return;
    }
    setState(() {
      appliedCoupon = code;
      discountAmount = newDiscount;
    });
    if (appliedCoupon.isEmpty) {
      AppSnack.showInfo(context, 'Coupon cleared');
    } else {
      AppSnack.showSuccess(context, 'Applied $appliedCoupon');
    }
  }

  @override
  void initState() {
    super.initState();
    _prefillSavedAddress();
  }

  Future<void> _prefillSavedAddress() async {
    final data = await AddressStorage.load();
    if (data == null) return;
    if (!mounted) return;
    setState(() {
      nameController.text = data['name']?.toString() ?? '';
      phoneController.text = data['phone']?.toString() ?? '';
      addressController.text = data['address']?.toString() ?? '';
      landmarkController.text = data['landmark']?.toString() ?? '';
      cityController.text = data['city']?.toString() ?? '';
      stateController.text = data['state']?.toString() ?? '';
      pincodeController.text = data['pincode']?.toString() ?? '';
      addressType = data['type']?.toString() ?? 'Home';
    });
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return false;
      AppSnack.showError(context, 'Please enable location services');
      return false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return false;
        AppSnack.showError(context, 'Location permission denied');
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return false;
      AppSnack.showError(
        context,
        'Location permissions are permanently denied',
      );
      return false;
    }
    return true;
  }

  void placeOrder() {
    if (_formKey.currentState!.validate()) {
      AppSnack.showSuccess(context, '✅ Order Placed Successfully!');

      // Navigate to Payment Page with data
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentPage(
            totalAmount: total,
            paymentMethod: paymentMethod,
            upiId: upiIdController.text,
            cardNumber: cardNumberController.text,
          ),
        ),
      );

      if (saveAddress) {
        AddressStorage.save({
          'name': nameController.text,
          'phone': phoneController.text,
          'address': addressController.text,
          'landmark': landmarkController.text,
          'city': cityController.text,
          'state': stateController.text,
          'pincode': pincodeController.text,
          'type': addressType,
          'default': setDefaultAddress,
        });
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    if (!await _ensureLocationPermission()) return;
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      final placemarks = await geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final addressLine = [
          p.street,
          p.subLocality,
          p.locality,
        ].where((e) => (e ?? '').isNotEmpty).join(', ');
        if (!mounted) return;
        setState(() {
          addressController.text = addressLine;
          cityController.text = p.locality ?? '';
          stateController.text = p.administrativeArea ?? '';
          pincodeController.text = p.postalCode ?? '';
          landmarkController.text = p.subLocality ?? '';
        });
        if (!mounted) return;
        AppSnack.showSuccess(context, 'Address filled from current location');
      }
    } catch (e) {
      if (!mounted) return;
      AppSnack.showError(context, 'Failed to get location: $e');
    }
  }

  Future<void> _pickOnMap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerPage()),
    );
    if (result is Map<String, double>) {
      final lat = result['lat'];
      final lng = result['lng'];
      if (lat != null && lng != null) {
        try {
          final placemarks = await geocoding.placemarkFromCoordinates(lat, lng);
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final addressLine = [
              p.street,
              p.subLocality,
              p.locality,
            ].where((e) => (e ?? '').isNotEmpty).join(', ');
            if (!mounted) return;
            setState(() {
              addressController.text = addressLine;
              cityController.text = p.locality ?? '';
              stateController.text = p.administrativeArea ?? '';
              pincodeController.text = p.postalCode ?? '';
              landmarkController.text = p.subLocality ?? '';
            });
          }
        } catch (e) {
          if (!mounted) return;
          AppSnack.showError(context, 'Failed to reverse geocode: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fadeTween = Tween<double>(begin: 0, end: 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Checkout"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Builder(
          builder: (context) {
            final primary = Theme.of(context).colorScheme.primary;
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, Color.lerp(primary, Colors.white, 0.2)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress indicator
            _buildProgress(),
            const SizedBox(height: 16),
            // 🛒 Order Summary
            TweenAnimationBuilder<double>(
              tween: fadeTween,
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - t)),
                  child: _orderSummary(),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 📦 Delivery Info
            TweenAnimationBuilder<double>(
              tween: fadeTween,
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - t)),
                  child: _deliveryInfo(),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 💳 Payment Method
            TweenAnimationBuilder<double>(
              tween: fadeTween,
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - t)),
                  child: _paymentSection(),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // ✅ Place Order Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: placeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Place Order",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _totalsBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final stages = ['Cart', 'Address', 'Payment', 'Review'];
    final activeIndex =
        paymentMethod == 'Cash on Delivery' ||
            paymentMethod == 'UPI' ||
            paymentMethod == 'Card'
        ? 2
        : 1;
    return Row(
      children: List.generate(stages.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(
            child: Container(
              height: 2,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.4),
            ),
          );
        }
        final idx = i ~/ 2;
        final active = idx <= activeIndex;
        return CircleAvatar(
          radius: 12,
          backgroundColor: active
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.shade300,
          child: Text(
            '${idx + 1}',
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        );
      }),
    );
  }

  Widget _orderSummary() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Order Summary',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => showSummary = !showSummary),
                  icon: AnimatedRotation(
                    turns: showSummary ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more),
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: showSummary
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Column(
                children: [
                  ...widget.cartItems.map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.shopping_bag,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(item['name']),
                      subtitle: Text(
                        'Qty: ${item['quantity']} × ₹${item['price']}',
                      ),
                      trailing: Text(
                        '₹${(item['price'] as num) * (item['quantity'] as num)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const Divider(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Delivery slot'),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: const [
                            'Today, 6-9 PM',
                            'Tomorrow, 9-12 AM',
                            'Tomorrow, 3-6 PM',
                          ].length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            const slots = [
                              'Today, 6-9 PM',
                              'Tomorrow, 9-12 AM',
                              'Tomorrow, 3-6 PM',
                            ];
                            final slot = slots[index];
                            return ChoiceChip(
                              label: Text(
                                slot,
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: deliverySlot == slot,
                              onSelected: (_) =>
                                  setState(() => deliverySlot = slot),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: couponController,
                          decoration: const InputDecoration(
                            labelText: 'Coupon code',
                            prefixIcon: Icon(Icons.card_giftcard),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        onPressed: applyCoupon,
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deliveryInfo() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            children: [
              const Text(
                'Delivery Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // Address type (compact chips)
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final t in ['Home', 'Work', 'Other'])
                      ChoiceChip(
                        label: Text(t),
                        selected: addressType == t,
                        onSelected: (_) => setState(() => addressType = t),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Full name (single field)
              TextFormField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) =>
                    value!.trim().isEmpty ? 'Enter your name' : null,
              ),
              const SizedBox(height: 10),
              // Phone (single field)
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (value) =>
                    (value?.length ?? 0) == 10 ? null : '10-digit phone',
              ),
              const SizedBox(height: 10),
              // Address line
              TextFormField(
                controller: addressController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Address line',
                  prefixIcon: Icon(Icons.home),
                ),
                validator: (value) =>
                    value!.trim().isEmpty ? 'Enter your address' : null,
              ),
              // Quick actions under address line (lighter)
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: _useCurrentLocation,
                      icon: const Icon(Icons.my_location_outlined, size: 18),
                      label: const Text('Use current location'),
                    ),
                    TextButton.icon(
                      onPressed: _pickOnMap,
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Pick on map'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Landmark
              TextFormField(
                controller: landmarkController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Landmark (optional)',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 10),
              // City & State in one row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: cityController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        prefixIcon: Icon(Icons.location_city),
                      ),
                      validator: (value) =>
                          value!.trim().isEmpty ? 'Enter city' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: stateController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'State',
                        prefixIcon: Icon(Icons.map),
                      ),
                      validator: (value) =>
                          value!.trim().isEmpty ? 'Enter state' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Pincode (single field)
              TextFormField(
                controller: pincodeController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: 'Pincode',
                  prefixIcon: Icon(Icons.local_post_office),
                ),
                validator: (value) =>
                    (value?.length ?? 0) == 6 ? null : '6-digit pincode',
              ),
              const SizedBox(height: 10),
              // Delivery instructions
              TextFormField(
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Delivery instructions (optional)',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
              ),
              const SizedBox(height: 10),
              // Save/default checkboxes
              CheckboxListTile(
                value: saveAddress,
                onChanged: (v) => setState(() => saveAddress = (v ?? true)),
                title: const Text('Save this address'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                value: setDefaultAddress,
                onChanged: (v) =>
                    setState(() => setDefaultAddress = (v ?? true)),
                title: const Text('Make this my default address'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentSection() {
    Widget methodTile(String label, String key) {
      final selected = paymentMethod == key;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
          ),
        ),
        child: ListTile(
          leading: Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(label),
          onTap: () => setState(() => paymentMethod = key),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Method',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            methodTile('Cash on Delivery', 'Cash on Delivery'),
            methodTile('UPI', 'UPI'),
            if (paymentMethod == 'UPI')
              TextFormField(
                controller: upiIdController,
                decoration: const InputDecoration(
                  labelText: 'UPI ID',
                  prefixIcon: Icon(Icons.payment),
                ),
                validator: (value) => paymentMethod == 'UPI' && value!.isEmpty
                    ? 'Enter UPI ID'
                    : null,
              ),
            methodTile('Credit/Debit Card', 'Card'),
            if (paymentMethod == 'Card')
              TextFormField(
                controller: cardNumberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Card Number',
                  prefixIcon: Icon(Icons.credit_card),
                ),
                validator: (value) =>
                    paymentMethod == 'Card' && value!.length < 16
                    ? 'Enter valid card number'
                    : null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _totalsBar() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row('Subtotal', '₹${subtotal.toStringAsFixed(2)}'),
            if (discountAmount > 0)
              _row(
                'Discount${appliedCoupon.isNotEmpty ? ' ($appliedCoupon)' : ''}',
                '-₹${discountAmount.toStringAsFixed(2)}',
                valueColor: Colors.green,
              ),
            _row(
              'Delivery',
              deliveryFee == 0 ? 'FREE' : '₹${deliveryFee.toStringAsFixed(2)}',
              valueColor: deliveryFee == 0
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            const Divider(height: 18),
            _row('Total', '₹${total.toStringAsFixed(2)}', isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 18 : 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
