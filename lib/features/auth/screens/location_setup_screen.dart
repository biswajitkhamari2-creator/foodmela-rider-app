import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/app_colors.dart';
import 'package:food_track/core/utils/routes.dart';
import 'package:food_track/features/auth/models/auth_state.dart';

class LocationSetupScreen extends StatefulWidget {
  final UserAuthData authData;

  const LocationSetupScreen({super.key, required this.authData});

  @override
  State<LocationSetupScreen> createState() => _LocationSetupScreenState();
}

class _LocationSetupScreenState extends State<LocationSetupScreen> {
  bool _isLoading = false;

  void _useCurrentLocation() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    widget.authData.deliveryAddress = 'Connaught Place, New Delhi';
    widget.authData.isLocationGranted = true;

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.of(context).pushNamed(
        AppRoutes.authSuccess,
        arguments: widget.authData,
      );
    }
  }

  void _enterLocationManually() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final manualController = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter Delivery Address',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: manualController,
                decoration: InputDecoration(
                  hintText: 'Search street, area or building',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                  fillColor: AppColors.surfaceLight,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    final addr = manualController.text.trim();
                    widget.authData.deliveryAddress =
                        addr.isNotEmpty ? addr : 'Main Street, Central City';
                    Navigator.of(context).pop();
                    Navigator.of(context).pushNamed(
                      AppRoutes.authSuccess,
                      arguments: widget.authData,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Confirm Location',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),

            // Header Title
            Text(
              'Where should we deliver?',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Allow location access to discover restaurants and offers near you.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),

            const Spacer(),

            // Map & Delivery Scooter Graphic (Matching Design Card Screen 5)
            Stack(
              alignment: Alignment.center,
              children: [
                // Glowing background backdrop
                Container(
                  width: size.width * 0.7,
                  height: size.width * 0.7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryLight.withValues(alpha: 0.15),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/delivery_rider_hero.jpg',
                    width: size.width * 0.7,
                    height: size.width * 0.7,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: size.width * 0.7,
                      height: size.width * 0.7,
                      color: AppColors.primaryLight.withValues(alpha: 0.2),
                      child: const Icon(Icons.location_on_rounded, size: 80, color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Action Buttons Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  // Button 1: Use my current location
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _useCurrentLocation,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Colors.grey, width: 1),
                        elevation: 2,
                        shadowColor: Colors.black.withValues(alpha: 0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.my_location_rounded, color: AppColors.primary, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  'Use my current location',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Button 2: Enter location manually
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton(
                      onPressed: _enterLocationManually,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Colors.grey, width: 1),
                        elevation: 2,
                        shadowColor: Colors.black.withValues(alpha: 0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_rounded, color: Color(0xFF2563EB), size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Enter location manually',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
