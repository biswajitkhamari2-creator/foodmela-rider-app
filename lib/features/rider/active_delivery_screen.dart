import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/food_melaa_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class ActiveDeliveryScreen extends StatefulWidget {
  final String orderId;
  final String customerName;
  final String customerPhone;
  final String address;
  final String itemsSummary;
  final double totalAmount;

  const ActiveDeliveryScreen({
    super.key,
    required this.orderId,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    required this.itemsSummary,
    required this.totalAmount,
  });

  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  int _currentStep = 0;
  final TextEditingController _otpController = TextEditingController();
  Map<String, dynamic>? _orderData;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _orderSubscription;
  bool _isCancelledAlertShown = false;
  // Rider LIVE GPS → same order doc (customer map reads these, no refresh).
  StreamSubscription<Position>? _riderGpsSub;
  Position? _riderPos;

  final List<String> _stepTitles = [
    'Reached Pickup Store',
    'Items Picked & Verified',
    'Out for Delivery',
    'Complete Delivery',
  ];
  final List<IconData> _stepIcons = [
    Icons.store_rounded,
    Icons.inventory_2_rounded,
    Icons.delivery_dining_rounded,
    Icons.verified_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _listenToOrderCancellation();
    _startRiderLiveGps();
  }

  /// Rider's ACTUAL device GPS → order doc (riderLat/riderLng/riderUpdatedAt).
  /// Best accuracy, distance-filtered (~10m) so battery stays sensible.
  /// Customer map listens to the same doc — marker moves with no refresh.
  Future<void> _startRiderLiveGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        debugPrint('Rider GPS permission denied — live marker off');
        return;
      }
      const settings = LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
      );
      _riderGpsSub = Geolocator.getPositionStream(locationSettings: settings).listen(
        (pos) async {
          _riderPos = pos;
          try {
            await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
              'riderLat': pos.latitude,
              'riderLng': pos.longitude,
              'riderUpdatedAt': FieldValue.serverTimestamp(),
            });
          } catch (e) {
            debugPrint('Rider GPS write: $e');
          }
        },
        onError: (e) => debugPrint('Rider GPS stream: $e'),
      );
    } catch (e) {
      debugPrint('Rider GPS start: $e');
    }
  }

  void _listenToOrderCancellation() {
    _orderSubscription = FirebaseFirestore.instance.collection('orders').doc(widget.orderId).snapshots().listen((snap) {
      if (snap.exists && snap.data() != null) {
        setState(() => _orderData = snap.data());
        final status = (snap.data()?['status'] as String? ?? '').toLowerCase();
        final stage = (snap.data()?['stage'] as num?)?.toInt() ?? 0;
        if (stage == -1 || status.contains('cancel')) _showCancellationAlert();
      }
    });
  }

  void _showCancellationAlert() {
    if (_isCancelledAlertShown || !mounted) return;
    _isCancelledAlertShown = true;
    _orderSubscription?.cancel();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [const Icon(Icons.error_outline_rounded, color: Colors.red, size: 28), const SizedBox(width: 10), Text('Order Cancelled! 🚨', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))]),
          content: Text('This order has been cancelled. Please do NOT proceed with delivery. Returning to dashboard.', style: GoogleFonts.inter(fontSize: 13)),
          actions: [ElevatedButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('OK', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)))],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    _riderGpsSub?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _advanceStep() {
    if (_isCancelled) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: FoodMelaaColors.error, content: Text('Order cancelled — cannot update', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white))));
      return;
    }
    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _updateFirestoreStage(_currentStep);
    } else {
      _showOtpDialog();
    }
  }

  /// Attach current rider GPS to every stage write so the customer map
  /// never goes stale even between stream ticks.
  Future<Map<String, dynamic>> _riderGpsPatch() async {
    if (_riderPos != null) {
      return {
        'riderLat': _riderPos!.latitude,
        'riderLng': _riderPos!.longitude,
        'riderUpdatedAt': FieldValue.serverTimestamp(),
      };
    }
    return {};
  }

  Future<void> _updateFirestoreStage(int step) async {
    if (_isCancelled) return;
    // Guard: re-check cancellation before writing
    try {
      final snap = await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).get();
      if (snap.exists) {
        final s = (snap.data()?['stage'] as num?)?.toInt() ?? 0;
        final st = (snap.data()?['status'] as String? ?? '').toLowerCase();
        if (s == -1 || st.contains('cancel')) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: FoodMelaaColors.error, content: Text('Order was cancelled — update blocked', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white))));
          return;
        }
      }
    } catch (_) {}
    int targetStage = 1;
    String targetStatus = '';
    if (step == 0) { targetStage = 1; targetStatus = 'Order Accepted'; }
    else if (step == 1) { targetStage = 1; targetStatus = 'Reached Store'; }
    else if (step == 2) { targetStage = 2; targetStatus = 'Items Picked Up'; }
    else if (step == 3) { targetStage = 2; targetStatus = 'Out for Delivery'; }
    else if (step == 4) { targetStage = 3; targetStatus = 'Delivered'; }
    try {
      await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
        'stage': targetStage,
        'status': targetStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        ...await _riderGpsPatch(),
      });
    } catch (e) { debugPrint('Firestore update: $e'); }
  }

  void _showOtpDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: FoodMelaaColors.riderPrimaryLight, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.vpn_key_rounded, color: FoodMelaaColors.riderPrimary, size: 18)), const SizedBox(width: 10), Text('Delivery OTP', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: FoodMelaaColors.textDark))]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ask customer for the 4-digit OTP in their app', style: GoogleFonts.inter(fontSize: 12, color: FoodMelaaColors.textSecondary)),
            const SizedBox(height: 14),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 8, color: FoodMelaaColors.textDark),
              textAlign: TextAlign.center,
              decoration: InputDecoration(hintText: '••••', hintStyle: GoogleFonts.poppins(letterSpacing: 8, color: FoodMelaaColors.textGrey), filled: true, fillColor: FoodMelaaColors.background, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: FoodMelaaColors.riderPrimary, width: 1.5)), counterText: ''),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Cancel', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: FoodMelaaColors.textSecondary))),
          ElevatedButton(
            onPressed: () async {
              final outerContext = context;
              final enteredOtp = _otpController.text.trim();
              if (enteredOtp.length != 4) {
                if (outerContext.mounted) ScaffoldMessenger.of(outerContext).showSnackBar(SnackBar(backgroundColor: FoodMelaaColors.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), content: Text('Enter 4-digit OTP', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white))));
                return;
              }
              try {
                final doc = await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).get();
                String? actualOtp;
                if (doc.exists) actualOtp = doc.data()?['deliveryOtp']?.toString();
                if (actualOtp == null || actualOtp.isEmpty) {
                  final paths = ['/sdcard/Download/food_mela_pending_orders.json', '/storage/emulated/0/Download/food_mela_pending_orders.json', '${Directory.systemTemp.path}/food_mela_pending_orders.json'];
                  for (final path in paths) {
                    final f = File(path);
                    if (f.existsSync()) {
                      final content = f.readAsStringSync();
                      if (content.isNotEmpty) {
                        final List<dynamic> decoded = jsonDecode(content);
                        final matching = decoded.firstWhere((o) => o['id'] == widget.orderId || o['orderId'] == widget.orderId, orElse: () => null);
                        if (matching != null) { actualOtp = matching['deliveryOtp']?.toString(); break; }
                      }
                    }
                  }
                }
                if (actualOtp != null && actualOtp.isNotEmpty && enteredOtp != actualOtp) {
                  if (outerContext.mounted) ScaffoldMessenger.of(outerContext).showSnackBar(SnackBar(backgroundColor: FoodMelaaColors.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), content: Text('Invalid OTP — check customer app', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white))));
                  return;
                }
              } catch (e) { debugPrint('OTP check: $e'); }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              await _updateFirestoreStage(4);
              try { await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({'stage': 3, 'status': 'Delivered', 'deliveredAt': FieldValue.serverTimestamp(), 'deliveryOtpEntered': enteredOtp}); } catch (_) {}
              if (outerContext.mounted) {
                showDialog(
                  context: outerContext,
                  barrierDismissible: false,
                  builder: (thankYouCtx) => AlertDialog(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: FoodMelaaColors.riderPrimaryLight, shape: BoxShape.circle), child: const Icon(Icons.check_circle_rounded, color: FoodMelaaColors.riderPrimary, size: 48)),
                        const SizedBox(height: 16),
                        Text('Delivered!', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: FoodMelaaColors.riderPrimary)),
                        const SizedBox(height: 8),
                        Text('Order #${widget.orderId} completed\n₹40 added to your earnings', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: FoodMelaaColors.textSecondary, height: 1.5)),
                        const SizedBox(height: 20),
                        SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: () { Navigator.pop(thankYouCtx); if (outerContext.mounted) Navigator.pop(outerContext); }, style: ElevatedButton.styleFrom(backgroundColor: FoodMelaaColors.riderPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text('Back to Dashboard', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)))),
                      ],
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: FoodMelaaColors.riderPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Verify & Complete', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  bool get _isCancelled {
    final status = (_orderData?['status'] as String? ?? '').toLowerCase();
    final stage = (_orderData?['stage'] as num?)?.toInt() ?? 0;
    return stage == -1 || status.contains('cancel');
  }

  @override
  Widget build(BuildContext context) {
    if (_isCancelled) {
      return Scaffold(
        backgroundColor: FoodMelaaColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: Container(margin: const EdgeInsets.all(8), decoration: BoxDecoration(color: FoodMelaaColors.background, shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: FoodMelaaColors.textDark, size: 20), onPressed: () => Navigator.pop(context))),
          title: Text('Order Cancelled', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: FoodMelaaColors.error)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 80, height: 80, decoration: BoxDecoration(color: const Color(0xFFFEF2F2), shape: BoxShape.circle, border: Border.all(color: FoodMelaaColors.error.withValues(alpha: 0.15))), child: const Icon(Icons.cancel_rounded, size: 40, color: FoodMelaaColors.error)),
                const SizedBox(height: 16),
                Text('This order has been cancelled', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: FoodMelaaColors.error)),
                const SizedBox(height: 8),
                Text('Order #${widget.orderId} was cancelled.\nNo delivery action is required.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: FoodMelaaColors.textSecondary, height: 1.5)),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: FoodMelaaColors.textDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text('Back to Dashboard', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)))),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: FoodMelaaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Container(margin: const EdgeInsets.all(8), decoration: BoxDecoration(color: FoodMelaaColors.background, shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: FoodMelaaColors.textDark, size: 20), onPressed: () => Navigator.pop(context))),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Active Delivery', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: FoodMelaaColors.textDark)), Text('#${widget.orderId}', style: GoogleFonts.inter(fontSize: 11, color: FoodMelaaColors.textSecondary))]),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(color: FoodMelaaColors.riderPrimaryLight, borderRadius: BorderRadius.circular(12)),
            child: IconButton(icon: const Icon(Icons.phone_rounded, color: FoodMelaaColors.riderPrimary, size: 20), tooltip: 'Call Customer', onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Calling ${widget.customerName}: ${widget.customerPhone}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white)), backgroundColor: FoodMelaaColors.textDark, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Navigation card — premium (with rider LIVE GPS readout)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: FoodMelaaColors.riderPrimary, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: FoodMelaaColors.riderPrimary.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))]),
              child: Row(
                children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.address, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(
                        _riderPos != null
                            ? '🚴 Live GPS active — customer sees you move'
                            : 'Tap GPS to navigate',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
                  ])),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opening Maps', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white)), backgroundColor: FoodMelaaColors.textDark, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))), icon: const Icon(Icons.near_me_rounded, size: 14, color: FoodMelaaColors.riderPrimary), label: Text('GPS', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: FoodMelaaColors.riderPrimary)), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Workflow — premium
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: FoodMelaaColors.borderLight), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: FoodMelaaColors.riderPrimaryLight, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.route_rounded, color: FoodMelaaColors.riderPrimary, size: 16)), const SizedBox(width: 10), Text('Delivery Progress', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: FoodMelaaColors.textDark))]),
                  const SizedBox(height: 18),
                  for (int i = 0; i < 4; i++) ...[
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: i <= _currentStep ? FoodMelaaColors.riderPrimary : FoodMelaaColors.borderGrey, boxShadow: i == _currentStep ? [BoxShadow(color: FoodMelaaColors.riderPrimary.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))] : null),
                          child: Icon(i < _currentStep ? Icons.check_rounded : _stepIcons[i], size: 16, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_stepTitles[i], style: GoogleFonts.poppins(fontSize: 13, fontWeight: i == _currentStep ? FontWeight.w700 : (i < _currentStep ? FontWeight.w600 : FontWeight.w500), color: i <= _currentStep ? FoodMelaaColors.textDark : FoodMelaaColors.textGrey))),
                        if (i == _currentStep) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: FoodMelaaColors.riderPrimaryLight, borderRadius: BorderRadius.circular(8)), child: Text('NOW', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: FoodMelaaColors.riderPrimary))),
                      ],
                    ),
                    if (i < 3) Container(margin: const EdgeInsets.only(left: 15, top: 4, bottom: 4), width: 2, height: 18, decoration: BoxDecoration(color: i < _currentStep ? FoodMelaaColors.riderPrimary : FoodMelaaColors.borderGrey, borderRadius: BorderRadius.circular(2))),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Customer & order — premium
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: FoodMelaaColors.borderLight), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: FoodMelaaColors.background, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.person_rounded, color: FoodMelaaColors.textSecondary, size: 16)), const SizedBox(width: 10), Text('Customer & Order', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: FoodMelaaColors.textDark))]),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(width: 44, height: 44, decoration: BoxDecoration(color: FoodMelaaColors.riderPrimaryLight, shape: BoxShape.circle), child: Center(child: Text(widget.customerName.isNotEmpty ? widget.customerName[0].toUpperCase() : 'C', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: FoodMelaaColors.riderPrimary)))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.customerName, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: FoodMelaaColors.textDark)), GestureDetector(onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Calling ${widget.customerPhone}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white)), backgroundColor: FoodMelaaColors.textDark, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))), child: Text(widget.customerPhone, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FoodMelaaColors.riderPrimary, decoration: TextDecoration.underline, decorationColor: FoodMelaaColors.riderPrimary)))])),
                      Container(decoration: BoxDecoration(color: FoodMelaaColors.riderPrimary, shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.phone_rounded, color: Colors.white, size: 18), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Calling ${widget.customerPhone}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white)), backgroundColor: FoodMelaaColors.textDark, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(height: 1, color: FoodMelaaColors.borderLight),
                  const SizedBox(height: 14),
                  _detailRow(Icons.location_on_rounded, 'Delivery Address', widget.address, const Color(0xFFDC2626)),
                  const SizedBox(height: 12),
                  _detailRow(Icons.shopping_bag_rounded, 'Items', widget.itemsSummary.isNotEmpty ? widget.itemsSummary : 'See order details', const Color(0xFFD97706)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: FoodMelaaColors.riderPrimaryLight, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.payments_rounded, size: 14, color: FoodMelaaColors.riderPrimary)), const SizedBox(width: 8), Text('₹${widget.totalAmount.toInt()}', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, color: FoodMelaaColors.textDark))]),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFBBF7D0))), child: Text('PAID ONLINE', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF166534)))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // CTA — NO cancel/reject after acceptance
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _advanceStep,
                style: ElevatedButton.styleFrom(backgroundColor: FoodMelaaColors.riderPrimary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), shadowColor: FoodMelaaColors.riderPrimary.withValues(alpha: 0.3)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_currentStep == 3 ? 'Enter Customer OTP' : 'Update Status', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle), child: Icon(_currentStep == 3 ? Icons.vpn_key_rounded : Icons.arrow_forward_rounded, color: Colors.white, size: 14)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(child: Text('Accepted orders cannot be cancelled', style: GoogleFonts.inter(fontSize: 11, color: FoodMelaaColors.textGrey))),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 14, color: color)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: FoodMelaaColors.textGrey, letterSpacing: 0.5)), const SizedBox(height: 2), Text(value, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: FoodMelaaColors.textDark, height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis)])),
      ],
    );
  }
}
