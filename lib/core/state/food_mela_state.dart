import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:food_track/core/data/food_mela_data.dart';
import 'package:food_track/core/services/firebase_service.dart';

/// ─── FOOD MELA STATE ──────────────────────────────────────────────────────────
/// Manages customer-side app state: cart, address, orders, profile, search.
///
/// 🔒 ORDER HISTORY IS IMMUTABLE:
///   - Past orders can NEVER be deleted by ANYONE — not customer, not driver, not admin.
///   - Cancelled orders are PRESERVED in pastOrders (marked as Cancelled ❌, not removed).
///   - Firestore orders have isDeleted: false — no delete API is exposed.
class FoodMelaState extends ChangeNotifier {
  // Singleton instance
  static final FoodMelaState _instance = FoodMelaState._internal();
  factory FoodMelaState() => _instance;

  FoodMelaState._internal() {
    _loadFromPrefs();
  }

  // ── Cart ──────────────────────────────────────────────────────────────────────
  final Map<String, int> _cart = {};         // key: 'itemId::unit', value: qty
  final Map<String, String> _selectedUnits = {}; // itemId → chosen unit

  // ── Orders ────────────────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _liveOrders = [];
  final List<Map<String, dynamic>> _pastOrders = [];   // NEVER deleted

  // ── Address ───────────────────────────────────────────────────────────────────
  String _selectedAddress = '📍 Saheed Nagar, Bhubaneswar, Odisha 751007';
  bool _isDetectingLocation = false;
  final List<Map<String, String>> _savedAddresses = [];

  // ── User Profile ──────────────────────────────────────────────────────────────
  String _userName = '';
  String _userEmail = '';
  String _userPhone = '';

  // ── Search & Filter ───────────────────────────────────────────────────────────
  String _searchQuery = '';
  String _selectedCategoryKey = 'all';
  bool _isVegOnly = false;

  // ── Pricing ───────────────────────────────────────────────────────────────────
  static const double _deliveryFeeThreshold = 299;
  static const double _deliveryFee = 39;

  // ──────────────────────────────────────────────────────────────────────────────
  // GETTERS
  // ──────────────────────────────────────────────────────────────────────────────
  Map<String, int> get cart => Map.unmodifiable(_cart);
  List<Map<String, dynamic>> get liveOrders => List.unmodifiable(_liveOrders);

  /// 🔒 Past orders are PERMANENTLY READ-ONLY.
  /// No method exists to delete, clear, or modify past order history.
  /// This applies to: customer, driver, and admin alike.
  List<Map<String, dynamic>> get pastOrders => List.unmodifiable(
    _pastOrders.map((o) => Map<String, dynamic>.unmodifiable(o)).toList(),
  );

  String get selectedAddress => _selectedAddress;
  bool get isDetectingLocation => _isDetectingLocation;
  List<Map<String, String>> get savedAddresses => List.unmodifiable(_savedAddresses);

  String get userName => _userName;
  String get userEmail => _userEmail;
  String get userPhone => _userPhone;

  String get searchQuery => _searchQuery;
  String get selectedCategoryKey => _selectedCategoryKey;
  bool get isVegOnly => _isVegOnly;

  int get totalCartCount => _cart.values.fold(0, (a, b) => a + b);

  /// Helper to calculate exact unit price based on selected unit (500g = 0.5x, 2kg = 2x, etc.)
  static double getItemUnitPrice(FoodItem item, String unit) {
    if (!item.isRawItem) return item.price;
    final u = unit.toLowerCase().trim();
    double multiplier = 1.0;

    if (u.contains('500g') || u.contains('500ml') || u.contains('half kg')) {
      multiplier = 0.5;
    } else if (u.contains('250g') || u.contains('250ml')) {
      multiplier = 0.25;
    } else if (u.contains('2 kg') || u.contains('2 litre') || u.contains('2 dozen') || u.contains('2 plates') || u.contains('2 portion')) {
      multiplier = 2.0;
    } else if (u.contains('3 kg') || u.contains('3 litre') || u.contains('3 plates')) {
      multiplier = 3.0;
    } else if (u.contains('5 kg') || u.contains('5 litre')) {
      multiplier = 5.0;
    } else if (u.contains('10 kg')) {
      multiplier = 10.0;
    } else if (u.contains('6 eggs')) {
      multiplier = 0.5;
    } else if (u.contains('30 eggs')) {
      multiplier = 2.5;
    }

    return item.price * multiplier;
  }

