import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'nurse_reviews_screen.dart';
import 'home_screen.dart' show isDark, bgColor, kCardDark, kTextDark, kSubDark, kBorderDark;

class MyRequestsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const MyRequestsScreen({super.key, required this.userData});
  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _requests = [];
  bool _isLoading = true;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _fetchRequests();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      final r = await http.get(Uri.parse(
          '${ApiService.baseUrl}/client_requests_api.php?action=my_requests&client_id=${widget.userData['user_id']}'))
          .timeout(const Duration(seconds: 15));
      final d = jsonDecode(r.body);
      if (d['status'] == 'success') setState(() => _requests = d['requests'] ?? []);
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  List<dynamic> get _pendingRequests => _requests
      .where((r) => ['Pending','Applied','DirectBooked'].contains(r['status']))
      .toList();

  List<dynamic> get _acceptedRequests => _requests
      .where((r) => ['Accepted','Cancelled','Rejected'].contains(r['status']))
      .toList();

  Future<void> _cancelRequest(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Request'),
        content: const Text('Are you sure you want to cancel this request?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Yes', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final r = await http.post(
          Uri.parse('${ApiService.baseUrl}/client_requests_api.php?action=cancel_request'),
          body: {
            'request_id': id.toString(),
            'client_id': widget.userData["user_id"].toString()
          });
      final d = jsonDecode(r.body);
      if (mounted && d['status'] == 'success') {
        _fetchRequests();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Request cancelled'), backgroundColor: Colors.orange));
        }
      }
    } catch (_) {}
  }

  void _viewApplications(Map<String, dynamic> request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ApplicationsSheet(
        request: request,
        userData: widget.userData,
        onAccepted: _fetchRequests,
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Accepted':     return Colors.green;
      case 'Applied':      return Colors.blue;
      case 'DirectBooked': return const Color(0xFF1A6BB5);
      case 'Cancelled':    return Colors.grey;
      case 'Rejected':     return Colors.red;
      default:             return Colors.orange;
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
        title: Text('My Requests', style: TextStyle(fontWeight: FontWeight.w700,
            color: dark ? kTextDark : const Color(0xFF1A2340))),
        iconTheme: IconThemeData(color: dark ? kTextDark : const Color(0xFF1A2340)),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF1A6BB5)), onPressed: _fetchRequests)],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFF1A6BB5),
          unselectedLabelColor: dark ? kSubDark : Colors.grey,
          indicatorColor: const Color(0xFF1A6BB5),
          tabs: [
            Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.pending_actions_rounded, size: 16),
              const SizedBox(width: 6),
              const Text('Pending', style: TextStyle(fontWeight: FontWeight.w600)),
              if (_pendingRequests.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)),
                    child: Text('${_pendingRequests.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
              ],
            ])),
            Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.check_circle_rounded, size: 16),
              const SizedBox(width: 6),
              const Text('Accepted', style: TextStyle(fontWeight: FontWeight.w600)),
              if (_acceptedRequests.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(10)),
                    child: Text('${_acceptedRequests.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
              ],
            ])),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabCtrl,
        children: [
          _RequestList(
            requests: _pendingRequests, dark: dark,
            emptyIcon: Icons.pending_actions_rounded,
            emptyText: 'No pending requests',
            emptySubText: 'Go to Home and request a service!',
            statusColor: _statusColor, onCancel: _cancelRequest,
            onViewApplicants: _viewApplications, showActions: true,
          ),
          _RequestList(
            requests: _acceptedRequests, dark: dark,
            emptyIcon: Icons.check_circle_outline_rounded,
            emptyText: 'No accepted requests yet',
            emptySubText: 'Accept a nurse from your pending requests!',
            statusColor: _statusColor, onCancel: _cancelRequest,
            onViewApplicants: _viewApplications, showActions: false,
          ),
        ],
      ),
    );
  }
}

// ── REQUEST LIST ──────────────────────────────────────────────────────────────
class _RequestList extends StatelessWidget {
  final List<dynamic> requests;
  final bool dark;
  final IconData emptyIcon;
  final String emptyText;
  final String emptySubText;
  final Color Function(String) statusColor;
  final Function(int) onCancel;
  final Function(Map<String, dynamic>) onViewApplicants;
  final bool showActions;

