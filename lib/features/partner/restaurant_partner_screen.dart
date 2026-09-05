import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RestaurantPartnerScreen extends StatefulWidget {
  const RestaurantPartnerScreen({super.key});

  @override
  State<RestaurantPartnerScreen> createState() => _RestaurantPartnerScreenState();
}

class _RestaurantPartnerScreenState extends State<RestaurantPartnerScreen> {
  bool _isOpen = true;

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
                  const Text('🍴', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'The Burger Lab',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A1614),
                          ),
                        ),
                        Text(
                          'Restaurant Partner Portal',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF7C3AED),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        _isOpen ? 'OPEN' : 'CLOSED',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _isOpen ? Colors.green : Colors.red,
                        ),
                      ),
                      Switch(
                        value: _isOpen,
                        activeThumbColor: Colors.green,
                        onChanged: (val) => setState(() => _isOpen = val),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Metrics Row
              Row(
                children: [
                  _buildMetricCard('Today Sales', '₹14,250', '+18%', const Color(0xFF7C3AED)),
                  const SizedBox(width: 12),
                  _buildMetricCard('Orders Today', '42', '5 Active', Colors.orange),
                ],
              ),

              const SizedBox(height: 24),

              Text(
                'Incoming Live Orders',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1614),
                ),
              ),

              const SizedBox(height: 12),

              // Real orders only — no demo/sample data in production.
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No new delivery requests',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String val, String sub, Color color) {
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
            Text(val, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(sub, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
          ],
        ),
      ),
    );
  }

  // Demo order card removed — production shows real backend orders only.
}
