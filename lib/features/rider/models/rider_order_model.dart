import 'package:cloud_firestore/cloud_firestore.dart';

/// Single item within a customer order for rider visibility.
class RiderOrderItem {
  final String name;
  final int quantity;
  final double? price;
  final String unit;

  const RiderOrderItem({
    required this.name,
    required this.quantity,
    this.price,
    this.unit = '',
  });

  /// Display string e.g. "2x Chicken Biryani (₹150)" or "1x Veg Roll"
  String get displayString {
    final qtyStr = '${quantity}x';
    final priceStr = price != null && price! > 0 ? ' • ₹${price!.toInt()}' : '';
    final unitStr = unit.isNotEmpty ? ' ($unit)' : '';
    return '$qtyStr $name$unitStr$priceStr';
  }
}

/// Helper utilities and parsers for rider orders.
class RiderOrderModel {
  RiderOrderModel._();

  /// Parses items from any order data structure in Firestore:
  /// 1. `rawItems` List of Maps
  /// 2. `items` List of Maps or Strings
  /// 3. `itemsSummary` formatted text
  static List<RiderOrderItem> parseItems(Map<String, dynamic> data) {
    final List<RiderOrderItem> result = [];

    // 1. Try 'rawItems'
    final rawItems = data['rawItems'];
    if (rawItems is List && rawItems.isNotEmpty) {
      for (final it in rawItems) {
        final parsed = _parseMapItem(it);
        if (parsed != null) result.add(parsed);
      }
      if (result.isNotEmpty) return result;
    }

    // 2. Try 'items'
    final items = data['items'];
    if (items is List && items.isNotEmpty) {
      for (final it in items) {
        if (it is Map) {
          final parsed = _parseMapItem(it);
          if (parsed != null) result.add(parsed);
        } else if (it is String && it.trim().isNotEmpty) {
          final parsed = _parseStringItem(it.trim());
          if (parsed != null) result.add(parsed);
        }
      }
      if (result.isNotEmpty) return result;
    } else if (items is String && items.trim().isNotEmpty) {
      final parsedList = _parseSummaryString(items);
      if (parsedList.isNotEmpty) return parsedList;
    }

    // 3. Try 'itemsSummary'
    final summary = data['itemsSummary'];
    if (summary is String && summary.trim().isNotEmpty) {
      final parsedList = _parseSummaryString(summary);
      if (parsedList.isNotEmpty) return parsedList;
    }

    // 4. Fallback: single item representing the order
    final total = (data['totalAmount'] as num?)?.toDouble();
    final cat = (data['orderCategoryLabel'] ?? data['orderCategory'] ?? 'Food').toString();
    return [
      RiderOrderItem(
        name: '$cat Order',
        quantity: 1,
        price: total,
      ),
    ];
  }

  static RiderOrderItem? _parseMapItem(dynamic it) {
    if (it is! Map) return null;
    final map = Map<String, dynamic>.from(it);
    final rawName = map['name'] ?? map['title'] ?? map['itemName'] ?? map['itemId'] ?? '';
    final name = rawName.toString().trim();
    if (name.isEmpty) return null;

    final rawQty = map['quantity'] ?? map['qty'] ?? map['count'] ?? 1;
    int qty = 1;
    if (rawQty is num) {
      qty = rawQty.toInt();
    } else if (rawQty is String) {
      qty = int.tryParse(rawQty) ?? 1;
    }

    final rawPrice = map['price'] ?? map['itemPrice'] ?? map['rate'] ?? map['total'];
    double? price;
    if (rawPrice is num) {
      price = rawPrice.toDouble();
    } else if (rawPrice is String) {
      final clean = rawPrice.replaceAll(RegExp(r'[^0-9.]'), '');
      price = double.tryParse(clean);
    }

    final unit = (map['unit'] ?? '').toString().trim();

    return RiderOrderItem(
      name: name,
      quantity: qty > 0 ? qty : 1,
      price: price,
      unit: unit,
    );
  }

