import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'home_screen.dart' show isDark, bgColor, kCardDark, kTextDark, kSubDark, kBorderDark;

class AdminForgotPasswordScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const AdminForgotPasswordScreen({super.key, required this.userData});
  @override
  State<AdminForgotPasswordScreen> createState() => _AdminForgotPasswordScreenState();
}

class _AdminForgotPasswordScreenState extends State<AdminForgotPasswordScreen> {
  List<dynamic> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      final r = await http.get(
        Uri.parse('${ApiService.baseUrl}/forgot_password_api.php?action=get_requests'),
      ).timeout(const Duration(seconds: 15));
      final d = jsonDecode(r.body);
      if (d['status'] == 'success') setState(() => _requests = d['requests'] ?? []);
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  void _showResetDialog(Map<String, dynamic> req) {
    final passCtrl = TextEditingController();
    bool showPass = false;
    final dark = isDark(context);
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: dark ? kCardDark : Colors.white,
          title: Text('Reset Password for ${req['user_name'] ?? req['email']}',
              style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A2340))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Email: ${req['email']}',
                  style: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 13)),
              const SizedBox(height: 14),
              TextField(
                controller: passCtrl,
                obscureText: !showPass,
                style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A2340)),
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: TextStyle(color: dark ? kSubDark : Colors.grey),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF1A6BB5)),
                  suffixIcon: IconButton(
                    icon: Icon(showPass ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        color: const Color(0xFF1A6BB5)),
                    onPressed: () => setS(() => showPass = !showPass),
                  ),
                  filled: true,
                  fillColor: dark ? const Color(0xFF0F1624) : const Color(0xFFF0F5FB),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: dark ? kBorderDark : const Color(0xFFE0E6FF))),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (passCtrl.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Min 6 characters'), backgroundColor: Colors.orange));
                  return;
                }
                Navigator.pop(ctx);
                final r = await http.post(
                  Uri.parse('${ApiService.baseUrl}/forgot_password_api.php?action=reset_password'),
                  body: {'id': '${req['id']}', 'email': req['email'], 'new_password': passCtrl.text},
                );
                final d = jsonDecode(r.body);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(d['message'] ?? 'Done'),
                  backgroundColor: d['status'] == 'success' ? Colors.green : Colors.red,
                ));
                _fetchRequests();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A6BB5), foregroundColor: Colors.white),
              child: const Text('Reset Password'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    final pending = _requests.where((r) => r['status'] == 'Pending').toList();
    final done    = _requests.where((r) => r['status'] == 'Done').toList();

    return Scaffold(
      backgroundColor: bgColor(context),
      appBar: AppBar(
        backgroundColor: dark ? kCardDark : Colors.white,
        elevation: 1,
        title: Text('Password Reset Requests',
            style: TextStyle(fontWeight: FontWeight.w700,
                color: dark ? kTextDark : const Color(0xFF1A2340))),
        iconTheme: IconThemeData(color: dark ? kTextDark : const Color(0xFF1A2340)),
        actions: [
          if (pending.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
              child: Text('${pending.length} pending',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF1A6BB5)), onPressed: _fetchRequests),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.lock_open_rounded, size: 64, color: dark ? kSubDark : Colors.grey),
        const SizedBox(height: 16),
        Text('No password reset requests',
            style: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 16)),
      ]))
          : RefreshIndicator(
        onRefresh: _fetchRequests,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (pending.isNotEmpty) ...[
              Text('⏳ Pending',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14,
                      color: dark ? kTextDark : const Color(0xFF1A2340))),
              const SizedBox(height: 8),
              ...pending.map((req) => _requestCard(req, true, dark)),
              const SizedBox(height: 16),
            ],
            if (done.isNotEmpty) ...[
              Text('✅ Completed',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14,
                      color: dark ? kTextDark : const Color(0xFF1A2340))),
              const SizedBox(height: 8),
              ...done.map((req) => _requestCard(req, false, dark)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> req, bool isPending, bool dark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: dark ? kCardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isPending ? Border.all(color: Colors.orange.shade300) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(dark ? 0.25 : 0.05), blurRadius: 8)],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: isPending ? Colors.orange.shade50 : Colors.green.shade50,
            child: Icon(isPending ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                color: isPending ? Colors.orange : Colors.green, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(req['user_name'] ?? 'Unknown',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                        color: dark ? kTextDark : const Color(0xFF1A2340))),
                Text(req['email'] ?? '',
                    style: TextStyle(fontSize: 12, color: dark ? kSubDark : Colors.grey)),
                if (req['phone'] != null)
                  Text('📞 ${req['phone']}',
                      style: TextStyle(fontSize: 12, color: dark ? kSubDark : Colors.grey)),
                Text(req['created_at'] ?? '',
                    style: TextStyle(fontSize: 11, color: dark ? kSubDark : Colors.grey)),
              ],
            ),
          ),
          if (isPending)
            ElevatedButton(
              onPressed: () => _showResetDialog(req),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A6BB5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('Reset', style: TextStyle(fontSize: 13)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
              child: const Text('Done',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
