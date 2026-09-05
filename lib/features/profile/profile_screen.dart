import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/food_melaa_colors.dart';
import 'package:food_track/core/utils/routes.dart';
import 'package:food_track/features/rider/rider_login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'Amit Kumar';
  String _userEmail = 'amit.kumar@foodmela.com';
  final String _lockedMobileNumber = '+91 98765 43210';

  void _showEditProfileModal(BuildContext context) {
    final nameController = TextEditingController(text: _userName);
    final emailController = TextEditingController(text: _userEmail);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_note_rounded, color: FoodMelaaColors.primary, size: 28),
                const SizedBox(width: 10),
                Text('Edit Profile Details ✏️', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),

            // Locked Mobile Number Field
            TextField(
              controller: TextEditingController(text: _lockedMobileNumber),
              enabled: false,
              decoration: InputDecoration(
                labelText: 'Mobile Number (Locked 🔒)',
                suffixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
            const SizedBox(height: 12),

            // Editable Name Field
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person_outline_rounded, color: FoodMelaaColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Editable Email Field
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: const Icon(Icons.email_outlined, color: FoodMelaaColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _userName = nameController.text.trim();
                    _userEmail = emailController.text.trim();
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile details updated successfully ✨')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FoodMelaaColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('SAVE PROFILE CHANGES ➔', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSavedAddressesModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_rounded, color: FoodMelaaColors.primary, size: 28),
                const SizedBox(width: 10),
                Text('Saved Delivery Addresses 📍', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            _buildAddressTile(context, 'Home 🏠', 'Flat 302, Saheed Nagar, Janpath Road, Bhubaneswar', isPrimary: true),
            _buildAddressTile(context, 'Work / Office 🏢', 'Plot 142, Master Canteen Square, Bhubaneswar'),
            _buildAddressTile(context, 'Gym 🏋️', 'Esplanade One Mall, Rasulgarh, Bhubaneswar'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.mapPicker);
                },
                icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white, size: 18),
                label: Text('ADD NEW ADDRESS ➔', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FoodMelaaColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressTile(BuildContext context, String title, String address, {bool isPrimary = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPrimary ? FoodMelaaColors.primaryLight : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isPrimary ? FoodMelaaColors.primary : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.place_rounded, color: isPrimary ? FoodMelaaColors.primary : Colors.grey, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold)),
                Text(address, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700)),
              ],
            ),
          ),
          if (isPrimary)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: FoodMelaaColors.primary, borderRadius: BorderRadius.circular(6)),
              child: Text('DEFAULT', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
        ],
      ),
    );
  }

  void _showPaymentOptionsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payment_rounded, color: Colors.green, size: 28),
                const SizedBox(width: 10),
                Text('Payment Options & Wallets 💳', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.qr_code_2_rounded, color: Colors.purple, size: 28),
              title: Text('UPI Apps (PhonePe, GooglePay, Paytm)', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: Text('Linked ID: 9876543210@ybl', style: GoogleFonts.inter(fontSize: 11)),
              trailing: const Icon(Icons.check_circle_rounded, color: Colors.green),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.credit_card_rounded, color: Colors.blue, size: 28),
              title: Text('Credit / Debit Cards', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: Text('HDFC Bank Visa ending in **** 4821', style: GoogleFonts.inter(fontSize: 11)),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.money_rounded, color: Colors.amber, size: 28),
              title: Text('Cash on Delivery (COD)', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: Text('Pay cash or scan QR at door', style: GoogleFonts.inter(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpSupportModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: FoodMelaaColors.primaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.support_agent_rounded, size: 40, color: FoodMelaaColors.primary),
            ),
            const SizedBox(height: 12),
            Text('FOOD MELA 24x7 Support 🎧', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('We are available 24x7 to assist with your order delivery & refunds.', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Calling Support Helpline: 1800-FOOD-MELA 📞')),
                  );
                },
                icon: const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 18),
                label: Text('CALL SUPPORT (1800-FOOD-MELA)', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opening Live WhatsApp Support Chat... 💬')),
                  );
                },
                icon: const Icon(Icons.chat_rounded, color: FoodMelaaColors.primary, size: 18),
                label: Text('CHAT ON WHATSAPP 💬', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: FoodMelaaColors.primary)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: FoodMelaaColors.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Log Out?', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to log out of FOOD MELA?', style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(context, AppRoutes.welcome, (route) => false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logged out successfully 👋')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text('LOGOUT 🚪', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FoodMelaaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'My Profile 👤',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: FoodMelaaColors.textDark),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // User Card with Edit Profile Button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 30,
                          backgroundColor: FoodMelaaColors.primaryLight,
                          child: Icon(Icons.person_rounded, size: 36, color: FoodMelaaColors.primary),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_userName, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                              Text('🔒 $_lockedMobileNumber', style: GoogleFonts.inter(fontSize: 12, color: FoodMelaaColors.textSecondary, fontWeight: FontWeight.w600)),
                              Text(_userEmail, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: OutlinedButton.icon(
                        onPressed: () => _showEditProfileModal(context),
                        icon: const Icon(Icons.edit_rounded, size: 16, color: FoodMelaaColors.primary),
                        label: Text('EDIT PROFILE ✏️', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: FoodMelaaColors.primary)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: FoodMelaaColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Delivery Partner Mode Banner
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RiderLoginScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade700, Colors.deepOrange],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Delivery Partner Mode 🛵', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text('Switch to Rider Portal (Mobile: 9999988888)', style: GoogleFonts.inter(fontSize: 10, color: Colors.white70)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Menu List Items
              _buildMenuItem(
                context,
                icon: Icons.shopping_bag_outlined,
                title: 'Your Orders',
                subtitle: 'Track live orders & order history',
                onTap: () => Navigator.pushNamed(context, AppRoutes.orderTracking),
              ),
              _buildMenuItem(
                context,
                icon: Icons.location_on_outlined,
                title: 'Saved Addresses',
                subtitle: 'Manage Home, Office, Gym addresses',
                onTap: () => _showSavedAddressesModal(context),
              ),
              _buildMenuItem(
                context,
                icon: Icons.payment_outlined,
                title: 'Payment Options',
                subtitle: 'UPI, Paytm, PhonePe, Cards & COD',
                onTap: () => _showPaymentOptionsModal(context),
              ),
              _buildMenuItem(
                context,
                icon: Icons.support_agent_outlined,
                title: 'Help & Support',
                subtitle: '24x7 Helpline & Live WhatsApp Chat',
                onTap: () => _showHelpSupportModal(context),
              ),
              _buildMenuItem(
                context,
                icon: Icons.logout_rounded,
                title: 'Log Out',
                subtitle: 'Sign out of your FOOD MELA account',
                isLogout: true,
                onTap: () => _showLogoutDialog(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: isLogout ? Colors.red : FoodMelaaColors.primary),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isLogout ? Colors.red : FoodMelaaColors.textDark,
          ),
        ),
        subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isLogout ? Colors.red : Colors.grey),
      ),
    );
  }
}
