import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// Phone dialer helper — replaces the removed Agora/SIP in-app calling.
/// Opens the system dialer with the customer number; no VoIP, no tokens.
class CallHelper {
  CallHelper._();

  static Future<void> dialCustomer(BuildContext context, String rawPhone) async {
    final phone = rawPhone.trim();
    if (phone.isEmpty || phone == 'N/A') {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Customer number not available',
              style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.white)),
          backgroundColor: const Color(0xFF1C1815),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
      return;
    }
    final uri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not open dialer',
              style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.white)),
          backgroundColor: const Color(0xFF1C1815),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (_) {}
  }
}
