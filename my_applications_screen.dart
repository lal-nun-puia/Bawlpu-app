import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'home_screen.dart' show isDark, bgColor, kCardDark, kTextDark, kSubDark, kBorderDark;

class MyApplicationsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const MyApplicationsScreen({super.key, required this.userData});
  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  List<dynamic> _apps = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _fetchApps(); }

  Future<void> _fetchApps() async {
    setState(() => _isLoading = true);
    try {
      final r = await http.get(Uri.parse(
          '${ApiService.baseUrl}/nurse_jobs_api.php?action=my_applications'
              '&nurse_id=${widget.userData['user_id']}'))
          .timeout(const Duration(seconds: 15));
      final d = jsonDecode(r.body);
      if (d['status'] == 'success' && mounted) {
        setState(() => _apps = d['applications'] ?? []);
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  // Check if this is a direct booking
  bool _isDirect(Map<String, dynamic> app) {
    final v = app['is_direct'];
    if (v == null) return false;
    return v == 1 || v == '1' || v == true || v.toString() == '1';
  }

  Future<void> _acceptDirect(Map<String, dynamic> app) async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [
        Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
        SizedBox(width: 8),
        Text('Accept Booking'),
      ]),
      content: Text('Accept the direct booking from ${app['client_name'] ?? 'client'}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          child: const Text('Accept'),
        ),
      ],
    ));
    if (confirm != true) return;
    try {
      final r = await http.post(
        Uri.parse('${ApiService.baseUrl}/nurse_jobs_api.php?action=accept_direct'),
        body: {
          'booking_id': '${app['id']}',
          'nurse_id':   '${widget.userData['user_id']}',
          'request_id': '${app['request_id'] ?? 0}',
        },
      ).timeout(const Duration(seconds: 10));
      final d = jsonDecode(r.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(d['message'] ?? (d['status'] == 'success' ? 'Accepted!' : 'Failed')),
          backgroundColor: d['status'] == 'success' ? Colors.green : Colors.red,
        ));
      }
      if (d['status'] == 'success') _fetchApps();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _rejectDirect(Map<String, dynamic> app) async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [
        Icon(Icons.cancel_rounded, color: Colors.red, size: 24),
        SizedBox(width: 8),
        Text('Reject Booking'),
      ]),
      content: const Text('Reject this direct booking? The client will be notified.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text('Reject'),
        ),
      ],
    ));
    if (confirm != true) return;
    try {
      final r = await http.post(
        Uri.parse('${ApiService.baseUrl}/nurse_jobs_api.php?action=reject_direct'),
        body: {
          'booking_id': '${app['id']}',
          'nurse_id':   '${widget.userData['user_id']}',
          'request_id': '${app['request_id'] ?? 0}',
        },
      ).timeout(const Duration(seconds: 10));
      final d = jsonDecode(r.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(d['message'] ?? 'Done'),
          backgroundColor: d['status'] == 'success' ? Colors.orange : Colors.red,
        ));
      }
      if (d['status'] == 'success') _fetchApps();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _withdraw(Map<String, dynamic> app) async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Withdraw Application'),
      content: const Text('Withdraw this application?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
        TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (confirm != true) return;
    try {
      final r = await http.post(
        Uri.parse('${ApiService.baseUrl}/nurse_jobs_api.php?action=withdraw'),
        body: {
          'booking_id': '${app['id']}',
          'nurse_id':   '${widget.userData['user_id']}',
          'request_id': '${app['request_id'] ?? 0}',
        },
      ).timeout(const Duration(seconds: 10));
      final d = jsonDecode(r.body);
      if (d['status'] == 'success') {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Application withdrawn'), backgroundColor: Colors.orange));
        _fetchApps();
      }
    } catch (_) {}
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Accepted':  return Colors.green;
      case 'Rejected':  return Colors.red;
      case 'Withdrawn': return Colors.grey;
      default:          return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return Scaffold(
      backgroundColor: bgColor(context),
      appBar: AppBar(
        backgroundColor: dark ? kCardDark : Colors.white,
        elevation: 1,
        title: Text('My Applications', style: TextStyle(
            fontWeight: FontWeight.w700,
            color: dark ? kTextDark : const Color(0xFF1A2340))),
        iconTheme: IconThemeData(color: dark ? kTextDark : const Color(0xFF1A2340)),
        actions: [IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF1A6BB5)),
            onPressed: _fetchApps)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _apps.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.work_outline, size: 64, color: dark ? kSubDark : Colors.grey),
        const SizedBox(height: 16),
        Text('No applications yet',
            style: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 16)),
        const SizedBox(height: 4),
        Text('Apply for jobs from Available Jobs',
            style: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 13)),
      ]))
          : RefreshIndicator(
        onRefresh: _fetchApps,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _apps.length,
          itemBuilder: (_, i) {
            final app  = _apps[i];
            final status   = app['status']?.toString() ?? 'Applied';
            final direct   = _isDirect(app);
            final color    = _statusColor(status);
            final clientName = app['client_name']?.toString() ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: dark ? kCardDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(dark ? 0.25 : 0.05),
                    blurRadius: 8)],
                border: direct && status == 'Applied'
                    ? Border.all(color: const Color(0xFF1A6BB5), width: 1.5)
                    : status == 'Accepted'
                    ? Border.all(color: Colors.green.shade300, width: 1.5)
                    : status == 'Rejected'
                    ? Border.all(color: Colors.red.shade200)
                    : null,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── TOP ROW: service + direct badge + status ────────
                Wrap(spacing: 8, runSpacing: 6, children: [
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: const Color(0xFF1A6BB5).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(app['service_type']?.toString() ?? '',
                          style: const TextStyle(color: Color(0xFF1A6BB5),
                              fontSize: 12, fontWeight: FontWeight.w600))),
                  if (direct)
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: const Color(0xFF1A6BB5),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.person_pin_rounded, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text('Direct Request', style: TextStyle(
                              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                        ])),
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(status, style: TextStyle(
                          color: color, fontSize: 11, fontWeight: FontWeight.w600))),
                ]),
                const SizedBox(height: 10),

                // ── DIRECT INFO BANNER ─────────────────────────────
                if (direct && status == 'Applied') ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: const Color(0xFF1A6BB5).withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1A6BB5).withOpacity(0.2))),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFF1A6BB5), size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        'Client $clientName specifically chose you for this service.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF1A6BB5)),
                      )),
                    ]),
                  ),
                ],

                // ── DETAILS ────────────────────────────────────────
                _row(Icons.person_outline, 'Patient: ${app['patient_name'] ?? ''}', dark, bold: true),
                _row(Icons.location_on_outlined, app['address']?.toString() ?? '', dark),
                _row(Icons.phone_outlined, app['phone']?.toString() ?? '', dark),
                if ((app['date']?.toString() ?? '').isNotEmpty)
                  _row(Icons.calendar_today_outlined,
                      '${app['date']} ${app['time'] ?? ''}', dark),
                if ((app['notes']?.toString() ?? '').isNotEmpty)
                  _row(Icons.note_outlined, app['notes'].toString(), dark),
                _row(Icons.person_rounded, 'Client: $clientName', dark),

                const SizedBox(height: 12),

                // ── ACTIONS ────────────────────────────────────────
                // Direct + Applied → Accept / Reject
                if (direct && status == 'Applied')
                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _acceptDirect(app),
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: const Text('Accept',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _rejectDirect(app),
                        icon: const Icon(Icons.cancel_rounded, size: 18, color: Colors.red),
                        label: const Text('Reject',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                                color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ]),

                // Normal + Applied → Withdraw
                if (!direct && status == 'Applied')
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _withdraw(app),
                      icon: const Icon(Icons.undo_rounded, size: 16, color: Colors.orange),
                      label: const Text('Withdraw Application',
                          style: TextStyle(color: Colors.orange, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),

                // Accepted
                if (status == 'Accepted')
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                          direct
                              ? 'You accepted! Contact client $clientName to confirm details.'
                              : 'Client accepted your application! Contact them.',
                          style: const TextStyle(color: Colors.green,
                              fontSize: 12, fontWeight: FontWeight.w600))),
                    ]),
                  ),

                // Rejected
                if (status == 'Rejected')
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.cancel_rounded, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(child: Text(
                          'You rejected this booking request.',
                          style: TextStyle(color: Colors.red,
                              fontSize: 12, fontWeight: FontWeight.w600))),
                    ]),
                  ),
              ]),
            );
          },
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text, bool dark, {bool bold = false, Color? color}) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(children: [
        Icon(icon, size: 14, color: color ?? (dark ? kSubDark : Colors.grey)),
        const SizedBox(width: 6),
        Expanded(child: Text(text, overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: bold ? 13 : 12,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                color: color ?? (dark ? kTextDark : const Color(0xFF1A2340))))),
      ]),
    );
  }
}