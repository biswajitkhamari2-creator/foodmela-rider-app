// ─── Food Mela — Masked In-App Calling config ─────────────────────────────────
// Numbers stay hidden: VoIP only. Channel = order_<orderId>. Tokens come from
// the backend (agoraCalls.js) which checks active-order membership.
class CallConfig {
  // Deployed backend (same one the website uses).
  static const String backendBaseUrl = 'https://food-mela-backend.vercel.app';

  // Agora project: FoodMela-Calls (App ID + Token auth).
  static const String agoraAppId = 'ca957bd9daa74c6199bbe2178d8c6b3c';

  static bool get isConfigured =>
      agoraAppId != 'YOUR_AGORA_APP_ID' && agoraAppId.isNotEmpty;
}
