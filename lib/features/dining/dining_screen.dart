import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/food_melaa_colors.dart';

class DiningScreen extends StatelessWidget {
  const DiningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FoodMelaaColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dining Out 🍽️',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: FoodMelaaColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Book tables & pay bills to get up to 40% OFF',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: FoodMelaaColors.textSecondary,
                ),
              ),

              const SizedBox(height: 16),

              // Promo Food Melaa Pay Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [FoodMelaaColors.primary, FoodMelaaColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.percent_rounded, color: Colors.white, size: 32),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Food Melaa Pay Offer',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Flat 30% OFF on dining bills at 500+ top restaurants in city',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'MUST VISIT COLLECTIONS',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: FoodMelaaColors.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildCollectionCard(
                      'Romantic Dining',
                      '12 Places',
                      'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400&h=300&fit=crop',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCollectionCard(
                      'Rooftop Spots',
                      '8 Places',
                      'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=400&h=300&fit=crop',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionCard(String title, String count, String img) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: DecorationImage(image: NetworkImage(img), fit: BoxFit.cover),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(count, style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