  double get cartSubtotal {
    double total = 0;
    _cart.forEach((key, qty) {
      final parts = key.split('::');
      final itemId = parts[0];
      final unit = parts.length > 1 ? parts[1] : '';
      try {
        final item = FoodMelaData.allFoodItems.firstWhere(
          (i) => i.id == itemId,
          orElse: () => FoodItem(
            id: itemId,
            name: itemId,
            category: 'vegetables',
            price: 0,
            rating: 4.5,
            image: '',
            isVeg: true,
          ),
        );
        if (item.id.isNotEmpty) {
          total += getItemUnitPrice(item, unit) * qty;
        }
      } catch (_) {}
    });
    return total;
  }

  double get deliveryFee => cartSubtotal >= _deliveryFeeThreshold ? 0 : _deliveryFee;
  double get grandTotal => cartSubtotal + deliveryFee;

  // ──────────────────────────────────────────────────────────────────────────────
  // CART METHODS
  // ──────────────────────────────────────────────────────────────────────────────
  void addItemToCart(String itemId, String unit) {
    final key = '$itemId::$unit';
    _cart[key] = (_cart[key] ?? 0) + 1;
    notifyListeners();
  }

  void removeItemFromCart(String itemId, String unit) {
    final key = '$itemId::$unit';
    if (_cart.containsKey(key)) {
      if (_cart[key]! <= 1) {
        _cart.remove(key);
      } else {
        _cart[key] = _cart[key]! - 1;
      }
    }
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  int getItemQuantity(String itemId, String unit) {
    return _cart['$itemId::$unit'] ?? 0;
  }

  // Unit selection (for raw items with multiple unit options)
  String getSelectedUnit(dynamic item) {
    final id = item.id as String;
    if (_selectedUnits.containsKey(id)) return _selectedUnits[id]!;
    // Default to first unitOption if available
    try {
      final opts = item.unitOptions as List;
      return opts.isNotEmpty ? opts.first as String : '1 portion';
    } catch (_) {
      return '1 portion';
    }
  }

  void setSelectedUnit(String itemId, String unit) {
    _selectedUnits[itemId] = unit;
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────────────────────────────
  // ORDER METHODS
  // ──────────────────────────────────────────────────────────────────────────────
  /// Places a new order. Orders are added to _liveOrders.
  /// Drivers CANNOT delete orders from history.
  /// Places a new order. Orders are added to _liveOrders.
  /// Unique Order ID format: FM-XXXXXX
  void placeNewOrder({
    required String address,
    required String itemsSummary,
    required double totalAmount,
    String customerName = 'Customer',
    String phone = '',
    List<Map<String, dynamic>>? rawItemsList,
  }) {
    final now = DateTime.now();
    final uniqueId = 'FM-${now.millisecondsSinceEpoch.toString().substring(6)}${(100 + now.microsecond % 900)}';
    final newOrder = {
      'id': uniqueId,
      'orderId': uniqueId,
      'customerName': customerName.isNotEmpty ? customerName : (_userName.isNotEmpty ? _userName : 'Customer'),
      'customerPhone': phone.isNotEmpty ? phone : _userPhone,
      'address': address,
      'items': itemsSummary,
      'rawItems': rawItemsList ?? [],
      'total': '₹${totalAmount.toInt()}',
      'totalAmount': totalAmount,
      'status': 'Order Placed',
      'stage': 0,
      'statusColor': Colors.blue,
      'placedAt': now.toIso8601String(),
    };
    _liveOrders.insert(0, newOrder);
    _saveOrdersToFile();
    notifyListeners();
  }

  /// Reorders items from a past order back into the cart.
  void reorderPastOrder(Map<String, dynamic> pastOrder) {
    final itemsSummary = pastOrder['items'] as String? ?? '';
    final rawItems = pastOrder['rawItems'] ?? pastOrder['itemsList'];

    if (rawItems is List && rawItems.isNotEmpty) {
      for (var item in rawItems) {
        if (item is Map) {
          final itemId = item['itemId'] as String? ?? '';
          final unit = item['unit'] as String? ?? '1 unit';
          final qty = (item['quantity'] as num?)?.toInt() ?? 1;
          if (itemId.isNotEmpty) {
            for (int i = 0; i < qty; i++) {
              addItemToCart(itemId, unit);
            }
          }
        }
      }
    } else if (itemsSummary.isNotEmpty) {
      // Parse readable summary string: e.g. "2x Fresh Tomato (1 kg), 1x Potato (1 kg)"
      final parts = itemsSummary.split(',');
      for (final part in parts) {
        final trimmed = part.trim();
        final match = RegExp(r'^(\d+)x\s+(.+)$').firstMatch(trimmed);
        if (match != null) {
          final qty = int.tryParse(match.group(1)!) ?? 1;
          final nameAndUnit = match.group(2)!;

          // Find food item by name
          final foundItem = FoodMelaData.allFoodItems.firstWhere(
            (i) => nameAndUnit.toLowerCase().contains(i.name.toLowerCase()),
            orElse: () => FoodMelaData.allFoodItems.first,
          );

          String unit = foundItem.unitOptions.isNotEmpty ? foundItem.unitOptions.first : '1 unit';
          final unitMatch = RegExp(r'\(([^)]+)\)').firstMatch(nameAndUnit);
          if (unitMatch != null) unit = unitMatch.group(1)!;

          for (int i = 0; i < qty; i++) {
            addItemToCart(foundItem.id, unit);
          }
        }
      }
    }
    notifyListeners();
  }

  /// Updates order tracking stage. Called from OrderTrackingScreen.
  /// Drivers CAN update stage (accepted, picked up, delivered) but CANNOT delete.
  void updateOrderStatusStage(String orderId, int newStage) {
    for (var order in _liveOrders) {
      if (order['id'] == orderId || order['orderId'] == orderId) {
        order['stage'] = newStage;
        if (newStage == 1) order['status'] = 'Order Accepted ✅';
        if (newStage == 2) order['status'] = 'Out for Delivery 🛵';
        if (newStage == 3) {
          order['status'] = 'Delivered 🏁';
          // Move to past orders — history is PRESERVED forever
          final completed = Map<String, dynamic>.from(order);
          completed['deliveredAt'] = DateTime.now().toIso8601String();
          _pastOrders.insert(0, completed);
          _liveOrders.remove(order);
        }
        break;
      }
    }
    notifyListeners();
  }

  /// Cancels an order within the 2-minute window.
  /// Order is MARKED as cancelled in history, NOT deleted.
  void cancelOrder(String orderId) {
    for (var order in _liveOrders) {
      if (order['id'] == orderId || order['orderId'] == orderId) {
        final cancelled = Map<String, dynamic>.from(order);
        cancelled['status'] = 'Cancelled ❌';
        cancelled['stage'] = -1;
        cancelled['cancelledAt'] = DateTime.now().toIso8601String();
        _pastOrders.insert(0, cancelled); // PRESERVE in history
        _liveOrders.remove(order);
        break;
      }
    }
    _saveOrdersToFile();
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────────────────────────────
  // ADDRESS METHODS
  // ──────────────────────────────────────────────────────────────────────────────
  void setAddress(String address) {
    _selectedAddress = address;
    notifyListeners();
  }

  void setSelectedAddress(String address) {
    _selectedAddress = address;
    notifyListeners();
  }

  /// GPS location detection using Geolocator with fallback
  Future<void> autoDetectGpsLocation() async {
    _isDetectingLocation = true;
    notifyListeners();

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _selectedAddress = '📍 Saheed Nagar, Bhubaneswar, Odisha 751007';
        _isDetectingLocation = false;
        notifyListeners();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        );
        _selectedAddress = '📍 Current Location (${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)})';
      } else {
        _selectedAddress = '📍 Saheed Nagar, Bhubaneswar, Odisha 751007';
      }
    } catch (_) {
      _selectedAddress = '📍 Saheed Nagar, Bhubaneswar, Odisha 751007';
    } finally {
      _isDetectingLocation = false;
      notifyListeners();
    }
  }

