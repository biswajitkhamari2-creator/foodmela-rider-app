// ─── Food Mela Rider — Call Alert Permissions Setup Dialog ───────────────────
// Proactively asks the delivery partner for essential permissions on app launch/login:
//  1. Display Over Other Apps (SYSTEM_ALERT_WINDOW) — for WhatsApp-style popup over any app
//  2. Notifications (POST_NOTIFICATIONS) — for high-priority sound & call alerts
//  3. Full-Screen Intent (USE_FULL_SCREEN_INTENT) — for waking locked screens
//  4. Battery Optimization Exemption — to prevent Android OS from sleeping the background listener
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:food_track/core/services/native_order_alert.dart';
import 'package:food_track/core/theme/food_melaa_colors.dart';

class OrderPermissionSetupDialog extends StatefulWidget {
  const OrderPermissionSetupDialog({super.key});

  /// Check if any critical permission is missing, and if so, show the setup dialog.
  static Future<void> checkAndPrompt(BuildContext context) async {
    try {
      final notifGranted = await Permission.notification.isGranted;
      final overlayGranted = await NativeOrderAlert.canDrawOverlays();
      final batteryIgnored = await NativeOrderAlert.isIgnoringBatteryOptimizations();
      final fullScreenGranted = await NativeOrderAlert.canUseFullScreenIntent();

      if (!notifGranted || !overlayGranted || !batteryIgnored || !fullScreenGranted) {
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const OrderPermissionSetupDialog(),
        );
      }
    } catch (_) {}
  }

  @override
  State<OrderPermissionSetupDialog> createState() => _OrderPermissionSetupDialogState();
}

class _OrderPermissionSetupDialogState extends State<OrderPermissionSetupDialog> with WidgetsBindingObserver {
  bool _notifGranted = false;
  bool _overlayGranted = false;
  bool _batteryIgnored = false;
  bool _fullScreenGranted = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    try {
      final notif = await Permission.notification.isGranted;
      final overlay = await NativeOrderAlert.canDrawOverlays();
      final battery = await NativeOrderAlert.isIgnoringBatteryOptimizations();
      final fullScreen = await NativeOrderAlert.canUseFullScreenIntent();

      if (mounted) {
        setState(() {
          _notifGranted = notif;
          _overlayGranted = overlay;
          _batteryIgnored = battery;
          _fullScreenGranted = fullScreen;
          _loading = false;
        });

        // Auto-close if all permissions are granted!
        if (notif && overlay && battery && fullScreen) {
          Navigator.of(context).pop();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allDone = _notifGranted && _overlayGranted && _batteryIgnored && _fullScreenGranted;

    return PopScope(
      canPop: allDone,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF075E54).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.ring_volume_rounded,
                      color: Color(0xFF075E54),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enable Order Call Alerts',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: FoodMelaaColors.textDark,
                          ),
                        ),
                        Text(
                          'Get WhatsApp-style calls for new orders',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Please grant these permissions so incoming orders ring continuously over any app or lock screen:',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: Color(0xFF075E54)),
                  ),
                )
              else ...[
                // 1. Notification Permission
                _permissionTile(
                  icon: Icons.notifications_active_rounded,
                  title: 'Order Notifications',
                  subtitle: 'Receive instant ringing alerts for new orders',
                  isGranted: _notifGranted,
                  onGrant: () async {
                    await Permission.notification.request();
                    await _refreshStatus();
                  },
                ),

                // 2. Display Over Other Apps (Overlay)
                _permissionTile(
                  icon: Icons.layers_rounded,
                  title: 'Display Over Other Apps',
                  subtitle: 'Shows WhatsApp-style call screen over any active app',
                  isGranted: _overlayGranted,
                  onGrant: () async {
                    await NativeOrderAlert.openOverlaySettings();
                  },
                ),

                // 3. Full-Screen Intent (Lock screen wake-up)
                _permissionTile(
                  icon: Icons.screen_lock_portrait_rounded,
                  title: 'Full-Screen Call Intent',
                  subtitle: 'Wakes up screen and shows call when phone is locked',
                  isGranted: _fullScreenGranted,
                  onGrant: () async {
                    await NativeOrderAlert.openFullScreenIntentSettings();
                  },
                ),

                // 4. Disable Battery Optimization
                _permissionTile(
                  icon: Icons.battery_charging_full_rounded,
                  title: 'Background Activity (No Sleep)',
                  subtitle: 'Keeps alert engine running 24/7 without being killed',
                  isGranted: _batteryIgnored,
                  onGrant: () async {
                    await NativeOrderAlert.requestIgnoreBatteryOptimizations();
                  },
                ),
              ],

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Remind Later',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _refreshStatus,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF075E54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        allDone ? 'All Done! ✓' : 'Refresh Status',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
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

  Widget _permissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onGrant,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isGranted ? const Color(0xFFF0FDF4) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGranted ? const Color(0xFFBBF7D0) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: isGranted ? const Color(0xFF16A34A) : FoodMelaaColors.riderPrimary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: FoodMelaaColors.textDark,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isGranted)
            const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 24)
          else
            ElevatedButton(
              onPressed: onGrant,
              style: ElevatedButton.styleFrom(
                backgroundColor: FoodMelaaColors.riderPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                'ENABLE',
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
