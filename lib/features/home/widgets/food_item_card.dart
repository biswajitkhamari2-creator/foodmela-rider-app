import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/food_melaa_colors.dart';
import 'package:food_track/core/data/food_mela_data.dart';
import 'package:food_track/core/state/food_mela_state.dart';

class FoodItemCard extends StatelessWidget {
  final FoodItem item;
  final FoodMelaState state;

  const FoodItemCard({
    super.key,
    required this.item,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final currentUnit = state.getSelectedUnit(item);
    final qty = state.getItemQuantity(item.id, currentUnit);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Food Image with Veg/Non-Veg & Freshness Badge
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  item.image,
                  width: 105,
                  height: 105,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 105,
                    height: 105,
                    color: Colors.orange.shade50,
                    child: const Icon(Icons.shopping_basket_rounded, color: FoodMelaaColors.primary),
                  ),
                ),
              ),

              // Veg / Non-Veg Indicator Dot
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: item.isVeg ? FoodMelaaColors.vegGreen : FoodMelaaColors.nonVegRed,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.circle,
                    size: 8,
                    color: item.isVeg ? FoodMelaaColors.vegGreen : FoodMelaaColors.nonVegRed,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 14),

          // Details Section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: FoodMelaaColors.textDark,
                  ),
                ),

                const SizedBox(height: 2),

                // Rating & Freshness Tag
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: FoodMelaaColors.ratingGreen,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${item.rating}',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.star_rounded, size: 10, color: Colors.white),
                        ],
                      ),
                    ),
                    if (item.freshnessTag != null) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.freshnessTag!,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.green.shade800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 8),

                // Unit Selector Dropdown for Raw Products
                if (item.isRawItem && item.unitOptions.length > 1)
                  Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: currentUnit,
                        isDense: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: FoodMelaaColors.textDark),
                        onChanged: (newUnit) {
                          if (newUnit != null) {
                            state.setSelectedUnit(item.id, newUnit);
                          }
                        },
                        items: item.unitOptions.map((u) {
                          return DropdownMenuItem<String>(
                            value: u,
                            child: Text(u),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                const SizedBox(height: 8),

                // Price in ₹ & ADD / Quantity Counter Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '₹${item.price.toInt()}',
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: FoodMelaaColors.primary,
                          ),
                        ),
                        if (item.isRawItem)
                          Text(
                            ' / ${item.unit}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: FoodMelaaColors.textSecondary,
                            ),
                          ),
                      ],
                    ),

                    // ADD Button / Quantity Selector Key
                    qty == 0
                        ? SizedBox(
                            height: 34,
                            width: 76,
                            child: ElevatedButton(
                              onPressed: () => state.addItemToCart(item.id, currentUnit),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: FoodMelaaColors.primary,
                                elevation: 0,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'ADD',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            height: 34,
                            decoration: BoxDecoration(
                              color: FoodMelaaColors.primaryLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: FoodMelaaColors.primary),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 14, color: FoodMelaaColors.primary),
                                  onPressed: () => state.removeItemFromCart(item.id, currentUnit),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 34),
                                ),
                                Text(
                                  '$qty',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: FoodMelaaColors.primary,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 14, color: FoodMelaaColors.primary),
                                  onPressed: () => state.addItemToCart(item.id, currentUnit),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 34),
                                ),
                              ],
                            ),
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
}
