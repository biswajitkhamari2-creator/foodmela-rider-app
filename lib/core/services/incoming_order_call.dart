// ─── Food Mela — Incoming order CALL (full-screen, WhatsApp style) ───────────
// Shows IncomingOrderScreen as a real full-screen "call" the moment a new
// order arrives — foreground FCM pushes it directly, notification taps open
// it from background/killed. One screen per order, never duplicates.
//
// Wiring: main.dart / main_rider.dart set [navigatorKey] and call
// [ensureInitialized] once at startup. FirebaseService forwards FCM +
// notification-tap events here through hooks (no import cycle).
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:food_track/core/services/firebase_service.dart';
import 'package:food_track/core/services/native_order_alert.dart';
import 'package:food_track/core/services/order_ringtone_service.dart';
import 'package:food_track/core/services/rider_auth_service.dart';
import 'package:food_track/features/rider/active_delivery_screen.dart';
import 'package:food_track/features/rider/incoming_order_screen.dart';

class IncomingOrderCall {
  IncomingOrderCall._();

  /// Set once from main() — the live app navigator.
  static GlobalKey<NavigatorState>? navigatorKey;

  static final Map<String, Route<void>> _routes = {};
  static final Set<String> _shownIds = {};

  static bool isShown(String orderId) => _shownIds.contains(orderId);

  static void markShown(String orderId) {
    _shownIds.add(orderId);
    if (_shownIds.length > 200) {
      _shownIds.remove(_shownIds.first);
    }
  }

  static void unmarkShown(String orderId) {
    _shownIds.remove(orderId);
  }

  /// Dashboard registers routes it pushes itself so FCM skips duplicates
  /// and the silence-loop can dismiss them.
  static void trackRoute(String orderId, Route<void> route) {
    _routes[orderId] = route;
  }

  static void untrackRoute(String orderId) => _routes.remove(orderId);

  /// Hook FirebaseService events into this call UI. Idempotent.
  static void ensureInitialized() {
    FirebaseService.onForegroundNewOrder = (data) => showIncomingCall(data);
    FirebaseService.onNotificationTap = (payload) => openFromPayload(payload);
    FirebaseService.onFcmOpen = (data) =>
        showIncomingCall(data, verifyAvailable: true);
    // Cold start via notification tap: FirebaseService's own getInitialMessage
    // hook may fire before hooks were set — check directly as well.
    FirebaseMessaging.instance.getInitialMessage().then((m) {
      if (m == null) return;
      final type = m.data['type']?.toString() ?? '';
      if (type == 'new_order' || (m.data['orderId']?.toString().isNotEmpty == true)) {
        showIncomingCall(_strMap(m.data), verifyAvailable: true);
      }
    }).catchError((_) {});
  }

