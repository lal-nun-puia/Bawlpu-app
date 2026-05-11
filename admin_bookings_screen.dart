import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'home_screen.dart' show isDark, bgColor, kCardDark, kTextDark, kSubDark;

class AdminBookingsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const AdminBookingsScreen({super.key, required this.userData});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  List<dynamic> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/admin_api.php?action=get_bookings'),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        setState(() => _bookings = data['bookings'] ?? []);
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Accepted': return Colors.green;
      case 'Rejected': return Colors.red;
      case 'Cancelled': return Colors.grey;
      default: return Colors.orange;
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
        title: Text('All Bookings',
            style: TextStyle(fontWeight: FontWeight.w700,
                color: dark ? kTextDark : const Color(0xFF1A1A2E))),
        iconTheme: IconThemeData(color: dark ? kTextDark : const Color(0xFF1A1A2E)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF0D6EFD)), onPressed: _fetchBookings),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookings.isEmpty
          ? Center(child: Text('No bookings yet',
          style: TextStyle(color: dark ? kSubDark : Colors.grey)))
          : RefreshIndicator(
        onRefresh: _fetchBookings,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _bookings.length,
          itemBuilder: (_, i) {
            final b = _bookings[i];
            final status = b['status'] ?? 'Applied';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: dark ? kCardDark : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(dark ? 0.25 : 0.05), blurRadius: 8)],
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('#${b['id']}',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0D6EFD))),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(status,
                            style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.person_outline, size: 14, color: dark ? kSubDark : Colors.grey),
                    const SizedBox(width: 4),
                    Text('Client: ${b['client_name'] ?? 'N/A'}',
                        style: TextStyle(fontSize: 13, color: dark ? kTextDark : const Color(0xFF1A1A2E))),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.medical_services_outlined, size: 14, color: dark ? kSubDark : Colors.grey),
                    const SizedBox(width: 4),
                    Text('Nurse: ${b['nurse_name'] ?? 'N/A'}',
                        style: TextStyle(fontSize: 13, color: dark ? kTextDark : const Color(0xFF1A1A2E))),
                  ]),
                  if (b['date'] != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.calendar_today_outlined, size: 14, color: dark ? kSubDark : Colors.grey),
                      const SizedBox(width: 4),
                      Text('${b['date']} ${b['time'] ?? ''}',
                          style: TextStyle(fontSize: 12, color: dark ? kSubDark : Colors.grey)),
                    ]),
                  ],
                  const SizedBox(height: 4),
                  Text('Created: ${b['created_at'] ?? ''}',
                      style: TextStyle(fontSize: 11, color: dark ? kSubDark : Colors.grey)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}