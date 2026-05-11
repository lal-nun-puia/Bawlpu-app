import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'home_screen.dart' show isDark, bgColor, kCardDark, kTextDark, kSubDark, kBorderDark;

class AdminNotificationScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const AdminNotificationScreen({super.key, required this.userData});
  @override
  State<AdminNotificationScreen> createState() => _AdminNotificationScreenState();
}

class _AdminNotificationScreenState extends State<AdminNotificationScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl  = TextEditingController();
  String _selectedRole = '';
  bool _isLoading = false;
  bool _sent = false;
  String? _message;
  bool _isError = false;

  static bool _isSending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendNotification() async {
    if (_isSending) {
      setState(() { _message = 'Please wait...'; _isError = true; });
      return;
    }
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      setState(() { _message = 'Title and message are required'; _isError = true; });
      return;
    }

    _isSending = true;
    setState(() { _isLoading = true; _message = null; _sent = true; });

    try {
      final title = _titleCtrl.text.trim();
      final body  = _bodyCtrl.text.trim();
      final role  = _selectedRole;

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/admin_api.php?action=send_notification'),
        body: {'title': title, 'body': body, 'role': role},
      ).timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body);
      if (mounted) {
        setState(() {
          _message  = data['message'] ?? 'Done';
          _isError  = data['status'] != 'success';
          _isLoading = false;
        });
      }

      if (data['status'] == 'success') {
        _titleCtrl.clear();
        _bodyCtrl.clear();
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) setState(() { _sent = false; _message = null; });
        _isSending = false;
      } else {
        _isSending = false;
        if (mounted) setState(() { _sent = false; _isLoading = false; });
      }
    } catch (e) {
      _isSending = false;
      if (mounted) setState(() {
        _message  = 'Failed to send. Check connection.';
        _isError  = true;
        _isLoading = false;
        _sent     = false;
      });
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
        title: Text('Send Notification',
            style: TextStyle(fontWeight: FontWeight.w700,
                color: dark ? kTextDark : const Color(0xFF1A2340))),
        iconTheme: IconThemeData(color: dark ? kTextDark : const Color(0xFF1A2340)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            color: dark ? kCardDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(dark ? 0.25 : 0.06), blurRadius: 16)],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Broadcast Notification',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                      color: dark ? kTextDark : const Color(0xFF1A2340))),
              const SizedBox(height: 4),
              Text('Send a message to users',
                  style: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 13)),
              const SizedBox(height: 24),

              // Audience
              Text('Audience',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: dark ? kTextDark : const Color(0xFF1A2340))),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF0F1624) : const Color(0xFFF0F5FB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: dark ? kBorderDark : const Color(0xFFE0E6FF)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRole,
                    isExpanded: true,
                    dropdownColor: dark ? kCardDark : Colors.white,
                    style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A2340)),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF1A6BB5)),
                    items: [
                      DropdownMenuItem(value: '',
                          child: Text('All Users',
                              style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A2340)))),
                      DropdownMenuItem(value: 'Client',
                          child: Text('Clients Only',
                              style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A2340)))),
                      DropdownMenuItem(value: 'Nurse',
                          child: Text('Nurses Only',
                              style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A2340)))),
                    ],
                    onChanged: _sent ? null : (v) => setState(() => _selectedRole = v ?? ''),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text('Title',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: dark ? kTextDark : const Color(0xFF1A2340))),
              const SizedBox(height: 8),
              TextField(
                controller: _titleCtrl,
                enabled: !_sent,
                style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A2340)),
                decoration: _fieldDeco('Notification title', Icons.title_rounded, dark),
              ),
              const SizedBox(height: 16),

              // Message
              Text('Message',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: dark ? kTextDark : const Color(0xFF1A2340))),
              const SizedBox(height: 8),
              TextField(
                controller: _bodyCtrl,
                maxLines: 4,
                enabled: !_sent,
                style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A2340)),
                decoration: _fieldDeco('Write your message here...', Icons.message_rounded, dark),
              ),
              const SizedBox(height: 20),

              // Result message
              if (_message != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isError ? const Color(0xFFFFEEEE) : const Color(0xFFEEFFEE),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _isError ? Colors.red.shade200 : Colors.green.shade200),
                  ),
                  child: Text(_message!,
                      style: TextStyle(
                          color: _isError ? Colors.red.shade700 : Colors.green.shade700,
                          fontSize: 13)),
                ),
                const SizedBox(height: 16),
              ],

              // Send Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (_isLoading || _sent) ? null : _sendNotification,
                  icon: _isLoading
                      ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Icon(_sent ? Icons.check_rounded : Icons.send_rounded),
                  label: Text(
                      _isLoading ? 'Sending...' : _sent ? 'Sent! ✅' : 'Send Notification',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _sent ? Colors.green : const Color(0xFF1A6BB5),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _sent ? Colors.green : Colors.grey,
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDeco(String hint, IconData icon, bool dark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 13),
      prefixIcon: Icon(icon, color: dark ? kSubDark : Colors.grey, size: 20),
      filled: true,
      fillColor: dark ? const Color(0xFF0F1624) : const Color(0xFFF0F5FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dark ? kBorderDark : const Color(0xFFE0E6FF))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dark ? kBorderDark : const Color(0xFFE0E6FF))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1A6BB5), width: 1.5)),
    );
  }
}