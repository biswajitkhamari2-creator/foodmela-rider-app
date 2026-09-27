import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:food_track/core/theme/food_melaa_colors.dart';
import 'package:food_track/features/calling/call_launcher.dart';
import 'package:food_track/features/rider/models/rider_order_model.dart';
import 'package:food_track/features/rider/widgets/rider_order_detail_sheet.dart';

class RiderOrderCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  final String riderId;
  final bool isActiveDelivery;
  final bool isAccepting;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onOpenActiveDelivery;

  const RiderOrderCard({
    super.key,
    required this.data,
    required this.docId,
    required this.riderId,
    this.isActiveDelivery = false,
    this.isAccepting = false,
    this.onAccept,
    this.onReject,
    this.onOpenActiveDelivery,
  });

  @override
  State<RiderOrderCard> createState() => _RiderOrderCardState();
}

class _RiderOrderCardState extends State<RiderOrderCard> {
  bool _isItemsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final orderId = widget.data['orderId'] as String? ?? widget.docId;
    final customerName = (widget.data['customerName'] as String?)?.trim().isNotEmpty == true
        ? widget.data['customerName'] as String
        : 'FoodMela Customer';
    final rawPhone = (widget.data['customerPhone'] ?? widget.data['phone'] ?? '').toString();
    final maskedPhone = RiderOrderModel.maskPhone(rawPhone);
    final rawAddress = widget.data['address'] as String? ?? 'Delivery address not provided';
    final address = RiderOrderModel.cleanAddress(rawAddress);
    final totalAmount = (widget.data['totalAmount'] as num?)?.toDouble() ??
        (double.tryParse('${widget.data['amountValue'] ?? widget.data['total'] ?? 0}') ?? 0.0);
    final isPrepaid = RiderOrderModel.isPrepaid(widget.data);
    final items = RiderOrderModel.parseItems(widget.data);
    final catKey = (widget.data['orderCategory'] as String? ?? 'general').toLowerCase();
    final catLabel = widget.data['orderCategoryLabel'] as String? ?? catKey.toUpperCase();
    final catColor = FoodMelaaColors.categoryColor(catKey);

    final deliveryLat = (widget.data['deliveryLat'] as num?)?.toDouble();
    final deliveryLng = (widget.data['deliveryLng'] as num?)?.toDouble();

    int stage = 0;
    final rawStage = widget.data['stage'];
    if (rawStage is num) {
      stage = rawStage.toInt();
    } else if (rawStage is String) {
      stage = int.tryParse(rawStage) ?? 0;
    }

    final statusStr = (widget.data['status'] as String? ?? '').toLowerCase();
    final isCancelled = stage == -1 || statusStr.contains('cancel');

    final placedTimeStr = RiderOrderModel.formatTimestamp(
      widget.data['createdAt'] ?? widget.data['placedAt'],
    );

    final stageColor = isCancelled
        ? FoodMelaaColors.error
        : stage == 0
            ? FoodMelaaColors.riderPrimary
            : stage == 1
                ? const Color(0xFFD97706)
                : stage == 2
                    ? const Color(0xFF059669)
                    : const Color(0xFF10B981);