  Future<void> simulateGpsLocationDetection() async {
    await autoDetectGpsLocation();
  }

  Future<void> addNewSavedAddress(String title, String address) async {
    _savedAddresses.removeWhere((a) => a['title'] == title);
    _savedAddresses.add({'title': title, 'address': address});
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('savedAddresses', jsonEncode(_savedAddresses));
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────────────────────────────
  // SEARCH & FILTER
  // ──────────────────────────────────────────────────────────────────────────────
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void selectCategory(String key) {
    _selectedCategoryKey = key;
    notifyListeners();
  }

  void toggleVegOnly() {
    _isVegOnly = !_isVegOnly;
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────────────────────────────
  // USER PROFILE
  // ──────────────────────────────────────────────────────────────────────────────
  /// Called after OTP login — loads user data by phone number from SharedPreferences.
  Future<void> initUserSession(String phone) async {
    _userPhone = phone;
    FirebaseService.listenToCustomerOrderStatus(phone);
    try {
      final prefs = await SharedPreferences.getInstance();
      _userName = prefs.getString('userName') ?? '';
      _userEmail = prefs.getString('userEmail') ?? '';
      await prefs.setString('userPhone', phone);

      final addressesJson = prefs.getString('savedAddresses');
      if (addressesJson != null) {
        final List<dynamic> decoded = jsonDecode(addressesJson);
        _savedAddresses.clear();
        _savedAddresses.addAll(decoded.cast<Map<String, dynamic>>().map(
          (m) => m.map((k, v) => MapEntry(k, v.toString()))));
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> updateUserProfile({required String name, required String email}) async {
    _userName = name;
    _userEmail = email;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', name);
    await prefs.setString('userEmail', email);
    notifyListeners();
  }

  void setUserPhone(String phone) {
    _userPhone = phone;
    FirebaseService.listenToCustomerOrderStatus(phone);
    SharedPreferences.getInstance().then((p) => p.setString('userPhone', phone));
    notifyListeners();
  }

  Future<void> logout() async {
    _userName = '';
    _userEmail = '';
    _userPhone = '';
    _cart.clear();
    _liveOrders.clear();
    // 🔒 _pastOrders is intentionally NOT cleared on logout.
    //    Order history must be preserved even after user logs out.
    //    pastOrders remain in memory until app is fully restarted.
    final prefs = await SharedPreferences.getInstance();
    // Only clear profile/session data, NOT order history keys
    await prefs.remove('userName');
    await prefs.remove('userEmail');
    await prefs.remove('userPhone');
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────────────────────────────
  // PERSISTENCE
  // ──────────────────────────────────────────────────────────────────────────────
  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userName = prefs.getString('userName') ?? '';
      _userEmail = prefs.getString('userEmail') ?? '';
      _userPhone = prefs.getString('userPhone') ?? '';

      if (_userPhone.isNotEmpty) {
        FirebaseService.listenToCustomerOrderStatus(_userPhone);
      }

      final addressesJson = prefs.getString('savedAddresses');
      if (addressesJson != null) {
        final List<dynamic> decoded = jsonDecode(addressesJson);
        _savedAddresses.addAll(decoded.cast<Map<String, dynamic>>().map((m) =>
          m.map((k, v) => MapEntry(k, v.toString()))));
      }
    } catch (_) {}
    notifyListeners();
  }

  void _saveOrdersToFile() {
    try {
      final paths = [
        '/sdcard/Download/food_mela_pending_orders.json',
        '/storage/emulated/0/Download/food_mela_pending_orders.json',
        '${Directory.systemTemp.path}/food_mela_pending_orders.json',
      ];
      final allOrders = [..._liveOrders, ..._pastOrders];
      final jsonStr = jsonEncode(allOrders.map((o) => {
        ...o,
        'statusColor': null, // Color is not serializable
      }).toList());
      for (final path in paths) {
        try { File(path).writeAsStringSync(jsonStr); } catch (_) {}
      }
    } catch (_) {}
  }

}
