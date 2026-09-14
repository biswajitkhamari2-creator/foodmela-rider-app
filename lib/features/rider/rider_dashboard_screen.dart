import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:food_track/core/theme/food_melaa_colors.dart';
import 'package:food_track/core/services/firebase_service.dart';
import 'package:food_track/core/services/incoming_order_call.dart';
import 'package:food_track/core/services/native_order_alert.dart';
import 'package:food_track/core/services/order_ringtone_service.dart';
import 'package:food_track/core/services/rider_auth_service.dart';
import 'package:food_track/features/calling/call_launcher.dart';
import 'package:food_track/features/calling/call_models.dart';
import 'package:food_track/features/calling/call_service.dart';
import 'package:food_track/features/calling/incoming_call_screen.dart';
import 'package:food_track/features/rider/active_delivery_screen.dart';
import 'package:food_track/features/rider/incoming_order_screen.dart';
import 'package:food_track/features/rider/order_permission_setup_dialog.dart';
import 'package:food_track/features/rider/rider_login_screen.dart';

// ─── Category helpers (mirrors FirebaseService helpers) ─────────────────────
String _catLabel(String key) {
  switch (key.toLowerCase()) {
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

String _catIcon(String key) {
  switch (key.toLowerCase()) {
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

class RiderDashboardScreen extends StatefulWidget {
  final Map<String, dynamic>? riderData;
  const RiderDashboardScreen({super.key, this.riderData});

  @override
  State<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen>
    with WidgetsBindingObserver {
  final Set<String> _notifiedOrderIds = {};
  final Set<String> _rejectedOrderIds = {}; // Local reject — hides card until refresh
  final Set<String> _acceptingOrderIds = {}; // Prevent double-tap

  /// Persisted notified IDs — survives restarts so old orders NEVER re-ring.
  /// Pruned to recent 200 to bound storage.
  Future<void> _loadNotifiedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('rider_notified_orders') ?? [];
      _notifiedOrderIds.addAll(saved);
      // Also restore claimed (accepted-but-echo-pending across restart)
      final claimed = prefs.getStringList('rider_claimed_orders') ?? [];
      _claimedOrderIds.addAll(claimed);
    } catch (_) {}
  }

  Future<void> _saveNotifiedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final n = _notifiedOrderIds.toList();
      await prefs.setStringList(
          'rider_notified_orders', n.length > 200 ? n.sublist(n.length - 200) : n);
      final c = _claimedOrderIds.toList();
      await prefs.setStringList(
          'rider_claimed_orders', c.length > 200 ? c.sublist(c.length - 200) : c);
    } catch (_) {}
  }
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ordersSub;
  bool _isOnline = true;
  // ── Global incoming-call listening (rider side) ──────────────────────────
  // Dashboard watches MY active deliveries for ringing invites, so the call
  // rings even when ActiveDeliveryScreen isn't open. One sub per order.
  final Map<String, StreamSubscription<List<CallInvite>>> _callSubs = {};
  final Set<String> _shownCallIds = {};

  String get _riderName => widget.riderData?['name'] as String? ?? 'Delivery Partner';
  String get _riderPartnerId => widget.riderData?['partnerId'] as String? ?? '';
  String get _riderPhone => widget.riderData?['phone'] as String? ?? '';
  String get _riderEmail => widget.riderData?['email'] as String? ?? '';
  String get _riderId => _riderPartnerId.isNotEmpty ? _riderPartnerId : (_riderPhone.isNotEmpty ? _riderPhone : 'rider');

  /// True once the OS confirms full-screen alerts are allowed. Starts false
  /// so the banner shows; set true when granted (banner hides itself).
  bool _fullScreenGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadNotifiedIds();
    _attachOrdersListenerWithRetry();
    // Re-subscribe to FCM topic on every dashboard init (covers re-login after logout)
    FirebaseService.subscribeToRiderNotifications();
    _refreshFullScreenState();
    // Permission is MUST for all riders (new + existing): if not granted,
    // ask upfront on every dashboard open until granted — new orders ring
    // like a WhatsApp call only with this ON.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _askFullScreenPermissionMust();
    });
  }

  /// Mandatory full-screen permission prompt for EVERY rider. Shows on each
  /// dashboard open until granted. UNCONDITIONAL — the native check returns
  /// true even while the OS still blocks full-screen, so never gate on it.
  /// ALLOW opens the exact Settings page; LATER keeps the yellow banner.
  /// Skipped only when the rider granted in THIS session (no nagging).
  bool _askedMustThisSession = false;
  Future<void> _askFullScreenPermissionMust() async {
    if (!mounted || _askedMustThisSession) return;
    _askedMustThisSession = true;
    await OrderPermissionSetupDialog.checkAndPrompt(context);
    if (mounted) {
      _refreshFullScreenState();
    }
  }

  /// Re-check every time the app returns to foreground — covers the user
  /// granting the permission in Settings after tapping ENABLE.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshFullScreenState();
    }
  }

  Future<void> _refreshFullScreenState() async {
    try {
      final allowed = await NativeOrderAlert.canUseFullScreenIntent();
      if (mounted && allowed != _fullScreenGranted) {
        setState(() => _fullScreenGranted = allowed);
      }
    } catch (_) {}
  }

  /// ENABLE tap: open the exact Settings page, then verify on return. When
  /// granted, fire one REAL full-screen test alert so the rider sees proof
  /// it works — and tapping / dismissing it proves the tone stops too.
  Future<void> _onEnableTap() async {
    await NativeOrderAlert.openFullScreenIntentSettings();
    // Poll for the grant for ~10s after returning (user may take a moment
    // in Settings). On grant: hide banner + fire the proof test alert.
    for (var i = 0; i < 10; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      bool allowed = false;
      try {
        allowed = await NativeOrderAlert.canUseFullScreenIntent();
      } catch (_) {}
      if (allowed) {
        if (mounted) setState(() => _fullScreenGranted = true);
        await FirebaseService.showFullScreenTestAlert();
        return;
      }
    }
    if (mounted) await _refreshFullScreenState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ordersSub?.cancel();
    for (final s in _callSubs.values) {
      s.cancel();
    }
    _callSubs.clear();
    OrderRingtoneService.stopAll();
    super.dispose();
  }

  /// Watch my active deliveries for incoming customer calls.
  /// Called on every orders snapshot — adds subs for new actives, drops finished.
  void _syncCallListening(List<QueryDocumentSnapshot<Map<String, dynamic>>> activeDocs) {
    final myActives = <String>{};
    for (final doc in activeDocs) {
      final data = doc.data();
      final orderId = data['orderId'] as String? ?? doc.id;
      final riderId = data['riderId'] as String?;
      if (riderId == _riderId) myActives.add(orderId);
    }
    // Drop subs for orders no longer mine
    for (final id in _callSubs.keys.toList()) {
      if (!myActives.contains(id)) {
        _callSubs.remove(id)?.cancel();
      }
    }
    // Add subs for new actives
    for (final orderId in myActives) {
      if (_callSubs.containsKey(orderId)) continue;
      _callSubs[orderId] = CallService.instance
          .incomingCallStream(orderId: orderId, myId: _riderId)
          .listen((invites) => _onCallInvites(orderId, invites));
    }
  }

  void _onCallInvites(String orderId, List<CallInvite> invites) {
    if (!mounted || !_isOnline) return;
    final fresh = invites.where((i) =>
        i.status == CallStatus.ringing &&
        !_shownCallIds.contains(i.callId) &&
        DateTime.now().difference(i.createdAt).inSeconds < 60);
    for (final invite in fresh) {
      _shownCallIds.add(invite.callId);
      OrderRingtoneService.startRinging('call_$orderId');
      if (!mounted) return;
      Navigator.of(context)
          .push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => IncomingCallScreen(
          orderId: invite.orderId,
          callerLabel: invite.callerLabel,
          onAccept: () {
            Navigator.of(context).pop();
            OrderRingtoneService.stopRinging('call_$orderId');
            CallLauncher.answerCall(
              context: context,
              invite: invite,
              myId: _riderId,
              myRole: 'rider',
            );
          },
          onDecline: () {
            Navigator.of(context).pop();
            OrderRingtoneService.stopRinging('call_$orderId');
            CallLauncher.declineCall(invite);
          },
        ),
      ))
          .then((_) => OrderRingtoneService.stopRinging('call_$orderId'));
    }
  }

  Future<void> _attachOrdersListenerWithRetry() async {
    for (int attempt = 1; attempt <= 10; attempt++) {
      final stream = FirebaseService.liveOrdersStream;
      if (stream != null) {
        _ordersSub = stream.listen(
          _handleOrdersSnapshot,
          onError: (e) {
            debugPrint('❌ [RIDER] Firestore orders listener error: $e');
            // Auth expired or permission denied — rider needs to re-login
            if (e.toString().contains('permission-denied') || e.toString().contains('unauthenticated')) {
              debugPrint('⚠️ [RIDER] Auth expired — redirecting to login');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Session expired — please login again', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white)), backgroundColor: FoodMelaaColors.error),
                );
              }
            }
          },
        );
        debugPrint('✅ [RIDER] Firestore orders listener attached (attempt $attempt)');
        return;
      }
      debugPrint('⏳ [RIDER] Firestore not ready, retry $attempt/10');
      await Future.delayed(const Duration(milliseconds: 500));
    }
    debugPrint('❌ [RIDER] Failed to attach Firestore listener after 10 attempts');
  }

  void _toggleOnlineStatus(bool online) {
    setState(() {
      _isOnline = online;
      if (online) {
        FirebaseService.subscribeToRiderNotifications();
      } else {
        FirebaseService.unsubscribeFromRiderNotifications();
        // Going offline silences ringing + closes incoming screens
        OrderRingtoneService.stopAll();
        for (final id in _incomingRoutes.keys.toList()) {
          _dismissIncomingOrderScreen(id);
        }
      }
    });
  }

  /// Orders older than this never ring — they were placed while this rider
  /// was offline. Only FRESH orders (just placed) trigger sound + full screen.
  static const Duration _freshOrderWindow = Duration(minutes: 30);

  DateTime _orderTime(Map<String, dynamic> data) {
    try {
      final v = data['createdAt'];
      if (v is Timestamp) return v.toDate();
      if (v is String && v.isNotEmpty) return DateTime.parse(v);
      if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
      final fb = data['placedAt'];
      if (fb is String && fb.isNotEmpty) return DateTime.parse(fb);
    } catch (_) {}
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _handleOrdersSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (!_isOnline) return;
    // Fresh orders ring INSTANTLY (<1s via Firestore stream). Stale orders
    // (placed while rider was offline) show silently in the list — no sound,
    // no full-screen popup, no duplicates. Notified IDs persist in
    // FirebaseService prefs so restarts can't re-ring either.
    final stillPending = <String>{};
    final now = DateTime.now();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final orderId = data['orderId'] as String? ?? doc.id;
      final stage = (data['stage'] as num?)?.toInt() ?? 0;
      final isDeleted = data['isDeleted'] as bool? ?? false;
      final riderId = data['riderId'] as String?;
      final status = (data['status'] as String? ?? '').toLowerCase();
      // Locally claimed/rejected by ME — never ring again, even before
      // the Firestore write echoes back (kills the re-ring loop).
      if (_claimedOrderIds.contains(orderId) || _rejectedOrderIds.contains(orderId)) {
        continue;
      }
      final available = stage == 0 &&
          !isDeleted &&
          (riderId == null || riderId.isEmpty) &&
          !status.contains('cancel');
      if (available) stillPending.add(orderId);
      // Stale = placed >30 min ago (rider was offline then) → list only, silent
      final isFresh = now.difference(_orderTime(data)) < _freshOrderWindow;
      if (!isFresh) continue;
      if (available && !_notifiedOrderIds.contains(orderId) && !_rejectedOrderIds.contains(orderId) && !IncomingOrderCall.isShown(orderId)) {
        _notifiedOrderIds.add(orderId);
        IncomingOrderCall.markShown(orderId);
        _saveNotifiedIds();
        final items = data['itemsSummary'] as String? ?? _buildItemsSummary(data['items']);
        final catLabel = data['orderCategoryLabel'] as String? ?? _catLabel(data['orderCategory'] as String? ?? 'general');
        debugPrint('🔔 [RIDER] INSTANT notify for $orderId — $catLabel');
        FirebaseService.notifyDriverNewOrder(
          orderId: orderId,
          customerName: data['customerName'] as String? ?? 'Customer',
          address: data['address'] as String? ?? 'Address not set',
          amount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
          phone: data['customerPhone'] as String? ?? '',
          items: items,
          orderCategoryLabel: catLabel,
        );
        // Call-style ringing + full-screen alert until someone accepts
        NativeOrderAlert.bringAppToForeground();
        OrderRingtoneService.startRinging(orderId);
        _showIncomingOrderScreen(
          orderId: orderId,
          customerName: data['customerName'] as String? ?? 'Customer',
          address: data['address'] as String? ?? 'Address not set',
          totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
          itemsSummary: items,
          categoryLabel: catLabel,
          customerPhone: data['customerPhone'] as String? ?? '',
        );
      }
    }
    // Silence orders that are no longer available (accepted / cancelled /
    // claimed) — ringtone stops, call screen closes, AND the tray
    // notification vanishes. If the rider was LOOKING at the call screen,
    // say WHY it vanished instead of cutting it silently.
    final docsById = <String, Map<String, dynamic>>{};
    for (final doc in snapshot.docs) {
      final d = doc.data();
      docsById[(d['orderId'] as String? ?? doc.id)] = d;
    }
    for (final ringingId in OrderRingtoneService.ringingOrderIds) {
      if (!stillPending.contains(ringingId)) {
        final d = docsById[ringingId];
        final claimer = d?['riderId'] as String?;
        final status = (d?['status'] as String? ?? '').toLowerCase();
        final gone = d == null ||
            (d['isDeleted'] as bool? ?? false) ||
            status.contains('cancel');
        final mine =
            claimer != null && claimer.isNotEmpty && claimer == _riderId;
        final takenByOther =
            claimer != null && claimer.isNotEmpty && !mine;
        final wasViewing = _incomingRoutes.containsKey(ringingId) ||
            IncomingOrderCall.isShown(ringingId);
        OrderRingtoneService.stopRinging(ringingId);
        FirebaseService.dismissOrderNotification(ringingId);
        _dismissIncomingOrderScreen(ringingId);
        if (mounted && wasViewing && !mine) {
          final msg = gone
              ? 'Order $ringingId was cancelled by the customer'
              : takenByOther
                  ? 'Order $ringingId was just taken by another rider'
                  : 'Order $ringingId is no longer available';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: FoodMelaaColors.textDark,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              content: Text(msg,
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  // ── Incoming-order full screen (one per order, tracked by route) ────────────
  final Map<String, Route<void>> _incomingRoutes = {};

  void _showIncomingOrderScreen({
    required String orderId,
    required String customerName,
    required String address,
    required double totalAmount,
    required String itemsSummary,
    required String categoryLabel,
    required String customerPhone,
  }) {
    NativeOrderAlert.bringAppToForeground();
    if (!mounted || _incomingRoutes.containsKey(orderId)) return;
    final route = MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => IncomingOrderScreen(
        orderId: orderId,
        customerName: customerName,
        customerPhone: customerPhone,
        address: address,
        totalAmount: totalAmount,
        itemsSummary: itemsSummary,
        categoryLabel: categoryLabel,
        onAccept: () {
          _dismissIncomingOrderScreen(orderId);
          _acceptOrder(orderId, customerName, customerPhone, address,
              itemsSummary, totalAmount);
        },
        onDecline: () {
          _dismissIncomingOrderScreen(orderId);
          _rejectOrder(orderId);
        },
        // VIEW ORDER: keep ringing, show the existing order card bottom-sheet
        // on top of the call screen (same UI as tapping the dashboard card).
        onViewOrder: () => _showViewOrderSheet(
          orderId: orderId,
          customerName: customerName,
          customerPhone: customerPhone,
          address: address,
          totalAmount: totalAmount,
          itemsSummary: itemsSummary,
          categoryLabel: categoryLabel,
        ),
      ),
    );
    _incomingRoutes[orderId] = route;
    IncomingOrderCall.trackRoute(orderId, route);
    Navigator.of(context).push(route).then((_) {
      _incomingRoutes.remove(orderId);
      IncomingOrderCall.untrackRoute(orderId);
    });
  }

  void _dismissIncomingOrderScreen(String orderId) {
    final route = _incomingRoutes.remove(orderId);
    IncomingOrderCall.dismiss(orderId);
    OrderRingtoneService.stopRinging(orderId);
    if (route == null) return;
    final nav = route.navigator;
    if (nav == null) return;
    try {
      nav.removeRoute(route);
    } catch (_) {
      // Already popped (e.g. user pressed back) — nothing to do
    }
  }

  /// VIEW ORDER from the incoming call screen: read-only detail sheet over
  /// the ringing call UI. Ringing continues — the rider still accepts or
  /// rejects from the call screen underneath. Uses the same receipt layout
  /// as tapping a dashboard order card (no duplicate order logic).
  void _showViewOrderSheet({
    required String orderId,
    required String customerName,
    required String customerPhone,
    required String address,
    required double totalAmount,
    required String itemsSummary,
    required String categoryLabel,
  }) {
    if (!mounted) return;
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
                        color: FoodMelaaColors.borderGrey,
                        borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: FoodMelaaColors.riderPrimaryLight,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.receipt_long_rounded,
                      color: FoodMelaaColors.riderPrimary, size: 20)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Order #$orderId',
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: FoodMelaaColors.textDark)),
                    Text(categoryLabel.isNotEmpty ? categoryLabel : 'NEW ORDER',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: FoodMelaaColors.textSecondary)),
                  ])),
            ]),
            const SizedBox(height: 16),
            _receiptRow('Customer', customerName),
            _receiptRow('Phone',
                customerPhone.isNotEmpty ? customerPhone : 'N/A'),
            _receiptRow('Address', address),
            _receiptRow('Items',
                itemsSummary.isNotEmpty ? itemsSummary : 'See details'),
            _receiptRow('Total', '₹${totalAmount.toInt()} (online)'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(sheetContext),
                style: ElevatedButton.styleFrom(
                    backgroundColor: FoodMelaaColors.riderPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: Text('Back to Accept / Reject',
                    style: GoogleFonts.poppins(
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

  String _buildItemsSummary(dynamic items) {
    if (items == null) {
      return 'Items not listed';
    }
    try {
      if (items is List) {
        return items.map((item) => '${item['quantity'] ?? 1}x ${item['itemId'] ?? ''}').join(', ');
      }
      return items.toString();
    } catch (_) {
      return 'See order details';
    }
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) {
      return 'Date N/A';
    }
    try {
      DateTime dt;
      if (timestamp is Timestamp) {
        dt = timestamp.toDate();
      } else if (timestamp is String) {
        dt = DateTime.parse(timestamp);
      } else {
        return 'Date N/A';
      }
      final dateStr = '${dt.day}/${dt.month}/${dt.year}';
      final hourStr = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minStr = dt.minute.toString().padLeft(2, '0');
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$dateStr at $hourStr:$minStr $amPm';
    } catch (_) { return 'Date N/A'; }
  }

  // ── Reject: local hide (no backend write — order stays available for other riders)
  void _rejectOrder(String orderId) {
    OrderRingtoneService.stopRinging(orderId);
    FirebaseService.dismissOrderNotification(orderId);
    _dismissIncomingOrderScreen(orderId);
    setState(() => _rejectedOrderIds.add(orderId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: FoodMelaaColors.textDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(children: [const Icon(Icons.block_rounded, color: Colors.white, size: 16), const SizedBox(width: 8), Text('Order declined — hidden from your view', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white))]),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Accept: backend transaction + loading + race-condition safe ──
  // Single-tap guarantee: claimed orders are remembered locally so the same
  // order NEVER rings again, even if the Firestore write takes time to echo.
  final Set<String> _claimedOrderIds = {};
  Future<void> _acceptOrder(String orderId, String customerName, String customerPhone, String address, String itemsSummary, double totalAmount, {double? deliveryLat, double? deliveryLng}) async {
    if (_acceptingOrderIds.contains(orderId) || _claimedOrderIds.contains(orderId)) return; // Prevent double-tap
    OrderRingtoneService.stopRinging(orderId);
    FirebaseService.dismissOrderNotification(orderId);
    _dismissIncomingOrderScreen(orderId);
    setState(() => _acceptingOrderIds.add(orderId));
    // Show instant feedback — blocking loader so one tap is enough
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PopScope(
          canPop: false,
          child: Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
        ),
      );
    }
    try {
      final success = await FirebaseService.acceptOrder(orderId: orderId, riderName: _riderName, riderId: _riderId);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // close loader
      setState(() => _acceptingOrderIds.remove(orderId));
      if (success) {
        // Remember claim locally — snapshot echo delay can't re-ring this order
        _claimedOrderIds.add(orderId);
        _notifiedOrderIds.add(orderId);
        _saveNotifiedIds();
        Navigator.push(context, MaterialPageRoute(builder: (_) => ActiveDeliveryScreen(orderId: orderId, customerName: customerName, customerPhone: customerPhone, address: address, itemsSummary: itemsSummary, totalAmount: totalAmount, deliveryLat: deliveryLat, deliveryLng: deliveryLng, riderId: _riderId)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: const Color(0xFFD97706), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), content: Row(children: [const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18), const SizedBox(width: 8), Expanded(child: Text('Order already taken by another rider', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white))) ])),
        );
      }
    } catch (e) {
      if (mounted) {
        try { Navigator.of(context, rootNavigator: true).pop(); } catch (_) {} // close loader
        setState(() => _acceptingOrderIds.remove(orderId));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: FoodMelaaColors.error, content: Text('Accept failed — check internet & try again', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white))));
      }
    }
  }

  void _showRiderProfileModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: FoodMelaaColors.borderGrey, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 16),
            // Premium header — avatar on RIGHT
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_riderName, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: FoodMelaaColors.textDark)),
                      const SizedBox(height: 4),
                      _profileRow(Icons.badge_rounded, 'Partner ID', _riderPartnerId.isNotEmpty ? _riderPartnerId : '—'),
                      const SizedBox(height: 4),
                      _profileRow(Icons.phone_rounded, 'Phone', _riderPhone.isNotEmpty ? _riderPhone : '—'),
                      const SizedBox(height: 4),
                      _profileRow(Icons.email_rounded, 'Email', _riderEmail.isNotEmpty ? _riderEmail : '—'),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF047857), Color(0xFF10B981)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: const Icon(Icons.person_rounded, size: 36, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: FoodMelaaColors.borderLight),
            const SizedBox(height: 16),
            _profileStatusRow('Account Status', 'Verified Partner', const Color(0xFF10B981)),
            const SizedBox(height: 10),
            _profileStatusRow('Availability', _isOnline ? 'Online — Receiving orders' : 'Offline — Not receiving orders', _isOnline ? const Color(0xFF10B981) : FoodMelaaColors.error),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () async {
                  try { await FirebaseService.unsubscribeFromRiderNotifications(); } catch (_) {}
                  try { await _ordersSub?.cancel(); } catch (_) {}
                  try { await RiderAuthService.instance.logout(); } catch (_) {}
                  if (context.mounted) {
                    Navigator.pop(context);
                    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const RiderLoginScreen()), (route) => false);
                  }
                },
                icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 18),
                label: Text('Log Out', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: FoodMelaaColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileRow(IconData icon, String label, String value) {
    return Row(children: [Icon(icon, size: 13, color: FoodMelaaColors.textGrey), const SizedBox(width: 6), Text('$label: ', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: FoodMelaaColors.textSecondary)), Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: FoodMelaaColors.textDark), overflow: TextOverflow.ellipsis))]);
  }

  Widget _profileStatusRow(String label, String value, Color color) {
    return Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 8), Text('$label: ', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: FoodMelaaColors.textSecondary)), Expanded(child: Text(value, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: color)))]);
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: FoodMelaaColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: FoodMelaaColors.riderPrimaryLight, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.delivery_dining_rounded, color: FoodMelaaColors.riderPrimary, size: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_greeting()}, ${_riderName.split(' ').first}', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: FoodMelaaColors.textDark), overflow: TextOverflow.ellipsis),
                    Text(_riderPartnerId.isNotEmpty ? _riderPartnerId : 'Food Mela Delivery', style: GoogleFonts.inter(fontSize: 11, color: FoodMelaaColors.textSecondary), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            GestureDetector(
              onTap: () => _showRiderProfileModal(context),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                width: 36,
                height: 36,
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF047857), Color(0xFF10B981)]), shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))]),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _isOnline ? FoodMelaaColors.riderPrimaryLight : const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(20), border: Border.all(color: _isOnline ? const Color(0xFF10B981).withValues(alpha: 0.3) : FoodMelaaColors.error.withValues(alpha: 0.2))),
              child: Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: _isOnline ? const Color(0xFF10B981) : FoodMelaaColors.error, shape: BoxShape.circle, boxShadow: [BoxShadow(color: (_isOnline ? const Color(0xFF10B981) : FoodMelaaColors.error).withValues(alpha: 0.4), blurRadius: 6, spreadRadius: 1)])),
                  const SizedBox(width: 6),
                  Text(_isOnline ? 'ONLINE' : 'OFFLINE', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: _isOnline ? FoodMelaaColors.riderPrimary : FoodMelaaColors.error)),
                  const SizedBox(width: 4),
                  Switch(value: _isOnline, activeThumbColor: FoodMelaaColors.riderPrimary, activeTrackColor: Colors.white, inactiveThumbColor: FoodMelaaColors.textGrey, inactiveTrackColor: Colors.white, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, onChanged: (val) => _toggleOnlineStatus(val)),
                ],
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              decoration: BoxDecoration(color: FoodMelaaColors.background, borderRadius: BorderRadius.circular(14)),
              child: TabBar(
                indicator: BoxDecoration(color: FoodMelaaColors.riderPrimary, borderRadius: BorderRadius.circular(12)),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: FoodMelaaColors.textSecondary,
                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12.5),
                unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12.5),
                tabs: const [Tab(text: 'Active'), Tab(text: 'History'), Tab(text: 'Cancelled')],
              ),
            ),
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseService.liveOrdersStream,
          builder: (context, snapshot) {
            final allDocs = snapshot.data?.docs ?? [];
            // ── Dedup by real unique Order ID (doc may repeat across snapshots) ──
            final seen = <String>{};
            final uniqueDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            for (final doc in allDocs) {
              final key = (doc.data()['orderId'] as String?)?.trim().isNotEmpty == true
                  ? (doc.data()['orderId'] as String).trim()
                  : doc.id;
              if (seen.add(key)) uniqueDocs.add(doc);
            }
            // ── Local-state sort: newest real `createdAt` FIRST ──
            FirebaseService.sortNewestFirst(uniqueDocs, (d) => d.data());
            final pendingDocs = uniqueDocs.where((doc) {
              final d = doc.data();
              final stage = (d['stage'] as num?)?.toInt() ?? 0;
              final isDeleted = d['isDeleted'] as bool? ?? false;
              final docId = d['orderId'] as String? ?? doc.id;
              // New Orders → ONLY genuinely available: stage 0, not deleted,
              // no rider assigned yet, status not cancelled
              final riderId = d['riderId'] as String?;
              final status = (d['status'] as String? ?? '').toLowerCase();
              return stage == 0 &&
                  !isDeleted &&
                  (riderId == null || riderId.isEmpty) &&
                  !status.contains('cancel') &&
                  !_rejectedOrderIds.contains(docId);
            }).toList();
            final activeDocs = uniqueDocs.where((doc) {
              final d = doc.data();
              final stage = (d['stage'] as num?)?.toInt() ?? 0;
              final isDeleted = d['isDeleted'] as bool? ?? false;
              final riderId = d['riderId'] as String?;
              return (stage == 1 || stage == 2) && riderId == _riderId && !isDeleted;
            }).toList();
            // ── Global incoming-call watch: ring even if delivery screen closed ──
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _syncCallListening(activeDocs);
            });
            final completedDocs = uniqueDocs.where((doc) {
              final d = doc.data();
              final stage = (d['stage'] as num?)?.toInt() ?? 0;
              final riderId = d['riderId'] as String?;
              final status = (d['status'] as String? ?? '').toLowerCase();
              // Completed = ONLY stage 3 and NOT cancelled
              return stage == 3 && riderId == _riderId && !status.contains('cancel');
            }).toList();
            // ── CANCELLED: stage == -1 OR status contains cancel, assigned to this rider ──
            final cancelledForRider = uniqueDocs.where((doc) {
              final d = doc.data();
              final stage = (d['stage'] as num?)?.toInt() ?? 0;
              final status = (d['status'] as String? ?? '').toLowerCase();
              final riderId = d['riderId'] as String?;
              return (stage == -1 || status.contains('cancel')) && riderId == _riderId;
            }).toList();
            // ── EARNINGS: ONLY after successful DELIVERY (stage == 3) ──────────
            final earnedDocs = uniqueDocs.where((doc) {
              final d = doc.data();
              final stage = (d['stage'] as num?)?.toInt() ?? 0;
              final riderId = d['riderId'] as String?;
              final isDeleted = d['isDeleted'] as bool? ?? false;
              final status = d['status'] as String? ?? '';
              return stage == 3 && riderId == _riderId && !isDeleted && !status.toLowerCase().contains('cancel');
            }).toList();
            final totalEarnings = earnedDocs.length * 40.0;

            return Column(
              children: [
                // Full-screen permission banner — visible until the OS
                // confirms the grant. ENABLE opens Settings, then fires a
                // real test alert as proof (tone stops on tap/dismiss).
                if (!_fullScreenGranted)
                  GestureDetector(
                    onTap: _onEnableTap,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFFF59E0B)
                                .withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.phone_in_talk_rounded,
                              color: Color(0xFFB45309), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Enable incoming-call alerts',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF92400E))),
                                Text(
                                    'Tap to allow full-screen order alerts — otherwise orders arrive as notifications only',
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: const Color(0xFF92400E))),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                                color: const Color(0xFFB45309),
                                borderRadius: BorderRadius.circular(10)),
                            child: Text('ENABLE',
                                style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Stats banner — premium
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: FoodMelaaColors.borderLight), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))]),
                  child: Row(
                    children: [
                      Expanded(child: _statCard('DELIVERED', '${earnedDocs.length} Orders', Icons.check_circle_rounded, FoodMelaaColors.riderPrimary, FoodMelaaColors.riderPrimaryLight)),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard('EARNINGS', '₹${totalEarnings.toInt()}', Icons.account_balance_wallet_rounded, const Color(0xFFD97706), const Color(0xFFFFFBEB))),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildActiveTab(context, activeDocs, pendingDocs),
                      _buildHistoryTab(context, completedDocs),
                      _buildCancelledTab(context, cancelledForRider),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.15))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.6)),
          const SizedBox(height: 6),
          Row(children: [Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 12)), const SizedBox(width: 8), Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: FoodMelaaColors.textDark))]),
        ],
      ),
    );
  }

  // ── ACTIVE TAB ─────────────────────────────────────────────────────────
  Widget _buildActiveTab(BuildContext context, List<QueryDocumentSnapshot<Map<String, dynamic>>> activeDocs, List<QueryDocumentSnapshot<Map<String, dynamic>>> pendingDocs) {
    if (!_isOnline) return _buildOfflineView();
    if (activeDocs.isEmpty && pendingDocs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: FoodMelaaColors.borderLight), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))]), child: const Icon(Icons.notifications_none_rounded, size: 36, color: FoodMelaaColors.textGrey)),
              const SizedBox(height: 16),
              Text('No new delivery requests', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: FoodMelaaColors.textDark)),
              const SizedBox(height: 6),
              Text('You will be notified when a new\norder arrives — even if phone is locked', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: FoodMelaaColors.textSecondary, height: 1.5)),
            ],
          ),
        ),
      );
    }
    final children = <Widget>[];
    if (activeDocs.isNotEmpty) {
      children.add(Padding(padding: const EdgeInsets.only(top: 16, bottom: 8), child: Row(children: [Container(width: 3, height: 14, decoration: BoxDecoration(color: const Color(0xFFD97706), borderRadius: BorderRadius.circular(3))), const SizedBox(width: 8), Text('MY ACTIVE DELIVERIES', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: FoodMelaaColors.textSecondary, letterSpacing: 0.8)), const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFD97706), borderRadius: BorderRadius.circular(8)), child: Text('${activeDocs.length}', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)))])));
      for (final doc in activeDocs) {
        children.add(_buildPremiumOrderCard(context, doc.data(), doc.id, isActiveDelivery: true));
      }
    }
    if (pendingDocs.isNotEmpty) {
      children.add(Padding(padding: const EdgeInsets.only(top: 16, bottom: 8), child: Row(children: [Container(width: 3, height: 14, decoration: BoxDecoration(color: FoodMelaaColors.riderPrimary, borderRadius: BorderRadius.circular(3))), const SizedBox(width: 8), Text('NEW ORDERS', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: FoodMelaaColors.textSecondary, letterSpacing: 0.8)), const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: FoodMelaaColors.riderPrimary, borderRadius: BorderRadius.circular(8)), child: Text('${pendingDocs.length}', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)))])));
      for (final doc in pendingDocs) {
        children.add(_buildPremiumOrderCard(context, doc.data(), doc.id, isActiveDelivery: false));
      }
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: children);
  }

  Widget _buildOfflineView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 80, height: 80, decoration: BoxDecoration(color: const Color(0xFFFEF2F2), shape: BoxShape.circle, border: Border.all(color: FoodMelaaColors.error.withValues(alpha: 0.15))), child: const Icon(Icons.power_settings_new_rounded, size: 36, color: FoodMelaaColors.error)),
            const SizedBox(height: 16),
            Text('You are offline', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: FoodMelaaColors.textDark)),
            const SizedBox(height: 6),
            Text('Go online to receive new orders', style: GoogleFonts.inter(fontSize: 12, color: FoodMelaaColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab(BuildContext context, List<QueryDocumentSnapshot<Map<String, dynamic>>> completedDocs) {
    if (completedDocs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: FoodMelaaColors.borderLight)), child: const Icon(Icons.history_rounded, size: 36, color: FoodMelaaColors.textGrey)),
              const SizedBox(height: 16),
              Text('No completed deliveries', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: FoodMelaaColors.textDark)),
              Text('Completed orders will appear here', style: GoogleFonts.inter(fontSize: 12, color: FoodMelaaColors.textSecondary)),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: completedDocs.length,
      itemBuilder: (context, index) => _buildCompletedCard(context, completedDocs[index].data(), completedDocs[index].id),
    );
  }

  Widget _buildCompletedCard(BuildContext context, Map<String, dynamic> data, String docId) {
    final orderId = data['orderId'] as String? ?? docId;
    final customerName = data['customerName'] as String? ?? 'Customer';
    final customerPhone = data['customerPhone'] as String? ?? 'N/A';
    final dateFormatted = _formatDateTime(data['acceptedAt'] ?? data['createdAt']);
    final catKey = data['orderCategory'] as String? ?? 'general';
    final catColor = FoodMelaaColors.categoryColor(catKey);
    return GestureDetector(
      onTap: () => _showReceiptModal(context, data, docId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: FoodMelaaColors.borderLight), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))]),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: FoodMelaaColors.riderPrimaryLight, borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
              child: Row(children: [Expanded(child: Text('Order #$orderId', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: FoodMelaaColors.textDark))), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: catColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Text('${_catIcon(catKey)} ${_catLabel(catKey)}', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: catColor))), const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: FoodMelaaColors.riderPrimary, borderRadius: BorderRadius.circular(8)), child: Text('Delivered', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)))]),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [const Icon(Icons.person_outline_rounded, size: 14, color: FoodMelaaColors.textGrey), const SizedBox(width: 6), Text('$customerName • $customerPhone', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FoodMelaaColors.textDark))]), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFDE68A))), child: Text('+ ₹40', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF92400E))))]),
                  const SizedBox(height: 8),
                  Row(children: [const Icon(Icons.access_time_rounded, size: 13, color: FoodMelaaColors.textGrey), const SizedBox(width: 6), Text(dateFormatted, style: GoogleFonts.inter(fontSize: 11, color: FoodMelaaColors.textSecondary))]),
                  const SizedBox(height: 8),
                  Row(children: [const Icon(Icons.receipt_long_rounded, size: 13, color: FoodMelaaColors.riderPrimary), const SizedBox(width: 4), Text('Tap for receipt', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: FoodMelaaColors.riderPrimary))]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiptModal(BuildContext context, Map<String, dynamic> data, String docId) {
    final orderId = data['orderId'] as String? ?? docId;
    final customerName = data['customerName'] as String? ?? 'Customer';
    final customerPhone = data['customerPhone'] as String? ?? 'N/A';
    final address = data['address'] as String? ?? 'Address not provided';
    final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
    final itemsSummary = data['itemsSummary'] as String? ?? _buildItemsSummary(data['items']);
    final dateFormatted = _formatDateTime(data['acceptedAt'] ?? data['createdAt']);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: FoodMelaaColors.borderGrey, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 16),
            Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: FoodMelaaColors.riderPrimaryLight, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.receipt_long_rounded, color: FoodMelaaColors.riderPrimary, size: 20)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Receipt #$orderId', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: FoodMelaaColors.textDark)), Text(dateFormatted, style: GoogleFonts.inter(fontSize: 11, color: FoodMelaaColors.textSecondary))]))]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: FoodMelaaColors.riderPrimaryLight, borderRadius: BorderRadius.circular(14), border: Border.all(color: FoodMelaaColors.riderPrimary.withValues(alpha: 0.15))),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('RIDER PAYOUT', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: FoodMelaaColors.riderPrimary, letterSpacing: 0.6)), Text('+ ₹40.00', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: FoodMelaaColors.riderPrimary))]), const Icon(Icons.account_balance_wallet_rounded, color: FoodMelaaColors.riderPrimary, size: 28)]),
            ),
            const SizedBox(height: 16),
            _receiptRow('Customer', customerName),
            _receiptRow('Phone', customerPhone),
            _receiptRow('Address', address),
            _receiptRow('Items', itemsSummary),
            _receiptRow('Total Paid', '₹${totalAmount.toInt()} (online)'),
            _receiptRow('Date', dateFormatted),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: FoodMelaaColors.riderPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text('Close', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)))),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 90, child: Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: FoodMelaaColors.textSecondary))), Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FoodMelaaColors.textDark)))]),
    );
  }

  // ── CANCELLED TAB ──────────────────────────────────────────────────────
  Widget _buildCancelledTab(BuildContext context, List<QueryDocumentSnapshot<Map<String, dynamic>>> cancelledDocs) {
    if (cancelledDocs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 80, height: 80, decoration: BoxDecoration(color: const Color(0xFFFEF2F2), shape: BoxShape.circle, border: Border.all(color: FoodMelaaColors.error.withValues(alpha: 0.15))), child: const Icon(Icons.cancel_rounded, size: 36, color: FoodMelaaColors.error)),
              const SizedBox(height: 16),
              Text('No cancelled orders', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: FoodMelaaColors.textDark)),
              const SizedBox(height: 6),
              Text('Cancelled orders assigned to you will appear here', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: FoodMelaaColors.textSecondary, height: 1.5)),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cancelledDocs.length,
      itemBuilder: (context, index) => _buildCancelledCard(context, cancelledDocs[index].data(), cancelledDocs[index].id),
    );
  }

  Widget _buildCancelledCard(BuildContext context, Map<String, dynamic> data, String docId) {
    final orderId = data['orderId'] as String? ?? docId;
    final customerName = data['customerName'] as String? ?? 'Customer';
    final customerPhone = data['customerPhone'] as String? ?? 'N/A';
    final address = data['address'] as String? ?? 'Address not provided';
    final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
    final itemsSummary = data['itemsSummary'] as String? ?? _buildItemsSummary(data['items']);
    final status = data['status'] as String? ?? 'Cancelled';
    final cancelledAt = data['cancelledAt'] ?? data['updatedAt'] ?? data['createdAt'];
    final dateFormatted = _formatDateTime(cancelledAt);
    final catKey = data['orderCategory'] as String? ?? 'general';
    final catColor = FoodMelaaColors.categoryColor(catKey);
    final reason = status.contains('Customer') ? 'Cancelled by Customer' : status.contains('Admin') ? 'Cancelled by Admin' : status.contains('Store') ? 'Cancelled by Store' : 'Cancelled';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: FoodMelaaColors.error.withValues(alpha: 0.15)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(color: Color(0xFFFEF2F2), borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
            child: Row(children: [
              Expanded(child: Text('Order #$orderId', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: FoodMelaaColors.textDark))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: catColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Text('${_catIcon(catKey)} ${_catLabel(catKey)}', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: catColor))),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: FoodMelaaColors.error, borderRadius: BorderRadius.circular(8)), child: Text('CANCELLED', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(Icons.person_rounded, 'Customer', '$customerName • $customerPhone', const Color(0xFF2563EB)),
                const SizedBox(height: 8),
                _infoRow(Icons.location_on_rounded, 'Address', address, const Color(0xFFDC2626)),
                const SizedBox(height: 8),
                _infoRow(Icons.shopping_bag_rounded, 'Items', itemsSummary.isNotEmpty ? itemsSummary : 'See details', const Color(0xFFD97706)),
                const SizedBox(height: 8),
                _infoRow(Icons.payments_rounded, 'Amount', '₹${totalAmount.toInt()} • No earning', const Color(0xFF64748B)),
                const SizedBox(height: 8),
                _infoRow(Icons.cancel_rounded, 'Reason', reason, FoodMelaaColors.error),
                const SizedBox(height: 8),
                _infoRow(Icons.access_time_rounded, 'Cancelled', dateFormatted, const Color(0xFF64748B)),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10), border: Border.all(color: FoodMelaaColors.error.withValues(alpha: 0.15))),
                  child: Row(children: [const Icon(Icons.info_outline_rounded, size: 14, color: FoodMelaaColors.error), const SizedBox(width: 6), Expanded(child: Text('This order was cancelled — no delivery required', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: FoodMelaaColors.error)))]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── PREMIUM ORDER CARD ───────────────────────────────────────────────────
  Widget _buildPremiumOrderCard(BuildContext context, Map<String, dynamic> data, String docId, {required bool isActiveDelivery}) {
    final orderId = data['orderId'] as String? ?? docId;
    final customerName = data['customerName'] as String? ?? 'Customer';
    final customerPhone = data['customerPhone'] as String? ?? 'N/A';
    final address = data['address'] as String? ?? 'Address not provided';
    final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
    final itemsSummary = data['itemsSummary'] as String? ?? _buildItemsSummary(data['items']);
    // Customer's live GPS pin (saved by customer app at order time)
    final deliveryLat = (data['deliveryLat'] as num?)?.toDouble();
    final deliveryLng = (data['deliveryLng'] as num?)?.toDouble();
    final items = data['items'] as List? ?? [];
    final itemCount = items.isNotEmpty ? items.length : (itemsSummary.isEmpty ? 0 : itemsSummary.split(',').length);
    final isAccepting = _acceptingOrderIds.contains(orderId);

    // ── Real category from Firestore ───────────────────────────────────
    final catKey = data['orderCategory'] as String? ?? 'general';
    final catLabel = data['orderCategoryLabel'] as String? ?? _catLabel(catKey);
    final catColor = FoodMelaaColors.categoryColor(catKey);
    final catIcon = _catIcon(catKey);

    int stage = 0;
    final rawStage = data['stage'];
    if (rawStage is num) {
      stage = rawStage.toInt();
    } else if (rawStage is String) {
      stage = int.tryParse(rawStage) ?? 0;
    }

    final stageColor = stage == 0 ? FoodMelaaColors.riderPrimary : stage == 1 ? const Color(0xFFD97706) : stage == 2 ? const Color(0xFF059669) : const Color(0xFF7C3AED);
    final stageText = stage == 0 ? 'New Order' : stage == 1 ? 'Accepted' : stage == 2 ? 'Out for Delivery' : 'Delivered';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActiveDelivery ? FoodMelaaColors.riderPrimary.withValues(alpha: 0.2) : FoodMelaaColors.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4)), BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 32, offset: const Offset(0, 12))],
      ),
      child: Column(
        children: [
          // ── Category badge — MOST PROMINENT ──────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: catColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(8)), child: Text(catIcon, style: const TextStyle(fontSize: 16))),
                const SizedBox(width: 10),
                Text('$catLabel ORDER', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.8)),
                const Spacer(),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Text('Order #$orderId', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: catColor))),
              ],
            ),
          ),

          // ── Status row ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: stageColor.withValues(alpha: 0.06)),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: stageColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: stageColor.withValues(alpha: 0.4), blurRadius: 6, spreadRadius: 1)])),
                const SizedBox(width: 8),
                Text(stageText, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: stageColor)),
                const Spacer(),
                if (!isActiveDelivery) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: FoodMelaaColors.riderPrimary, borderRadius: BorderRadius.circular(8)), child: Text('+ ₹40 Earning', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white))),
                if (isActiveDelivery) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: stageColor, borderRadius: BorderRadius.circular(8)), child: Text(stageText.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white))),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _infoRow(Icons.person_rounded, 'Customer', '$customerName  •  $customerPhone', const Color(0xFF2563EB)),
                const SizedBox(height: 10),
                _infoRow(Icons.location_on_rounded, 'Deliver To', deliveryLat != null && deliveryLng != null ? '$address  •  📍 LIVE GPS' : address, const Color(0xFFDC2626)),
                const SizedBox(height: 10),
                _infoRow(Icons.shopping_bag_rounded, 'Items', itemsSummary.isNotEmpty ? itemsSummary : 'See details', const Color(0xFFD97706), trailing: itemCount > 0 ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: FoodMelaaColors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: FoodMelaaColors.borderGrey)), child: Text('$itemCount items', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: FoodMelaaColors.textDark))) : null),
                const SizedBox(height: 10),
                _infoRow(Icons.payments_rounded, 'Amount', '₹${totalAmount.toInt()}  •  Paid Online', const Color(0xFF059669)),
                const SizedBox(height: 10),
                _infoRow(Icons.access_time_rounded, 'Placed', _formatDateTime(data['createdAt']), const Color(0xFF64748B)),
                if (data['specialInstructions'] != null && (data['specialInstructions'] as String).trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _infoRow(Icons.note_alt_rounded, 'Instructions', data['specialInstructions'] as String, const Color(0xFF7C3AED)),
                ],
              ],
            ),
          ),

          // ── Actions ──────────────────────────────────────────────────
          if (!isActiveDelivery) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  // REJECT — before acceptance only
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: isAccepting ? null : () => _rejectOrder(orderId),
                        icon: const Icon(Icons.close_rounded, size: 16, color: FoodMelaaColors.textSecondary),
                        label: Text('Reject', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: FoodMelaaColors.textSecondary)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: FoodMelaaColors.borderGrey, width: 1.2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), backgroundColor: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // ACCEPT — with loading + race-condition safe
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: isAccepting ? null : () => _acceptOrder(orderId, customerName, customerPhone, address, itemsSummary, totalAmount, deliveryLat: deliveryLat, deliveryLng: deliveryLng),
                        icon: isAccepting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                        label: Text(isAccepting ? 'Accepting...' : 'Accept', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: FoodMelaaColors.riderPrimary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), disabledBackgroundColor: FoodMelaaColors.riderPrimary.withValues(alpha: 0.6)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ActiveDeliveryScreen(orderId: orderId, customerName: customerName, customerPhone: customerPhone, address: address, itemsSummary: itemsSummary, totalAmount: totalAmount, deliveryLat: deliveryLat, deliveryLng: deliveryLng, riderId: _riderId)));
                  },
                  icon: const Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
                  label: Text('View Active Delivery', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: stageColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color, {Widget? trailing}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 14, color: color)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: FoodMelaaColors.textGrey, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(value, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: FoodMelaaColors.textDark, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing],
      ],
    );
  }
}
