import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/app_colors.dart';
import 'package:food_track/core/utils/routes.dart';
import 'package:food_track/features/auth/models/auth_state.dart';

class RoleSelectionScreen extends StatefulWidget {
  final UserAuthData? authData;

  const RoleSelectionScreen({super.key, this.authData});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole _selectedRole = UserRole.customer;

  void _onContinue() {
    final auth = widget.authData ?? UserAuthData();
    auth.role = _selectedRole;

    if (_selectedRole == UserRole.customer) {
      auth.status = UserStatus.approved;
      Navigator.of(context).pushNamed(AppRoutes.phoneInput, arguments: auth);
    } else if (_selectedRole == UserRole.delivery) {
      auth.status = UserStatus.pending;
      Navigator.of(context).pushNamed('/delivery-pending', arguments: auth);
    }
  }

  @override
  Widget build(BuildContext context) {
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),

              Text(
                'What is your role?',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Select how you would like to use FoodTrack',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              RadioGroup<UserRole>(
                groupValue: _selectedRole,
                onChanged: (val) {
                  if (val != null) setState(() => _selectedRole = val);
                },
                child: Column(
                  children: [
                    _buildRoleCard(
                      role: UserRole.customer,
                      icon: Icons.school_rounded,
                      title: 'Customer / Student',
                      subtitle: 'Order delicious food, get student offers, and track orders live.',
                      statusBadge: 'Instant Approval • Active',
                      badgeColor: const Color(0xFF16A34A),
                    ),
                    const SizedBox(height: 16),
                    _buildRoleCard(
                      role: UserRole.delivery,
                      icon: Icons.delivery_dining_rounded,
                      title: 'Delivery Partner',
                      subtitle: 'Earn by delivering food orders in your city on your schedule.',
                      statusBadge: 'Verification Required • Request Pending',
                      badgeColor: Colors.orange,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Continue Action Button
              Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFF4A1A)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue as ${_selectedRole == UserRole.customer ? 'Customer' : 'Delivery Partner'}',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required UserRole role,
    required IconData icon,
    required String title,
    required String subtitle,
    required String statusBadge,
    required Color badgeColor,
  }) {
    final isSelected = _selectedRole == role;

    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Radio<UserRole>(
                        value: role,
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      statusBadge,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
