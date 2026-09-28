import re
import os

with open('firebase_service.dart.bak', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Import incoming_order_call.dart
if 'incoming_order_call.dart' not in content:
    content = content.replace("import 'package:food_track/core/utils/network_retry.dart';", 
                              "import 'package:food_track/core/utils/network_retry.dart';\nimport 'package:food_track/core/services/incoming_order_call.dart';")

# 2. Add id param to _showCallNotification
content = content.replace('''Future<void> _showCallNotification({
  required String title,
  required String body,
  String? payload,
}) async {''', '''Future<void> _showCallNotification({
  required String title,
  required String body,
  String? payload,
  int? id,
}) async {''')

content = content.replace('''    const androidDetails = AndroidNotificationDetails(
      'food_mela_calls',
      'Food Mela Calls',
      channelDescription: 'Incoming voice-call alerts (WhatsApp style)',''', '''    const androidDetails = AndroidNotificationDetails(
      'food_mela_orders',
      'Food Mela Orders',
      channelDescription: 'Live order notifications for Food Mela Delivery Partner',''')

content = content.replace('''    await _localNotifications.show(
      900001, // fixed ID — a new call replaces the previous ring''', '''    await _localNotifications.show(
      id ?? 900001,''')

# 3. Update firebaseMessagingBackgroundHandler
old_bg = '''  // WhatsApp-style incoming call for orders & calls — wake screen, bring to front, ring continuously
  if (dataType == 'incoming_call' || dataType == 'new_order' || orderId.isNotEmpty) {
    debugPrint('📞 [RIDER BACKGROUND] Incoming order call for order $orderId');
    try {
      if (orderId.isNotEmpty) {
        await NativeOrderAlert.start(orderId);
        await NativeOrderAlert.bringAppToForeground();
      }
    } catch (_) {}
    await _showCallNotification(
      title: title.isNotEmpty ? title : '📞 INCOMING ORDER CALL',
      body: '$body — Tap to Open Call',
      payload: message.data.toString(),
    );
    return;
  }'''

new_bg = '''  // WhatsApp-style incoming call for orders & calls — wake screen, bring to front, ring continuously
  if (dataType == 'incoming_call' || dataType == 'new_order' || orderId.isNotEmpty) {
    debugPrint('📞 [RIDER BACKGROUND] Incoming order call for order $orderId');
    try {
      if (orderId.isNotEmpty) {
        await NativeOrderAlert.start(orderId);
        await NativeOrderAlert.bringAppToForeground();
      }
    } catch (_) {}
    
    final hasNotificationBlock = message.notification != null;
    if (hasNotificationBlock) {
      debugPrint('ℹ️ [RIDER BACKGROUND] Skipping local notification (OS already showed it from notification block)');
    } else {
      await _showCallNotification(
        title: title.isNotEmpty ? title : '📞 INCOMING ORDER CALL',
        body: '$body — Tap to Open Call',
        payload: message.data.toString(),
        id: orderId.isNotEmpty ? FirebaseService.notificationIdForOrder(orderId) : null,
      );
    }
    return;
  }'''
content = content.replace(old_bg, new_bg)


# 4. _globalNotifiedIds replacing _notifiedOrderIds
# Remove the old static final Set<String> _notifiedOrderIds = {};
content = content.replace('  static final Set<String> _notifiedOrderIds = {};', '')

# Insert the new static methods somewhere in FirebaseService, for instance right after `_settledOrderIds`
global_ids_code = '''  static final Set<String> _globalNotifiedIds = {};

  static bool isOrderNotified(String orderId) {
    if (orderId.isEmpty) return false;
    return _globalNotifiedIds.contains(orderId);
  }

  static Future<void> markOrderNotified(String orderId) async {
    if (orderId.isEmpty) return;
    _globalNotifiedIds.add(orderId);
    if (_globalNotifiedIds.length > 200) {
      _globalNotifiedIds.remove(_globalNotifiedIds.first);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('global_notified_ids', _globalNotifiedIds.toList());
    } catch (_) {}
  }
'''

content = content.replace('''  // ── Notify Driver via Local Push ─────────────────────────────────────────────
  /// Terminal states: once an order reaches one, it must NEVER notify again
  /// for this rider session (accept/reject/cancel echo, snapshot replay).
  static final Set<String> _settledOrderIds = {};''', '''  // ── Notify Driver via Local Push ─────────────────────────────────────────────
  /// Terminal states: once an order reaches one, it must NEVER notify again
  /// for this rider session (accept/reject/cancel echo, snapshot replay).
  static final Set<String> _settledOrderIds = {};

''' + global_ids_code)

# 5. loadNotifiedOrders in loadSettledOrders
content = content.replace('''  static Future<void> loadSettledOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('rider_settled_orders') ?? [];
      _settledOrderIds.addAll(saved);
    } catch (_) {}
  }''', '''  static Future<void> loadSettledOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('rider_settled_orders') ?? [];
      _settledOrderIds.addAll(saved);
      final savedNotified = prefs.getStringList('global_notified_ids') ?? [];
      _globalNotifiedIds.addAll(savedNotified);
    } catch (_) {}
  }''')

# 6. settleOrder updates
content = content.replace('''  static Future<void> settleOrder(String orderId) async {
    if (orderId.isEmpty) return;
    _settledOrderIds.add(orderId);
    if (_settledOrderIds.length > 500) {
      _settledOrderIds.remove(_settledOrderIds.first);
    }
    _notifiedOrderIds.remove(orderId);
    try {''', '''  static Future<void> settleOrder(String orderId) async {
    if (orderId.isEmpty) return;
    _settledOrderIds.add(orderId);
    if (_settledOrderIds.length > 500) {
      _settledOrderIds.remove(_settledOrderIds.first);
    }
    _globalNotifiedIds.add(orderId); // ensure it's considered notified too
    try {''')

# 7. notifyDriverNewOrder updates
old_notify = '''    if (_notifiedOrderIds.contains(orderId)) {
      debugPrint('ℹ️ Notification skipped (already shown): $orderId');
      return;
    }
    _notifiedOrderIds.add(orderId);'''

new_notify = '''    if (isOrderNotified(orderId) || IncomingOrderCall.isShown(orderId)) {
      debugPrint('ℹ️ Notification skipped (already shown): $orderId');
      return;
    }
    markOrderNotified(orderId);'''
content = content.replace(old_notify, new_notify)

# 8. onMessage listener updates
old_onmessage = '''        // Settled orders (accepted/rejected/cancelled/taken) NEVER re-fire —
        // repeated FCM redelivery for the same order is dropped here.
        if (orderId.isNotEmpty && _settledOrderIds.contains(orderId)) {
          debugPrint('ℹ️ [RIDER FCM] dropped redelivery for settled $orderId');
          return;
        }'''

new_onmessage = '''        // Settled orders (accepted/rejected/cancelled/taken) NEVER re-fire —
        // repeated FCM redelivery for the same order is dropped here.
        if (orderId.isNotEmpty && _settledOrderIds.contains(orderId)) {
          debugPrint('ℹ️ [RIDER FCM] dropped redelivery for settled $orderId');
          return;
        }
        
        if (orderId.isNotEmpty && (isOrderNotified(orderId) || IncomingOrderCall.isShown(orderId))) {
          debugPrint('ℹ️ [RIDER FCM] skipped notification, order $orderId is already notified/shown');
          return;
        }
        
        if (orderId.isNotEmpty) {
          markOrderNotified(orderId);
        }'''
content = content.replace(old_onmessage, new_onmessage)


with open('firebase_service.dart', 'w', encoding='utf-8') as f:
    f.write(content)
