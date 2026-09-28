import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:food_track/core/theme/food_melaa_colors.dart';
import 'package:food_track/core/theme/rider_gold.dart';
import 'package:food_track/core/state/rider_theme_state.dart';
import 'package:food_track/core/utils/privacy.dart';
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
import 'package:food_track/features/rider/rider_wallet_screen.dart';
import 'package:food_track/features/rider/incoming_order_screen.dart';
import 'package:food_track/features/rider/order_permission_setup_dialog.dart';
import 'package:food_track/features/rider/rider_login_screen.dart';
import 'package:food_track/features/rider/widgets/rider_order_card.dart';


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

// _catIcon removed in favor of RiderOrderCard

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
  String _searchQuery = ''; // Search query for Order ID search

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
    // Restore settled (accepted/rejected/cancelled) IDs so restarts can
    // never re-ring or re-notify them — the single choke point in
    // FirebaseService.notifyDriverNewOrder enforces this.
    FirebaseService.loadSettledOrders();
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

  /// Permission explainer: shown ONCE per install (persisted flag), not on
  /// every dashboard open. If the rider dismisses with "Remind Later", the
  /// non-blocking yellow banner remains — no more repeated modal nagging.
  /// Data-clear/reinstall resets the flag (correct: OS revokes grants too).
  bool _askedMustThisSession = false;
  Future<void> _askFullScreenPermissionMust() async {
    if (!mounted || _askedMustThisSession) return;
    _askedMustThisSession = true;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('permExplainerShown') == true) return;
    if (!mounted) return;
    final ctx = context;
    try {
      await OrderPermissionSetupDialog.checkAndPrompt(ctx);
    } catch (_) {}
    try {
      await prefs.setBool('permExplainerShown', true);
    } catch (_) {}
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
            // permission-denied = custom-token session toot gayi (backend token
            // rotate/expire). Pehle SILENT repair: token re-mint + stream
            // re-attach. Kaamyaab to user ko pata bhi nahi chalega; fail tabhi
            // snackbar. Kabhi auto-logout nahi.
            if (e.toString().contains('permission-denied') || e.toString().contains('unauthenticated')) {
              _repairStreamSilently();
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

  bool _repairingStream = false;

  Future<void> _repairStreamSilently() async {
    if (_repairingStream || !mounted) return;
    _repairingStream = true;
    try {
      final ok = await RiderAuthService.refreshFirestoreToken();
      if (ok && mounted) {
        try { await _ordersSub?.cancel(); } catch (_) {}
        _ordersSub = null;
        debugPrint('✅ [RIDER] token repaired — re-attaching orders stream');
        _attachOrdersListenerWithRetry();
        return;
      }
      // A temporary network/auth refresh failure must never look like a
      // logout. Keep the saved rider session and retry on the next stream
      // event; only the explicit Logout action clears credentials.
      debugPrint('⚠️ [RIDER] token repair deferred; saved session preserved');
      if (mounted) {
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted && _ordersSub == null) {
            _attachOrdersListenerWithRetry();
          }
        });
      }
    } finally {
      _repairingStream = false;
    }
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
    final ordersToClean = <String>[]; // Orders that are no longer pending but in claimed set

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final orderId = data['orderId'] as String? ?? doc.id;
      final stage = (data['stage'] as num?)?.toInt() ?? 0;
      final isDeleted = data['isDeleted'] as bool? ?? false;
      final riderId = data['riderId'] as String?;
      final status = (data['status'] as String? ?? '').toLowerCase();

      // Clean up: if order was claimed locally but is now accepted/completed, remove from claimed set
      if (_claimedOrderIds.contains(orderId) && stage > 0) {
        ordersToClean.add(orderId);
      }

      // Locally claimed/rejected by ME — never ring again, even before
      // the Firestore write echoes back (kills the re-ring loop).
      if (_claimedOrderIds.contains(orderId) || _rejectedOrderIds.contains(orderId)) {
        // But if it's already confirmed accepted (stage > 0), remove from claimed
        if (stage > 0) continue;
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

    // Clean up claimed orders that are now confirmed accepted
    if (ordersToClean.isNotEmpty) {
      for (final id in ordersToClean) {
        _claimedOrderIds.remove(id);
      }
      _saveNotifiedIds();
      debugPrint('🧹 Cleaned ${ordersToClean.length} confirmed orders from claimed set');
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
    if (route == null || !mounted) return;
    // removeRoute during another transition (push/pop animation in flight)
    // trips Navigator._debugLocked. Defer to end of frame so any in-flight
    // transition completes first; guard isCurrent in case it already popped.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final nav = route.navigator;
        if (nav == null || !route.isCurrent) return;
        nav.removeRoute(route);
      } catch (_) {
        // Already popped (e.g. user pressed back) — nothing to do
      }
    });
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
            // Privacy: rider never sees the real number — masked always.
            _receiptRow('Phone', maskPhone(customerPhone)),
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

  

  // ── Reject: local hide (no backend write — order stays available for other riders)
  void _rejectOrder(String orderId) {
    OrderRingtoneService.stopRinging(orderId);
    FirebaseService.settleOrder(orderId);
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
    _claimedOrderIds.add(orderId);
    _notifiedOrderIds.add(orderId);
    _saveNotifiedIds();
    IncomingOrderCall.markShown(orderId);
    await OrderRingtoneService.stopAll();
    await NativeOrderAlert.stopAll();
    await FirebaseService.settleOrder(orderId);
    await FirebaseService.dismissOrderNotification(orderId);
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
      final success = await FirebaseService.acceptOrder(orderId: orderId, riderName: _riderName, riderId: _riderId, riderPhone: _riderPhone);
      if (!mounted) return;
      // Close the loader via the ROOT navigator (dialogs always live there),
      // then let the frame settle before any further navigation — pushing
      // while the pop transition is still in flight trips _debugLocked.
      Navigator.of(context, rootNavigator: true).pop(); // close loader
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      if (mounted) setState(() => _acceptingOrderIds.remove(orderId));
      if (success) {
        // Remember claim locally — snapshot echo delay can't re-ring this order
        _claimedOrderIds.add(orderId);
        _notifiedOrderIds.add(orderId);
        _saveNotifiedIds();
        await Navigator.push(context, MaterialPageRoute(builder: (_) => ActiveDeliveryScreen(orderId: orderId, customerName: customerName, customerPhone: customerPhone, address: address, itemsSummary: itemsSummary, totalAmount: totalAmount, deliveryLat: deliveryLat, deliveryLng: deliveryLng, riderId: _riderId)));
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

  /// Premium profile sheet — read-only IDs/phone, theme switch, logout.
  /// Rider ID, phone, customer ID are display-only (never editable).
  void _showRiderProfileModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? RiderGold.inkDark : RiderGold.inkLight;
    final muted = isDark ? RiderGold.mutedDark : RiderGold.mutedLight;
    final cardBg = isDark ? RiderGold.cardDark : Colors.white;
    // Customer ID: surfaced when the backend/session carries one, else hidden.
    final customerId = (widget.riderData?['customerId'] ??
            widget.riderData?['customer_id'] ??
            widget.riderData?['uid'] ??
            '')
        .toString();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: isDark
                              ? RiderGold.borderDark
                              : FoodMelaaColors.borderGrey,
                          borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 16),
              // Golden identity header
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: RiderGold.headerGradient(),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                        color: RiderGold.gold.withValues(alpha: 0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 5)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 2),
                      ),
                      child: const Icon(Icons.person_rounded,
                          size: 30, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_riderName,
                              style: GoogleFonts.poppins(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text('Delivery Partner',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color:
                                      Colors.white.withValues(alpha: 0.85))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Read-only identity fields
              _goldReadOnlyRow(
                  context, Icons.badge_rounded, 'Rider ID',
                  _riderPartnerId.isNotEmpty ? _riderPartnerId : '—'),
              const SizedBox(height: 8),
              _goldReadOnlyRow(context, Icons.phone_rounded,
                  'Registered Mobile',
                  _riderPhone.isNotEmpty ? _riderPhone : '—'),
              if (customerId.isNotEmpty) ...[
                const SizedBox(height: 8),
                _goldReadOnlyRow(
                    context, Icons.person_outline_rounded, 'Customer ID', customerId),
              ],
              if (_riderEmail.isNotEmpty) ...[
                const SizedBox(height: 8),
                _goldReadOnlyRow(
                    context, Icons.email_rounded, 'Email', _riderEmail),
              ],
              const SizedBox(height: 8),
              _profileStatusRow('Account Status', 'Verified Partner',
                  const Color(0xFF10B981)),
              const SizedBox(height: 8),
              _profileStatusRow(
                  'Availability',
                  _isOnline
                      ? 'Online — Receiving orders'
                      : 'Offline — Not receiving orders',
                  _isOnline
                      ? const Color(0xFF10B981)
                      : FoodMelaaColors.error),
              const SizedBox(height: 14),
              // Appearance — persisted via RiderThemeState (SharedPreferences)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? RiderGold.surfaceDark
                      : RiderGold.goldWash,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isDark
                          ? RiderGold.borderDark
                          : RiderGold.goldBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('APPEARANCE',
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: muted)),
                    const SizedBox(height: 10),
                    _themeOption(
                        sheetCtx, 'Light', Icons.light_mode_rounded,
                        ThemeMode.light, ink, muted, cardBg),
                    const SizedBox(height: 8),
                    _themeOption(sheetCtx, 'Dark', Icons.dark_mode_rounded,
                        ThemeMode.dark, ink, muted, cardBg),
                    const SizedBox(height: 8),
                    _themeOption(sheetCtx, 'System default',
                        Icons.settings_suggest_rounded, ThemeMode.system,
                        ink, muted, cardBg),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await FirebaseService
                          .unsubscribeFromRiderNotifications();
                    } catch (_) {}
                    try {
                      await _ordersSub?.cancel();
                    } catch (_) {}
                    try {
                      await RiderAuthService.instance.logout();
                    } catch (_) {}
                    if (context.mounted) {
                      Navigator.pop(context);
                      Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RiderLoginScreen()),
                          (route) => false);
                    }
                  },
                  icon: const Icon(Icons.logout_rounded,
                      color: Colors.white, size: 18),
                  label: Text('Log Out',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: FoodMelaaColors.error,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Read-only identity row — value can be copied, never edited.
  Widget _goldReadOnlyRow(
      BuildContext context, IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? RiderGold.inkDark : RiderGold.inkLight;
    final muted = isDark ? RiderGold.mutedDark : RiderGold.mutedLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? RiderGold.surfaceDark : RiderGold.goldWash,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? RiderGold.borderDark : RiderGold.goldBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: RiderGold.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: muted)),
                const SizedBox(height: 1),
                Text(value,
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('$label copied',
                    style: GoogleFonts.poppins(fontSize: 12)),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 1),
              ));
            },
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child:
                  Icon(Icons.copy_rounded, size: 14, color: RiderGold.gold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeOption(BuildContext context, String label, IconData icon,
      ThemeMode mode, Color ink, Color muted, Color cardBg) {
    final selected = riderThemeState.mode == mode;
    return InkWell(
      onTap: () {
        riderThemeState.setMode(mode);
        setState(() {});
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? RiderGold.gold.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? RiderGold.gold : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18, color: selected ? RiderGold.gold : muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: ink)),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  size: 18, color: RiderGold.gold),
          ],
        ),
      ),
    );
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

  bool _matchesSearchQuery(Map<String, dynamic> orderData) {
    if (_searchQuery.isEmpty) return true;
    final orderId = (orderData['orderId'] as String? ?? '').toUpperCase();
    return orderId.contains(_searchQuery.toUpperCase());
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: RiderGold.scaffold(context),
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(gradient: RiderGold.headerGradient()),
          ),
          // Profile icon on the EXTREME LEFT of the header (spec point 2/11).
          leading: GestureDetector(
            onTap: () => _showRiderProfileModal(context),
            child: Container(
              margin: const EdgeInsets.only(left: 12, top: 10, bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55), width: 1.5),
              ),
              child: const Icon(Icons.person_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_greeting()}, ${_riderName.split(' ').first}',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        softWrap: false),
                    Text(
                        _riderPartnerId.isNotEmpty
                            ? _riderPartnerId
                            : 'Food Mela Delivery',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.85)),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        softWrap: false),
                  ],
                ),
              ),
            ],
          ),
          actions: [
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
            preferredSize: const Size.fromHeight(56),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(30),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: RiderGold.goldDeep,
                unselectedLabelColor: Colors.white,
                labelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800, fontSize: 12.5),
                unselectedLabelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 12.5),
                tabs: const [
                  Tab(text: 'Active Orders'),
                  Tab(text: 'History'),
                  Tab(text: 'Cancelled'),
                ],
              ),
            ),
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseService.liveOrdersStream,
          builder: (context, snapshot) {
            // ── orderBy fallback: if the ordered query errors (mixed
            // `createdAt` types across docs), retry WITHOUT orderBy — the
            // Dart-side sort below still guarantees newest-first display.
            if (snapshot.hasError && (snapshot.data?.docs.isEmpty ?? true)) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseService.liveOrdersStreamUnordered,
                builder: (context, fbSnapshot) => _buildOrdersBody(
                  context, fbSnapshot.data?.docs ?? [],
                ),
              );
            }
            return _buildOrdersBody(context, snapshot.data?.docs ?? []);
          },
        ),
      ),
    );
  }

  /// Builds the tabbed orders body from a raw doc list.
  /// ORDERING CONTRACT: every tab list is sorted newest → oldest by real
  /// timestamp (tiebroken by order key), so the sequence is ALWAYS
  /// latest-first no matter how Firestore delivers the snapshot.
  Widget _buildOrdersBody(BuildContext context, List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs) {
            // ── Dedup by canonical Order ID (doc may repeat across snapshots).
            // LAST occurrence wins — it carries the freshest field values.
            final byKey = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
            for (final doc in allDocs) {
              byKey[FirebaseService.orderKeyOf(doc.data(), doc.id)] = doc;
            }
            final uniqueDocs = byKey.values.toList();
            // ── Canonical sort: newest real timestamp FIRST (stable tiebreak) ──
            FirebaseService.sortNewestFirst(
              uniqueDocs,
              (d) => d.data(),
              (d) => FirebaseService.orderKeyOf(d.data(), d.id),
            );
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
                // Stats banner — golden gradient premium
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: RiderGold.headerGradient(),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: RiderGold.gold.withValues(alpha: 0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                          child: _goldStatCard(
                              'DELIVERED',
                              '${earnedDocs.length} Orders',
                              Icons.check_circle_rounded)),
                      const SizedBox(width: 12),
                      // EARNINGS → opens premium Wallet (withdrawals + history)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RiderWalletScreen(
                                  riderId: _riderId,
                                  riderName: _riderName),
                            ),
                          ),
                          child: Stack(
                            children: [
                              _goldStatCard(
                                  'EARNINGS',
                                  '₹${totalEarnings.toInt()}',
                                  Icons
                                      .account_balance_wallet_rounded),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(alpha: 0.25),
                                      borderRadius:
                                          BorderRadius.circular(8)),
                                  child: Text('WALLET ›',
                                      style: GoogleFonts.poppins(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
  }

  /// Golden stat tile on the gradient banner — white text, translucent tile.
  Widget _goldStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.35))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.85),
                  letterSpacing: 0.6)),
          const SizedBox(height: 6),
          Row(children: [
            Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle),
                child:
                    Icon(icon, color: Colors.white, size: 12)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(value,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ],
      ),
    );
  }

  // ── ACTIVE TAB ─────────────────────────────────────────────────────────
  Widget _buildActiveTab(BuildContext context, List<QueryDocumentSnapshot<Map<String, dynamic>>> activeDocs, List<QueryDocumentSnapshot<Map<String, dynamic>>> pendingDocs) {
    if (!_isOnline) return _buildOfflineView();

    final filteredActiveDocs = activeDocs.where((doc) => _matchesSearchQuery(doc.data())).toList();
    final filteredPendingDocs = pendingDocs.where((doc) => _matchesSearchQuery(doc.data())).toList();

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

    if (_searchQuery.isNotEmpty && filteredActiveDocs.isEmpty && filteredPendingDocs.isEmpty) {
      return Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: FoodMelaaColors.borderLight), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))]), child: const Icon(Icons.search_rounded, size: 36, color: FoodMelaaColors.textGrey)),
                    const SizedBox(height: 16),
                    Text('No orders found', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: FoodMelaaColors.textDark)),
                    const SizedBox(height: 6),
                    Text('Try searching with a different Order ID', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: FoodMelaaColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final children = <Widget>[];
    int entranceIndex = 0;

    children.add(_buildSearchBar());

    if (filteredActiveDocs.isNotEmpty) {
      children.add(Padding(padding: const EdgeInsets.only(top: 16, bottom: 8), child: Row(children: [Container(width: 3, height: 14, decoration: BoxDecoration(color: const Color(0xFFD97706), borderRadius: BorderRadius.circular(3))), const SizedBox(width: 8), Text('MY ACTIVE DELIVERIES', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: FoodMelaaColors.textSecondary, letterSpacing: 0.8)), const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFD97706), borderRadius: BorderRadius.circular(8)), child: Text('${filteredActiveDocs.length}', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)))])));
      for (final doc in filteredActiveDocs) {
        children.add(_buildPremiumOrderCard(context, doc.data(), doc.id, isActiveDelivery: true).animate().fadeIn(delay: (50 * entranceIndex).ms).slideY(begin: 0.1, curve: Curves.easeOutCubic)); entranceIndex++;
      }
    }
    if (filteredPendingDocs.isNotEmpty) {
      children.add(Padding(padding: const EdgeInsets.only(top: 16, bottom: 8), child: Row(children: [Container(width: 3, height: 14, decoration: BoxDecoration(color: FoodMelaaColors.riderPrimary, borderRadius: BorderRadius.circular(3))), const SizedBox(width: 8), Text('NEW ORDERS', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: FoodMelaaColors.textSecondary, letterSpacing: 0.8)), const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: FoodMelaaColors.riderPrimary, borderRadius: BorderRadius.circular(8)), child: Text('${filteredPendingDocs.length}', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)))])));
      for (final doc in filteredPendingDocs) {
        children.add(_buildPremiumOrderCard(context, doc.data(), doc.id, isActiveDelivery: false).animate().fadeIn(delay: (50 * entranceIndex).ms).slideY(begin: 0.1, curve: Curves.easeOutCubic)); entranceIndex++;
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
    final filteredDocs = completedDocs.where((doc) => _matchesSearchQuery(doc.data())).toList();

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

    if (_searchQuery.isNotEmpty && filteredDocs.isEmpty) {
      return Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: FoodMelaaColors.borderLight), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))]), child: const Icon(Icons.search_rounded, size: 36, color: FoodMelaaColors.textGrey)),
                    const SizedBox(height: 16),
                    Text('No orders found', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: FoodMelaaColors.textDark)),
                    const SizedBox(height: 6),
                    Text('Try searching with a different Order ID', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: FoodMelaaColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) => _buildCompletedCard(context, filteredDocs[index].data(), filteredDocs[index].id).animate().fadeIn(delay: (50 * index).ms).slideX(begin: -0.1, curve: Curves.easeOutCubic),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedCard(BuildContext context, Map<String, dynamic> data, String docId) {
    return RiderOrderCard(
      data: data,
      docId: docId,
      riderId: _riderId,
      isActiveDelivery: false,
    );
  }

  

  // ── CANCELLED TAB ──────────────────────────────────────────────────────
  Widget _buildCancelledTab(BuildContext context, List<QueryDocumentSnapshot<Map<String, dynamic>>> cancelledDocs) {
    final filteredDocs = cancelledDocs.where((doc) => _matchesSearchQuery(doc.data())).toList();

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

    if (_searchQuery.isNotEmpty && filteredDocs.isEmpty) {
      return Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: FoodMelaaColors.borderLight), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))]), child: const Icon(Icons.search_rounded, size: 36, color: FoodMelaaColors.textGrey)),
                    const SizedBox(height: 16),
                    Text('No orders found', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: FoodMelaaColors.textDark)),
                    const SizedBox(height: 6),
                    Text('Try searching with a different Order ID', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: FoodMelaaColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) => _buildCancelledCard(context, filteredDocs[index].data(), filteredDocs[index].id).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.1, curve: Curves.easeOutCubic),
          ),
        ),
      ],
    );
  }

  Widget _buildCancelledCard(BuildContext context, Map<String, dynamic> data, String docId) {
    return RiderOrderCard(
      data: data,
      docId: docId,
      riderId: _riderId,
      isActiveDelivery: false,
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
    final deliveryLat = (data['deliveryLat'] as num?)?.toDouble();
    final deliveryLng = (data['deliveryLng'] as num?)?.toDouble();

    return RiderOrderCard(
      data: data,
      docId: docId,
      riderId: _riderId,
      isActiveDelivery: isActiveDelivery,
      isAccepting: _acceptingOrderIds.contains(orderId),
      onAccept: () => _acceptOrder(
        orderId,
        customerName,
        customerPhone,
        address,
        itemsSummary,
        totalAmount,
        deliveryLat: deliveryLat,
        deliveryLng: deliveryLng,
      ),
      onReject: () => _rejectOrder(orderId),
      onOpenActiveDelivery: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActiveDeliveryScreen(
              orderId: orderId,
              customerName: customerName,
              customerPhone: customerPhone,
              address: address,
              itemsSummary: itemsSummary,
              totalAmount: totalAmount,
              deliveryLat: deliveryLat,
              deliveryLng: deliveryLng,
              riderId: _riderId,
            ),
          ),
        );
      },
    );
  }


  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8F9FA),
          border: Border.all(
            color: isDark ? const Color(0xFF404040) : const Color(0xFFE8E8E8),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
            if (!isDark)
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.8),
                blurRadius: 8,
                offset: const Offset(-2, -2),
              ),
          ],
        ),
        child: TextField(
          onChanged: (value) {
            setState(() => _searchQuery = value);
          },
          decoration: InputDecoration(
            hintText: 'Search by Order ID...',
            hintStyle: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: isDark ? const Color(0xFF999999) : const Color(0xFF999999),
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(
                Icons.search_rounded,
                color: FoodMelaaColors.riderPrimary,
                size: 22,
              ),
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      setState(() => _searchQuery = '');
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Icon(
                        Icons.clear_rounded,
                        color: isDark ? const Color(0xFF666666) : const Color(0xFF999999),
                        size: 20,
                      ),
                    ),
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          ),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF1A1A1A),
          ),
          cursorColor: FoodMelaaColors.riderPrimary,
          cursorWidth: 2,
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
}