  /// Push the full-screen call UI for a new order. No-op when logged out,
  /// already showing/shown, or (with verify) no longer available.
  static Future<void> showIncomingCall(
    Map<String, String> data, {
    bool verifyAvailable = false,
  }) async {
    var d = Map<String, String>.from(data);
    final orderId = (d['orderId'] ?? '').trim();
    if (orderId.isEmpty || _routes.containsKey(orderId) || _shownIds.contains(orderId)) return;

    // Must be a logged-in rider — otherwise stay on login, notification only.
    Map<String, String>? session;
    try {
      session = await RiderAuthService.instance.getSession();
    } catch (_) {}
    if (session == null || (session['uid'] ?? '').isEmpty) return;
    final riderName =
        (session['name'] ?? '').isNotEmpty ? session['name']! : 'Delivery Partner';
    final partnerId = session['partnerId'] ?? '';
    final phone = session['phone'] ?? '';
    final riderId = partnerId.isNotEmpty
        ? partnerId
        : (phone.isNotEmpty ? phone : 'rider');

    // Tap-from-killed/background: confirm the order is still claimable and
    // fill any fields the push payload didn't carry.
    if (verifyAvailable || _needsEnrichment(d)) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .get()
            .timeout(const Duration(seconds: 6));
        if (!doc.exists) return;
        final od = doc.data()!;
        final stage = (od['stage'] as num?)?.toInt() ?? 0;
        final rId = od['riderId'] as String?;
        final status = (od['status'] as String? ?? '').toLowerCase();
        final deleted = od['isDeleted'] as bool? ?? false;
        if (stage != 0 || (rId != null && rId.isNotEmpty) || status.contains('cancel') || deleted) {
          return;
        }
        d = _enriched(d, od);
      } catch (_) {
        if (verifyAvailable) return;
      }
    }

    final nav = navigatorKey?.currentState;
    if (nav == null) return;
    markShown(orderId);
    await OrderRingtoneService.startRinging(orderId);
    await NativeOrderAlert.bringAppToForeground();

    final snapshot = Map<String, String>.from(d);
    final route = MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (routeContext) => IncomingOrderScreen(
        orderId: orderId,
        customerName: snapshot['customerName'] ?? 'Customer',
        customerPhone: snapshot['customerPhone'] ?? '',
        address: snapshot['address'] ?? 'Address not set',
        totalAmount: double.tryParse(snapshot['amount'] ?? '') ?? 0,
        itemsSummary: snapshot['items'] ?? '',
        categoryLabel: snapshot['categoryLabel'] ?? '',
        onAccept: () => _accept(orderId, snapshot, riderName, riderId),
        onDecline: () {
          OrderRingtoneService.stopRinging(orderId);
          FirebaseService.dismissOrderNotification(orderId);
          dismiss(orderId);
        },
        // VIEW ORDER: read-only detail sheet over the ringing call UI.
        // Ringing continues — accept/reject still happen from this screen.
        onViewOrder: () => _showViewOrderSheet(routeContext, orderId, snapshot),
      ),
    );
    _routes[orderId] = route;
    nav.push(route).then((_) => _routes.remove(orderId));
  }

  static bool _needsEnrichment(Map<String, String> d) {
    return (d['customerName'] ?? '').isEmpty || (d['address'] ?? '').isEmpty;
  }

  static Map<String, String> _enriched(
      Map<String, String> d, Map<String, dynamic> od) {
    final out = Map<String, String>.from(d);
    String s(String k) => (od[k] as String? ?? '').trim();
    out['customerName'] =
        out['customerName']!.isNotEmpty ? out['customerName']! : (s('customerName').isNotEmpty ? s('customerName') : 'Customer');
    out['address'] =
        out['address']!.isNotEmpty ? out['address']! : (s('address').isNotEmpty ? s('address') : 'Address not set');
    if ((out['items'] ?? '').isEmpty) {
      final summary = s('itemsSummary');
      out['items'] = summary.isNotEmpty ? summary : _itemsSummary(od['items']);
    }
    if ((out['amount'] ?? '').isEmpty) {
      out['amount'] = ((od['totalAmount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0);
    }
    if ((out['customerPhone'] ?? '').isEmpty) out['customerPhone'] = s('customerPhone');
    if ((out['categoryLabel'] ?? '').isEmpty) {
      out['categoryLabel'] = s('orderCategoryLabel').isNotEmpty
          ? s('orderCategoryLabel')
          : _catLabel(s('orderCategory'));
    }
    return out;
  }

  static String _itemsSummary(dynamic items) {
    try {
      if (items is List) {
        return items
            .map((e) => '${e['quantity'] ?? 1}x ${e['itemId'] ?? e['name'] ?? ''}')
            .join(', ');
      }
      return items?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  static String _catLabel(String key) {
    switch (key.toLowerCase()) {
      case 'grocery':
        return 'GROCERY';
      case 'vegetables':
        return 'VEGETABLES';
      case 'fruits':
        return 'FRUITS';
      case 'dairy':
        return 'DAIRY';
      case 'eggs_meat':
        return 'EGGS & MEAT';
      case 'cooked_food':
        return 'COOKED FOOD';
      case 'non_veg':
        return 'NON-VEG';
      case 'sweets':
        return 'SWEETS';
      case 'snacks':
        return 'SNACKS';
      case 'mixed':
        return 'MIXED';
      default:
        return 'GENERAL';
    }
  }

  /// Accept from the call screen: stop ring, claim via transaction, open delivery.
  static Future<void> _accept(
    String orderId,
    Map<String, String> data,
    String riderName,
    String riderId,
  ) async {
    final nav = navigatorKey?.currentState;
    if (nav == null) return;
    OrderRingtoneService.stopRinging(orderId);
    FirebaseService.dismissOrderNotification(orderId);
    dismiss(orderId);
    final messenger = ScaffoldMessenger.maybeOf(nav.context);
    final rootNav = Navigator.of(nav.context, rootNavigator: true);
    showDialog(
      context: nav.context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
      ),
    );
    bool success = false;
    try {
      success = await FirebaseService.acceptOrder(
        orderId: orderId,
        riderName: riderName,
        riderId: riderId,
      ).timeout(const Duration(seconds: 15));
    } catch (_) {}
    try {
      rootNav.pop();
    } catch (_) {}
    if (success) {
      markShown(orderId);
      nav.push(MaterialPageRoute(
        builder: (_) => ActiveDeliveryScreen(
          orderId: orderId,
          customerName: data['customerName'] ?? 'Customer',
          customerPhone: data['customerPhone'] ?? '',
          address: data['address'] ?? '',
          itemsSummary: data['items'] ?? '',
          totalAmount: double.tryParse(data['amount'] ?? '') ?? 0,
          riderId: riderId,
        ),
      ));
    } else {
      try {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Order already taken by another rider'),
            backgroundColor: Color(0xFFD97706),
          ),
        );
      } catch (_) {}
    }
  }

  /// VIEW ORDER sheet: same read-only order details as the dashboard
  /// receipt, shown over the ringing call UI without stopping the ring.
  static void _showViewOrderSheet(
    BuildContext context,
    String orderId,
    Map<String, String> data,
  ) {
    final amount = double.tryParse(data['amount'] ?? '') ?? 0;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 16),
            Text('Order #$orderId',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
                (data['categoryLabel'] ?? '').isNotEmpty
                    ? data['categoryLabel']!
                    : 'NEW ORDER',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            _sheetRow('Customer', data['customerName'] ?? 'Customer'),
            _sheetRow('Phone', (data['customerPhone'] ?? '').isNotEmpty
                ? data['customerPhone']!
                : 'N/A'),
            _sheetRow('Address', data['address'] ?? 'Address not set'),
            _sheetRow('Items', (data['items'] ?? '').isNotEmpty
                ? data['items']!
                : 'See details'),
            _sheetRow('Total', '₹${amount.toInt()} (online)'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(sheetContext),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: const Text('Back to Accept / Reject',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _sheetRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 90,
              child: Text(label,
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade600))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  /// Remove the call screen (order claimed / cancelled / declined).
  static void dismiss(String orderId) {
    _shownIds.remove(orderId);
    final route = _routes.remove(orderId);
    if (route == null) return;
    try {
      route.navigator?.removeRoute(route);
    } catch (_) {}
  }

  /// Notification-tap payload → open the call screen (verified).
  static Future<void> openFromPayload(String payload) async {
    final data = _parsePayload(payload);
    if ((data['orderId'] ?? '').isEmpty) return;
    await showIncomingCall(data, verifyAvailable: true);
  }

  static Map<String, String> _parsePayload(String payload) {
    if (payload.isEmpty) return {};
    // New format: JSON with full order fields.
    try {
      final first = payload.indexOf('{');
      final last = payload.lastIndexOf('}');
      if (first >= 0 && last > first) {
        final decoded = Map<String, dynamic>.from(
            jsonDecode(payload.substring(first, last + 1)));
        return decoded.map((k, v) => MapEntry(k, v?.toString() ?? ''));
      }
    } catch (_) {}
    // Legacy format: orderId=FM-123&phone=91...
    final out = <String, String>{};
    final m = RegExp(r'orderId=([^&}]+)').firstMatch(payload);
    if (m != null) out['orderId'] = m.group(1)!.trim();
    final p = RegExp(r'phone=([^&}]+)').firstMatch(payload);
    if (p != null) out['customerPhone'] = p.group(1)!.trim();
    return out;
  }

  static Map<String, String> _strMap(Map<String, dynamic> raw) {
    return raw.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  }
}
