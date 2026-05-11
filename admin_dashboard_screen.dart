import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../main.dart';
import 'home_screen.dart' show ThemeToggleTile, loadThemeForUser, isDark, bgColor, kBgDark, kCardDark, kText, kTextDark, kSub, kSubDark;
import 'admin_users_screen.dart';
import 'admin_requests_screen.dart';
import 'admin_bookings_screen.dart';
import 'admin_notification_screen.dart';
import 'admin_services_screen.dart';
import 'admin_forgot_password_screen.dart';
import 'admin_service_images_screen.dart';

const _kPrimary = Color(0xFF1A6BB5);
const _kAccent  = Color(0xFF3B9EE8);

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic> _userData = {};
  Map<String, dynamic> _stats   = {};
  bool _isLoading   = true;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map<String, dynamic>) {
        setState(() { _userData = Map<String, dynamic>.from(args); _initialized = true; });
        // Load admin's saved theme
        final userId = _userData['user_id']?.toString() ?? 'admin';
        loadThemeForUser(userId);
      }
      _fetchStats();
    }
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      final r = await http.get(Uri.parse('${ApiService.baseUrl}/admin_api.php?action=stats'))
          .timeout(const Duration(seconds: 15));
      final d = jsonDecode(r.body);
      if (d['status'] == 'success') {
        // Ensure all values are properly parsed as integers
        final stats = Map<String, dynamic>.from(d);
        for (final key in ['total_clients','total_nurses','pending_nurses','total_bookings','total_requests']) {
          stats[key] = int.tryParse(stats[key]?.toString() ?? '0') ?? 0;
        }
        setState(() => _stats = stats);
      }
    } catch (e) {
      debugPrint('Stats error: \$e');
    }
    setState(() => _isLoading = false);
  }

  void _logout() {
    themeModeNotifier.value = ThemeMode.light; // Reset on logout
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _go(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  String get _userId => _userData['user_id']?.toString() ?? 'admin';

  @override
  Widget build(BuildContext context) {
    final name = _userData['name'] ?? 'Admin';
    final dark = isDark(context);
    return Scaffold(
      backgroundColor: bgColor(context),
      drawer: _buildDrawer(name, dark),
      body: SafeArea(
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [_kPrimary, _kAccent],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(28))),
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Builder(builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
                      onPressed: () => Scaffold.of(ctx).openDrawer())),
                  CircleAvatar(radius: 20, backgroundColor: Colors.white.withOpacity(0.25),
                      child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 20)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Welcome 👋', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(name, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  ])),
                  IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22), onPressed: _fetchStats),
                ]),
                const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text('Admin Dashboard', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900))),
                const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Text('Manage users, services & system', style: TextStyle(color: Colors.white70, fontSize: 12))),
              ]),
            ),
          ),

          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: dark ? kTextDark : kText)))),
          SliverToBoxAdapter(
            child: _isLoading
                ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.2,
                children: [
                  _statCard('Total Clients',   '${_stats['total_clients']  ?? 0}', Icons.people_rounded,          const Color(0xFF1A6BB5), () => _go(AdminUsersScreen(userData: _userData, filterRole: 'Client'))),
                  _statCard('Approved Nurses', '${_stats['total_nurses']   ?? 0}', Icons.medical_services_rounded, const Color(0xFF0F9B8E), () => _go(AdminUsersScreen(userData: _userData, filterRole: 'Nurse', filterStatus: 'Approved'))),
                  _statCard('Pending Nurses',  '${_stats['pending_nurses'] ?? 0}', Icons.pending_actions_rounded,  const Color(0xFFE8870A), () => _go(AdminUsersScreen(userData: _userData, filterRole: 'Nurse', filterStatus: 'Pending'))),
                  _statCard('Total Bookings',  '${_stats['total_bookings'] ?? 0}', Icons.calendar_today_rounded,   const Color(0xFF7B3FC4), () => _go(AdminBookingsScreen(userData: _userData))),
                  _statCard('Total Requests',  '${_stats['total_requests'] ?? 0}', Icons.assignment_rounded,       const Color(0xFFE91E63), () => _go(AdminRequestsScreen(userData: _userData))),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: dark ? kTextDark : kText)))),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: Column(children: [
                _actionCard('Manage Users',      'View, approve or delete users',            Icons.manage_accounts_rounded,      const Color(0xFF1A6BB5), () => _go(AdminUsersScreen(userData: _userData))),
                const SizedBox(height: 10),
                _actionCard('Manage Services',   'Add, edit or delete service items',        Icons.medical_services_outlined,    const Color(0xFF0F9B8E), () => _go(AdminServicesScreen(userData: _userData))),
                const SizedBox(height: 10),
                _actionCard('Service Images',    'Upload photos & descriptions for services', Icons.image_rounded,               const Color(0xFF3B9EE8), () => _go(AdminServiceImagesScreen(userData: _userData))),
                const SizedBox(height: 10),
                _actionCard('All Bookings',      'View all bookings in the system',          Icons.book_online_rounded,          const Color(0xFF7B3FC4), () => _go(AdminBookingsScreen(userData: _userData))),
                const SizedBox(height: 10),
                _actionCard('Send Notification', 'Broadcast message to all users',           Icons.notifications_active_rounded, const Color(0xFFE8870A), () => _go(AdminNotificationScreen(userData: _userData))),
                const SizedBox(height: 10),
                _actionCard('Password Resets',   'View & handle forgot password requests',   Icons.lock_reset_rounded,           Colors.red,             () => _go(AdminForgotPasswordScreen(userData: _userData))),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildDrawer(String name, bool dark) {
    return Drawer(
      backgroundColor: dark ? kCardDark : Colors.white,
      child: SafeArea(child: Column(children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [_kPrimary, _kAccent])),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const CircleAvatar(radius: 30, backgroundColor: Colors.white24,
                child: Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 30)),
            const SizedBox(height: 10),
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const Text('Administrator', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
        _dtile(Icons.dashboard_rounded,           'Dashboard',          () => Navigator.pop(context), dark),
        _dtile(Icons.manage_accounts_rounded,     'Manage Users',       () { Navigator.pop(context); _go(AdminUsersScreen(userData: _userData)); }, dark),
        _dtile(Icons.medical_services_outlined,   'Manage Services',    () { Navigator.pop(context); _go(AdminServicesScreen(userData: _userData)); }, dark),
        _dtile(Icons.image_rounded,               'Service Images',     () { Navigator.pop(context); _go(AdminServiceImagesScreen(userData: _userData)); }, dark),
        _dtile(Icons.book_online_rounded,         'All Bookings',       () { Navigator.pop(context); _go(AdminBookingsScreen(userData: _userData)); }, dark),
        _dtile(Icons.notifications_active_rounded,'Send Notification',  () { Navigator.pop(context); _go(AdminNotificationScreen(userData: _userData)); }, dark),
        _dtile(Icons.lock_reset_rounded,          'Password Resets',    () { Navigator.pop(context); _go(AdminForgotPasswordScreen(userData: _userData)); }, dark, color: Colors.red),
        const Divider(),
        ThemeToggleTile(userId: _userId),
        const Divider(),
        _dtile(Icons.logout_rounded, 'Logout', _logout, dark, color: Colors.red),
      ])),
    );
  }

  Widget _dtile(IconData icon, String label, VoidCallback onTap, bool dark, {Color color = _kPrimary}) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w600,
          color: label == 'Logout' || label == 'Password Resets' ? Colors.red : (dark ? kTextDark : kText))),
      onTap: onTap,
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, VoidCallback onTap) {
    final dark = isDark(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: dark ? kCardDark : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(dark ? 0.3 : 0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Container(width: 40, height: 40,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                  child: Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color))),
              Text(label, style: TextStyle(fontSize: 11, color: dark ? kSubDark : kSub, fontWeight: FontWeight.w500),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          )),
        ]),
      ),
    );
  }

  Widget _actionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    final dark = isDark(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: dark ? kCardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(dark ? 0.3 : 0.05), blurRadius: 8)],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(width: 44, height: 44,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: dark ? kTextDark : kText)),
            Text(subtitle, style: TextStyle(fontSize: 12, color: dark ? kSubDark : kSub)),
          ])),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
        ]),
      ),
    );
  }
}