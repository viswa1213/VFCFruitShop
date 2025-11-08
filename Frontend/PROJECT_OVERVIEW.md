# Frontend Overview (Flutter)

## Structure

```
lib/
  main.dart                   # App entry (themes, routes)
  pages/
    home.dart                 # Home + tabs (Orders, Favorites, Profile)
    cart.dart                 # Cart UI & debounced server sync
    checkout.dart             # Address + payment method selection
    payment.dart              # Razorpay checkout & confirmation
    orders.dart               # Orders listing (backend only)
    order_details.dart        # Order detail view
    login.dart, register.dart # Auth screens
    profile.dart, settings.dart
  services/
    auth_service.dart         # Base URL, token, auth headers
    user_data_api.dart        # Orders, cart, favorites, address, hydrate
    payment_api.dart          # Razorpay API calls
    razorpay_service.dart     # SDK wrapper
    favorites_storage.dart    # Local cache (favorites only)
    address_storage.dart      # Local cache of last used address
  widgets/
    app_snackbar.dart         # Snackbar helpers (success/info/error)
  assets/                     # Static JSON data & images
```

## Data Flow (server-first)
- Auth: Token stored in SharedPreferences. `authHeaders()` adds Bearer token.
- Cart: State kept in memory; synchronized to server (PUT /api/user/cart) with debounce.
- Favorites: Toggle updates server (PUT /api/user/favorites), with local fallback cache.
- Orders: Persisted only in backend. Listing pulls from `/api/orders`.
- Address: Saved optionally locally for convenience; also mirrored to backend (PUT /api/user/address).

## Orders Flow
1. Checkout builds order payload.
2. For Razorpay: create + verify payment, then POST order to `/api/orders`.
3. For COD/UPI/Card (non-Razorpay): directly POST order to `/api/orders`.
4. On success, clear server cart and navigate to Orders tab.

## Navigation
- After successful order creation (any method), the app navigates to `/home` with `initialTab: 1` to show Orders directly.

## Notes
- Large files (e.g., `home.dart`) include multiple UI sections for simplicity; consider extracting widgets incrementally as needed.
- Models are represented as `Map<String, dynamic>` for flexibility; you may introduce typed models later.

## Running
```bash
flutter pub get
flutter run
```

## Next Improvements
- Introduce typed models (Order, OrderItem, Address) with fromJson/toJson.
- Extract reusable UI components from `home.dart` into smaller widgets.
- Add pagination and pull-to-refresh enhancements for orders.
