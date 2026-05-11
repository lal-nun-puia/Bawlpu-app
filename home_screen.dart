import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../main.dart';
import 'request_service_screen.dart';
import 'available_jobs_screen.dart';
import 'my_requests_screen.dart';
import 'my_applications_screen.dart';
import 'search_nurses_screen.dart';
import 'give_feedback_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'nurse_reviews_screen.dart';
import 'conversations_screen.dart';

// ─── THEME CONSTANTS ─────────────────────────────────────────────────────────
const kPrimary   = Color(0xFF1A6BB5);
const kAccent    = Color(0xFF3B9EE8);
const kBg        = Color(0xFFF0F5FB);
const kBgDark    = Color(0xFF0F1624);
const kCardDark  = Color(0xFF1A2235);
const kText      = Color(0xFF1A2340);
const kTextDark  = Color(0xFFE8ECFF);
const kSub        = Color(0xFF6B7A9B);
const kSubDark    = Color(0xFF8B9CC5);
const kBorder     = Color(0xFFE0E6FF);
const kBorderDark = Color(0xFF2A3550);

Color bgColor(BuildContext ctx)   => isDark(ctx) ? kBgDark   : kBg;
Color cardColor(BuildContext ctx) => isDark(ctx) ? kCardDark : Colors.white;
Color textColor(BuildContext ctx) => isDark(ctx) ? kTextDark : kText;
Color subColor(BuildContext ctx)  => isDark(ctx) ? kSubDark  : kSub;
bool  isDark(BuildContext ctx)    => Theme.of(ctx).brightness == Brightness.dark;

// ─── PER-USER THEME HELPERS ───────────────────────────────────────────────────
Future<void> saveThemeForUser(String userId, bool dark) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('theme_$userId', dark);
}

Future<void> loadThemeForUser(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  final dark = prefs.getBool('theme_$userId') ?? false;
  themeModeNotifier.value = dark ? ThemeMode.dark : ThemeMode.light;
}

// ─── SERVICE DATA ─────────────────────────────────────────────────────────────
final List<Map<String, dynamic>> kServices = [
  {'title': 'Elderly Care', 'slug': 'ElderlyCare', 'icon': Icons.elderly_rounded,         'color': const Color(0xFF1A6BB5), 'bg': const Color(0xFFE8F2FB)},
  {'title': 'Patient Care', 'slug': 'PatientCare', 'icon': Icons.medical_services_rounded, 'color': const Color(0xFF0F9B8E), 'bg': const Color(0xFFE0F5F3)},
  {'title': 'Babysitting',  'slug': 'Babysitting', 'icon': Icons.child_care_rounded,      'color': const Color(0xFFE8870A), 'bg': const Color(0xFFFEF3E2)},
  {'title': 'Lab Testing',  'slug': 'LabTesting',  'icon': Icons.biotech_rounded,         'color': const Color(0xFF7B3FC4), 'bg': const Color(0xFFF0E8FC)},
];

