// ─── Food Mela — Rider Wallet (premium) ───────────────────────────────────────
// Balance = ₹40 × delivered orders (stage 3, this rider). Withdrawals live in
// Firestore `withdrawals/{id}`: { riderId, riderName, amount, status, ... }.
// Status flow: pending (Under Review) → approved | rejected (by admin).
// Available = lifetime earnings − approved − pending amounts.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/food_melaa_colors.dart';

const double _perDelivery = 40.0;

class RiderWalletScreen extends StatefulWidget {
  final String riderId;
  final String riderName;

  const RiderWalletScreen({
    super.key,
    required this.riderId,
    required this.riderName,
  });

  @override
  State<RiderWalletScreen> createState() => _RiderWalletScreenState();
}

class _RiderWalletScreenState extends State<RiderWalletScreen> {
  bool _loading = true;
  int _deliveredCount = 0;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _withdrawals = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final db = FirebaseFirestore.instance;
      final orders = await db
          .collection('orders')
          .where('riderId', isEqualTo: widget.riderId)
          .where('stage', isEqualTo: 3)
          .get();
      final wd = await db
          .collection('withdrawals')
          .where('riderId', isEqualTo: widget.riderId)
          .get();
      if (!mounted) return;
      final valid = orders.docs.where((d) {
        final data = d.data();
        final status = (data['status'] as String? ?? '').toLowerCase();
        return !(data['isDeleted'] as bool? ?? false) && !status.contains('cancel');
      }).toList();
      final wds = wd.docs.toList()
        ..sort((a, b) {
          final ta = _wdTime(a.data());
          final tb = _wdTime(b.data());
          return tb.compareTo(ta);
        });
      setState(() {
        _deliveredCount = valid.length;
        _withdrawals = wds;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime _wdTime(Map<String, dynamic> d) {
    final v = d['createdAt'];
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  double get _lifetime => _deliveredCount * _perDelivery;

  double _sumWhere(bool Function(Map<String, dynamic>) test) {
    double s = 0;
    for (final w in _withdrawals) {
      final d = w.data();
      if (test(d)) s += ((d['amount'] as num?)?.toDouble() ?? 0);
    }
    return s;
  }

  double get _pendingSum => _sumWhere((d) => (d['status'] as String? ?? '') == 'pending');
  double get _approvedSum => _sumWhere((d) => (d['status'] as String? ?? '') == 'approved');
  double get _available => (_lifetime - _approvedSum - _pendingSum).clamp(0, double.infinity);

  bool get _hasPending => _withdrawals.any((w) => (w.data()['status'] as String? ?? '') == 'pending');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FoodMelaaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: FoodMelaaColors.background, shape: BoxShape.circle),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: FoodMelaaColors.textDark, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text('My Wallet', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: FoodMelaaColors.textDark)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : RefreshIndicator(
              color: FoodMelaaColors.riderPrimary,
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Premium balance hero ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF047857), Color(0xFF065F46), Color(0xFF064E3B)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF047857).withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Text('AVAILABLE BALANCE',
                                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 1.0)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('₹${_available.toInt()}',
                              style: GoogleFonts.poppins(fontSize: 44, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
                          const SizedBox(height: 6),
                          Text('$_deliveredCount deliveries × ₹40',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(child: _heroStat('EARNED', '₹${_lifetime.toInt()}')),
                              Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.2)),
                              Expanded(child: _heroStat('WITHDRAWN', '₹${_approvedSum.toInt()}')),
                              Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.2)),
                              Expanded(child: _heroStat('IN REVIEW', '₹${_pendingSum.toInt()}')),
                            ],
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: (_available < 40 || _hasPending) ? null : () => _showWithdrawSheet(),
                              icon: Icon(
                                _hasPending ? Icons.hourglass_top_rounded : Icons.payments_rounded,
                                size: 18,
                                color: _hasPending || _available < 40 ? FoodMelaaColors.textSecondary : FoodMelaaColors.riderPrimary,
                              ),
                              label: Text(
                                _hasPending
                                    ? 'Request Under Review'
                                    : _available < 40
                                        ? 'Min ₹40 to Withdraw'
                                        : 'Request Withdrawal',
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: _hasPending || _available < 40 ? FoodMelaaColors.textSecondary : FoodMelaaColors.riderPrimary),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                disabledBackgroundColor: Colors.white.withValues(alpha: 0.6),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // ── Withdrawal history ──
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(color: FoodMelaaColors.riderPrimaryLight, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.history_rounded, color: FoodMelaaColors.riderPrimary, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Text('Withdrawal History', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: FoodMelaaColors.textDark)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_withdrawals.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: FoodMelaaColors.borderLight),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: const BoxDecoration(color: FoodMelaaColors.background, shape: BoxShape.circle),
                              child: const Icon(Icons.savings_outlined, color: FoodMelaaColors.textGrey, size: 28),
                            ),
                            const SizedBox(height: 12),
                            Text('No withdrawals yet', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: FoodMelaaColors.textDark)),
                            const SizedBox(height: 4),
                            Text('Complete deliveries to earn, then withdraw to your account',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 12, color: FoodMelaaColors.textSecondary)),
                          ],
                        ),
                      )
                    else
                      for (final w in _withdrawals) _withdrawalCard(w.data()),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _heroStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white60, letterSpacing: 0.8)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
      ],
    );
  }

  Widget _withdrawalCard(Map<String, dynamic> d) {
    final amount = ((d['amount'] as num?)?.toDouble() ?? 0).toInt();
    final status = (d['status'] as String? ?? 'pending').toLowerCase();
    final date = _fmtDate(_wdTime(d));
    final Color color;
    final String label;
    final IconData icon;
    if (status == 'approved') {
      color = const Color(0xFF059669);
      label = 'APPROVED';
      icon = Icons.check_circle_rounded;
    } else if (status == 'rejected') {
      color = FoodMelaaColors.error;
      label = 'REJECTED';
      icon = Icons.cancel_rounded;
    } else {
      color = const Color(0xFFD97706);
      label = 'UNDER REVIEW';
      icon = Icons.hourglass_top_rounded;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('₹$amount', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, color: FoodMelaaColors.textDark)),
                Text(date, style: GoogleFonts.inter(fontSize: 11, color: FoodMelaaColors.textSecondary)),
                if (status == 'pending')
                  Text('Wait for admin approval', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                if (status == 'rejected' && (d['adminNote'] as String?)?.isNotEmpty == true)
                  Text(d['adminNote'] as String, style: GoogleFonts.inter(fontSize: 11, color: FoodMelaaColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(label, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    if (dt.millisecondsSinceEpoch == 0) return '';
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day}/${dt.month}/${dt.year} at $hour:$min $amPm';
  }

  void _showWithdrawSheet() {
    final ctrl = TextEditingController();
    String? error;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: FoodMelaaColors.borderGrey, borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: FoodMelaaColors.riderPrimaryLight, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.payments_rounded, color: FoodMelaaColors.riderPrimary, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Request Withdrawal', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: FoodMelaaColors.textDark)),
                  Text('Available: ₹${_available.toInt()}', style: GoogleFonts.inter(fontSize: 12, color: FoodMelaaColors.textSecondary)),
                ])),
              ]),
              const SizedBox(height: 16),
              Text('AMOUNT (₹)', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: FoodMelaaColors.textGrey, letterSpacing: 0.6)),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: FoodMelaaColors.textDark),
                decoration: InputDecoration(
                  hintText: 'Enter amount',
                  hintStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: FoodMelaaColors.textGrey),
                  filled: true,
                  fillColor: FoodMelaaColors.background,
                  prefixText: '₹ ',
                  prefixStyle: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: FoodMelaaColors.riderPrimary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: FoodMelaaColors.riderPrimary, width: 1.5)),
                  errorText: error,
                ),
                onChanged: (_) {
                  if (error != null) setSheet(() => error = null);
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [40, 100, 200, 500].map((v) {
                  final enabled = v <= _available;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: OutlinedButton(
                        onPressed: enabled
                            ? () {
                                ctrl.text = '$v';
                                setSheet(() => error = null);
                              }
                            : null,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: enabled ? FoodMelaaColors.riderPrimary.withValues(alpha: 0.4) : FoodMelaaColors.borderGrey),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: Text('₹$v',
                            style: GoogleFonts.poppins(
                                fontSize: 12, fontWeight: FontWeight.w700, color: enabled ? FoodMelaaColors.riderPrimary : FoodMelaaColors.textGrey)),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    final amount = int.tryParse(ctrl.text.trim()) ?? 0;
                    if (amount < 40) {
                      setSheet(() => error = 'Minimum ₹40');
                      return;
                    }
                    if (amount > _available) {
                      setSheet(() => error = 'Exceeds available ₹${_available.toInt()}');
                      return;
                    }
                    Navigator.pop(sheetCtx);
                    await _submitWithdrawal(amount);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: FoodMelaaColors.riderPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: Text('Submit Request', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                  child: Text('Admin approval ke baad amount milega',
                      style: GoogleFonts.inter(fontSize: 11, color: FoodMelaaColors.textSecondary))),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitWithdrawal(int amount) async {
    try {
      await FirebaseFirestore.instance.collection('withdrawals').add({
        'riderId': widget.riderId,
        'riderName': widget.riderName,
        'amount': amount,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      final ctx = context;
      await _load();
      if (!ctx.mounted) return;
      // ── Success → Under Review confirmation ──
      showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD97706).withValues(alpha: 0.25),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 44),
              ),
              const SizedBox(height: 16),
              Text('Under Review', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: FoodMelaaColors.textDark)),
              const SizedBox(height: 8),
              Text('Your ₹$amount withdrawal request is under review.\nWait for admin approval.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, color: FoodMelaaColors.textSecondary, height: 1.5)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: FoodMelaaColors.riderPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: Text('Done', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: FoodMelaaColors.error,
        content: Text('Request failed — check internet & try again',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.white)),
      ));
    }
  }
}
