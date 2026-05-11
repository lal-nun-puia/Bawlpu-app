import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'home_screen.dart' show isDark, bgColor, kCardDark, kTextDark, kSubDark;

class NotificationsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const NotificationsScreen({super.key, required this.userData});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  int _unreadCount = 0;
  bool _selectMode = false;
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final r = await http.get(Uri.parse(
          '${ApiService.baseUrl}/notifications_api.php?action=get_notifications&user_id=${widget.userData['user_id']}'))
          .timeout(const Duration(seconds: 15));
      final d = jsonDecode(r.body);
      if (d['status'] == 'success') {
        setState(() {
          _notifications = d['notifications'] ?? [];
          _unreadCount = d['unread_count'] ?? 0;
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _markAllRead() async {
    try {
      await http.post(Uri.parse('${ApiService.baseUrl}/notifications_api.php?action=mark_read'),
          body: {'user_id': '${widget.userData['user_id']}'});
      _fetchNotifications();
    } catch (_) {}
  }

  Future<void> _markOneRead(int id) async {
    try {
      await http.post(Uri.parse('${ApiService.baseUrl}/notifications_api.php?action=mark_read'),
          body: {'user_id': '${widget.userData['user_id']}', 'notif_id': '$id'});
      _fetchNotifications();
    } catch (_) {}
  }

  Future<void> _deleteOne(int id) async {
    try {
      await http.post(Uri.parse('${ApiService.baseUrl}/notifications_api.php?action=delete'),
          body: {'user_id': '${widget.userData['user_id']}', 'notif_id': '$id'});
      _fetchNotifications();
    } catch (_) {}
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Notifications'),
        content: Text('Delete ${_selected.length} selected?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await http.post(Uri.parse('${ApiService.baseUrl}/notifications_api.php?action=delete_multiple'),
          body: {'user_id': '${widget.userData['user_id']}', 'ids': _selected.join(',')});
      setState(() { _selected.clear(); _selectMode = false; });
      _fetchNotifications();
    } catch (_) {}
  }

  Future<void> _deleteAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete All'),
        content: const Text('Delete all notifications?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete All', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await http.post(Uri.parse('${ApiService.baseUrl}/notifications_api.php?action=delete'),
          body: {'user_id': '${widget.userData['user_id']}'});
      setState(() { _selected.clear(); _selectMode = false; });
      _fetchNotifications();
    } catch (_) {}
  }

  void _toggleSelect(int id) {
    setState(() {
      if (_selected.contains(id)) _selected.remove(id);
      else _selected.add(id);
    });
  }

  void _selectAll() {
    setState(() {
      if (_selected.length == _notifications.length) {
        _selected.clear();
      } else {
        _selected.clear();
        for (final n in _notifications) {
          _selected.add(n['id'] as int);
        }
      }
    });
  }

  Color _notifColor(String? type) {
    switch (type) {
      case 'booking': return const Color(0xFF1A6BB5);
      case 'approval': return Colors.green;
      case 'feedback': return const Color(0xFFFFC107);
      default: return const Color(0xFF7B3FC4);
    }
  }

  IconData _notifIcon(String? type) {
    switch (type) {
      case 'booking': return Icons.calendar_today_rounded;
      case 'approval': return Icons.check_circle_rounded;
      case 'feedback': return Icons.star_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  String _timeAgo(String? createdAt) {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _notifications.isNotEmpty &&
        _selected.length == _notifications.length;
    final dark = isDark(context);

    return Scaffold(
      backgroundColor: bgColor(context),
      appBar: _buildAppBar(allSelected, dark),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? _buildEmpty(dark)
          : RefreshIndicator(
        onRefresh: _fetchNotifications,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _notifications.length,
          itemBuilder: (_, i) => _buildItem(_notifications[i], dark),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool allSelected, bool dark) {
    return AppBar(
      backgroundColor: dark ? kCardDark : Colors.white,
      elevation: 1,
      leading: _selectMode
          ? IconButton(
        icon: Icon(Icons.close_rounded, color: dark ? kTextDark : const Color(0xFF1A2340)),
        onPressed: () => setState(() {
          _selectMode = false;
          _selected.clear();
        }),
      )
          : null,
      title: _selectMode
          ? Text('${_selected.length} selected',
          style: TextStyle(fontWeight: FontWeight.w700, color: dark ? kTextDark : const Color(0xFF1A2340)))
          : Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Notifications',
              style: TextStyle(fontWeight: FontWeight.w700, color: dark ? kTextDark : const Color(0xFF1A2340), fontSize: 17)),
          if (_unreadCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
              child: Text('$_unreadCount',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
      iconTheme: IconThemeData(color: dark ? kTextDark : const Color(0xFF1A2340)),
      actions: _buildActions(allSelected),
    );
  }

  List<Widget> _buildActions(bool allSelected) {
    if (_selectMode) {
      final list = <Widget>[
        TextButton.icon(
          onPressed: _selectAll,
          icon: Icon(
              allSelected ? Icons.deselect : Icons.select_all,
              color: const Color(0xFF1A6BB5), size: 20),
          label: Text(allSelected ? 'Deselect' : 'All',
              style: const TextStyle(color: Color(0xFF1A6BB5), fontWeight: FontWeight.w600)),
        ),
      ];
      if (_selected.isNotEmpty) {
        list.add(IconButton(
          icon: const Icon(Icons.delete_rounded, color: Colors.red),
          onPressed: _deleteSelected,
        ));
      }
      return list;
    }

    final list = <Widget>[];
    if (_unreadCount > 0) {
      list.add(IconButton(
          icon: const Icon(Icons.done_all_rounded, color: Color(0xFF1A6BB5)),
          tooltip: 'Mark all read',
          onPressed: _markAllRead));
    }
    if (_notifications.isNotEmpty) {
      list.add(IconButton(
          icon: const Icon(Icons.checklist_rounded, color: Color(0xFF1A6BB5)),
          tooltip: 'Select',
          onPressed: () => setState(() => _selectMode = true)));
      list.add(PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF1A6BB5)),
        onSelected: (v) {
          if (v == 'delete_all') _deleteAll();
          if (v == 'refresh') _fetchNotifications();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'refresh',
              child: Row(children: [Icon(Icons.refresh, size: 18), SizedBox(width: 8), Text('Refresh')])),
          PopupMenuItem(value: 'delete_all',
              child: Row(children: [
                Icon(Icons.delete_forever, color: Colors.red, size: 18),
                SizedBox(width: 8),
                Text('Delete All', style: TextStyle(color: Colors.red))
              ])),
        ],
      ));
    } else {
      list.add(IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF1A6BB5)),
          onPressed: _fetchNotifications));
    }
    return list;
  }

  Widget _buildEmpty(bool dark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: const Color(0xFF1A6BB5).withOpacity(0.08),
                shape: BoxShape.circle),
            child: const Icon(Icons.notifications_none_rounded, size: 56, color: Color(0xFF1A6BB5)),
          ),
          const SizedBox(height: 16),
          Text('No notifications yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                  color: dark ? kTextDark : const Color(0xFF1A2340))),
          const SizedBox(height: 4),
          Text('You will see notifications here',
              style: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildItem(dynamic n, bool dark) {
    final id = n['id'] as int;
    final isUnread = n['is_read'] == 0 || n['is_read'] == '0';
    final isSelected = _selected.contains(id);
    final color = _notifColor(n['type']?.toString());

    return Dismissible(
      key: Key('notif_$id'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => _deleteOne(id),
      child: GestureDetector(
        onTap: () {
          if (_selectMode) {
            _toggleSelect(id);
          } else {
            if (isUnread) _markOneRead(id);
          }
        },
        onLongPress: () => setState(() {
          _selectMode = true;
          _selected.add(id);
        }),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF1A6BB5).withOpacity(0.08)
                : (dark ? kCardDark : Colors.white),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(dark ? 0.25 : 0.05), blurRadius: 8)],
            border: isSelected
                ? Border.all(color: const Color(0xFF1A6BB5), width: 1.5)
                : isUnread ? Border.all(color: const Color(0xFF1A6BB5).withOpacity(0.3)) : null,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            leading: _selectMode
                ? Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleSelect(id),
              activeColor: const Color(0xFF1A6BB5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            )
                : Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(_notifIcon(n['type']?.toString()), color: color, size: 22),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(n['title'] ?? 'Notification',
                      style: TextStyle(
                          fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                          fontSize: 14,
                          color: dark ? kTextDark : const Color(0xFF1A2340))),
                ),
                if (isUnread && !_selectMode)
                  Container(width: 8, height: 8,
                      decoration: const BoxDecoration(color: Color(0xFF1A6BB5), shape: BoxShape.circle)),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.admin_panel_settings_rounded, size: 12, color: Color(0xFF1A6BB5)),
                  const SizedBox(width: 4),
                  Text(n['sender_name'] ?? 'From Admin',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF1A6BB5), fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 2),
                Text(n['message'] ?? '',
                    style: TextStyle(
                        fontSize: 13,
                        color: isUnread ? (dark ? kTextDark : const Color(0xFF1A2340)) : (dark ? kSubDark : Colors.grey))),
                const SizedBox(height: 4),
                Text(_timeAgo(n['created_at']),
                    style: TextStyle(fontSize: 11, color: dark ? kSubDark : Colors.grey)),
              ],
            ),
            trailing: _selectMode
                ? null
                : IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
              onPressed: () => _deleteOne(id),
            ),
          ),
        ),
      ),
    );
  }
}