// ═══════════════════════════════════════════════════════════════════════════════
// THEME TOGGLE TILE
// ═══════════════════════════════════════════════════════════════════════════════
class ThemeToggleTile extends StatelessWidget {
  final String userId;
  const ThemeToggleTile({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (_, mode, __) {
        final isD = mode == ThemeMode.dark;
        return ListTile(
          leading: Icon(isD ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: isD ? Colors.amber : kPrimary, size: 22),
          title: Text(isD ? 'Dark Mode' : 'Light Mode',
              style: TextStyle(fontWeight: FontWeight.w600, color: dark ? kTextDark : kText)),
          trailing: Switch(
            value: isD,
            activeColor: kPrimary,
            activeTrackColor: kPrimary.withOpacity(0.3),
            onChanged: (v) {
              themeModeNotifier.value = v ? ThemeMode.dark : ThemeMode.light;
              saveThemeForUser(userId, v);
            },
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HOME SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic> _userData = {};
  int _navIndex = 0;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map<String, dynamic> && args.isNotEmpty) {
        _userData = Map<String, dynamic>.from(args);
        _initialized = true;
        _fetchPhoto();
        loadThemeForUser(_userData['user_id']?.toString() ?? '');
      }
    }
  }

  @override
  void initState() { super.initState(); }

  Future<void> _fetchPhoto() async {
    try {
      final r = await http.get(Uri.parse(
          '${ApiService.baseUrl}/profile_api.php?action=get_profile&user_id=${_userData['user_id']}'))
          .timeout(const Duration(seconds: 5));
      final d = jsonDecode(r.body);
      if (d['status'] == 'success') {
        final photo = d['user']['photo_url'] ?? '';
        if (photo.isNotEmpty) profilePhotoNotifier.value = photo;
      }
    } catch (_) {}
  }

  String get _userRole => _userData['role'] ?? 'Client';
  bool get _isNurse    => _userRole == 'Nurse';
  String get _userId   => _userData['user_id']?.toString() ?? '';

  void _logout() {
    // Dismiss keyboard before navigating
    FocusScope.of(context).unfocus();
    Future.delayed(const Duration(milliseconds: 100), () {
      themeModeNotifier.value = ThemeMode.light;
      profilePhotoNotifier.value = '';
      Navigator.pushReplacementNamed(context, '/login');
    });
  }

  // ── Push a tab screen with Navigator so back button works ──────────────────
  void _onNavTap(int index) {
    if (index == 0) {
      setState(() => _navIndex = 0);
      return;
    }
    setState(() => _navIndex = index);
    Widget? screen;
    if (_isNurse) {
      if (index == 1) screen = AvailableJobsScreen(userData: _userData);
      if (index == 2) screen = MyApplicationsScreen(userData: _userData);
      if (index == 3) screen = ProfileScreen(userData: _userData);
    } else {
      if (index == 1) screen = SearchNursesScreen(userData: _userData);
      if (index == 2) screen = MyRequestsScreen(userData: _userData);
      if (index == 3) screen = ProfileScreen(userData: _userData);
    }
    if (screen != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen!))
          .then((_) => setState(() => _navIndex = 0));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _userData.isEmpty) {
      return Scaffold(
        backgroundColor: bgColor(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    // WillPopScope prevents Android back from logging out
    return WillPopScope(
      onWillPop: () async {
        if (_navIndex != 0) {
          setState(() => _navIndex = 0);
          return false; // Don't pop
        }
        return false; // Stay on home, don't exit
      },
      child: ValueListenableBuilder<String>(
        valueListenable: profilePhotoNotifier,
        builder: (context, photoUrl, _) => Scaffold(
          backgroundColor: bgColor(context),
          body: _isNurse
              ? _NurseHomePage(userData: _userData, userId: _userId, onLogout: _logout, onNavTap: _onNavTap)
              : _ClientHomePage(userData: _userData, userId: _userId, onLogout: _logout, onNavTap: _onNavTap),
          bottomNavigationBar: _buildBottomNav(context, photoUrl),
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, String photoUrl) {
    final name = _userData['name'] ?? 'U';
    final profileIcon = photoUrl.isNotEmpty
        ? CircleAvatar(radius: 12, backgroundImage: NetworkImage(photoUrl))
        : CircleAvatar(radius: 12, backgroundColor: kPrimary.withOpacity(0.15),
        child: Text(name[0].toUpperCase(),
            style: const TextStyle(color: kPrimary, fontSize: 11, fontWeight: FontWeight.w700)));
    final dark = isDark(context);
    final clientItems = [
      const BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
      const BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'Search'),
      const BottomNavigationBarItem(icon: Icon(Icons.assignment_rounded), label: 'Requests'),
      BottomNavigationBarItem(icon: profileIcon, label: 'Profile'),
    ];
    final nurseItems = [
      const BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
      const BottomNavigationBarItem(icon: Icon(Icons.work_rounded), label: 'Jobs'),
      const BottomNavigationBarItem(icon: Icon(Icons.assignment_rounded), label: 'Applied'),
      BottomNavigationBarItem(icon: profileIcon, label: 'Profile'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: dark ? kCardDark : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -4))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BottomNavigationBar(
          currentIndex: _navIndex,
          onTap: _onNavTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: dark ? kCardDark : Colors.white,
          selectedItemColor: kPrimary,
          unselectedItemColor: dark ? kSubDark : kSub,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          elevation: 0,
          items: _isNurse ? nurseItems : clientItems,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLIENT HOME PAGE
// ═══════════════════════════════════════════════════════════════════════════════
class _ClientHomePage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String userId;
  final VoidCallback onLogout;
  final Function(int) onNavTap;
  const _ClientHomePage({required this.userData, required this.userId, required this.onLogout, required this.onNavTap});
  @override
  State<_ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<_ClientHomePage> {
  int _unread = 0;
  List<Map<String, dynamic>> _serviceImages = [];

  @override
  void initState() { super.initState(); _fetchUnread(); _fetchServiceImages(); }

  Future<void> _fetchUnread() async {
    try {
      final r = await http.get(Uri.parse(
          '${ApiService.baseUrl}/notifications_api.php?action=unread_count&user_id=${widget.userData['user_id']}'))
          .timeout(const Duration(seconds: 5));
      final d = jsonDecode(r.body);
      if (mounted) setState(() => _unread = d['count'] ?? 0);
    } catch (_) {}
  }

  Future<void> _fetchServiceImages() async {
    try {
      final r = await http.get(Uri.parse('${ApiService.baseUrl}/service_images_api.php?action=get_all'))
          .timeout(const Duration(seconds: 10));
      final d = jsonDecode(r.body);
      if (d['status'] == 'success' && mounted) {
        setState(() => _serviceImages = List<Map<String, dynamic>>.from(d['services']));
      }
    } catch (_) {}
  }

  String _imgUrl(String slug) {
    final s = _serviceImages.firstWhere(
          (s) => (s['slug'] ?? s['service_slug'] ?? '') == slug,
      orElse: () => {},
    );
    if (s.isEmpty) return '';
    // Check images array first
    final imgs = s['images'] as List?;
    if (imgs != null && imgs.isNotEmpty) {
      return (imgs.first['image_url'] ?? imgs.first['image_path'] ?? '').toString();
    }
    return (s['image_url'] ?? '').toString();
  }

  String _desc(String slug) {
    final s = _serviceImages.firstWhere(
          (s) => (s['slug'] ?? s['service_slug'] ?? '') == slug,
      orElse: () => {},
    );
    return (s['description'] ?? '').toString();
  }

  void _showPopup(Map<String, dynamic> s) {
    final color = s['color'] as Color;
    final dark  = isDark(context);
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(color: dark ? kCardDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade500, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          ClipRRect(borderRadius: BorderRadius.circular(20),
              child: _imgUrl(s['slug']).isNotEmpty
                  ? Image.network(_imgUrl(s['slug']), height: 180, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _noImg(color, s['icon'] as IconData, dark))
                  : _noImg(color, s['icon'] as IconData, dark)),
          const SizedBox(height: 20),
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(s['title'], style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: dark ? kTextDark : kText)),
          ]),
          const SizedBox(height: 10),
          Text(_desc(s['slug']).isNotEmpty ? _desc(s['slug']) : 'Professional ${s['title']} service by verified healthcare workers.',
              style: TextStyle(fontSize: 14, color: dark ? kSubDark : kSub, height: 1.6)),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(
                  builder: (_) => RequestServiceScreen(userData: widget.userData, serviceType: s['slug'], serviceTitle: s['title']))); },
              icon: const Icon(Icons.assignment_add, size: 20),
              label: Text('Request ${s['title']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: dark ? kSubDark : kSub))),
        ]),
      ),
    );
  }

  Widget _noImg(Color c, IconData i, bool dark) => Container(height: 180, width: double.infinity,
      decoration: BoxDecoration(color: c.withOpacity(dark ? 0.2 : 0.1), borderRadius: BorderRadius.circular(20)),
      child: Icon(i, color: c, size: 70));

  @override
  Widget build(BuildContext context) {
    final name = widget.userData['name'] ?? 'User';
    final dark = isDark(context);
    return Scaffold(
      backgroundColor: bgColor(context),
      drawer: _buildDrawer(name, dark),
      body: SafeArea(child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1A6BB5), Color(0xFF3B9EE8)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28))),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Builder(builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
                  onPressed: () => Scaffold.of(ctx).openDrawer())),
              const SizedBox(width: 4),
              ValueListenableBuilder<String>(valueListenable: profilePhotoNotifier,
                  builder: (_, photo, __) => CircleAvatar(radius: 20,
                      backgroundColor: Colors.white.withOpacity(0.25),
                      backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                      child: photo.isEmpty ? Text(name[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)) : null)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Hello 👋', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(name, overflow: TextOverflow.ellipsis, maxLines: 1,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              ])),
              Stack(children: [
                IconButton(icon: const Icon(Icons.notifications_rounded, color: Colors.white, size: 24),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => NotificationsScreen(userData: widget.userData)))),
                if (_unread > 0) Positioned(top: 8, right: 8,
                    child: Container(width: 16, height: 16,
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: Center(child: Text('$_unread',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800))))),
              ]),
            ]),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchNursesScreen(userData: widget.userData))),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.3))),
                child: const Row(children: [
                  Icon(Icons.search_rounded, color: Colors.white70, size: 20), SizedBox(width: 10),
                  Flexible(child: Text('Search nurses by name or location...',
                      overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white70, fontSize: 13))),
                ]),
              ),
            ),
          ]),
        )),

        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Row(children: [
              Text('Our Services', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor(context))),
              const Spacer(),
              Text('4 available', style: TextStyle(fontSize: 12, color: subColor(context))),
            ]))),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.85,
              children: kServices.map((s) => _ServiceImageCard(service: s, imageUrl: _imgUrl(s['slug']),
                  buttonLabel: 'Request →', onTap: () => _showPopup(s))).toList()),
        )),

        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor(context))))),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(children: [
            Expanded(child: _QuickAction(icon: Icons.assignment_rounded, label: 'My Requests', color: kPrimary,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MyRequestsScreen(userData: widget.userData))))),
            const SizedBox(width: 12),
            Expanded(child: _QuickAction(icon: Icons.chat_rounded, label: 'Messages', color: const Color(0xFF1A6BB5),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ConversationsScreen(userData: widget.userData))))),
            const SizedBox(width: 12),
            Expanded(child: _QuickAction(icon: Icons.star_rounded, label: 'Give Feedback', color: const Color(0xFFE8870A),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GiveFeedbackScreen(userData: widget.userData))))),
            const SizedBox(width: 12),
            Expanded(child: _QuickAction(icon: Icons.logout_rounded, label: 'Logout', color: Colors.redAccent, onTap: widget.onLogout)),
          ]),
        )),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Container(padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0F9B8E), Color(0xFF0ABFAB)]),
                borderRadius: BorderRadius.circular(20)),
            child: const Row(children: [
              Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 40), SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Professional Care', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                SizedBox(height: 4),
                Text('All our nurses are certified and background-checked by admin.',
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
              ])),
            ]),
          ),
        )),
      ])),
    );
  }

  Widget _buildDrawer(String name, bool dark) {
    return Drawer(
      backgroundColor: dark ? kCardDark : Colors.white,
      child: SafeArea(child: Column(children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [kPrimary, kAccent])),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ValueListenableBuilder<String>(valueListenable: profilePhotoNotifier,
                builder: (_, photo, __) => CircleAvatar(radius: 30,
                    backgroundColor: Colors.white.withOpacity(0.25),
                    backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                    child: photo.isEmpty ? Text(name[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24)) : null)),
            const SizedBox(height: 10),
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const Text('Client', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
        _dtile(Icons.home_rounded,          'Home',            kPrimary,                dark, () { Navigator.pop(context); widget.onNavTap(0); }),
        _dtile(Icons.search_rounded,        'Search Nurses',   kPrimary,                dark, () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => SearchNursesScreen(userData: widget.userData))); }),
        _dtile(Icons.assignment_rounded,    'My Requests',     kPrimary,                dark, () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => MyRequestsScreen(userData: widget.userData))); }),
        _dtile(Icons.star_rounded,          'Give Feedback',   const Color(0xFFE8870A), dark, () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => GiveFeedbackScreen(userData: widget.userData))); }),
        _dtile(Icons.person_rounded,        'Profile',         kPrimary,                dark, () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userData: widget.userData))); }),
        _dtile(Icons.notifications_rounded, 'Notifications',   kPrimary,                dark, () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen(userData: widget.userData))); }),
        _dtile(Icons.chat_rounded,           'Messages',         kPrimary,                dark, () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => ConversationsScreen(userData: widget.userData))); }),
        const Divider(),
        ThemeToggleTile(userId: widget.userId),
        const Divider(),
        _dtile(Icons.logout_rounded, 'Logout', Colors.red, dark, widget.onLogout),
      ])),
    );
  }

  Widget _dtile(IconData icon, String label, Color color, bool dark, VoidCallback onTap) => ListTile(
    leading: Icon(icon, color: color, size: 22),
    title: Text(label, style: TextStyle(fontWeight: FontWeight.w600,
        color: label == 'Logout' ? Colors.red : (dark ? kTextDark : kText))),
    onTap: onTap,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// NURSE HOME PAGE
// ═══════════════════════════════════════════════════════════════════════════════
class _NurseHomePage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String userId;
  final VoidCallback onLogout;
  final Function(int) onNavTap;
  const _NurseHomePage({required this.userData, required this.userId, required this.onLogout, required this.onNavTap});
  @override
  State<_NurseHomePage> createState() => _NurseHomePageState();
}

