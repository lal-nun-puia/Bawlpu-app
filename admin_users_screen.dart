import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'home_screen.dart' show isDark, bgColor, kCardDark, kTextDark, kSubDark, kBorderDark;

class AdminUsersScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String filterRole;
  final String filterStatus;
  const AdminUsersScreen({super.key, required this.userData, this.filterRole = '', this.filterStatus = ''});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _allUsers = [];
  bool _isLoading = true;
  String _search = '';
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _statusFilter = widget.filterStatus;
    if (widget.filterRole == 'Client') _tabController.index = 1;
    else if (widget.filterRole == 'Nurse') _tabController.index = 2;
    _fetchUsers(role: widget.filterRole);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers({String role = ''}) async {
    setState(() => _isLoading = true);
    try {
      String url = '${ApiService.baseUrl}/admin_api.php?action=get_users';
      if (role.isNotEmpty) url += '&role=$role';
      if (_statusFilter.isNotEmpty) url += '&status=$_statusFilter';
      if (_search.isNotEmpty) url += '&q=$_search';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        setState(() => _allUsers = data['users'] ?? []);
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  String _roleForTab(int index) {
    switch (index) {
      case 0: return '';
      case 1: return 'Client';
      case 2: return 'Nurse';
      case 3: return 'Admin';
      default: return '';
    }
  }

  Future<void> _updateStatus(int userId, String status) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/admin_api.php?action=update_status'),
        body: {'user_id': '$userId', 'approval_status': status},
      );
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to $status'), backgroundColor: Colors.green),
        );
        _fetchUsers(role: _roleForTab(_tabController.index));
      }
    } catch (_) {}
  }

  Future<void> _deleteUser(int userId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/admin_api.php?action=delete_user'),
        body: {'user_id': '$userId', 'admin_id': '${widget.userData['user_id']}'},
      );
      final data = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data['message'] ?? 'Done'),
          backgroundColor: data['status'] == 'success' ? Colors.green : Colors.red,
        ),
      );
      if (data['status'] == 'success') {
        _fetchUsers(role: _roleForTab(_tabController.index));
      }
    } catch (_) {}
  }

  Future<void> _viewCertificate(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/get_certificate.php?user_id=$userId'),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        final url = Uri.parse(data['url']);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot open: ${data['url']}'), backgroundColor: Colors.red),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'No certificate'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _userAvatar(Map<String, dynamic> user, Color roleColor) {
    final name = user['name'] ?? 'U';
    final photo = (user['profile_photo'] ?? '').toString();
    final initial = name[0].toUpperCase();
    if (photo.isNotEmpty && photo.startsWith('http')) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: roleColor.withOpacity(0.12),
        child: ClipOval(
          child: Image.network(
            photo,
            width: 40, height: 40, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Text(initial,
                style: TextStyle(color: roleColor, fontWeight: FontWeight.w700)),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: roleColor.withOpacity(0.12),
      child: Text(initial,
          style: TextStyle(color: roleColor, fontWeight: FontWeight.w700)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return Scaffold(
      backgroundColor: bgColor(context),
      appBar: AppBar(
        backgroundColor: dark ? kCardDark : Colors.white,
        elevation: 1,
        title: Text('Manage Users',
            style: TextStyle(fontWeight: FontWeight.w700,
                color: dark ? kTextDark : const Color(0xFF1A1A2E))),
        iconTheme: IconThemeData(color: dark ? kTextDark : const Color(0xFF1A1A2E)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0D6EFD),
          unselectedLabelColor: dark ? kSubDark : Colors.grey,
          indicatorColor: const Color(0xFF0D6EFD),
          onTap: (i) => _fetchUsers(role: _roleForTab(i)),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Clients'),
            Tab(text: 'Nurses'),
            Tab(text: 'Admins'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A1A2E)),
                    decoration: InputDecoration(
                      hintText: 'Search name or email...',
                      hintStyle: TextStyle(color: dark ? kSubDark : Colors.grey),
                      prefixIcon: Icon(Icons.search, size: 20, color: dark ? kSubDark : Colors.grey),
                      filled: true,
                      fillColor: dark ? kCardDark : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: dark ? kBorderDark : Colors.transparent)),
                    ),
                    onChanged: (v) {
                      _search = v;
                      _fetchUsers(role: _roleForTab(_tabController.index));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                if (_tabController.index == 2)
                  DropdownButton<String>(
                    value: _statusFilter.isEmpty ? null : _statusFilter,
                    hint: Text('Status',
                        style: TextStyle(fontSize: 13, color: dark ? kSubDark : Colors.grey)),
                    dropdownColor: dark ? kCardDark : Colors.white,
                    style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A1A2E)),
                    underline: const SizedBox(),
                    items: [
                      DropdownMenuItem(value: '',
                          child: Text('All', style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A1A2E)))),
                      DropdownMenuItem(value: 'Pending',
                          child: Text('Pending', style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A1A2E)))),
                      DropdownMenuItem(value: 'Approved',
                          child: Text('Approved', style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A1A2E)))),
                      DropdownMenuItem(value: 'Rejected',
                          child: Text('Rejected', style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A1A2E)))),
                    ],
                    onChanged: (v) {
                      setState(() => _statusFilter = v ?? '');
                      _fetchUsers(role: _roleForTab(_tabController.index));
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _allUsers.isEmpty
                ? Center(child: Text('No users found',
                style: TextStyle(color: dark ? kSubDark : Colors.grey)))
                : RefreshIndicator(
              onRefresh: () => _fetchUsers(role: _roleForTab(_tabController.index)),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _allUsers.length,
                itemBuilder: (_, i) => _buildUserCard(_allUsers[i], dark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, bool dark) {
    final role = user['role'] ?? '';
    final status = user['approval_status'] ?? 'Approved';
    final isNurse = role == 'Nurse';
    final isPending = status == 'Pending';

    Color statusColor = Colors.green;
    if (status == 'Pending') statusColor = Colors.orange;
    if (status == 'Rejected') statusColor = Colors.red;

    Color roleColor = const Color(0xFF0D6EFD);
    if (role == 'Nurse') roleColor = const Color(0xFF4CAF50);
    if (role == 'Admin') roleColor = const Color(0xFF9C27B0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: dark ? kCardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(dark ? 0.25 : 0.05), blurRadius: 8)],
        border: isPending ? Border.all(color: Colors.orange.shade200) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _userAvatar(user, roleColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user['name'] ?? '',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                              color: dark ? kTextDark : const Color(0xFF1A1A2E))),
                      Text(user['email'] ?? '',
                          style: TextStyle(fontSize: 12, color: dark ? kSubDark : Colors.grey)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(role,
                      style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),

            if (isNurse) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (user['service'] != null)
                    Expanded( // FIXED: Wrapped in Expanded to prevent pixel overflow
                      child: Text(
                        'Service: ${user['service']}',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(fontSize: 12, color: dark ? kSubDark : Colors.grey),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(status,
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (status != 'Approved')
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _updateStatus(user['id'], 'Approved'),
                        icon: const Icon(Icons.check_circle, size: 16),
                        label: const Text('Approve', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  if (status != 'Approved') const SizedBox(width: 8),
                  if (status != 'Rejected')
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _updateStatus(user['id'], 'Rejected'),
                        icon: const Icon(Icons.cancel, size: 16),
                        label: const Text('Reject', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  if (status != 'Rejected') const SizedBox(width: 8),
                  if (status != 'Pending')
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _updateStatus(user['id'], 'Pending'),
                        icon: const Icon(Icons.pending, size: 16),
                        label: const Text('Pending', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _viewCertificate(user['id']),
                  icon: const Icon(Icons.file_present, size: 16, color: Color(0xFF0D6EFD)),
                  label: const Text('View Certificate',
                      style: TextStyle(color: Color(0xFF0D6EFD), fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0D6EFD)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _deleteUser(user['id'], user['name'] ?? 'User'),
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                label: const Text('Delete', style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}