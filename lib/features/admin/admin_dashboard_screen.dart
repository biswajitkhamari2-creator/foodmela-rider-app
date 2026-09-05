import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F2),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Text('⚙️', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FoodTrack Admin',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A1614),
                        ),
                      ),
                      Text(
                        'System Overview & Platform Metrics',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF0EA5E9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Metrics Grid
              Row(
                children: [
                  _buildMetric('Total Revenue', '₹4,82,900', '+24%', const Color(0xFF0EA5E9)),
                  const SizedBox(width: 12),
                  _buildMetric('Active Orders', '148 Live', 'Across 3 cities', Colors.green),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildMetric('Restaurants', '1,240', '98% Active', const Color(0xFF7C3AED)),
                  const SizedBox(width: 12),
                  _buildMetric('Active Riders', '680 On Road', '96% SLA', Colors.orange),
                ],
              ),

              const SizedBox(height: 24),

              Text(
                'Top Performing Restaurants',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1614),
                ),
              ),

              const SizedBox(height: 12),

              _buildRestRow('The Burger Lab', 'Saheed Nagar', '1,420 orders', '4.8 ★'),
              _buildRestRow('Pizza Paradise', 'Chandrasekharpur', '1,280 orders', '4.7 ★'),
              _buildRestRow('Spice Route', 'Janpath', '980 orders', '4.6 ★'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(String title, String val, String sub, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 6),
            Text(val, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(sub, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
          ],
        ),
      ),
    );
  }

  Widget _buildRestRow(String name, String loc, String orders, String rating) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                Text(loc, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Text(orders, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(rating, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
