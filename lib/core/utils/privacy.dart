// ─── Food Mela — Privacy helpers ──────────────────────────────────────────────
// Rider must NEVER see the customer's real phone number. Calls are masked
// (in-app VoIP only), and every UI surface shows a masked form instead.
//   maskPhone('9660887725') → 'XXXXXX7725'
// Empty/unknown → 'Hidden' (never 'N/A' with digits, never blank).
library;

String maskPhone(String? phone) {
  final digits = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 4) return 'Hidden';
  return 'XXXXXX${digits.substring(digits.length - 4)}';
}
