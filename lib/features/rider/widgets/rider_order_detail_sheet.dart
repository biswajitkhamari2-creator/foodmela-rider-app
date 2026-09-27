import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:food_track/core/theme/food_melaa_colors.dart';
import 'package:food_track/features/calling/call_helper.dart';
import 'package:food_track/features/rider/models/rider_order_model.dart';

class RiderOrderDetailSheet extends StatelessWidget {
  final Map<String, dynamic> orderData;
  final String orderId;
  final String riderId;
  final bool isActiveDelivery;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onOpenActiveDelivery;

  const RiderOrderDetailSheet({
    super.key,
    required this.orderData,
    required this.orderId,
    required this.riderId,
    this.isActiveDelivery = false,
    this.onAccept,
    this.onReject,
    this.onOpenActiveDelivery,
  });

  static void show(
    BuildContext context, {
    required Map<String, dynamic> orderData,
    required String orderId,
    required String riderId,
    bool isActiveDelivery = false,
    VoidCallback? onAccept,
    VoidCallback? onReject,
    VoidCallback? onOpenActiveDelivery,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RiderOrderDetailSheet(
        orderData: orderData,
        orderId: orderId,
        riderId: riderId,
        isActiveDelivery: isActiveDelivery,
        onAccept: onAccept,
        onReject: onReject,
        onOpenActiveDelivery: onOpenActiveDelivery,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final customerName = (orderData['customerName'] as String?)?.trim().isNotEmpty == true
        ? orderData['customerName'] as String
        : 'FoodMela Customer';
    final rawPhone = (orderData['customerPhone'] ?? orderData['phone'] ?? '').toString();
    final maskedPhone = RiderOrderModel.maskPhone(rawPhone);
    final rawAddress = orderData['address'] as String? ?? 'Delivery address not provided';
    final address = RiderOrderModel.cleanAddress(rawAddress);
    final totalAmount = (orderData['totalAmount'] as num?)?.toDouble() ??
        (double.tryParse('${orderData['amountValue'] ?? orderData['total'] ?? 0}') ?? 0.0);
    final isPrepaid = RiderOrderModel.isPrepaid(orderData);
    final items = RiderOrderModel.parseItems(orderData);
    final catKey = (orderData['orderCategory'] as String? ?? 'general').toLowerCase();
    final catLabel = orderData['orderCategoryLabel'] as String? ?? catKey.toUpperCase();
    final catColor = FoodMelaaColors.categoryColor(catKey);
    final specialInstructions = (orderData['specialInstructions'] as String?)?.trim();

    final deliveryLat = (orderData['deliveryLat'] as num?)?.toDouble();
    final deliveryLng = (orderData['deliveryLng'] as num?)?.toDouble();

    int stage = 0;
    final rawStage = orderData['stage'];
    if (rawStage is num) {
      stage = rawStage.toInt();
    } else if (rawStage is String) {
      stage = int.tryParse(rawStage) ?? 0;
    }

    final placedTimeStr = RiderOrderModel.formatTimestamp(orderData['createdAt'] ?? orderData['placedAt']);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14171E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top drag pill
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: catColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        catLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: catColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Order #${orderId.length > 8 ? orderId.substring(orderId.length - 8) : orderId}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : FoodMelaaColors.textDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: orderId));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Order ID copied to clipboard'),
                                      duration: Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                child: const Icon(Icons.copy_rounded, size: 14, color: FoodMelaaColors.textGrey),
                              ),
                            ],
                          ),
                          Text(
                            'Placed $placedTimeStr',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: FoodMelaaColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      color: isDark ? Colors.white70 : FoodMelaaColors.textSecondary,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              Divider(color: isDark ? Colors.white10 : const Color(0xFFF1F5F9), height: 1),

              // Scrollable Body
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  children: [
                    // ── Status Stepper ──────────────────────────────────────
                    _buildStatusProgress(stage, isDark),
                    const SizedBox(height: 18),

                    // ── Customer Details Tile ───────────────────────────────
                    _buildSectionHeader('CUSTOMER DETAILS', Icons.person_rounded),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
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
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customerName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : FoodMelaaColors.textDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  maskedPhone,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: FoodMelaaColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
if (rawPhone.isNotEmpty && rawPhone != 'N/A') ...[
                            const SizedBox(width: 8),
                            // Direct Phone Dialer Fallback
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.dialer_sip_rounded, color: Color(0xFF3B82F6), size: 20),
                                tooltip: 'Phone Dialer',
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
                    ),

                    const SizedBox(height: 18),

                    // ── Delivery Location Tile ──────────────────────────────
                    _buildSectionHeader('DELIVERY LOCATION', Icons.location_on_rounded),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.navigation_rounded, color: Color(0xFFDC2626), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  address,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : FoodMelaaColors.textDark,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (deliveryLat != null && deliveryLng != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.my_location_rounded, size: 14, color: Color(0xFF059669)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Accurate Customer GPS Pin Available',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _openMaps(deliveryLat, deliveryLng, address),
                              icon: const Icon(Icons.directions_rounded, size: 18),
                              label: const Text('Open in Google Maps / Directions'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF059669),
                                side: const BorderSide(color: Color(0xFF059669), width: 1.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (specialInstructions != null && specialInstructions.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _buildSectionHeader('DELIVERY INSTRUCTIONS', Icons.notes_rounded),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                specialInstructions,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF92400E),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // ── ORDER ITEMS LIST (DETAILED) ─────────────────────────
                    Row(
                      children: [
                        const Icon(Icons.lunch_dining_rounded, size: 16, color: FoodMelaaColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'ORDERED FOOD ITEMS',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: isDark ? Colors.white70 : const Color(0xFF64748B),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: FoodMelaaColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: FoodMelaaColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < items.length; i++) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  // Qty Pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: FoodMelaaColors.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: FoodMelaaColors.primary.withValues(alpha: 0.25)),
                                    ),
                                    child: Text(
                                      '${items[i].quantity}x',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: FoodMelaaColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Item Name & Unit
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          items[i].name,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : FoodMelaaColors.textDark,
                                          ),
                                        ),
                                        if (items[i].unit.isNotEmpty)
                                          Text(
                                            items[i].unit,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: FoodMelaaColors.textSecondary,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (items[i].price != null && items[i].price! > 0)
                                    Text(
                                      '₹${(items[i].price! * items[i].quantity).toInt()}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : FoodMelaaColors.textDark,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (i < items.length - 1)
                              Divider(
                                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                                height: 1,
                                indent: 14,
                                endIndent: 14,
                              ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Payment & Earnings Card ─────────────────────────────
                    _buildSectionHeader('PAYMENT & RIDER EARNINGS', Icons.account_balance_wallet_rounded),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Payment Mode',
                                style: GoogleFonts.inter(fontSize: 13, color: FoodMelaaColors.textSecondary),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isPrepaid
                                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                      : const Color(0xFFD97706).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isPrepaid
                                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                        : const Color(0xFFD97706).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  isPrepaid ? 'PAID ONLINE (PREPAID)' : 'CASH ON DELIVERY (COD)',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isPrepaid ? const Color(0xFF059669) : const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Order Value',
                                style: GoogleFonts.inter(fontSize: 13, color: FoodMelaaColors.textSecondary),
                              ),
                              Text(
                                '₹${totalAmount.toInt()}',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : FoodMelaaColors.textDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), height: 1),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.electric_moped_rounded, color: Color(0xFF059669), size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Your Delivery Payout',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF059669),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '+ ₹40.00',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14171E) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      if (!isActiveDelivery && stage == 0) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              onReject?.call();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: FoodMelaaColors.textSecondary,
                              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              'Reject',
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              onAccept?.call();
                            },
                            icon: const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                            label: Text(
                              'Accept Order',
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FoodMelaaColors.riderPrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ] else if (isActiveDelivery) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              onOpenActiveDelivery?.call();
                            },
                            icon: const Icon(Icons.navigation_rounded, size: 20, color: Colors.white),
                            label: Text(
                              'Open Active Delivery Screen',
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FoodMelaaColors.riderPrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              'Close',
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: FoodMelaaColors.riderPrimary),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusProgress(int stage, bool isDark) {
    final steps = ['Placed', 'Accepted', 'Out for Delivery', 'Delivered'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= stage ? const Color(0xFF10B981) : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      i <= stage ? Icons.check_rounded : Icons.circle_outlined,
                      size: 16,
                      color: i <= stage ? Colors.white : FoodMelaaColors.textGrey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    steps[i],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: i == stage ? FontWeight.w700 : FontWeight.w500,
                      color: i <= stage ? (isDark ? Colors.white : FoodMelaaColors.textDark) : FoodMelaaColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            if (i < steps.length - 1)
              Container(
                width: 20,
                height: 2,
                color: i < stage ? const Color(0xFF10B981) : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              ),
          ],
        ],
      ),
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