  static RiderOrderItem? _parseStringItem(String text) {
    var s = text.trim();
    if (s.isEmpty) return null;

    // Check for trailing price like "(₹120)" or "₹120"
    double? price;
    final priceMatch = RegExp(r'[₹$]\s*(\d+(?:\.\d+)?)').firstMatch(s);
    if (priceMatch != null) {
      price = double.tryParse(priceMatch.group(1)!);
      s = s.replaceAll(RegExp(r'\s*\([₹$]?\s*\d+(?:\.\d+)?\)\s*'), ' ').trim();
      s = s.replaceAll(RegExp(r'[₹$]\s*\d+(?:\.\d+)?'), ' ').trim();
    }

    // Case 1: "2x Chicken Biryani" or "2 × Chicken Biryani" or "2 * Biryani"
    final leadingMatch = RegExp(r'^(\d+)\s*[xX×*]\s*(.+)$').firstMatch(s);
    if (leadingMatch != null) {
      final qty = int.tryParse(leadingMatch.group(1)!) ?? 1;
      final name = leadingMatch.group(2)!.trim();
      return RiderOrderItem(name: name, quantity: qty, price: price);
    }

    // Case 2: "Chicken Biryani x 2" or "Chicken Biryani × 2"
    final trailingMatch = RegExp(r'^(.+?)\s*[xX×*]\s*(\d+)$').firstMatch(s);
    if (trailingMatch != null) {
      final name = trailingMatch.group(1)!.trim();
      final qty = int.tryParse(trailingMatch.group(2)!) ?? 1;
      return RiderOrderItem(name: name, quantity: qty, price: price);
    }

    // Case 3: "Chicken Biryani" (default quantity 1)
    return RiderOrderItem(name: s, quantity: 1, price: price);
  }

  static List<RiderOrderItem> _parseSummaryString(String summary) {
    final List<RiderOrderItem> items = [];
    final tokens = summary.split(RegExp(r'[,;\n]'));
    for (final token in tokens) {
      final clean = token.trim();
      if (clean.isNotEmpty) {
        final parsed = _parseStringItem(clean);
        if (parsed != null) items.add(parsed);
      }
    }
    return items;
  }

  /// Determines if an order is paid online (prepaid) or cash on delivery.
  static bool isPrepaid(Map<String, dynamic> data) {
    if (data['isPaid'] == true) return true;
    final mode = (data['paymentMode'] as String? ?? '').toUpperCase();
    if (mode.contains('PREPAID') || mode.contains('PAYU') || mode.contains('ONLINE') || mode.contains('UPI')) {
      return true;
    }
    final status = (data['paymentStatus'] as String? ?? '').toUpperCase();
    if (status == 'PAID' || status == 'SUCCESS') return true;
    final addr = (data['address'] as String? ?? '').toUpperCase();
    if (addr.contains('PREPAID') || addr.contains('PAYU') || addr.contains('ONLINE')) {
      return true;
    }
    return false;
  }

  /// Cleans technical tags like `[PREPAID - PAYU]` or `[CASH ON DELIVERY]` from address.
  static String cleanAddress(String rawAddress) {
    return rawAddress
        .replaceAll(RegExp(r'\[PREPAID[^\]]*\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[CASH ON DELIVERY[^\]]*\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[COD\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[ONLINE\]', caseSensitive: false), '')
        .trim();
  }

  /// Formats timestamp or relative time.
  /// All values normalized to LOCAL time — Firestore Timestamps, UTC ISO
  /// strings and epoch millis otherwise render hours off (e.g. 2:13 AM).
  static DateTime _toLocal(DateTime dt) => dt.isUtc ? dt.toLocal() : dt;

  static String formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    try {
      DateTime dt;
      if (timestamp is Timestamp) {
        dt = _toLocal(timestamp.toDate());
      } else if (timestamp is DateTime) {
        dt = _toLocal(timestamp);
      } else if (timestamp is String) {
        dt = _toLocal(DateTime.tryParse(timestamp) ?? DateTime.now());
      } else if (timestamp is num) {
        dt = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt(), isUtc: true).toLocal();
      } else {
        return 'Recently';
      }

      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) {
        final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final minute = dt.minute.toString().padLeft(2, '0');
        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
        return '$hour:$minute $ampm';
      }

      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.day} ${months[(dt.month - 1).clamp(0, 11)]}, $hour:$minute $ampm';
    } catch (_) {
      return 'Recently';
    }
  }

  /// Safe phone masking: keeps first 2 and last 4 digits visible.
  static String maskPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 6) return phone.isNotEmpty ? phone : 'Customer Phone';
    final start = digits.substring(0, 2);
    final end = digits.substring(digits.length - 4);
    return '$start••••$end';
  }
}