class _NurseHomePageState extends State<_NurseHomePage> {
  List<Map<String, dynamic>> _serviceImages = [];

  @override
  void initState() { super.initState(); _fetchServiceImages(); }

  Future<void> _fetchServiceImages() async {
    try {
      final r = await http.get(Uri.parse('${ApiService.baseUrl}/service_images_api.php?action=get_all'))
          .timeout(const Duration(seconds: 10));
      final d = jsonDecode(r.body);
      if (d['status'] == 'success' && mounted) {
        setState(() => _serviceImages = List<Map<String, dynamic>>.from(d['services']));
      }
    } catch (_) {}
  }

  String _imgUrl(String slug) {
    final s = _serviceImages.firstWhere(
          (s) => (s['slug'] ?? s['service_slug'] ?? '') == slug,
      orElse: () => {},
    );
    if (s.isEmpty) return '';
    // Check images array first
    final imgs = s['images'] as List?;
    if (imgs != null && imgs.isNotEmpty) {
      return (imgs.first['image_url'] ?? imgs.first['image_path'] ?? '').toString();
    }
    return (s['image_url'] ?? '').toString();
  }

  String _desc(String slug) {
    final s = _serviceImages.firstWhere(
          (s) => (s['slug'] ?? s['service_slug'] ?? '') == slug,
      orElse: () => {},
    );
    return (s['description'] ?? '').toString();
  }

