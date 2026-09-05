import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/food_melaa_colors.dart';
import 'package:food_track/core/state/food_mela_state.dart';

class OrdersScreen extends StatefulWidget {
  final FoodMelaState? state;
  const OrdersScreen({super.key, this.state});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.state ?? FoodMelaState();

    return Scaffold(
      backgroundColor: FoodMelaaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'My Orders 📦',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: FoodMelaaColors.textDark,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: FoodMelaaColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: FoodMelaaColors.primary,
          labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Active Orders 🔴'),
            Tab(text: 'Past Orders ✅'),
          ],
        ),
      ),
      body: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              // ── Active Orders Tab ──────────────────────────────────────
              _buildOrderList(
                orders: appState.liveOrders,
                emptyMessage: 'No active orders right now.\nPlace a new order from the home screen!',
                emptyIcon: Icons.delivery_dining_rounded,
                isActive: true,
              ),
              // ── Past Orders Tab ────────────────────────────────────────
              // Order history is IMMUTABLE — neither customer nor driver can delete
              _buildOrderList(
                orders: appState.pastOrders,
                emptyMessage: 'No past orders yet.\nYour order history is permanently safe here 🔒',
                emptyIcon: Icons.receipt_long_rounded,
                isActive: false,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrderList({
    required List<Map<String, dynamic>> orders,
    required String emptyMessage,
    required IconData emptyIcon,
    required bool isActive,
  }) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: FoodMelaaColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(emptyIcon, size: 56, color: FoodMelaaColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              emptyMessage,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 🔒 LOCK BANNER — shown on Past Orders tab only
        if (!isActive)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_rounded, size: 16, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Order history is permanently protected. Cannot be deleted by anyone.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              // 🔒 GestureDetector blocks long-press context menu (no delete option)
              return GestureDetector(
                onLongPress: () {
                  // Intentionally empty — no context menu, no delete option
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.green.shade700,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      content: Row(
                        children: [
                          const Icon(Icons.lock_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Order history cannot be deleted 🔒',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: _buildOrderCard(order, isActive),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, bool isActive) {
    final orderId = order['orderId'] as String? ?? order['id'] as String? ?? 'FM-XXXX';
    final items = order['items'] as String? ?? 'Items not available';
    final total = order['total'] as String? ?? '₹0';
    final address = order['address'] as String? ?? 'Address not set';
    final status = order['status'] as String? ?? 'Order Placed';
    final stage = order['stage'] as int? ?? 0;
    final placedAt = order['placedAt'] as String? ?? order['cancelledAt'] as String? ?? '';

    Color statusColor;
    if (stage == -1) {
      statusColor = Colors.red;
    } else if (stage == 3) {
      statusColor = Colors.green;
    } else if (stage == 2) {
      statusColor = Colors.orange;
    } else if (stage == 1) {
      statusColor = Colors.blue;
    } else {
      statusColor = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #$orderId',
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Items
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shopping_bag_outlined,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        items,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.grey.shade700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Address
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        address,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.grey.shade700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      total,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: FoodMelaaColors.primary,
                      ),
                    ),
                    if (placedAt.isNotEmpty)
                      Text(
                        _formatDate(placedAt),
                        style: GoogleFonts.inter(
                            fontSize: 10, color: Colors.grey.shade500),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
