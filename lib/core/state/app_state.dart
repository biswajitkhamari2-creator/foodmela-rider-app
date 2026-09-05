import 'package:flutter/material.dart';
import 'package:food_track/core/data/food_track_data.dart';

enum AppModeType { customer, restaurant, delivery, admin }

class AppState extends ChangeNotifier {
  AppModeType _appMode = AppModeType.customer;
  final List<CartItemModel> _cart = [];
  RestaurantModel? _selectedRestaurant;
  MenuItemModel? _selectedFood;
  CouponModel? _appliedCoupon;
  AddressModel? _selectedAddress = FoodTrackData.addresses.first;
  String _selectedPayment = 'upi';

  AppModeType get appMode => _appMode;
  List<CartItemModel> get cart => List.unmodifiable(_cart);
  RestaurantModel? get selectedRestaurant => _selectedRestaurant;
  MenuItemModel? get selectedFood => _selectedFood;
  CouponModel? get appliedCoupon => _appliedCoupon;
  AddressModel? get selectedAddress => _selectedAddress;
  String get selectedPayment => _selectedPayment;

  int get cartCount => _cart.fold(0, (sum, item) => sum + item.quantity);
  double get cartSubtotal => _cart.fold(0, (sum, item) => sum + (item.item.price * item.quantity));

  double get cartDiscount {
    if (_appliedCoupon == null) return 0;
    if (_appliedCoupon!.type == 'percent') {
      return (cartSubtotal * (_appliedCoupon!.value / 100)).clamp(0, 150);
    } else {
      return _appliedCoupon!.value;
    }
  }

  double get deliveryFee => cartSubtotal > 299 ? 0 : 35;
  double get taxes => (cartSubtotal * 0.05); // 5% GST
  double get cartTotal => (cartSubtotal - cartDiscount + deliveryFee + taxes).clamp(0, 99999);

  void setAppMode(AppModeType mode) {
    _appMode = mode;
    notifyListeners();
  }

  void selectRestaurant(RestaurantModel restaurant) {
    _selectedRestaurant = restaurant;
    notifyListeners();
  }

  void selectFood(MenuItemModel food) {
    _selectedFood = food;
    notifyListeners();
  }

  void addToCart(MenuItemModel item, String restaurantId, String restaurantName) {
    int index = _cart.indexWhere((c) => c.item.id == item.id);
    if (index >= 0) {
      _cart[index].quantity += 1;
    } else {
      _cart.add(CartItemModel(
        item: item,
        quantity: 1,
        restaurantId: restaurantId,
        restaurantName: restaurantName,
      ));
    }
    notifyListeners();
  }

  void removeFromCart(String itemId) {
    int index = _cart.indexWhere((c) => c.item.id == itemId);
    if (index >= 0) {
      if (_cart[index].quantity > 1) {
        _cart[index].quantity -= 1;
      } else {
        _cart.removeAt(index);
      }
      notifyListeners();
    }
  }

  void applyCoupon(CouponModel? coupon) {
    _appliedCoupon = coupon;
    notifyListeners();
  }

  void selectAddress(AddressModel address) {
    _selectedAddress = address;
    notifyListeners();
  }

  void selectPayment(String payment) {
    _selectedPayment = payment;
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    _appliedCoupon = null;
    notifyListeners();
  }
}
