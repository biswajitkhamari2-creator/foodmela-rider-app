import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:food_track/core/state/food_mela_state.dart';
import 'package:food_track/core/services/native_order_alert.dart';

// ─── BACKGROUND MESSAGE HANDLER — RIDER APP ─────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final dataType = message.data['type']?.toString() ?? '';
  final title = message.notification?.title ??
      message.data['title']?.toString() ??
      '🛵 New Order!';
  final body = message.notification?.body ??
      message.data['body']?.toString() ??
      'A new order has arrived.';
  final orderId = message.data['orderId']?.toString() ?? '';

  // WhatsApp-style incoming call for orders & calls — wake screen, bring to front, ring continuously
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
  }
  debugPrint('🔔 [RIDER BACKGROUND] Message: $title');
  await _showLocalNotification(
    title: title,
    body: body,
    payload: message.data.toString(),
    id: orderId.isNotEmpty
        ? FirebaseService.notificationIdForOrder(orderId)
        : null,
  );
}

/// WhatsApp-style incoming-call alert: separate high-priority channel with
/// full-screen intent — wakes the screen even when the app is killed.
Future<void> _showCallNotification({
  required String title,
  required String body,
  String? payload,
}) async {
  try {
    const androidDetails = AndroidNotificationDetails(
      'food_mela_calls',
      'Food Mela Calls',
      channelDescription: 'Incoming voice-call alerts (WhatsApp style)',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      ticker: 'Incoming call!',
      autoCancel: true,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.call,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    await _localNotifications.show(
      900001, // fixed ID — a new call replaces the previous ring
      title,
      body,
      notificationDetails,
      payload: payload,
    );
    debugPrint('✅ Call notification shown: $title');
  } catch (e) {
    debugPrint('⚠️ Call notification error: $e');
  }
}

// ─── LOCAL NOTIFICATION HELPER ───────────────────────────────────────────────
final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

Future<void> _showLocalNotification({
  required String title,
  required String body,
  String? payload,
  int? id,
}) async {
  try {
    const androidDetails = AndroidNotificationDetails(
      'food_mela_orders',
      'Food Mela Orders',
      channelDescription: 'Live order notifications for Food Mela Delivery Partner',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      ticker: 'New Order Received!',
      autoCancel: true,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.call,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    await _localNotifications.show(
      id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
      payload: payload,
    );
    debugPrint('✅ Local notification shown: $title');
  } catch (e) {
    debugPrint('⚠️ Notification show error: $e');
  }
}

// ─── FIREBASE SERVICE ─────────────────────────────────────────────────────────
class FirebaseService {
  static bool _isFirebaseInitialized = false;

  // ── Incoming-order CALL hooks (set by IncomingOrderCall.ensureInitialized) ──
  // Kept as plain callbacks so firebase_service never imports the call UI.
  /// Foreground FCM new_order arrived — push the full-screen call UI.
  static void Function(Map<String, String> data)? onForegroundNewOrder;

  /// Any notification tapped (foreground/background/killed) — open call UI.
  static void Function(String payload)? onNotificationTap;

  /// App opened from terminated state via FCM — open call UI (verified).
  static void Function(Map<String, String> data)? onFcmOpen;

  /// Structured payload for new-order notifications: full order fields as
  /// JSON so a tap opens the call screen even from killed state.
  static String newOrderPayload({
    required String orderId,
    required String customerName,
    required String address,
    required double amount,
    required String phone,
    required String items,
    required String categoryLabel,
  }) {
    return jsonEncode({
      'type': 'new_order',
      'orderId': orderId,
      'customerName': customerName,
      'address': address,
      'amount': amount.toStringAsFixed(0),
      'customerPhone': phone,
      'items': items,
      'categoryLabel': categoryLabel,
    });
  }

  static Map<String, String> newOrderData({
    required String orderId,
    required String customerName,
    required String address,
    required double amount,
    required String phone,
    required String items,
    required String categoryLabel,
  }) {
    return {
      'type': 'new_order',
      'orderId': orderId,
      'customerName': customerName,
      'address': address,
      'amount': amount.toStringAsFixed(0),
      'customerPhone': phone,
      'items': items,
      'categoryLabel': categoryLabel,
    };
  }

  // ── Per-order notification IDs (so accept/decline can vanish them) ──────
  // Stable int per orderId — same ID shown from every path (FCM, Firestore,
  // background isolate), so cancelling by orderId always hits the right one.
  static int notificationIdForOrder(String orderId) {
    var h = 0;
    for (var i = 0; i < orderId.length; i++) {
      h = ((h * 31) + orderId.codeUnitAt(i)) & 0x7fffffff;
    }
    return 100000 + (h % 800000);
  }

  /// Proof test after the user grants full-screen permission: fires one REAL
  /// full-screen alert through the same channel new orders use. Tapping or
  /// swiping it away proves the tone stops — no order needed.
  static Future<void> showFullScreenTestAlert() async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'food_mela_orders',
        'Food Mela Orders',
        channelDescription: 'Live order notifications for Food Mela Delivery Partner',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        ticker: 'Full-screen alerts working!',
        autoCancel: true,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
      );
      const details = NotificationDetails(android: androidDetails);
      await _localNotifications.show(
        999001,
        '✅ Full-screen alerts ON',
        'Orders will now ring like incoming calls. Swipe this away — tone stops.',
        details,
        payload: '',
      );
      debugPrint('✅ [RIDER] Full-screen test alert fired');
    } catch (e) {
      debugPrint('⚠️ [RIDER] Test alert failed: $e');
    }
  }

  /// Dismiss the tray notification for an order (accept / decline / claimed).
  /// Also stops any ringing tied to it. Cancels BOTH the app-owned copy (by
  /// per-order ID) and the system copy posted by FCM's notification block
  /// (by tag = orderId, which the backend sets) — so no stale copy lingers.
  static Future<void> dismissOrderNotification(String orderId) async {
    if (orderId.isEmpty) return;
    try {
      await _localNotifications.cancel(notificationIdForOrder(orderId));
      try {
        final android = _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        // System copy posted by FCM carries tag = orderId (backend sets it).
        await android?.cancel(notificationIdForOrder(orderId),
            tag: orderId);
      } catch (_) {}
      debugPrint('🧹 [RIDER] notification dismissed for $orderId');
    } catch (e) {
      debugPrint('⚠️ notification cancel notice: $e');
    }
  }

  // ── Initialize ──────────────────────────────────────────────────────────────
  static Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _isFirebaseInitialized = true;
      // Background handler is registered in main.dart at top-level (required before any async init)

      await _setupLocalNotifications();
      await _setupPushNotifications();
    } catch (e) {
      debugPrint('Firebase init notice: $e');
    }
  }

  // ── Local Notification Setup ─────────────────────────────────────────────────
  static Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Notification tapped: ${details.payload}');
        // Tap → open the full-screen incoming-order call UI.
        final payload = details.payload ?? '';
        if (payload.isNotEmpty) {
          try {
            onNotificationTap?.call(payload);
          } catch (e) {
            debugPrint('⚠️ notification-tap hook notice: $e');
          }
        }
      },
    );

    // Create high-priority notification channels (required for Android 8+)
    const ordersChannel = AndroidNotificationChannel(
      'food_mela_orders',
      'Food Mela Orders',
      description: 'Live order notifications for Food Mela Delivery Partner',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
    );
    // Dedicated calls channel — WhatsApp-style full-screen incoming-call ring
    const callsChannel = AndroidNotificationChannel(
      'food_mela_calls',
      'Food Mela Calls',
      description: 'Incoming voice-call alerts (rings even when app is closed)',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
    );
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.createNotificationChannel(ordersChannel);
      await androidPlugin.createNotificationChannel(callsChannel);
    }
  }

  // ── FCM Setup ────────────────────────────────────────────────────────────────
  static Future<void> _setupPushNotifications() async {
    // Request permission (works on Android 13+ and iOS)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Make sure notifications show even when app is in foreground
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground FCM listener — RIDER APP: SHOW new_order notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final dataType = message.data['type'] ?? '';
      final title = message.notification?.title ?? message.data['title'] ?? '';
      final body = message.notification?.body ?? message.data['body'] ?? '';
      debugPrint('🔔 [RIDER FOREGROUND FCM] type=$dataType title=$title');
      // Incoming masked call — Firestore signaling shows the full screen;
      // the push is a heads-up so it isn't missed in foreground.
      if (dataType == 'incoming_call') {
        debugPrint('📞 [RIDER FOREGROUND] incoming call: ${message.data['orderId']}');
        _showCallNotification(
          title: title.isNotEmpty ? title : '📞 Incoming call',
          body: body.isNotEmpty ? body : 'Tap to answer (in-app)',
          payload: message.data.toString(),
        );
        return;
      }
      // Rider MUST receive new_order pushes (background FCM → foreground delivery)
      // FULL-SCREEN CALL: push IncomingOrderScreen directly — not just a
      // tray notification. The hook also starts the looping ringtone.
      if (dataType == 'new_order' || title.contains('New Order') || message.data.containsKey('orderId')) {
        final orderId = message.data['orderId']?.toString() ?? '';
        final data = message.data
            .map((k, v) => MapEntry(k, v?.toString() ?? ''));
        try {
          NativeOrderAlert.bringAppToForeground();
          onForegroundNewOrder?.call(data);
        } catch (e) {
          debugPrint('⚠️ [RIDER FCM] call-UI hook notice: $e');
        }
        // Tray notification stays as backup (lock screen / heads-up) with a
        // structured payload so tapping it opens the same call screen.
        // Stable per-order ID → accept/decline can dismiss exactly this one.
        _showLocalNotification(
          title: title.isNotEmpty ? title : '🛵 New Order!',
          body: body.isNotEmpty ? body : 'A new order has arrived — tap to view',
          payload: newOrderPayload(
            orderId: orderId,
            customerName: data['customerName'] ?? '',
            address: data['address'] ?? '',
            amount: double.tryParse(data['amount'] ?? '') ?? 0,
            phone: data['customerPhone'] ?? '',
            items: data['items'] ?? '',
            categoryLabel: data['categoryLabel'] ?? '',
          ),
          id: orderId.isNotEmpty ? notificationIdForOrder(orderId) : null,
        );
        return;
      }
      // Other FCM types (e.g. order status updates) — show generically
      _showLocalNotification(
        title: title.isNotEmpty ? title : 'Food Mela',
        body: body,
        payload: message.data.toString(),
      );
    });

    // App opened from terminated state via notification → open call UI.
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        debugPrint('App launched from terminated via notification: ${message.data}');
        try {
          onFcmOpen?.call(
              message.data.map((k, v) => MapEntry(k, v?.toString() ?? '')));
        } catch (e) {
          debugPrint('⚠️ fcm-open hook notice: $e');
        }
      }
    });

    // App resumed from background via notification tap → open call UI.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification opened app from background: ${message.data}');
      try {
        onFcmOpen?.call(
            message.data.map((k, v) => MapEntry(k, v?.toString() ?? '')));
      } catch (e) {
        debugPrint('⚠️ fcm-open hook notice: $e');
      }
    });

    // Rider MUST be subscribed to rider_notifications to receive FCM pushes
    try {
      await FirebaseMessaging.instance.subscribeToTopic('rider_notifications');
      debugPrint('✅ [RIDER] Subscribed to FCM topic: rider_notifications');
    } catch (e) {
      debugPrint('⚠️ [RIDER] Topic subscribe error: $e');
    }

    // Log FCM Token safely (catch network errors if device is offline)
    try {
      final token = await FirebaseMessaging.instance
          .getToken()
          .timeout(const Duration(seconds: 4));
      debugPrint('📱 FCM Token: $token');
    } catch (e) {
      debugPrint('FCM token retrieval notice (offline/play services): $e');
    }
  }

  // ── Order Category Helper ────────────────────────────────────────────────
  /// Derives the dominant order category from real item data.
  /// Uses actual FoodItem.category values — no fake data.
  static String deriveOrderCategory(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return 'general';
    final Map<String, int> counts = {};
    for (final item in items) {
      final cat = (item['category'] as String? ?? item['itemCategory'] as String? ?? '').toLowerCase().trim();
      // Fallback: try to infer from itemId prefix
      String key = cat;
      if (key.isEmpty) {
        final id = (item['itemId'] as String? ?? '').toLowerCase();
        if (id.startsWith('gr')) {
          key = 'grocery';
        } else if (id.startsWith('vg') || id.startsWith('fr')) {
          key = 'vegetables';
        } else if (id.startsWith('da')) {
          key = 'dairy';
        } else if (id.startsWith('em')) {
          key = 'eggs_meat';
        } else if (id.startsWith('cf') || id.startsWith('sw') || id.startsWith('sn')) {
          key = 'cooked_food';
        } else {
          key = 'general';
        }
      }
      counts[key] = (counts[key] ?? 0) + 1;
    }
    // Return most frequent category
    String dominant = 'general';
    int maxCount = 0;
    counts.forEach((k, v) {
      if (v > maxCount) { maxCount = v; dominant = k; }
    });
    // If mixed categories (more than 1 distinct), check if truly mixed
    if (counts.length > 1 && maxCount <= items.length / 2) {
      return 'mixed';
    }
    return dominant;
  }

  static String categoryDisplayLabel(String categoryKey) {
    switch (categoryKey.toLowerCase()) {
      case 'grocery': return 'GROCERY';
      case 'vegetables': return 'VEGETABLES';
      case 'fruits': return 'FRUITS';
      case 'dairy': return 'DAIRY';
      case 'eggs_meat': return 'EGGS & MEAT';
      case 'cooked_food': return 'COOKED FOOD';
      case 'non_veg': return 'NON-VEG';
      case 'sweets': return 'SWEETS';
      case 'snacks': return 'SNACKS';
      case 'mixed': return 'MIXED';
      default: return 'GENERAL';
    }
  }

  static String categoryIcon(String categoryKey) {
    switch (categoryKey.toLowerCase()) {
      case 'grocery': return '🛒';
      case 'vegetables': return '🥦';
      case 'fruits': return '🍎';
      case 'dairy': return '🥛';
      case 'eggs_meat': return '🥚';
      case 'cooked_food': return '🍛';
      case 'non_veg': return '🍗';
      case 'sweets': return '🍮';
      case 'snacks': return '🥙';
      case 'mixed': return '🍽️';
      default: return '📦';
    }
  }

  // ── Create Order in Firestore ────────────────────────────────────────────────
  /// Saves a complete order to Firestore including items, address, phone number.
  /// The Rider App listens to this collection in real-time via liveOrdersStream.
  static Future<String> createOrder({
    required String customerName,
    required String address,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    String customerPhone = '',
    String itemsSummary = '',
    String specialInstructions = '',
    String pincode = '',
    String locality = '',
    String? orderId,
    String? deliveryOtp,
  }) async {
    final finalOrderId = orderId ??
        'FM-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    // ── Derive real order category from actual item data ──────────────────
    final orderCategory = deriveOrderCategory(items);
    final orderCategoryLabel = categoryDisplayLabel(orderCategory);

    if (!_isFirebaseInitialized) {
      debugPrint('Firebase not initialized, skipping Firestore save');
      return finalOrderId;
    }

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(finalOrderId)
          .set({
        'orderId': finalOrderId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'address': address,
        'items': items,
        'itemsSummary': itemsSummary,
        'totalAmount': totalAmount,
        'specialInstructions': specialInstructions,
        'pincode': pincode,
        'locality': locality,
        'orderCategory': orderCategory,              // ✅ Real category key (e.g. grocery, cooked_food)
        'orderCategoryLabel': orderCategoryLabel,    // ✅ Display label (e.g. GROCERY)
        'status': 'Order Placed',
        'stage': 0,
        'riderId': null,
        'riderName': null,
        'deliveryOtp': deliveryOtp ?? _generateOtp(),
        'createdAt': FieldValue.serverTimestamp(),
        'isDeleted': false,
      });

      debugPrint('✅ Order $finalOrderId saved — category: $orderCategoryLabel');
      // Rider FCM push is sent by the BACKEND on /api/orders/place —
      // no client-side push needed (avoids duplicates).
    } catch (e) {
      debugPrint('Error saving order to Firestore: $e');
    }

    return finalOrderId;
  }

  // ── Live Customer Order Status Listener (for Customer App Notifications) ─────
  static final Set<String> _notifiedCustomerStages = {};
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _customerOrderSubscription;
  static String? _listeningPhone;

  /// Listens to active customer orders in Firestore and triggers push notification on customer device
  /// whenever rider accepts (stage 1), picks up (stage 2), or delivers (stage 3).
  /// Uses simple collection query (filtered in Dart) to prevent Firestore composite index errors.
  static void listenToCustomerOrderStatus(String phone) {
    if (!_isFirebaseInitialized || phone.isEmpty) return;
    if (_listeningPhone == phone && _customerOrderSubscription != null) {
      return; // Already listening for this phone number
    }

    _listeningPhone = phone;
    _customerOrderSubscription?.cancel();

    SharedPreferences.getInstance().then((prefs) {
      final list = prefs.getStringList('notifiedCustomerStages') ?? [];
      _notifiedCustomerStages.addAll(list);
      debugPrint('ℹ️ Loaded ${_notifiedCustomerStages.length} notified stages from SharedPreferences');

      // Setup Firestore listener AFTER loading persisted stages to prevent race conditions
      // ✅ Filter by phone on SERVER side — only downloads this customer's orders (much faster!)
      _customerOrderSubscription = FirebaseFirestore.instance
          .collection('orders')
          .where('customerPhone', isEqualTo: phone)
          .snapshots()
          .listen((snapshot) {
        bool hasNewNotifs = false;

        for (final doc in snapshot.docs) {
          final data = doc.data();

          final orderId = data['orderId'] as String? ?? doc.id;
          final stage = (data['stage'] as num?)?.toInt() ?? 0;

          // Always update app state in real-time
          FoodMelaState().updateOrderStatusStage(orderId, stage);

          if (stage <= 0) continue; // Filter active stages for push notifications

          final key = '$orderId::$stage';
          if (_notifiedCustomerStages.contains(key)) continue;
          _notifiedCustomerStages.add(key);
          hasNewNotifs = true;

          String title = '';
          String body = '';

          if (stage == 1) {
            final riderName = data['riderName'] as String? ?? 'Delivery Partner';
            title = '🛵 Order Accepted! #$orderId';
            body = '$riderName has accepted your order and is heading to restaurant! 👨‍🍳';
          } else if (stage == 2) {
            title = '🛵 Out for Delivery! #$orderId';
            body = 'Your food is picked up and on the way to your address! 📍';
          } else if (stage == 3) {
            title = '🎉 Order Delivered! #$orderId';
            body = 'Your food has been delivered. Enjoy your meal! 😋';
          }

          if (title.isNotEmpty) {
            _showLocalNotification(
              title: title,
              body: body,
              payload: 'orderId=$orderId',
            );
          }
        }

        if (hasNewNotifs) {
          prefs.setStringList('notifiedCustomerStages', _notifiedCustomerStages.toList());
        }
      }, onError: (e) {
        debugPrint('Customer order status listener notice: $e');
      });
    }).catchError((e) {
      debugPrint('Error loading persisted stages: $e');
    });
  }

  // ── Live Orders Stream (for Driver App) ─────────────────────────────────────
  /// Newest-first ordering is enforced DART-SIDE ([sortNewestFirst]) on every
  /// snapshot — the single source of truth for list order.
  /// The query ALSO requests `createdAt DESC` as a fast-path, but some order
  /// docs carry mixed `createdAt` shapes (Timestamp vs ISO string vs missing
  /// while serverTimestamp resolves). If Firestore rejects the orderBy, the
  /// dashboard falls back to [liveOrdersStreamUnordered] + the same Dart sort,
  /// so the list NEVER renders haphazard — worst case it costs one extra sort.
  /// Single collection stream, no where-filters → no composite index needed,
  /// orders appear INSTANTLY (<1s) via Firestore real-time listener.
  /// Vercel FCM push is backup for killed/background app; Firestore stream is primary for foreground.
  static Stream<QuerySnapshot<Map<String, dynamic>>>? get liveOrdersStream {
    if (!_isFirebaseInitialized) return null;
    return FirebaseFirestore.instance
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Fallback stream WITHOUT orderBy — used when the ordered query errors
  /// (mixed timestamp types). Dart-side [sortNewestFirst] still guarantees
  /// newest-first display.
  static Stream<QuerySnapshot<Map<String, dynamic>>>? get liveOrdersStreamUnordered {
    if (!_isFirebaseInitialized) return null;
    return FirebaseFirestore.instance.collection('orders').snapshots();
  }

  /// Real timestamp extractor — handles Firestore Timestamp, ISO string,
  /// millis int, seconds-double, or missing (missing sorts oldest).
  /// Checks `createdAt`, then `placedAt`, then `updatedAt`, then `timestamp`.
  static DateTime orderTimestamp(Map<String, dynamic> data) {
    DateTime? tryParse(dynamic v) {
      try {
        if (v is Timestamp) return v.toDate();
        if (v is String && v.isNotEmpty) {
          final parsed = DateTime.tryParse(v);
          if (parsed != null) return parsed;
          final asNum = num.tryParse(v);
          if (asNum != null) {
            return DateTime.fromMillisecondsSinceEpoch(
              asNum < 10000000000 ? (asNum * 1000).toInt() : asNum.toInt(),
            );
          }
        }
        if (v is num) {
          return DateTime.fromMillisecondsSinceEpoch(
            v < 10000000000 ? (v * 1000).toInt() : v.toInt(),
          );
        }
      } catch (_) {}
      return null;
    }

    for (final key in const ['createdAt', 'placedAt', 'updatedAt', 'timestamp']) {
      final parsed = tryParse(data[key]);
      if (parsed != null) return parsed;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Canonical order key — the stable identity used for dedup AND as the
  /// sort tiebreak (newer orderIds sort first when timestamps tie).
  static String orderKeyOf(Map<String, dynamic> data, String docId) {
    final oid = (data['orderId'] as String?)?.trim();
    return (oid != null && oid.isNotEmpty) ? oid : docId;
  }

  /// Local-state sort: newest first by real timestamp, tiebroken by order key
  /// so the sequence is STRICTLY deterministic — latest → oldest, always.
  /// Call after every realtime insert/update so the list stays consistent
  /// across refresh, reconnect, pagination, and returning to dashboard.
  static void sortNewestFirst<T>(List<T> docs, Map<String, dynamic> Function(T) dataOf, [String Function(T)? idOf]) {
    docs.sort((a, b) {
      final timeCmp = orderTimestamp(dataOf(b)).compareTo(orderTimestamp(dataOf(a)));
      if (timeCmp != 0) return timeCmp;
      final ka = idOf != null ? idOf(a) : '';
      final kb = idOf != null ? idOf(b) : '';
      return kb.compareTo(ka);
    });
  }

  /// Rider-scoped stream — only orders assigned to this rider (active + history).
  /// Use alongside [liveOrdersStream] if you want to reduce read volume.
  static Stream<QuerySnapshot<Map<String, dynamic>>>? riderOrdersStream(String riderId) {
    if (!_isFirebaseInitialized || riderId.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('orders')
        .where('riderId', isEqualTo: riderId)
        .where('isDeleted', isEqualTo: false)
        .snapshots();
  }

  // ── Update Order Status (Driver accepts) ────────────────────────────────────
  /// Enforces blocking + approval: blocked or unapproved partners cannot accept.
  static Future<bool> acceptOrder({
    required String orderId,
    required String riderName,
    required String riderId,
  }) async {
    if (!_isFirebaseInitialized) return false;
    // ── Enforce partner blocking/approval BEFORE transaction ─────────────────
    try {
      String? phoneToCheck;
      if (riderId.startsWith('FM-')) {
        final q = await FirebaseFirestore.instance.collection('users').where('partnerId', isEqualTo: riderId).limit(1).get();
        if (q.docs.isNotEmpty) phoneToCheck = q.docs.first.id;
      } else {
        phoneToCheck = riderId.replaceAll(RegExp(r'[^0-9]'), '');
      }
      if (phoneToCheck != null && phoneToCheck.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(phoneToCheck).get();
        if (userDoc.exists) {
          final ud = userDoc.data()!;
          if ((ud['accountStatus'] as String?) == 'blocked') {
            debugPrint('⛔ Blocked partner $riderId cannot accept orders');
            return false;
          }
          if ((ud['approvalStatus'] as String?) != 'approved' && (ud['role'] as String?) == 'delivery_partner') {
            debugPrint('⛔ Unapproved partner $riderId cannot accept orders');
            return false;
          }
        }
      }
    } catch (e) {
      debugPrint('Partner check notice: $e');
    }
    try {
      final docRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
      
      final success = await FirebaseFirestore.instance.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          return false;
        }

        final data = snapshot.data();
        if (data == null) {
          return false;
        }

        final existingRiderId = data['riderId'] as String?;
        final stage = (data['stage'] as num?)?.toInt() ?? 0;
        final status = data['status'] as String? ?? '';

        // If a rider is already assigned, or the order is not in stage 0 (pending), or cancelled
        if (existingRiderId != null || stage != 0 || status.toLowerCase().contains('cancel')) {
          return false; // Already claimed or cancelled
        }

        // Otherwise, claim the order
        transaction.update(docRef, {
          'stage': 1,
          'status': 'Order Accepted ✅',
          'riderName': riderName,
          'riderId': riderId,
          'acceptedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });

      return success;
    } catch (e) {
      debugPrint('Transaction error accepting order: $e');
      return false;
    }
  }

  static final Set<String> _notifiedOrderIds = {};

  /// Subscribe rider device to new order FCM topic (when online)
  static Future<void> subscribeToRiderNotifications() async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic('rider_notifications');
      debugPrint('✅ Subscribed rider to rider_notifications topic');
    } catch (e) {
      debugPrint('Error subscribing to rider_notifications topic: $e');
    }
  }

  /// Unsubscribe rider device from FCM topic (when offline)
  static Future<void> unsubscribeFromRiderNotifications() async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic('rider_notifications');
      debugPrint('🚫 Unsubscribed rider from rider_notifications topic');
    } catch (e) {
      debugPrint('Error unsubscribing from rider_notifications topic: $e');
    }
  }

  // ── Masked-call push hooks ───────────────────────────────────────────────────
  /// Subscribe to per-order call topic so incoming-call pushes arrive even
  /// when the app is in background. Call when entering an active order screen.
  static Future<void> subscribeToOrderCalls(String orderId) async {
    if (orderId.isEmpty) return;
    try {
      await FirebaseMessaging.instance.subscribeToTopic('calls_$orderId');
      debugPrint('✅ Subscribed to call topic: calls_$orderId');
    } catch (e) {
      debugPrint('call topic subscribe notice: $e');
    }
  }

  static Future<void> unsubscribeFromOrderCalls(String orderId) async {
    if (orderId.isEmpty) return;
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic('calls_$orderId');
    } catch (e) {
      debugPrint('call topic unsubscribe notice: $e');
    }
  }

  /// Save this device's FCM token on the order doc so the other party can
  /// push an incoming-call alert directly. Role is 'customer' or 'rider'.
  static Future<void> saveCallToken({
    required String orderId,
    required String role,
  }) async {
    try {
      final token = await FirebaseMessaging.instance
          .getToken()
          .timeout(const Duration(seconds: 4));
      if (token == null || token.isEmpty) return;
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        role == 'rider' ? 'riderFcmToken' : 'customerFcmToken': token,
      });
      debugPrint('✅ call token saved for $role on $orderId');
    } catch (e) {
      debugPrint('call token save notice: $e');
    }
  }

  /// Incoming-call push now goes via CallService → backend /api/calls/:id/ring
  /// (dead foodmela-notify service removed). Kept as no-op for callers.
  static void sendIncomingCallPush({
    required String orderId,
    required String callId,
    required String callerRole,
    String? receiverToken,
  }) {
    debugPrint('ℹ️ sendIncomingCallPush deprecated — CallService handles /ring directly');
  }

  // ── Notify Driver via Local Push ─────────────────────────────────────────────
  static Future<void> notifyDriverNewOrder({
    required String orderId,
    required String customerName,
    required String address,
    required double amount,
    String phone = '',
    String items = '',
    String orderCategoryLabel = '',
  }) async {
    if (_notifiedOrderIds.contains(orderId)) {
      debugPrint('ℹ️ Notification skipped (already shown): $orderId');
      return;
    }
    _notifiedOrderIds.add(orderId);
    debugPrint('🔔 Showing notification for new order: $orderId from $customerName — $orderCategoryLabel');
    final catPrefix = orderCategoryLabel.isNotEmpty ? 'New $orderCategoryLabel Order — ' : 'New Food Mela Order — ';
    await _showLocalNotification(
      title: '$catPrefix🛵 #$orderId',
      body: '${orderCategoryLabel.isNotEmpty ? "$orderCategoryLabel delivery" : "New order"} from ${customerName.isNotEmpty ? customerName : "Customer"} • ₹${amount.toInt()} — Tap to Accept or Reject',
      payload: newOrderPayload(
        orderId: orderId,
        customerName: customerName,
        address: address,
        amount: amount,
        phone: phone,
        items: items,
        categoryLabel: orderCategoryLabel,
      ),
      id: notificationIdForOrder(orderId),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  static String _generateOtp() {
    final now = DateTime.now();
    return ((now.minute + now.second + 1000) % 9000 + 1000).toString();
  }
}