    final stageText = isCancelled
        ? 'Cancelled'
        : stage == 0
            ? 'New Order'
            : stage == 1
                ? 'Accepted'
                : stage == 2
                    ? 'Out for Delivery'
                    : 'Delivered';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isActiveDelivery
              ? FoodMelaaColors.riderPrimary.withValues(alpha: 0.5)
              : (isDark ? const Color(0xFF2B2F3A) : const Color(0xFFE2E8F0)),
          width: widget.isActiveDelivery ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openDetailsSheet(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. TOP HEADER SECTION ───────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF222631) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xFF2D323E) : const Color(0xFFEDF2F7),
                    ),
                  ),
                ),
                // Two-row header: never squeezes text into vertical strips.
                // Row 1: order ID (flexible) + status badge (fixed).
                // Row 2: category tag + placed time.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Order ID — FULL official number, wraps instead of
                        // truncating. Expanded is the ONLY flexible child here
                        // so nothing else gets crushed to zero width.
                        Expanded(
                          child: Text(
                            '#$orderId',
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : FoodMelaaColors.textDark,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status Badge — Flexible with ellipsis so long labels
                        // (e.g. OUT FOR DELIVERY) shrink gracefully, never push
                        // siblings off-screen or render letter-by-letter.
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: stageColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: stageColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: stageColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    stageText.toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: stageColor,
                                      letterSpacing: 0.4,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Category Tag
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: catColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              catLabel,
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: catColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Placed Time
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time_rounded, size: 13, color: FoodMelaaColors.textGrey),
                            const SizedBox(width: 4),
                            Text(
                              placedTimeStr,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: FoodMelaaColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── 2. CUSTOMER & DELIVERY INFO SECTION ────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Column(
                  children: [
                    // Customer Row
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                            ),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customerName,
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : FoodMelaaColors.textDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                maskedPhone,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: FoodMelaaColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // One-Tap VoIP Call Button
                        Container(
                          height: 36,
                          width: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF10B981), size: 18),
                            tooltip: 'In-App Call Customer',
                            onPressed: () {
                              CallLauncher.placeCall(
                                context: context,
                                orderId: orderId,
                                myId: widget.riderId,
                                myRole: 'rider',
                                peerLabel: 'FoodMela Customer',
                              );
                            },
                          ),
                        ),
                        if (rawPhone.isNotEmpty && rawPhone != 'N/A') ...[
                          const SizedBox(width: 8),
                          // Phone dialer
                          Container(
                            height: 36,
                            width: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.dialer_sip_rounded, color: Color(0xFF3B82F6), size: 18),
                              tooltip: 'Phone Call',
                              onPressed: () async {
                                final uri = Uri.parse('tel:$rawPhone');
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                }
                              },
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Delivery Address Row
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF222631) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.location_on_rounded, size: 16, color: Color(0xFFDC2626)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  address,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : FoodMelaaColors.textDark,
                                    height: 1.35,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (deliveryLat != null && deliveryLng != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF059669).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '📍 LIVE GPS PIN',
                                          style: GoogleFonts.poppins(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF059669),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.near_me_rounded, color: Color(0xFF059669), size: 18),
                            tooltip: 'Directions',
                            onPressed: () => _openMaps(deliveryLat, deliveryLng, address),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Payment Badge Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isPrepaid
                                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                : const Color(0xFFD97706).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPrepaid ? Icons.check_circle_outline_rounded : Icons.payments_outlined,
                                size: 12,
                                color: isPrepaid ? const Color(0xFF059669) : const Color(0xFFD97706),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isPrepaid ? 'PAID ONLINE (PREPAID)' : 'CASH ON DELIVERY (COD)',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isPrepaid ? const Color(0xFF059669) : const Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (widget.data['specialInstructions'] != null &&
                            (widget.data['specialInstructions'] as String).trim().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.note_alt_rounded, size: 12, color: Color(0xFF7C3AED)),
                                const SizedBox(width: 4),
                                Text(
                                  'Note included',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF7C3AED),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── 3. FOOD ITEMS SECTION (ITEMIZED) ───────────────────────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF222631) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.restaurant_menu_rounded, size: 14, color: FoodMelaaColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'ORDER ITEMS (${items.length})',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: isDark ? Colors.white70 : const Color(0xFF64748B),
                          ),
                        ),
                        const Spacer(),
                        if (items.length > 2)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isItemsExpanded = !_isItemsExpanded;
                              });
                            },
                            child: Row(
                              children: [
                                Text(
                                  _isItemsExpanded ? 'Show less' : 'View all ${items.length}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: FoodMelaaColors.primary,
                                  ),
                                ),
                                Icon(
                                  _isItemsExpanded ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
                                  size: 18,
                                  color: FoodMelaaColors.primary,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Render list of items
                    ...() {
                      final countToShow = _isItemsExpanded ? items.length : items.length.clamp(0, 2);
                      final List<Widget> rows = [];
                      for (int i = 0; i < countToShow; i++) {
                        final item = items[i];
                        rows.add(
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Qty pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: FoodMelaaColors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${item.quantity}x',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: FoodMelaaColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : FoodMelaaColors.textDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (item.price != null && item.price! > 0)
                                  Text(
                                    '₹${(item.price! * item.quantity).toInt()}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }
                      return rows;
                    }(),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── 4. AMOUNT & EARNINGS ROW ────────────────────────────────
              // Flexible on both sides: on narrow screens the total shrinks
              // with ellipsis instead of pushing the earning pill off-screen
              // (the "RIGHT OVERFLOWED BY 15 PIXELS" crash).
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Text(
                            'Order Total: ',
                            style: TextStyle(
                              fontSize: 12,
                              color: FoodMelaaColors.textSecondary,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              '₹${totalAmount.toInt()}',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : FoodMelaaColors.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+ ₹40.00 Earning',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── 5. ACTION BUTTONS ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    if (!widget.isActiveDelivery && stage == 0) ...[
                      // REJECT BUTTON — Flexible (not Expanded): label keeps
                      // natural width, never forces siblings off-screen.
                      Flexible(
                        flex: 3,
                        fit: FlexFit.tight,
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton(
                            onPressed: widget.isAccepting ? null : widget.onReject,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: FoodMelaaColors.textSecondary,
                              side: BorderSide(
                                color: isDark ? const Color(0xFF2D323E) : FoodMelaaColors.borderGrey,
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(
                              'Reject',
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // ACCEPT BUTTON
                      Flexible(
                        flex: 5,
                        fit: FlexFit.tight,
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: widget.isAccepting ? null : widget.onAccept,
                            icon: widget.isAccepting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                            label: Flexible(
                              child: Text(
                                widget.isAccepting ? 'Accepting...' : 'Accept Order',
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FoodMelaaColors.riderPrimary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // VIEW DETAILS ICON
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF222631) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.info_outline_rounded, size: 20, color: FoodMelaaColors.riderPrimary),
                          tooltip: 'View Full Details',
                          onPressed: () => _openDetailsSheet(context),
                        ),
                      ),
                    ] else if (widget.isActiveDelivery) ...[
                      // ACTIVE DELIVERY ACTION
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: widget.onOpenActiveDelivery,
                            icon: const Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
                            label: Text(
                              'View Active Delivery',
                              style: GoogleFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF222631) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.info_outline_rounded, size: 20, color: Color(0xFF059669)),
                          tooltip: 'View Full Details',
                          onPressed: () => _openDetailsSheet(context),
                        ),
                      ),
                    ] else ...[
                      // COMPLETED OR OTHER
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: OutlinedButton.icon(
                            onPressed: () => _openDetailsSheet(context),
                            icon: const Icon(Icons.receipt_long_rounded, size: 18),
                            label: const Text('View Full Receipt & Details'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: FoodMelaaColors.riderPrimary,
                              side: const BorderSide(color: FoodMelaaColors.riderPrimary, width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetailsSheet(BuildContext context) {
    final orderId = widget.data['orderId'] as String? ?? widget.docId;
    RiderOrderDetailSheet.show(
      context,
      orderData: widget.data,
      orderId: orderId,
      riderId: widget.riderId,
      isActiveDelivery: widget.isActiveDelivery,
      onAccept: widget.onAccept,
      onReject: widget.onReject,
      onOpenActiveDelivery: widget.onOpenActiveDelivery,
    );
  }

  static Future<void> _openMaps(double? lat, double? lng, String address) async {
    Uri uri;
    if (lat != null && lng != null) {
      uri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
      if (!await canLaunchUrl(uri)) {
        uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
      }
    } else {
      final query = Uri.encodeComponent(address);
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