  const _RequestList({
    required this.requests, required this.dark, required this.emptyIcon,
    required this.emptyText, required this.emptySubText, required this.statusColor,
    required this.onCancel, required this.onViewApplicants, required this.showActions,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(emptyIcon, size: 64, color: dark ? kSubDark : Colors.grey),
        const SizedBox(height: 16),
        Text(emptyText, style: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 16)),
        const SizedBox(height: 4),
        Text(emptySubText, style: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 13)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (_, i) {
        final r = requests[i];
        final status = r['status'] ?? 'Pending';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: dark ? kCardDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(dark ? 0.25 : 0.05), blurRadius: 8)],
            border: status == 'Accepted' ? Border.all(color: Colors.green.shade300, width: 1.5) :
            status == 'Applied'  ? Border.all(color: Colors.blue.shade200) : null,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF1A6BB5).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(r['service_type'] ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF1A6BB5), fontSize: 12, fontWeight: FontWeight.w600))),
              ),
              const Spacer(),
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(status,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: statusColor(status), fontSize: 11, fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 10),
            _row(Icons.person_outline, 'Patient: ${r['patient_name'] ?? ''}', dark, bold: true),
            _row(Icons.phone_outlined, r['phone'] ?? '', dark),
            _row(Icons.location_on_outlined, r['address'] ?? '', dark),
            if (r['date'] != null)
              _row(Icons.calendar_today_outlined, '${r['date']} ${r['time'] ?? ''}', dark),
            // DirectBooked info
            if ((r['status'] == 'DirectBooked') && r['target_nurse_name'] != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color(0xFF1A6BB5).withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _row(Icons.person_pin_rounded, 'Sent directly to: ${r["target_nurse_name"]}', dark,
                      color: const Color(0xFF1A6BB5)),
                  const SizedBox(height: 2),
                  Text('Waiting for nurse to accept or reject',
                      style: TextStyle(fontSize: 11, color: dark ? kSubDark : Colors.grey)),
                ]),
              ),
            ],
            // Rejected info
            if (r['status'] == 'Rejected') ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10)),
                child: _row(Icons.cancel_rounded, 'Nurse rejected your booking request', dark, color: Colors.red),
              ),
            ],
            if (r['nurse_name'] != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.green.withOpacity(dark ? 0.15 : 0.06),
                    borderRadius: BorderRadius.circular(10)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _row(Icons.medical_services_outlined, 'Nurse: ${r['nurse_name']}', dark, color: Colors.green),
                  if (r['nurse_phone'] != null && r['nurse_phone'].toString().isNotEmpty)
                    _row(Icons.phone_outlined, r['nurse_phone'], dark, color: Colors.green),
                  if (r['nurse_location'] != null && r['nurse_location'].toString().isNotEmpty)
                    _row(Icons.location_on_outlined, r['nurse_location'], dark, color: Colors.green),
                ]),
              ),
            ],
            if (showActions && (status == 'Pending' || status == 'Applied')) ...[
              const SizedBox(height: 10),
              Row(children: [
                if (status == 'Applied')
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () => onViewApplicants(r),
                    icon: const Icon(Icons.people, size: 16),
                    label: const Text('View Applicants', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A6BB5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                  )),
                if (status == 'Applied') const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => onCancel(r['id']),
                  icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                  label: const Text('Cancel', style: TextStyle(color: Colors.red, fontSize: 12)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                )),
              ]),
            ],
          ]),
        );
      },
    );
  }

  Widget _row(IconData icon, String text, bool dark, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(icon, size: 14, color: color ?? (dark ? kSubDark : Colors.grey)),
        const SizedBox(width: 4),
        Expanded(child: Text(text, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: bold ? 13 : 12,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                color: color ?? (dark ? kTextDark : const Color(0xFF1A2340))))),
      ]),
    );
  }
}

// ── APPLICATIONS SHEET ────────────────────────────────────────────────────────
class _ApplicationsSheet extends StatefulWidget {
  final Map<String, dynamic> request;
  final Map<String, dynamic> userData;
  final VoidCallback onAccepted;
  const _ApplicationsSheet({required this.request, required this.userData, required this.onAccepted});
  @override
  State<_ApplicationsSheet> createState() => _ApplicationsSheetState();
}

class _ApplicationsSheetState extends State<_ApplicationsSheet> {
  List<dynamic> _apps = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() { super.initState(); _fetchApps(); }

  String _buildPhotoUrl(dynamic path) {
    if (path == null || path.toString().isEmpty) return '';
    final p = path.toString();
    if (p.startsWith('http')) return p;
    final base = ApiService.baseUrl.replaceAll('/api', '');
    return '$base/$p';
  }

