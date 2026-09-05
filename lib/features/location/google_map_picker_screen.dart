import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/food_melaa_colors.dart';
import 'package:food_track/core/state/food_mela_state.dart';

class GoogleMapPickerScreen extends StatefulWidget {
  final FoodMelaState state;
  const GoogleMapPickerScreen({super.key, required this.state});

  @override
  State<GoogleMapPickerScreen> createState() => _GoogleMapPickerScreenState();
}

class _GoogleMapPickerScreenState extends State<GoogleMapPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _houseNoController = TextEditingController(text: 'Flat 302, Building 4B');
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController(text: 'Near Master Canteen');
  final TextEditingController _instructionsController = TextEditingController(text: 'Ring doorbell twice on arrival');

  String _currentAddress = 'Saheed Nagar, Janpath Road, Bhubaneswar';
  double _lat = 20.2961;
  double _lng = 85.8245;
  String _mapType = 'Normal';

  @override
  void initState() {
    super.initState();
    _streetController.text = _currentAddress;
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isEmpty) return;
    setState(() {
      _currentAddress = '${query.trim()}, Bhubaneswar';
      _streetController.text = _currentAddress;
      _lat += 0.005;
      _lng += 0.005;
    });
  }

  void _showCompleteAddressFormModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      const Icon(Icons.edit_location_alt_rounded, color: FoodMelaaColors.primary, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        'Complete Delivery Address 📝',
                        style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: FoodMelaaColors.textDark),
                      ),
                    ],
                  ),
                  Text(
                    'Type your house number, landmark, and delivery instructions so rider can deliver directly to your door.',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 20),

                  // House / Flat No Input
                  Text('House / Flat / Building No *', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _houseNoController,
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'e.g. Flat 304, Plot 142',
                      prefixIcon: const Icon(Icons.home_outlined, color: FoodMelaaColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Street / Area Name Input
                  Text('Street / Area / Locality Name *', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _streetController,
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'e.g. Saheed Nagar, Janpath Road',
                      prefixIcon: const Icon(Icons.add_location_alt_outlined, color: FoodMelaaColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Landmark Input
                  Text('Nearby Landmark (Optional)', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _landmarkController,
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'e.g. Near Master Canteen / Opp Axis Bank',
                      prefixIcon: const Icon(Icons.assistant_direction_outlined, color: Colors.amber),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Delivery Instructions
                  Text('Delivery Instructions for Rider', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _instructionsController,
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. Ring bell twice / Leave with gate security',
                      prefixIcon: const Icon(Icons.record_voice_over_outlined, color: Colors.green),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Save Complete Address Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        final house = _houseNoController.text.trim();
                        final street = _streetController.text.trim();
                        final landmark = _landmarkController.text.trim();

                        final fullFormattedAddress = [
                          if (house.isNotEmpty) house,
                          if (street.isNotEmpty) street,
                          if (landmark.isNotEmpty) '($landmark)'
                        ].join(', ');

                        widget.state.setAddress(fullFormattedAddress);
                        Navigator.pop(context); // Close modal
                        Navigator.pop(context); // Close map picker screen

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Complete Address Saved: $fullFormattedAddress 📍')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FoodMelaaColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'SAVE COMPLETE ADDRESS ➔',
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
          'Google Maps Location 📍',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: FoodMelaaColors.textDark),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Interactive Map Visual
            Container(
              color: const Color(0xFFE2E8F0),
              child: Stack(
                children: [
                  CustomPaint(
                    size: Size.infinite,
                    painter: GoogleMapPainter(mapType: _mapType, centerLat: _lat, centerLng: _lng),
                  ),

                  // Center Pin Pointer
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: FoodMelaaColors.textDark,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '📍 Set Pin Location',
                            style: GoogleFonts.poppins(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Icon(Icons.location_on_rounded, size: 48, color: FoodMelaaColors.primary),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: FoodMelaaColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onSubmitted: _onSearchSubmitted,
                        style: GoogleFonts.inter(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search location on Google Maps...',
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Map Layer & Zoom Controls
            Positioned(
              right: 16,
              top: 80,
              child: Column(
                children: [
                  _buildMapControlButton(
                    Icons.layers_rounded,
                    () {
                      setState(() {
                        if (_mapType == 'Normal') {
                          _mapType = 'Satellite';
                        } else if (_mapType == 'Satellite') {
                          _mapType = 'Terrain';
                        } else {
                          _mapType = 'Normal';
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Map View switched to: $_mapType Mode 🗺️'), duration: const Duration(seconds: 1)),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildMapControlButton(
                    Icons.my_location_rounded,
                    () async {
                      await widget.state.simulateGpsLocationDetection();
                      setState(() {
                        _currentAddress = widget.state.selectedAddress;
                        _streetController.text = _currentAddress;
                      });
                    },
                    color: FoodMelaaColors.primary,
                  ),
                ],
              ),
            ),

            // Bottom Confirm Location Card
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: FoodMelaaColors.primary, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Select Delivery Location',
                            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Text(
                      _currentAddress,
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: FoodMelaaColors.textDark),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _showCompleteAddressFormModal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FoodMelaaColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          'ENTER COMPLETE ADDRESS DETAILS ➔',
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapControlButton(IconData icon, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: color ?? FoodMelaaColors.textDark),
      ),
    );
  }
}

class GoogleMapPainter extends CustomPainter {
  final String mapType;
  final double centerLat;
  final double centerLng;

  GoogleMapPainter({required this.mapType, required this.centerLat, required this.centerLng});

  @override
  void paint(Canvas canvas, Size size) {
    final paintBg = Paint();
    final paintGrid = Paint()..strokeWidth = 1;

    if (mapType == 'Satellite') {
      paintBg.color = const Color(0xFF1E293B);
      paintGrid.color = Colors.white10;
    } else if (mapType == 'Terrain') {
      paintBg.color = const Color(0xFFD97706).withValues(alpha: 0.15);
      paintGrid.color = Colors.brown.withValues(alpha: 0.15);
    } else {
      paintBg.color = const Color(0xFFF1F5F9);
      paintGrid.color = Colors.black12;
    }

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paintBg);

    // Draw Map Grid Lines
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paintGrid);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    // Draw Road Polylines
    final roadPaint = Paint()
      ..color = mapType == 'Satellite' ? Colors.white24 : Colors.white
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke;

    final roadPath = Path()
      ..moveTo(0, size.height * 0.3)
      ..lineTo(size.width, size.height * 0.3)
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(size.width * 0.5, size.height);

    canvas.drawPath(roadPath, roadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
