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
  // Saved so we can silently re-sign-in when the custom token expires
  static const _kRiderPassword = 'rider_password';

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
  /// Returns true ONLY when the Firestore custom token was applied (orders
  /// will stream). Returns false when the backend rejected the account
  /// (phone-keyed doc, unapproved, blocked…) — the caller must NOT let the
  /// user in, otherwise every orders read dies with permission-denied and the
  /// dashboard shows "Session expired" on every order arrival.
  static Future<bool> _mintRiderToken(User user, {String phone = ''}) async {
    try {
      final idToken = await user.getIdToken();
      final res = await http
          .post(Uri.parse('https://foodmela.online/api/auth/rider/token'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $idToken',
              },
              body: jsonEncode(phone.isNotEmpty ? {'phone': phone} : {}))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return false;
      final b = jsonDecode(res.body) as Map<String, dynamic>;
      final t = (b['apiToken'] as String?) ?? '';
      if (t.isEmpty) return false;
      (await SharedPreferences.getInstance()).setString(_kRiderApiToken, t);
      // Firestore sign-in with the backend-minted custom token so the
      // hardened rules (isRider → users/{uid} role) let orders stream in.
      final ft = (b['firebaseToken'] as String?) ?? '';
      if (ft.isEmpty) return false;
      try {
        await FirebaseAuth.instance.signInWithCustomToken(ft);
      } catch (_) {
        if (FirebaseAuth.instance.currentUser != null) return true;
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Probe a stored rider apiToken without placing a call: any response
  /// other than 401 proves the backend still accepts it. Network errors
  /// return true (don't force logout on flaky 2G).
  static Future<bool> probeCallToken(String token) async {
    try {
      final res = await http
          .post(Uri.parse('https://foodmela.online/api/calls/FM-HEALTH-PROBE/request'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({'callerId': 'probe', 'callerRole': 'rider'}))
          .timeout(const Duration(seconds: 8));
      return res.statusCode != 401;
    } catch (_) {
      return true;
    }
  }

  /// One-time silent repair for a live session whose orders stream died with
  /// permission-denied (e.g. logged in before the backend knew the phone-keyed
  /// doc). Returns true when the stream can be re-attached.
  static Future<bool> refreshFirestoreToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString(_kRiderPhone) ?? '';
      var user = FirebaseAuth.instance.currentUser;

      // If currentUser is null the custom token (1-hour TTL) has expired.
      // Silently re-sign-in with the saved email+password so we get a
      // long-lived refresh-token session back, then mint the backend token.
      if (user == null) {
        final email = prefs.getString(_kRiderEmail) ?? '';
        final password = prefs.getString(_kRiderPassword) ?? '';
        if (email.isNotEmpty && password.isNotEmpty) {
          try {
            final cred = await FirebaseAuth.instance
                .signInWithEmailAndPassword(email: email, password: password)
                .timeout(const Duration(seconds: 10));
            user = cred.user;
          } catch (_) {}
        }
      }

      // Fallback: wait briefly for Firebase to restore session from disk
      if (user == null) {
        try {
          user = await FirebaseAuth.instance
              .authStateChanges()
              .firstWhere((u) => u != null)
              .timeout(const Duration(seconds: 3));
        } catch (_) {}
      }
      user ??= FirebaseAuth.instance.currentUser;
      if (user == null || phone.isEmpty) return false;
      return await _mintRiderToken(user, phone: phone);
    } catch (_) {
      return false;
    }
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

    final signedInUser = cred.user!;
    final uid = signedInUser.uid;

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
    // Save password so we can silently re-sign-in when the custom token
    // (1-hour TTL) expires, without forcing the rider back to login screen.
    await prefs.setString(_kRiderPassword, password);
    // SECURITY: mint backend rider apiToken for /api/orders/* + /api/calls/*.
    // HARD FAIL: if the Firestore custom token was not applied, orders will
    // never stream (permission-denied on every read). Do NOT let the user in
    // with a broken session — sign out with a clear message instead.
    final riderPhone = data['phone'] as String? ?? phone;
    final minted = await _mintRiderToken(signedInUser, phone: riderPhone);
    if (!minted) {
      await _auth.signOut();
      throw RiderAuthException('Could not verify rider account — please try login again');
    }
    final activeUid = _auth.currentUser?.uid ?? uid;
    await prefs.setString(_kRiderUid, activeUid);
    await prefs.setString(_kRiderEmail, email);
    await prefs.setString(_kRiderPhone, riderPhone);
    await prefs.setString(_kRiderName, data['name'] as String? ?? '');
    await prefs.setString(_kRiderPartnerId, data['partnerId'] as String? ?? '');

    return {
      'uid': activeUid,
      'email': email,
      'phone': riderPhone,
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
    await prefs.remove(_kRiderPassword);
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

  Future<Map<String, String>?> recoverSessionFromFirebase() async {
    var user = _auth.currentUser;
    if (user == null) {
      try {
        user = await _auth
            .authStateChanges()
            .firstWhere((u) => u != null)
            .timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
    user ??= _auth.currentUser;
    if (user == null) {
      return getSession();
    }
    try {
      DocumentSnapshot<Map<String, dynamic>> riderDoc =
          await _db.collection('users').doc(user.uid).get();
      if (!riderDoc.exists && (user.email ?? '').isNotEmpty) {
        final q = await _db
            .collection('users')
            .where('email', isEqualTo: user.email!.toLowerCase())
            .where('role', isEqualTo: 'delivery_partner')
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) riderDoc = q.docs.first;
      }
      if (!riderDoc.exists) {
        final s = await getSession();
        if (s != null) return s;
        return null;
      }
      final data = riderDoc.data();
      if (data == null || data['role'] != 'delivery_partner') return null;
      if (data['approvalStatus'] == 'pending' ||
          data['approvalStatus'] == 'rejected' ||
          data['accountStatus'] == 'blocked') {
        return null;
      }

      final email = (data['email'] as String? ?? user.email ?? '').toLowerCase();
      final phone = data['phone'] as String? ?? '';
      final name = data['name'] as String? ?? '';
      final partnerId = data['partnerId'] as String? ?? '';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kRiderUid, user.uid);
      await prefs.setString(_kRiderEmail, email);
      await prefs.setString(_kRiderPhone, phone);
      await prefs.setString(_kRiderName, name);
      await prefs.setString(_kRiderPartnerId, partnerId);
      await _mintRiderToken(user, phone: phone);
      return {
        'uid': user.uid,
        'email': email,
        'phone': phone,
        'name': name,
        'partnerId': partnerId,
      };
    } catch (_) {
      return getSession();
    }
  }

  /// Check if Firebase Auth session is still valid (not expired)
  Future<bool> isSessionValid() async {
    try {
      var user = _auth.currentUser;
      if (user == null) {
        try {
          user = await _auth
              .authStateChanges()
              .firstWhere((u) => u != null)
              .timeout(const Duration(seconds: 3));
        } catch (_) {}
      }
      user ??= _auth.currentUser;
      if (user == null) {
        final session = await getSession();
        return session != null && session['uid']!.isNotEmpty;
      }
      final idToken = await user.getIdToken(false);
      return idToken != null && idToken.isNotEmpty;
    } catch (_) {
      final session = await getSession();
      return session != null && (session['uid'] ?? '').isNotEmpty;
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