  void _showPopup(Map<String, dynamic> s) {
    final color = s['color'] as Color;
    final dark  = isDark(context);
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(color: dark ? kCardDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade500, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          ClipRRect(borderRadius: BorderRadius.circular(20),
              child: _imgUrl(s['slug']).isNotEmpty
                  ? Image.network(_imgUrl(s['slug']), height: 180, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _noImg(color, s['icon'] as IconData, dark))
                  : _noImg(color, s['icon'] as IconData, dark)),
          const SizedBox(height: 20),
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(s['title'], style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: dark ? kTextDark : kText)),
          ]),
          const SizedBox(height: 10),
          Text(_desc(s['slug']).isNotEmpty ? _desc(s['slug']) : 'Apply for ${s['title']} and help clients.',
              style: TextStyle(fontSize: 14, color: dark ? kSubDark : kSub, height: 1.6)),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(
                  builder: (_) => AvailableJobsScreen(userData: widget.userData, initialService: s['slug']))); },
              icon: const Icon(Icons.work_rounded, size: 20),
              label: Text('Apply for ${s['title']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: dark ? kSubDark : kSub))),
        ]),
      ),
    );
  }

  Widget _noImg(Color c, IconData i, bool dark) => Container(height: 180, width: double.infinity,
      decoration: BoxDecoration(color: c.withOpacity(dark ? 0.2 : 0.1), borderRadius: BorderRadius.circular(20)),
      child: Icon(i, color: c, size: 70));

  @override
  Widget build(BuildContext context) {
    final name    = widget.userData['name'] ?? 'Nurse';
    final service = widget.userData['service'] ?? '';
    final status  = widget.userData['approval_status'] ?? 'Approved';
    final dark    = isDark(context);

    return Scaffold(
      backgroundColor: bgColor(context),
      drawer: _buildDrawer(name, dark),
      body: SafeArea(child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF0F9B8E), Color(0xFF3BC4B6)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28))),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
                  onPressed: () => Scaffold.of(ctx).openDrawer())),
              const SizedBox(width: 4),
              ValueListenableBuilder<String>(valueListenable: profilePhotoNotifier,
                  builder: (_, photo, __) => CircleAvatar(radius: 20,
                      backgroundColor: Colors.white.withOpacity(0.25),
                      backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                      child: photo.isEmpty ? Text(name[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)) : null)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Welcome back 👋', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              ])),
              IconButton(icon: const Icon(Icons.notifications_rounded, color: Colors.white, size: 26),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => NotificationsScreen(userData: widget.userData)))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    const Icon(Icons.medical_services_rounded, color: Colors.white, size: 14), const SizedBox(width: 6),
                    Text(service, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ])),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: status == 'Approved' ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
            ]),
          ]),
        )),

        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Text('Our Services', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor(context))))),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.85,
              children: kServices.map((s) => _ServiceImageCard(service: s, imageUrl: _imgUrl(s['slug']),
                  buttonLabel: 'Apply →', onTap: () => _showPopup(s))).toList()),
        )),

        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor(context))))),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(children: [
            Expanded(child: _QuickAction(icon: Icons.assignment_turned_in_rounded, label: 'My Applications',
                color: const Color(0xFF0F9B8E),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MyApplicationsScreen(userData: widget.userData))))),
            const SizedBox(width: 12),
            Expanded(child: _QuickAction(icon: Icons.star_rounded, label: 'My Reviews', color: const Color(0xFFE8870A),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NurseReviewsScreen(
                    userData: widget.userData, nurseId: widget.userData['user_id'], nurseName: widget.userData['name'] ?? 'My'))))),
            const SizedBox(width: 12),
            Expanded(child: _QuickAction(icon: Icons.chat_rounded, label: 'Messages', color: const Color(0xFF1A6BB5),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ConversationsScreen(userData: widget.userData))))),
            const SizedBox(width: 12),
            Expanded(child: _QuickAction(icon: Icons.logout_rounded, label: 'Logout', color: Colors.redAccent, onTap: widget.onLogout)),
          ]),
        )),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Container(padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1A6BB5), Color(0xFF3B9EE8)]),
                borderRadius: BorderRadius.circular(20)),
            child: const Row(children: [
              Icon(Icons.tips_and_updates_rounded, color: Colors.white, size: 36), SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Tip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                SizedBox(height: 4),
                Text('Keep your profile updated to attract more clients!',
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
              ])),
            ]),
          ),
        )),
      ])),
    );
  }

  Widget _buildDrawer(String name, bool dark) {
    return Drawer(
      backgroundColor: dark ? kCardDark : Colors.white,
      child: SafeArea(child: Column(children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0F9B8E), Color(0xFF3BC4B6)])),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ValueListenableBuilder<String>(valueListenable: profilePhotoNotifier,
                builder: (_, photo, __) => CircleAvatar(radius: 30,
                    backgroundColor: Colors.white.withOpacity(0.25),
                    backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                    child: photo.isEmpty ? Text(name[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24)) : null)),
            const SizedBox(height: 10),
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const Text('Nurse', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
        _dtile(Icons.home_rounded,          'Home',            const Color(0xFF0F9B8E), dark, () { Navigator.pop(context); widget.onNavTap(0); }),
        _dtile(Icons.work_rounded,          'Available Jobs',  const Color(0xFF0F9B8E), dark, () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => AvailableJobsScreen(userData: widget.userData))); }),
        _dtile(Icons.assignment_rounded,    'My Applications', const Color(0xFF0F9B8E), dark, () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => MyApplicationsScreen(userData: widget.userData))); }),
        _dtile(Icons.star_rounded,          'My Reviews',      const Color(0xFFE8870A), dark, () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => NurseReviewsScreen(userData: widget.userData, nurseId: widget.userData['user_id'], nurseName: widget.userData['name'] ?? 'My'))); }),
        _dtile(Icons.person_rounded,        'Profile',         const Color(0xFF0F9B8E), dark, () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userData: widget.userData))); }),
        _dtile(Icons.notifications_rounded, 'Notifications',   const Color(0xFF0F9B8E), dark, () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen(userData: widget.userData))); }),
        _dtile(Icons.chat_rounded,           'Messages',        const Color(0xFF1A6BB5), dark, () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => ConversationsScreen(userData: widget.userData))); }),
        const Divider(),
        ThemeToggleTile(userId: widget.userId),
        const Divider(),
        _dtile(Icons.logout_rounded, 'Logout', Colors.red, dark, widget.onLogout),
      ])),
    );
  }

  Widget _dtile(IconData icon, String label, Color color, bool dark, VoidCallback onTap) => ListTile(
    leading: Icon(icon, color: color, size: 22),
    title: Text(label, style: TextStyle(fontWeight: FontWeight.w600,
        color: label == 'Logout' ? Colors.red : (dark ? kTextDark : kText))),
    onTap: onTap,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICE IMAGE CARD
// ═══════════════════════════════════════════════════════════════════════════════
class _ServiceImageCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final String imageUrl;
  final String buttonLabel;
  final VoidCallback onTap;
  const _ServiceImageCard({required this.service, required this.imageUrl, required this.buttonLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = service['color'] as Color;
    final bg    = service['bg'] as Color;
    final icon  = service['icon'] as IconData;
    final dark  = isDark(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: dark ? kCardDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(dark ? 0.3 : 0.07), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(height: 16),
          Container(width: 85, height: 85,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dark ? color.withOpacity(0.2) : bg),
              child: imageUrl.isNotEmpty
                  ? ClipOval(child: Image.network(imageUrl, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(icon, color: color, size: 40)))
                  : Icon(icon, color: color, size: 40)),
          const SizedBox(height: 12),
          Text(service['title'], textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: dark ? kTextDark : kText)),
          const SizedBox(height: 4),
          Text(buttonLabel, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// QUICK ACTION
// ═══════════════════════════════════════════════════════════════════════════════
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark(context) ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 24), const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}