import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/app_colors.dart';

class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Live Delivery Tracking', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Delivery Timer Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D7377), Color(0xFF14A3A8)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D7377).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'ESTIMATED DELIVERY TIME',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '12 - 15 Mins',
                      style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Food is being prepared by chef at The Burger Lab',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Live Map Placeholder Card
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.map_rounded, size: 80, color: AppColors.primary),
                    Positioned(
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.navigation_rounded, color: AppColors.primary, size: 16),
                            const SizedBox(width: 6),
                            Text('Rider Amit is 1.2 km away', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Delivery Rider Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delivery_dining_rounded, color: Color(0xFF16A34A), size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Amit Kumar', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('Delivery Rider • Hero Scooter (OD 02 AB 1234)', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF16A34A)),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Calling Rider Amit...')),
                        );
                      },
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
}
