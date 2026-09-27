import 'package:cloud_firestore/cloud_firestore.dart';

/// 🛠️ Live maintenance flag — same Firestore doc as website + admin panel:
/// `app_settings/maintenance` { enabled: bool, eta: String }.
/// Admin panel ke Settings page se toggle hota hai, app update ki zarurat nahi.
class MaintenanceService {
  MaintenanceService._();
  static final instance = MaintenanceService._();

  Stream<({bool enabled, String eta})> watch() {
    return FirebaseFirestore.instance
        .collection('app_settings')
        .doc('maintenance')
        .snapshots()
        .map((snap) {
      final d = snap.data() ?? {};
      return (
        enabled: d['enabled'] == true,
        eta: (d['eta'] ?? '30 min').toString(),
      );
    });
  }
}
