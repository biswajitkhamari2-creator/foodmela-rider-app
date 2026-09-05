import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DeliveryPartnerScreen extends StatefulWidget {
  const DeliveryPartnerScreen({super.key});

  @override
  State<DeliveryPartnerScreen> createState() => _DeliveryPartnerScreenState();
}

class _DeliveryPartnerScreenState extends State<DeliveryPartnerScreen> {
  bool _isOnline = true;

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
                  const Text('🛵', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Amit Kumar',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A1614),
                          ),
                        ),
                        Text(
                          'Delivery Rider • Hero Scooter',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF16A34A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        _isOnline ? 'ONLINE' : 'OFFLINE',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _isOnline ? Colors.green : Colors.red,
                        ),
                      ),
                      Switch(
                        value: _isOnline,
                        activeThumbColor: const Color(0xFF16A34A),
                        onChanged: (val) => setState(() => _isOnline = val),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Metrics Row
              Row(
                children: [
                  _buildMetric('Today Earnings', '₹1,240', '12 Orders', const Color(0xFF16A34A)),
                  const SizedBox(width: 12),
                  _buildMetric('Active Delivery', '1 Pending', 'Saheed Nagar', Colors.orange),
                ],
              ),

              const SizedBox(height: 24),

              Text(
                'Current Assigned Delivery',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1614),
                ),
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'ORDER #FT2406001',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Payout: ₹65',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.storefront_rounded, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pickup: The Burger Lab (Saheed Nagar)',
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.navigation_rounded, color: Color(0xFF16A34A), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Dropoff: Laxmi Vihar, Nayapalli (2.4 km)',
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Swipe to Complete Pickup',
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
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
            Text(val, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(sub, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}
