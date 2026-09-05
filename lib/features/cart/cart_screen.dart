import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/food_melaa_colors.dart';
import 'package:food_track/core/utils/routes.dart';
import 'package:food_track/core/services/firebase_service.dart';
import 'package:food_track/core/state/food_mela_state.dart';
import 'package:food_track/core/data/food_mela_data.dart';

class CartScreen extends StatefulWidget {
  final FoodMelaState state;
  const CartScreen({super.key, required this.state});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, child) {
        final cart = widget.state.cart;
        final subtotal = widget.state.cartSubtotal;
        final deliveryFee = widget.state.deliveryFee;
        final grandTotal = widget.state.grandTotal;

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
              'Your Cart 🛒 (${widget.state.totalCartCount} items)',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: FoodMelaaColors.textDark),
            ),
            actions: [
              if (cart.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    widget.state.clearCart();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cart Cleared 🗑️')),
                    );
                  },
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                  label: Text('Clear All', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                ),
            ],
          ),
          body: SafeArea(
            child: cart.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              color: FoodMelaaColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.shopping_cart_outlined, size: 64, color: FoodMelaaColors.primary),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Your Cart is Empty 🛒',
                            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: FoodMelaaColors.textDark),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add cooked food, sweets, or grocery items to place your order.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 13, color: FoodMelaaColors.textSecondary),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FoodMelaaColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            ),
                            child: Text(
                              'Browse Food & Fresh Essentials ➔',
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order Items (${cart.length})',
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),

                        // Cart Items List
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: cart.entries.map((entry) {
                              final parts = entry.key.split('::');
                              final itemId = parts[0];
                              final unit = parts.length > 1 ? parts[1] : '1 unit';
                              final qty = entry.value;

                              final matchedItem = FoodMelaData.allFoodItems.firstWhere(
                                (i) => i.id == itemId,
                                orElse: () => FoodItem(
                                  id: itemId,
                                  name: itemId.replaceAll('_', ' ').toUpperCase(),
                                  category: 'cooked_food',
                                  price: 50,
                                  rating: 4.5,
                                  image: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500&h=350&fit=crop',
                                  isVeg: true,
                                ),
                              );

                              final itemPriceTotal = matchedItem.price * qty;

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        matchedItem.image,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          width: 50,
                                          height: 50,
                                          color: Colors.grey.shade200,
                                          child: const Icon(Icons.fastfood_rounded, color: Colors.grey, size: 24),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            matchedItem.name,
                                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            'Unit: $unit • ₹${matchedItem.price.toInt()} each',
                                            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                                          ),
                                          Text(
                                            'Total: ₹${itemPriceTotal.toInt()}',
                                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: FoodMelaaColors.primary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Minus / Plus Controls
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red, size: 20),
                                      onPressed: () {
                                        widget.state.removeItemFromCart(itemId, unit);
                                      },
                                    ),
                                    Text('$qty', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.green, size: 20),
                                      onPressed: () {
                                        widget.state.addItemToCart(itemId, unit);
                                      },
                                    ),
                                    // Trash Icon
                                    IconButton(
                                      icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 22),
                                      onPressed: () {
                                        widget.state.removeItemFromCart(itemId, unit);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Item deleted from cart 🗑️')),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Bill Details
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bill Summary', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Subtotal', style: GoogleFonts.inter(fontSize: 13)),
                                  Text('₹${subtotal.toInt()}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Delivery Fee', style: GoogleFonts.inter(fontSize: 13)),
                                  Text(
                                    deliveryFee == 0 ? 'FREE 🎉' : '₹${deliveryFee.toInt()}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: deliveryFee == 0 ? Colors.green : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Grand Total', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold)),
                                  Text(
                                    '₹${grandTotal.toInt()}',
                                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w900, color: FoodMelaaColors.primary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Place Order Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () => _showDeliveryAddressCheckoutModal(context, grandTotal, cart),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FoodMelaaColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text(
                              'SELECT ADDRESS & PLACE ORDER ➔ (₹${grandTotal.toInt()})',
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  void _showDeliveryAddressCheckoutModal(BuildContext context, double grandTotal, Map<String, int> cart) {
    String selectedAddressType = 'Current GPS Location 📍';
    String deliveryInstruction = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: FoodMelaaColors.primary, size: 28),
                  const SizedBox(width: 10),
                  Text('Confirm Delivery Address 📍', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 14),

              Text('SELECT SAVED ADDRESS:', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
              const SizedBox(height: 8),

              _buildCheckoutAddressOption(
                type: 'Current GPS Location 📍',
                address: widget.state.selectedAddress,
                selectedType: selectedAddressType,
                onSelect: (val) => setModalState(() => selectedAddressType = val),
              ),
              _buildCheckoutAddressOption(
                type: 'Home 🏠',
                address: 'Flat 302, Saheed Nagar, Janpath Road, Bhubaneswar',
                selectedType: selectedAddressType,
                onSelect: (val) => setModalState(() => selectedAddressType = val),
              ),
              _buildCheckoutAddressOption(
                type: 'Work / Office 🏢',
                address: 'Plot 142, Master Canteen Square, Bhubaneswar',
                selectedType: selectedAddressType,
                onSelect: (val) => setModalState(() => selectedAddressType = val),
              ),

              const SizedBox(height: 10),

              // Add New Address Button
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.mapPicker);
                },
                icon: const Icon(Icons.add_location_alt_rounded, size: 16, color: FoodMelaaColors.primary),
                label: Text('+ ADD / PICK NEW ADDRESS ON MAP 📍', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: FoodMelaaColors.primary)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: FoodMelaaColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),

              const SizedBox(height: 14),

              // Instructions Field
              TextField(
                onChanged: (val) => deliveryInstruction = val,
                decoration: InputDecoration(
                  labelText: 'Delivery Instructions (e.g. Ring bell twice)',
                  prefixIcon: const Icon(Icons.note_alt_outlined, color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final itemsList = cart.entries.map((e) {
                      final parts = e.key.split('::');
                      return {
                        'itemId': parts[0],
                        'unit': parts.length > 1 ? parts[1] : '1 unit',
                        'quantity': e.value,
                      };
                    }).toList();

                    final finalAddress = selectedAddressType == 'Current GPS Location 📍' ? widget.state.selectedAddress : selectedAddressType;
                    final targetAddress = deliveryInstruction.isNotEmpty ? '$finalAddress (Note: $deliveryInstruction)' : finalAddress;

                    final itemsSummary = cart.entries.map((e) {
                      final parts = e.key.split('::');
                      final item = FoodMelaData.allFoodItems.firstWhere((i) => i.id == parts[0], orElse: () => FoodMelaData.allFoodItems.first);
                      return '${e.value}x ${item.name} (${parts.length > 1 ? parts[1] : 'unit'})';
                    }).join(', ');

                    widget.state.placeNewOrder(
                      address: targetAddress,
                      itemsSummary: itemsSummary,
                      totalAmount: grandTotal,
                    );

                    await FirebaseService.createOrder(
                      customerName: 'Customer',
                      address: targetAddress,
                      items: itemsList,
                      totalAmount: grandTotal,
                    );
                    widget.state.clearCart();
                    if (context.mounted) {
                      Navigator.pop(context); // Close modal
                      Navigator.pushNamed(context, AppRoutes.orderTracking);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FoodMelaaColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    'CONFIRM & PLACE ORDER ➔ (₹${grandTotal.toInt()})',
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckoutAddressOption({
    required String type,
    required String address,
    required String selectedType,
    required ValueChanged<String> onSelect,
  }) {
    final isSelected = selectedType == type;
    return GestureDetector(
      onTap: () => onSelect(type),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? FoodMelaaColors.primaryLight : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? FoodMelaaColors.primary : Colors.grey.shade300, width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: isSelected ? FoodMelaaColors.primary : Colors.grey, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(address, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade700), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
