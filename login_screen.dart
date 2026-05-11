import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

const kPrimary = Color(0xFF1A6BB5);
const kAccent  = Color(0xFF3B9EE8);
const kBg      = Color(0xFFF0F5FB);
const kText    = Color(0xFF1A2340);
const kSub     = Color(0xFF6B7A9B);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _showPassword = false;
  bool _isLoading = false;
  bool _usePhone = false;
  String? _message;
  bool _isError = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _message = null; });

    final result = await ApiService.login(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    setState(() => _isLoading = false);

    if (result['status'] == 'success') {
      final role   = result['role'] ?? '';
      final name   = result['name'] ?? '';
      final userId = result['user_id'];
      if (!mounted) return;
      final route = role == 'Admin' ? '/admin' : '/home';
      Navigator.pushReplacementNamed(context, route,
          arguments: {'user_id': userId, 'name': name, 'role': role});
    } else {
      setState(() { _message = result['message'] ?? 'Login failed.'; _isError = true; });
    }
  }

  void _showForgotPassword() {
    final ctrl = TextEditingController();
    bool _sending = false;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: kPrimary),
              SizedBox(width: 8),
              Text('Forgot Password', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter your registered email. Admin will reset your password.',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email (@gmail.com)',
                  prefixIcon: const Icon(Icons.email_rounded, color: kPrimary),
                  filled: true,
                  fillColor: kBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E6FF))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimary, width: 1.5)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: _sending ? null : () async {
                if (ctrl.text.isEmpty || !ctrl.text.contains('@')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid email'), backgroundColor: Colors.orange));
                  return;
                }
                setS(() => _sending = true);
                try {
                  final r = await http.post(
                    Uri.parse('${ApiService.baseUrl}/forgot_password_api.php?action=submit'),
                    body: {'email': ctrl.text.trim()},
                  ).timeout(const Duration(seconds: 15));
                  final d = jsonDecode(r.body);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(d['message'] ?? 'Request sent!'),
                      backgroundColor: d['status'] == 'success' ? Colors.green : Colors.red,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                } catch (e) {
                  setS(() => _sending = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Connection error. Try again.'), backgroundColor: Colors.red));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
              child: _sending
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: kBg,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ── LOGO ─────────────────────────────────────────────────
                          Image.asset(
                            'assets/bawlpu_icon.png',
                            width: 100,
                            height: 100,
                          ),
                          const SizedBox(height: 16),

                          // ── CARD ─────────────────────────────────────────────────
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 30, offset: const Offset(0, 10))],
                            ),
                            padding: const EdgeInsets.all(28),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Welcome back!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kText)),
                                  const SizedBox(height: 4),
                                  const Text('Sign in to continue', style: TextStyle(color: kSub, fontSize: 13)),
                                  const SizedBox(height: 24),

                                  // Toggle Email / Phone
                                  Container(
                                    decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(14)),
                                    padding: const EdgeInsets.all(4),
                                    child: Row(
                                      children: [
                                        _tab('Email', Icons.email_rounded, !_usePhone, () {
                                          setState(() => _usePhone = false);
                                          _emailCtrl.clear(); _message = null;
                                        }),
                                        _tab('Phone', Icons.phone_rounded, _usePhone, () {
                                          setState(() => _usePhone = true);
                                          _emailCtrl.clear(); _message = null;
                                        }),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),

                                  // Input field
                                  TextFormField(
                                    key: ValueKey(_usePhone),
                                    controller: _emailCtrl,
                                    keyboardType: _usePhone ? TextInputType.number : TextInputType.emailAddress,
                                    style: const TextStyle(fontSize: 15, color: kText, fontWeight: FontWeight.w500),
                                    decoration: _fieldDeco(
                                      _usePhone ? '10-digit phone number' : 'your@gmail.com',
                                      _usePhone ? Icons.phone_rounded : Icons.email_rounded,
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return _usePhone ? 'Phone required' : 'Email required';
                                      if (_usePhone && !RegExp(r'^\d{10}$').hasMatch(v.trim())) return '10-digit phone number required';
                                      if (!_usePhone && !RegExp(r'^[^@]+@gmail\.com$').hasMatch(v.trim())) return 'Only @gmail.com allowed';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),

                                  // Password
                                  TextFormField(
                                    controller: _passwordCtrl,
                                    obscureText: !_showPassword,
                                    style: const TextStyle(fontSize: 15, color: kText, fontWeight: FontWeight.w500),
                                    decoration: _fieldDeco('Password', Icons.lock_rounded).copyWith(
                                      suffixIcon: IconButton(
                                        icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                            color: kSub, size: 20),
                                        onPressed: () => setState(() => _showPassword = !_showPassword),
                                      ),
                                    ),
                                    validator: (v) => (v == null || v.isEmpty) ? 'Password required' : null,
                                  ),
                                  const SizedBox(height: 8),

                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => _showForgotPassword(),
                                      child: const Text('Forgot password?', style: TextStyle(color: kPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                                    ),
                                  ),

                                  // Error message
                                  if (_message != null) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _isError ? const Color(0xFFFFEEEE) : const Color(0xFFEEFFEE),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: _isError ? Colors.red.shade200 : Colors.green.shade200),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(_isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                                              color: _isError ? Colors.red : Colors.green, size: 16),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(_message!,
                                              style: TextStyle(color: _isError ? Colors.red.shade700 : Colors.green.shade700, fontSize: 13))),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                  ],

                                  // Login button
                                  SizedBox(
                                    width: double.infinity, height: 54,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _login,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kPrimary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        elevation: 0,
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(width: 22, height: 22,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                          : const Text('Log In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Register
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Don't have an account? ", style: TextStyle(color: kSub, fontSize: 14)),
                              GestureDetector(
                                onTap: () => Navigator.pushNamed(context, '/register'),
                                child: const Text('Register', style: TextStyle(color: kPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(String label, IconData icon, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 8)] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: active ? kPrimary : kSub),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                  color: active ? kPrimary : kSub)),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDeco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: kSub, fontSize: 14),
      prefixIcon: Icon(icon, color: kSub, size: 20),
      filled: true,
      fillColor: kBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kPrimary, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.red)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.red)),
    );
  }
}