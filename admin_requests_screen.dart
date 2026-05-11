import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'home_screen.dart' show isDark, kCardDark, kTextDark, kSubDark, kBorderDark;

class AdminRequestsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const AdminRequestsScreen({super.key, required this.userData});
  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  List<dynamic> _requests = [];
  bool _isLoading = true;

  final _statusColors = {
    'Pending':     Colors.orange,
    'Applied':     Colors.blue,
    'DirectBooked':Colors.blue,
    'Accepted':    Colors.green,
    'Rejected':    Colors.red,
    'Cancelled':   Colors.red,
  };

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final r = await http.get(Uri.parse('${ApiService.baseUrl}/admin_api.php?action=get_requests'))
          .timeout(const Duration(seconds: 15));
      final d = jsonDecode(r.body);
      setState(() {
        _requests = d['requests'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _fmt(String? date) {
    if (date == null || date.isEmpty) return '';
    try {
      final d = DateTime.parse(date);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${months[d.month - 1]}';
    } catch (_) { return date; }
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0F1624) : const Color(0xFFF0F5FB),
      appBar: AppBar(
        title: const Text('All Service Requests', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: const Color(0xFF1A6BB5),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
        const SizedBox(height: 12),
        Text('No requests yet', style: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 16)),
      ]))
          : ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: _requests.length,
        itemBuilder: (_, i) {
          final r = _requests[i];
          final status = r['status'] ?? 'Pending';
          final sc = _statusColors[status] ?? Colors.orange;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: dark ? kCardDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: dark ? kBorderDark : const Color(0xFFE0E6FF)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Top: service type + status + date
              Wrap(spacing: 6, runSpacing: 4, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: const Color(0xFF1A6BB5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(r['service_type'] ?? '—',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF1A6BB5), fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: sc.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(status,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: sc, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                Text(_fmt(r['created_at']),
                    style: TextStyle(fontSize: 11, color: dark ? kSubDark : Colors.grey)),
              ]),
              const SizedBox(height: 8),
              // Patient name
              Text(r['patient_name'] ?? '—',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14,
                      color: dark ? kTextDark : const Color(0xFF1A2340))),
              const SizedBox(height: 3),
              // Client → Nurse
              Row(children: [
                Icon(Icons.person_outline, size: 13, color: dark ? kSubDark : Colors.grey),
                const SizedBox(width: 3),
                Text(r['client_name'] ?? '—',
                    style: TextStyle(fontSize: 12, color: dark ? kSubDark : Colors.grey)),
                if ((r['nurse_name'] ?? '').isNotEmpty) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward, size: 12, color: Colors.green),
                  const SizedBox(width: 3),
                  Text(r['nurse_name'],
                      style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                ],
              ]),
              if ((r['address'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.location_on_outlined, size: 13, color: dark ? kSubDark : Colors.grey),
                  const SizedBox(width: 3),
                  Expanded(child: Text(r['address'],
                      style: TextStyle(fontSize: 12, color: dark ? kSubDark : Colors.grey),
                      overflow: TextOverflow.ellipsis)),
                ]),
              ],
            ]),
          );
        },
      ),
    );
  }
}