  void _showNurseProfile(Map<String, dynamic> app) {
    final dark = isDark(context);
    final photo = app['photo_url']?.toString() ?? '';
    final name  = app['nurse_name']?.toString() ?? 'Nurse';
    final avg   = double.tryParse(app['avg_rating']?.toString() ?? '0') ?? 0.0;
    final total = int.tryParse(app['total_reviews']?.toString() ?? '0') ?? 0;
    final reviews = (app['recent_reviews'] as List?) ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
            color: dark ? kCardDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Container(width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
          Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20,0,20,20), children: [
            // ── HEADER ──────────────────────────────────────────────────
            Row(children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFF4CAF50).withOpacity(0.12),
                backgroundImage: photo.isNotEmpty && photo.startsWith('http') ? NetworkImage(photo) : null,
                child: (photo.isEmpty || !photo.startsWith('http'))
                    ? Text(name[0].toUpperCase(),
                    style: const TextStyle(color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.w800, fontSize: 22))
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                    color: dark ? kTextDark : const Color(0xFF1A2340))),
                const SizedBox(height: 4),
                if ((app['nurse_service'] ?? '').toString().isNotEmpty)
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                          color: const Color(0xFF1A6BB5).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(app['nurse_service']?.toString() ?? '',
                          style: const TextStyle(color: Color(0xFF1A6BB5),
                              fontSize: 12, fontWeight: FontWeight.w600))),
                if ((app['nurse_location'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.location_on_outlined, size: 13,
                        color: dark ? kSubDark : Colors.grey),
                    const SizedBox(width: 2),
                    Text(app['nurse_location']?.toString() ?? '',
                        style: TextStyle(fontSize: 12, color: dark ? kSubDark : Colors.grey)),
                  ]),
                ],
              ])),
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('Applied',
                      style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 16),
            // ── RATING ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: dark ? const Color(0xFF0F1624) : const Color(0xFFF8F9FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: dark ? kBorderDark : const Color(0xFFE0E6FF))),
              child: Row(children: [
                Column(children: [
                  Text(avg > 0 ? avg.toStringAsFixed(1) : '—',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
                          color: Color(0xFF1A6BB5))),
                  Row(children: List.generate(5, (i) => Icon(
                      i < avg.round() ? Icons.star_rounded : Icons.star_border_rounded,
                      color: const Color(0xFFFFC107), size: 14))),
                  const SizedBox(height: 2),
                  Text('$total review${total != 1 ? "s" : ""}',
                      style: TextStyle(fontSize: 11, color: dark ? kSubDark : Colors.grey)),
                ]),
                const SizedBox(width: 16),
                Expanded(child: Column(children: [
                  _infoRow2(Icons.work_outline_rounded,
                      'Exp: ' + (app['experience']?.toString() ?? '—'), dark),
                  _infoRow2(Icons.attach_money_rounded,
                      '₹' + (app['salary']?.toString() ?? '0') + '/day', dark),
                  _infoRow2(Icons.phone_outlined,
                      app['nurse_phone']?.toString() ?? '—', dark),
                ])),
              ]),
            ),
            const SizedBox(height: 12),
            // ── BIO ─────────────────────────────────────────────────────
            if ((app['bio'] ?? '').toString().isNotEmpty) ...[
              Text(app['bio'].toString(),
                  style: TextStyle(fontSize: 13, height: 1.5,
                      color: dark ? kSubDark : const Color(0xFF6B7A9B))),
              const SizedBox(height: 12),
            ],
            // ── VIEW ALL REVIEWS ─────────────────────────────────────────
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                final nurseId = int.tryParse(app['nurse_id']?.toString() ?? '0') ?? 0;
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => NurseReviewsScreen(
                        userData: widget.userData,
                        nurseId: nurseId,
                        nurseName: name)));
              },
              icon: const Icon(Icons.star_rounded, size: 16),
              label: Text('View All Reviews ($total)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A6BB5),
                side: const BorderSide(color: Color(0xFF1A6BB5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
            const SizedBox(height: 12),
            // ── RECENT REVIEWS ───────────────────────────────────────────
            if (reviews.isNotEmpty) ...[
              Text('Recent Reviews',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                      color: dark ? kTextDark : const Color(0xFF1A2340))),
              const SizedBox(height: 8),
              ...reviews.map((r) {
                final rRating = double.tryParse(r['rating']?.toString() ?? '0') ?? 0;
                final isAnon  = r['is_anonymous']?.toString() == '1';
                final rName   = isAnon ? 'Anonymous' : (r['client_name']?.toString() ?? 'Client');
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: dark ? const Color(0xFF0F1624) : const Color(0xFFF8F9FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: dark ? kBorderDark : const Color(0xFFE0E6FF))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      CircleAvatar(radius: 14,
                          backgroundColor: const Color(0xFF1A6BB5).withOpacity(0.1),
                          child: Text(rName[0].toUpperCase(),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A6BB5)))),
                      const SizedBox(width: 8),
                      Text(rName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                          color: dark ? kTextDark : const Color(0xFF1A2340))),
                      const Spacer(),
                      Row(children: List.generate(5, (i) => Icon(
                          i < rRating.round() ? Icons.star_rounded : Icons.star_border_rounded,
                          color: const Color(0xFFFFC107), size: 12))),
                    ]),
                    if ((r['comment'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(r['comment'].toString(),
                          style: TextStyle(fontSize: 12, color: dark ? kSubDark : Colors.grey,
                              height: 1.4)),
                    ],
                  ]),
                );
              }),
            ],
            const SizedBox(height: 12),
            // ── ACCEPT BUTTON ────────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: () { Navigator.pop(context); _acceptNurse(app['id']); },
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: Text('Accept ${name.split(' ').first}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0),
            ),
          ])),
        ]),
      ),
    );
  }

  Widget _infoRow2(IconData icon, String text, bool dark) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Icon(icon, size: 13, color: dark ? kSubDark : Colors.grey),
      const SizedBox(width: 4),
      Expanded(child: Text(text,
          style: TextStyle(fontSize: 12, color: dark ? kSubDark : Colors.grey),
          overflow: TextOverflow.ellipsis)),
    ]),
  );

  Future<void> _fetchApps() async {
    setState(() { _isLoading = true; _error = ''; });

    // Get request_id — try multiple keys since JOIN can sometimes overwrite 'id'
    final requestId = widget.request['id'] ?? widget.request['request_id'];
    final clientId  = widget.userData['user_id'];

    if (requestId == null) {
      setState(() { _isLoading = false; _error = 'Request ID is missing. Keys: ${widget.request.keys.toList()}'; });
      return;
    }

    try {
      final url = '${ApiService.baseUrl}/client_requests_api.php'
          '?action=get_applications'
          '&request_id=$requestId'
          '&client_id=$clientId';

      final r = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));

      // Check for HTML error page
      if (r.body.trim().startsWith('<')) {
        setState(() { _isLoading = false; _error = 'Server error in PHP file'; });
        return;
      }

      final d = jsonDecode(r.body);

      if (d['status'] == 'success') {
        setState(() {
          _apps = d['applications'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = d['message'] ?? 'Failed to load applicants';
        });
      }
    } catch (e) {
      setState(() { _isLoading = false; _error = 'Connection error: $e'; });
    }
  }

  Future<void> _acceptNurse(int bookingId) async {
    try {
      final r = await http.post(
          Uri.parse('${ApiService.baseUrl}/client_requests_api.php?action=accept_application'),
          body: {
            'booking_id': '$bookingId',
            'request_id': '${widget.request['id']}',
          });
      final d = jsonDecode(r.body);
      if (d['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nurse accepted! 🎉'), backgroundColor: Colors.green));
        widget.onAccepted();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(d['message'] ?? 'Failed'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
          color: dark ? kCardDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(children: [
        // Handle bar
        Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(color: Colors.grey.shade500, borderRadius: BorderRadius.circular(2))),

        // Title row with refresh
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Text('Nurse Applicants', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                  color: dark ? kTextDark : const Color(0xFF1A2340))),
              Text('Select the nurse you want',
                  style: TextStyle(fontSize: 12, color: dark ? kSubDark : Colors.grey)),
            ])),
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF1A6BB5)),
              onPressed: _fetchApps,
            ),
          ]),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error.isNotEmpty
          // ── ERROR STATE ────────────────────────────────────────────
              ? Center(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(_error, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchApps,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A6BB5)),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ]),
          ))
              : _apps.isEmpty
          // ── EMPTY STATE ────────────────────────────────────────
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.people_outline, size: 64, color: dark ? kSubDark : Colors.grey),
            const SizedBox(height: 12),
            Text('No applicants yet',
                style: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Nurses will appear here once they apply',
                style: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _fetchApps,
              icon: const Icon(Icons.refresh, color: Color(0xFF1A6BB5)),
              label: const Text('Refresh', style: TextStyle(color: Color(0xFF1A6BB5))),
            ),
          ]))
          // ── APPLICANTS LIST ────────────────────────────────────
              : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _apps.length,
              itemBuilder: (_, i) {
                final app = _apps[i];
                final photo = app['photo_url'] ?? '';
                final name  = app['nurse_name'] ?? 'Nurse';
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: dark ? const Color(0xFF0F1624) : const Color(0xFFF8F9FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: dark ? kBorderDark : const Color(0xFFE0E6FF))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    GestureDetector(
                      onTap: () => _showNurseProfile(app),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFF4CAF50).withOpacity(0.12),
                          backgroundImage: photo.isNotEmpty && photo.startsWith('http') ? NetworkImage(photo) : null,
                          child: !photo.startsWith('http') || photo.isEmpty
                              ? Text(name[0].toUpperCase(),
                              style: const TextStyle(color: Color(0xFF4CAF50),
                                  fontWeight: FontWeight.w700, fontSize: 16))
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: TextStyle(fontWeight: FontWeight.w700,
                              fontSize: 14, color: dark ? kTextDark : const Color(0xFF1A2340))),
                          if ((app['nurse_service'] ?? '').toString().isNotEmpty)
                            Text(app['nurse_service'] ?? '',
                                style: TextStyle(fontSize: 12, color: dark ? kSubDark : Colors.grey)),
                          if ((app['nurse_location'] ?? '').toString().isNotEmpty)
                            Row(children: [
                              Icon(Icons.location_on_outlined, size: 12, color: dark ? kSubDark : Colors.grey),
                              const SizedBox(width: 2),
                              Text(app['nurse_location'] ?? '',
                                  style: TextStyle(fontSize: 11, color: dark ? kSubDark : Colors.grey)),
                            ]),
                          const SizedBox(height: 3),
                          Builder(builder: (_) {
                            final avg = double.tryParse(app['avg_rating']?.toString() ?? '0') ?? 0.0;
                            final total = int.tryParse(app['total_reviews']?.toString() ?? '0') ?? 0;
                            return Row(children: [
                              ...List.generate(5, (j) => Icon(
                                  j < avg.round() ? Icons.star_rounded : Icons.star_border_rounded,
                                  color: const Color(0xFFFFC107), size: 13)),
                              const SizedBox(width: 4),
                              Text(
                                  avg > 0 ? '${avg.toStringAsFixed(1)} ($total review${total != 1 ? 's' : ''})' : 'No reviews yet',
                                  style: TextStyle(fontSize: 10, color: dark ? kSubDark : Colors.grey)),
                            ]);
                          }),
                        ])),
                        // Applied time
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Text('Applied',
                                  style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.w600))),
                        ]),
                      ]), // end Row
                    ), // end GestureDetector
                    const SizedBox(height: 8),
                    if ((app['experience'] ?? '').toString().isNotEmpty)
                      Padding(padding: const EdgeInsets.only(bottom: 2),
                          child: Text('📅 Experience: ${app['experience']} years',
                              style: TextStyle(fontSize: 12, color: dark ? kSubDark : Colors.grey))),
                    if ((app['salary'] ?? '').toString().isNotEmpty)
                      Padding(padding: const EdgeInsets.only(bottom: 2),
                          child: Text('💰 Expected: ₹${app['salary']}/day',
                              style: TextStyle(fontSize: 12, color: dark ? kSubDark : Colors.grey))),
                    if ((app['bio'] ?? '').toString().isNotEmpty)
                      Padding(padding: const EdgeInsets.only(bottom: 2),
                          child: Text(app['bio'],
                              style: TextStyle(fontSize: 12, color: dark ? kSubDark : Colors.grey),
                              maxLines: 2, overflow: TextOverflow.ellipsis)),
                    if ((app['nurse_phone'] ?? '').toString().isNotEmpty)
                      Padding(padding: const EdgeInsets.only(bottom: 2),
                          child: Row(children: [
                            Icon(Icons.phone_outlined, size: 12, color: dark ? kSubDark : Colors.grey),
                            const SizedBox(width: 4),
                            Text(app['nurse_phone'] ?? '',
                                style: TextStyle(fontSize: 12, color: dark ? kSubDark : Colors.grey)),
                          ])),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                          onPressed: () => _acceptNurse(app['id']),
                          icon: const Icon(Icons.check_circle_rounded, size: 18),
                          label: Text('Accept ${name.split(' ').first}',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green, foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0)),
                    ),
                  ]),
                );
              }),
        ),
      ]),
    );
  }
}