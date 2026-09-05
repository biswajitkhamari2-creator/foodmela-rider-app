import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/food_melaa_colors.dart';
import 'package:food_track/core/utils/routes.dart';
import 'package:food_track/core/state/food_mela_state.dart';

// ─── GLOBAL STATIC CANCEL TIMER (survives navigation) ─────────────────────────
// These are static so they don't reset when user presses Back and comes again
int _globalCancelSeconds = 0;
Timer? _globalCancelTimer;
String? _globalActiveOrderId;
bool _globalTimerStarted = false;

void startGlobalCancelTimer(String orderId) {
  // Only start once per order — don't restart if already running
  if (_globalTimerStarted && _globalActiveOrderId == orderId) return;
  _globalCancelTimer?.cancel();
  _globalCancelSeconds = 120;
  _globalActiveOrderId = orderId;
  _globalTimerStarted = true;
  _globalCancelTimer = Timer.periodic(const Duration(seconds: 1), (t) {
    if (_globalCancelSeconds > 0) {
      _globalCancelSeconds--;
    } else {
      t.cancel();
    }
  });
}

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _riderMoveController;
  late Animation<double> _riderProgress;

  int _orderStatusStage = 0;
  String _driverName = '';
  bool _hasNotifiedAcceptance = false;

  Timer? _statusPollerTimer;
  Timer? _uiRefreshTimer;

  final List<Map<String, dynamic>> _stages = [
    {
      'title': 'Order Placed • Waiting for Rider 📝',
      'sub': 'Notification sent! Waiting for a delivery partner to accept...',
      'icon': Icons.receipt_long_rounded,
      'color': Colors.blue
    },
    {
      'title': 'Preparing Order 🍳',
      'sub': 'Chef is preparing your meal & packing fresh items',
      'icon': Icons.soup_kitchen_rounded,
      'color': Colors.orange
    },
    {
      'title': 'Out for Delivery 🛵',
      'sub': 'Delivery Partner is heading to your address',
      'icon': Icons.delivery_dining_rounded,
      'color': Colors.green
    },
    {
      'title': 'Delivered 🏁',
      'sub': 'Order completed successfully! Enjoy your meal',
      'icon': Icons.check_circle_rounded,
      'color': Colors.purple
    },
  ];

  @override
  void initState() {
    super.initState();

    _riderMoveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);

    _riderProgress = Tween<double>(begin: 0.2, end: 0.85).animate(
      CurvedAnimation(parent: _riderMoveController, curve: Curves.easeInOut),
    );

    HapticFeedback.vibrate();

    // Start the global timer (won't reset if already running for same order)
    final liveOrders = FoodMelaState().liveOrders;
    if (liveOrders.isNotEmpty) {
      final orderId = liveOrders.first['id'] as String? ?? '';
      if (orderId.isNotEmpty) {
        startGlobalCancelTimer(orderId);
      }
    }

    // Refresh UI every second so cancel timer countdown updates
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    _startLiveStatusPoller();
  }

  @override
  void dispose() {
    _statusPollerTimer?.cancel();
    _uiRefreshTimer?.cancel();
    _riderMoveController.dispose();
    super.dispose();
  }

  // ─── LIVE STATUS POLLER ───────────────────────────────────────────────────
  void _startLiveStatusPoller() {
    _statusPollerTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final liveOrders = FoodMelaState().liveOrders;
      if (liveOrders.isEmpty) return;
      final orderId = liveOrders.first['id'] as String? ?? liveOrders.first['orderId'] as String? ?? '';
      if (orderId.isEmpty) return;

      // ── Fallback: read shared file written by Driver App ──────────────
      _readFallbackFile(orderId);
    });
  }

  void _readFallbackFile(String orderId) {
    try {
      // Try /sdcard/Download/ first (works on real Android devices)
      final paths = [
        '/sdcard/Download/food_mela_pending_orders.json',
        '/storage/emulated/0/Download/food_mela_pending_orders.json',
        '${Directory.systemTemp.path}/food_mela_pending_orders.json',
      ];

      for (final path in paths) {
        final f = File(path);
        if (f.existsSync()) {
          final content = f.readAsStringSync();
          if (content.isNotEmpty) {
            final List<dynamic> decoded = jsonDecode(content);
            final matching = decoded.firstWhere(
              (o) => o['id'] == orderId,
              orElse: () => null,
            );
            if (matching != null) {
              _applyOrderUpdate(Map<String, dynamic>.from(matching));
              return;
            }
          }
        }
      }
    } catch (_) {}
  }

  void _applyOrderUpdate(Map<String, dynamic> orderData) {
    final newStage = orderData['stage'] as int? ?? 0;
    final driverName = orderData['acceptedByName'] as String?
        ?? orderData['acceptedBy'] as String?
        ?? '';

    if (!mounted) return;

    // Update live orders stage in state
    FoodMelaState().updateOrderStatusStage(
      orderData['id'] as String? ?? '',
      newStage,
    );

    setState(() {
      _orderStatusStage = newStage.clamp(0, _stages.length - 1);
      if (driverName.isNotEmpty) _driverName = driverName;
    });

    // Show one-time snackbar when driver first accepts
    if (newStage >= 1 && !_hasNotifiedAcceptance) {
      _hasNotifiedAcceptance = true;
      final name = _driverName.isNotEmpty ? _driverName : 'a driver';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 4),
        content: Text(
          '🛵 Order accepted by $name! Kitchen is preparing your food 🍳',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ));
    }

    // Auto-navigate to past orders when delivered
    if (newStage >= 3 && mounted) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.home, (route) => false,
          );
        }
      });
    }
  }

  // ─── CANCEL ORDER ─────────────────────────────────────────────────────────
  void _showCancelOrderDialog() {
    final liveOrders = FoodMelaState().liveOrders;
    final activeOrder = liveOrders.isNotEmpty ? liveOrders.first : null;
    final orderId = activeOrder?['id'] as String? ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Text('Cancel Order?',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to cancel Order #$orderId?\nDriver will receive an instant cancellation alert.',
          style: GoogleFonts.inter(fontSize: 13, color: FoodMelaaColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('NO, KEEP ORDER',
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _cancelOrder(orderId, activeOrder);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('YES, CANCEL ❌',
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOrder(String orderId, Map<String, dynamic>? order) async {
    // Remove from local state
    FoodMelaState().cancelOrder(orderId);

    // Stop the global timer
    _globalCancelTimer?.cancel();
    _globalTimerStarted = false;
    _globalCancelSeconds = 0;

    // Build cancelled order data
    final cancelData = {
      'id': orderId,
      'customerName': order?['customerName'] ?? 'Customer',
      'address': order?['address'] ?? '',
      'items': order?['items'] ?? '',
      'total': order?['total'] ?? '₹0',
      'status': 'CANCELLED BY CUSTOMER 🚨',
      'stage': -1,
      'cancelledAt': DateTime.now().toIso8601String(),
    };

    // ── Write to shared file (Driver App will pick this up) ─────────────
    try {
      final jsonStr = jsonEncode([cancelData]);
      final paths = [
        '/sdcard/Download/food_mela_pending_orders.json',
        '/storage/emulated/0/Download/food_mela_pending_orders.json',
        '${Directory.systemTemp.path}/food_mela_pending_orders.json',
      ];
      for (final path in paths) {
        try { File(path).writeAsStringSync(jsonStr); } catch (_) {}
      }
    } catch (_) {}



    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (r) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Order #$orderId Cancelled! Driver notified 🚨',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      );
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final safeStage = _orderStatusStage.clamp(0, _stages.length - 1);
    final stageInfo = _stages[safeStage];
    final liveOrders = FoodMelaState().liveOrders;
    final activeOrder = liveOrders.isNotEmpty ? liveOrders.first : null;
    final orderId = activeOrder?['id'] as String? ?? activeOrder?['orderId'] as String? ?? 'FM-XXXX';

    // 🔒 Dynamic 2-minute (120 sec) cancellation window calculated from order placedAt timestamp
    int cancelSecs = 0;
    if (activeOrder != null) {
      final placedAtStr = activeOrder['placedAt'] as String?;
      if (placedAtStr != null && placedAtStr.isNotEmpty) {
        try {
          final placedAt = DateTime.parse(placedAtStr);
          final elapsedSecs = DateTime.now().difference(placedAt).inSeconds;
          cancelSecs = (120 - elapsedSecs).clamp(0, 120);
        } catch (_) {
          cancelSecs = _globalCancelSeconds;
        }
      } else {
        cancelSecs = _globalCancelSeconds;
      }
    } else {
      cancelSecs = _globalCancelSeconds;
    }

    final currentStage = (activeOrder?['stage'] as int?) ?? _orderStatusStage;
    final canCancel = cancelSecs > 0 && currentStage <= 0;

    return Scaffold(
      backgroundColor: FoodMelaaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: FoodMelaaColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Live Order Status 📦',
          style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.bold, color: FoodMelaaColors.textDark),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Animated map background
            AnimatedBuilder(
              animation: _riderProgress,
              builder: (context, child) {
                return Stack(
                  children: [
                    Container(
                      color: const Color(0xFFE2E8F0),
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: LiveRiderMapPainter(riderProgress: _riderProgress.value),
                      ),
                    ),

                    // Top stage banner
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (stageInfo['color'] as Color).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                stageInfo['icon'] as IconData,
                                color: stageInfo['color'] as Color,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    stageInfo['title'] as String,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: stageInfo['color'] as Color,
                                    ),
                                  ),
                                  Text(
                                    _orderStatusStage >= 1 && _driverName.isNotEmpty
                                        ? 'Driver $_driverName • ${stageInfo['sub']}'
                                        : stageInfo['sub'] as String,
                                    style: GoogleFonts.inter(
                                        fontSize: 11, color: FoodMelaaColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // Bottom info sheet
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Order #$orderId 📝',
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (stageInfo['color'] as Color).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'STAGE ${safeStage + 1}/4',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: stageInfo['color'] as Color,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 4-stage progress bar
                    Row(
                      children: List.generate(4, (index) {
                        final isPassed = index <= _orderStatusStage;
                        final isCurrent = index == _orderStatusStage;
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            height: 6,
                            decoration: BoxDecoration(
                              color: isPassed
                                  ? (isCurrent ? Colors.blue : Colors.green)
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'Stage ${safeStage + 1} of 4: ${stageInfo['title']}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: stageInfo['color'] as Color,
                      ),
                    ),

                    const Divider(height: 20),

                    // Cancel button (with live countdown)
                    if (canCancel) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _showCancelOrderDialog,
                          icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                          label: Text(
                            'CANCEL ORDER ❌  (${cancelSecs ~/ 60}:${(cancelSecs % 60).toString().padLeft(2, '0')})',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.red),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_off_rounded,
                                color: Colors.amber, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '2-min cancellation window closed ⏱️',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LiveRiderMapPainter extends CustomPainter {
  final double riderProgress;
  LiveRiderMapPainter({required this.riderProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFF1F5F9);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 24
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.15, size.height * 0.2);
    path.cubicTo(
      size.width * 0.5, size.height * 0.1,
      size.width * 0.2, size.height * 0.6,
      size.width * 0.85, size.height * 0.75,
    );
    canvas.drawPath(path, roadPaint);

    final routeLinePaint = Paint()
      ..color = const Color(0xFF059669)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, routeLinePaint);
  }

  @override
  bool shouldRepaint(covariant LiveRiderMapPainter oldDelegate) =>
      oldDelegate.riderProgress != riderProgress;
}
