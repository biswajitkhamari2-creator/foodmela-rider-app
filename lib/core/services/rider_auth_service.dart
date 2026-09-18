import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// ─── RIDER AUTH SERVICE ─────────────────────────────────────────────────
/// Handles email+password AND phone+password login for the SAME rider account.
/// Uses Firebase Auth (email/password) + Firestore users collection.
///
/// Phone login: looks up email by phone in Firestore, then signs in via email.
/// This ensures ONE account per rider — both identifiers map to same Auth user.
class RiderAuthService {
  RiderAuthService._();
  static final RiderAuthService instance = RiderAuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const _kRiderUid = 'rider_uid';
  static const _kRiderEmail = 'rider_email';
  static const _kRiderPhone = 'rider_phone';
  static const _kRiderName = 'rider_name';
  static const _kRiderPartnerId = 'rider_partner_id';
  static const _kRiderApiToken = 'rider_api_token';

  /// Backend rider apiToken (minted at login, bound to rider phone).
  /// Required by /api/orders/live, /accept, /update-stage, /calls/*.
  static Future<String> apiToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kRiderApiToken) ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<Map<String, String>> apiHeaders() async {
    final t = await apiToken();
    return {
      'Content-Type': 'application/json',
      if (t.isNotEmpty) 'Authorization': 'Bearer $t',
    };
  }

  /// Exchange the Firebase ID token for a backend rider apiToken.
  static Future<void> _mintRiderToken(User user) async {
    try {
      final idToken = await user.getIdToken();
      final res = await http
          .post(Uri.parse('https://foodmela.online/api/auth/rider/token'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $idToken',
              },
              body: jsonEncode({}))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return;
      final b = jsonDecode(res.body) as Map<String, dynamic>;
      final t = (b['apiToken'] as String?) ?? '';
      if (t.isEmpty) return;
      (await SharedPreferences.getInstance()).setString(_kRiderApiToken, t);
    } catch (_) {}
  }

  /// Login with email OR phone + password.
  /// Returns rider data on success, throws on failure.
  Future<Map<String, dynamic>> login({
    required String identifier, // email or phone
    required String password,
  }) async {
    final id = identifier.trim();
    if (id.isEmpty) throw RiderAuthException('Please enter email or phone number');
    if (password.isEmpty) throw RiderAuthException('Please enter password');

    // ── Resolve email from identifier ────────────────────────────────────
    String email;
    String phone = '';

    if (id.contains('@')) {
      // Email login
      if (!_isValidEmail(id)) throw RiderAuthException('Invalid email format');
      email = id.toLowerCase();
    } else {
      // Phone login — look up email in Firestore
      phone = id.replaceAll(RegExp(r'[^0-9]'), '');
      if (phone.length < 10) throw RiderAuthException('Invalid phone number');
      // Normalize: ensure 10 digits or with country code
      if (phone.length == 10) phone = '91$phone';
      // Search Firestore for rider with this phone
      final q = await _db.collection('users')
          .where('phone', isEqualTo: phone)
          .where('role', isEqualTo: 'delivery_partner')
          .limit(1)
          .get();
      // Also try without country code
      QuerySnapshot<Map<String, dynamic>>? q2;
      if (q.docs.isEmpty) {
        final shortPhone = phone.length > 10 ? phone.substring(phone.length - 10) : phone;
        q2 = await _db.collection('users')
            .where('phone', isEqualTo: shortPhone)
            .where('role', isEqualTo: 'delivery_partner')
            .limit(1)
            .get();
      }
      // Also try doc ID lookup
      if (q.docs.isEmpty && (q2 == null || q2.docs.isEmpty)) {
        try {
          final docSnap = await _db.collection('users').doc(phone).get();
          if (docSnap.exists && docSnap.data()?['role'] == 'delivery_partner') {
            final data = docSnap.data()!;
            email = (data['email'] as String? ?? '').toLowerCase();
            if (email.isEmpty) throw RiderAuthException('No email linked to this phone number');
            return await _signInWithEmail(email, password, phone);
          }
        } catch (_) {}
      }

      final found = q.docs.isNotEmpty ? q.docs.first : (q2 != null && q2.docs.isNotEmpty ? q2.docs.first : null);
      if (found == null) throw RiderAuthException('No rider account found for this phone number');
      email = (found.data()['email'] as String? ?? '').toLowerCase();
      if (email.isEmpty) throw RiderAuthException('No email linked to this phone number');
      phone = found.data()['phone'] as String? ?? phone;
    }

    return _signInWithEmail(email, password, phone);
  }

  Future<Map<String, dynamic>> _signInWithEmail(String email, String password, String phone) async {
    // ── Firebase Auth sign in ────────────────────────────────────────────
    UserCredential cred;
    try {
      cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential' || e.code == 'invalid-email') {
        throw RiderAuthException('Incorrect email/phone or password');
      }
      if (e.code == 'too-many-requests') {
        throw RiderAuthException('Too many attempts. Please try again later');
      }
      throw RiderAuthException('Login failed. Please try again');
    }

    final uid = cred.user!.uid;

    // ── Fetch rider profile from Firestore ─────────────────────────────────
    // Try by UID first, then by phone, then by email
    DocumentSnapshot<Map<String, dynamic>>? riderDoc;
    riderDoc = await _db.collection('users').doc(uid).get();
    if (!riderDoc.exists) {
      // Try phone lookup
      final phoneToCheck = phone.isNotEmpty ? phone : '';
      if (phoneToCheck.isNotEmpty) {
        riderDoc = await _db.collection('users').doc(phoneToCheck).get();
        if (!riderDoc.exists) {
          final shortPhone = phoneToCheck.length > 10 ? phoneToCheck.substring(phoneToCheck.length - 10) : phoneToCheck;
          riderDoc = await _db.collection('users').doc(shortPhone).get();
        }
      }
      // Try email lookup
      if (!riderDoc.exists) {
        final q = await _db.collection('users').where('email', isEqualTo: email).where('role', isEqualTo: 'delivery_partner').limit(1).get();
        if (q.docs.isNotEmpty) riderDoc = q.docs.first;
      }
    }

    if (!riderDoc.exists) {
      await _auth.signOut();
      throw RiderAuthException('Rider profile not found');
    }

    final data = riderDoc.data()!;

    // ── Enforce role ─────────────────────────────────────────────────────
    if (data['role'] != 'delivery_partner') {
      await _auth.signOut();
      throw RiderAuthException('Access denied — delivery partner account required');
    }

    // ── Enforce approval ─────────────────────────────────────────────────
    if (data['approvalStatus'] == 'pending') {
      await _auth.signOut();
      throw RiderAuthException('Your account is awaiting approval');
    }
    if (data['approvalStatus'] == 'rejected') {
      await _auth.signOut();
      throw RiderAuthException('Your account has been rejected');
    }

    // ── Enforce blocked ──────────────────────────────────────────────────
    if (data['accountStatus'] == 'blocked') {
      await _auth.signOut();
      throw RiderAuthException('Your rider account is blocked');
    }

    // ── Save session ─────────────────────────────────────────────────────
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRiderUid, uid);
    await prefs.setString(_kRiderEmail, email);
    await prefs.setString(_kRiderPhone, data['phone'] as String? ?? phone);
    await prefs.setString(_kRiderName, data['name'] as String? ?? '');
    await prefs.setString(_kRiderPartnerId, data['partnerId'] as String? ?? '');
    // SECURITY: mint backend rider apiToken for /api/orders/* + /api/calls/*.
    await _mintRiderToken(cred.user!);

    return {
      'uid': uid,
      'email': email,
      'phone': data['phone'] as String? ?? phone,
      'name': data['name'] as String? ?? '',
      'partnerId': data['partnerId'] as String? ?? '',
      'data': data,
    };
  }

  Future<void> logout() async {
    try { await _auth.signOut(); } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRiderUid);
    await prefs.remove(_kRiderEmail);
    await prefs.remove(_kRiderPhone);
    await prefs.remove(_kRiderName);
    await prefs.remove(_kRiderPartnerId);
    await prefs.remove(_kRiderApiToken);
  }

  Future<Map<String, String>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(_kRiderUid);
    if (uid == null || uid.isEmpty) return null;
    return {
      'uid': uid,
      'email': prefs.getString(_kRiderEmail) ?? '',
      'phone': prefs.getString(_kRiderPhone) ?? '',
      'name': prefs.getString(_kRiderName) ?? '',
      'partnerId': prefs.getString(_kRiderPartnerId) ?? '',
    };
  }

  /// Check if Firebase Auth session is still valid (not expired)
  Future<bool> isSessionValid() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      // Try to get a fresh token — will fail if session expired
      await user.getIdToken(true);
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
  }
}

class RiderAuthException implements Exception {
  final String message;
  RiderAuthException(this.message);
  @override
  String toString() => message;
}
