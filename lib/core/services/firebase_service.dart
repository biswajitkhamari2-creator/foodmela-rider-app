import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:food_track/core/state/food_mela_state.dart';

// ─── BACKGROUND MESSAGE HANDLER — RIDER APP ─────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final title = message.notification?.title ?? message.data['title'] ?? '🛵 New Order!';
  final body = message.notification?.body ?? message.data['body'] ?? 'A new order has arrived.';
  debugPrint('🔔 [RIDER BACKGROUND] New order: $title');
  await _showLocalNotification(title: title, body: body, payload: message.data.toString());
}

// ─── LOCAL NOTIFICATION HELPER ───────────────────────────────────────────────
final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

Future<void> _showLocalNotification({
  required String title,
  required String body,
  String? payload,
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
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
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
      },
    );

    // Create high-priority notification channel (required for Android 8+)
    const channel = AndroidNotificationChannel(
      'food_mela_orders',
      'Food Mela Orders',
      description: 'Live order notifications for Food Mela Delivery Partner',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
    );
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.createNotificationChannel(channel);
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
      // Rider MUST receive new_order pushes (background FCM → foreground delivery)
      if (dataType == 'new_order' || title.contains('New Order')) {
        final orderId = message.data['orderId'] as String? ?? '';
        if (orderId.isNotEmpty && _notifiedOrderIds.contains(orderId)) {
          debugPrint('ℹ️ [RIDER FCM] Duplicate FCM for $orderId — already notified via Firestore');
          return;
        }
        if (orderId.isNotEmpty) _notifiedOrderIds.add(orderId);
        _showLocalNotification(
          title: title.isNotEmpty ? title : '🛵 New Order!',
          body: body.isNotEmpty ? body : 'A new order has arrived — tap to view',
          payload: message.data.toString(),
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

    // App opened from terminated state via notification
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        debugPrint('App launched from terminated via notification: ${message.data}');
      }
    });

    // App resumed from background via notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification opened app from background: ${message.data}');
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

      _sendRiderNotificationViaVercel(
        orderId: finalOrderId,
        customerName: customerName,
        totalAmount: totalAmount,
        address: address,
        orderCategoryLabel: orderCategoryLabel,
      );
    } catch (e) {
      debugPrint('Error saving order to Firestore: $e');
    }

    return finalOrderId;
  }

  // ── Vercel Notification Trigger ──────────────────────────────────────────────
  /// Calls the free Vercel serverless function which sends FCM push to all riders.
  /// Fire-and-forget: does not block order creation if notification fails.
  static const String _vercelNotifyUrl =
      'https://foodmela-notify.vercel.app/api/notify';

  static void _sendRiderNotificationViaVercel({
    required String orderId,
    required String customerName,
    required double totalAmount,
    required String address,
    String orderCategoryLabel = '',
  }) {
    if (_vercelNotifyUrl == 'VERCEL_URL_PLACEHOLDER') return;
    Future(() async {
      try {
        final response = await http.post(
          Uri.parse(_vercelNotifyUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'orderId': orderId,
            'customerName': customerName,
            'totalAmount': totalAmount,
            'address': address,
            'orderCategory': orderCategoryLabel,
          }),
        ).timeout(const Duration(seconds: 5));
        debugPrint('🔔 Vercel notify response: ${response.statusCode}');
      } catch (e) {
        debugPrint('ℹ️ Vercel notify skipped (offline or not configured): $e');
      }
    });
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
  /// Newest-first at the QUERY level (createdAt DESC) + Dart-side re-sort.
  /// Real backend timestamp field: `createdAt` (serverTimestamp on create).
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

  /// Real timestamp extractor — handles Firestore Timestamp, ISO string,
  /// millis int, or missing (missing sorts oldest).
  static DateTime orderTimestamp(Map<String, dynamic> data) {
    try {
      final v = data['createdAt'];
      if (v is Timestamp) return v.toDate();
      if (v is String && v.isNotEmpty) return DateTime.parse(v);
      if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
      final fallback = data['placedAt'];
      if (fallback is String && fallback.isNotEmpty) return DateTime.parse(fallback);
    } catch (_) {}
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Local-state sort: newest first by real `createdAt`. Call after every
  /// realtime insert/update so the list stays consistent across refresh,
  /// reconnect, pagination, and returning to dashboard.
  static void sortNewestFirst<T>(List<T> docs, Map<String, dynamic> Function(T) dataOf) {
    docs.sort((a, b) => orderTimestamp(dataOf(b)).compareTo(orderTimestamp(dataOf(a))));
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
      payload: 'orderId=$orderId&phone=$phone',
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  static String _generateOtp() {
    final now = DateTime.now();
    return ((now.minute + now.second + 1000) % 9000 + 1000).toString();
  }
}
