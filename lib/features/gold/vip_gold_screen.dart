import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/food_melaa_colors.dart';

class VipGoldScreen extends StatelessWidget {
  const VipGoldScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Crown Badge
              Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: FoodMelaaColors.gold,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  size: 50,
                  color: Colors.black,
                ),
              ),

              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'FOOD MELAA ',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'VIP',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: FoodMelaaColors.gold,
                    ),
                  ),
                ],
              ),

              Text(
                'Unlock VIP privileges on Food Delivery & Dining Out',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey.shade400,
                ),
              ),

              const SizedBox(height: 32),

              // Benefit Cards
              _buildBenefitRow(Icons.local_shipping_rounded, 'FREE DELIVERY', 'On all orders above ₹199 from top restaurants'),
              const SizedBox(height: 14),
              _buildBenefitRow(Icons.restaurant_rounded, 'UP TO 40% OFF DINING', 'Extra discounts on dining out bills at 500+ spots'),
              const SizedBox(height: 14),
              _buildBenefitRow(Icons.bolt_rounded, 'VIP PRIORITY DISPATCH', 'Your order gets assigned to top rated riders first'),

              const SizedBox(height: 36),

              // Plan Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF242424),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: FoodMelaaColors.gold, width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('3 MONTHS VIP', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('₹99 Special Inaugural Offer', style: GoogleFonts.inter(fontSize: 12, color: FoodMelaaColors.gold)),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FoodMelaaColors.gold,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('JOIN NOW', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: Colors.black)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: FoodMelaaColors.gold, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(desc, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade400)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
