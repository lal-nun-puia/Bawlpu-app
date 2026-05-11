import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'home_screen.dart' show isDark, bgColor, kCardDark, kTextDark, kSubDark, kBorderDark;
import 'chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const ConversationsScreen({super.key, required this.userData});
  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  List<dynamic> _convs = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final r = await http.get(Uri.parse(
          '${ApiService.baseUrl}/chat_api.php?action=get_conversations&user_id=${widget.userData['user_id']}'))
          .timeout(const Duration(seconds: 15));
      final d = jsonDecode(r.body);
      if (d['status'] == 'success' && mounted) {
        setState(() => _convs = d['conversations'] ?? []);
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  String _timeAgo(String? dt) {
    if (dt == null) return '';
    try {
      final d = DateTime.parse(dt).toLocal();
      final diff = DateTime.now().difference(d);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return Scaffold(
      backgroundColor: bgColor(context),
      appBar: AppBar(
        backgroundColor: dark ? kCardDark : Colors.white,
        elevation: 1,
        title: Text('Messages', style: TextStyle(fontWeight: FontWeight.w700,
            color: dark ? kTextDark : const Color(0xFF1A2340))),
        iconTheme: IconThemeData(color: dark ? kTextDark : const Color(0xFF1A2340)),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF1A6BB5)), onPressed: _fetch)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _convs.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.chat_bubble_outline_rounded, size: 64, color: dark ? kSubDark : Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('No messages yet', style: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 16)),
        const SizedBox(height: 4),
        Text('Your conversations will appear here', style: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 13)),
      ]))
          : RefreshIndicator(
        onRefresh: _fetch,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _convs.length,
          itemBuilder: (_, i) {
            final c = _convs[i];
            final unread = int.tryParse(c['unread_count'].toString()) ?? 0;
            final photo = c['other_photo'] ?? '';
            final name = c['other_name'] ?? '';
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ChatScreen(
                  userData: widget.userData,
                  otherUserId: int.tryParse(c['other_id'].toString()) ?? 0,
                  otherUserName: name,
                  otherUserRole: c['other_role'] ?? '',
                  otherUserPhoto: photo.isNotEmpty ? photo : null,
                ),
              )).then((_) => _fetch()),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: dark ? kCardDark : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(dark ? 0.25 : 0.05), blurRadius: 8)],
                  border: unread > 0
                      ? Border.all(color: const Color(0xFF1A6BB5).withOpacity(0.4))
                      : null,
                ),
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Stack(children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFF1A6BB5).withOpacity(0.12),
                      backgroundImage: photo.isNotEmpty && photo.startsWith('http') ? NetworkImage(photo) : null,
                      child: !photo.startsWith('http') || photo.isEmpty
                          ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Color(0xFF1A6BB5),
                              fontSize: 18, fontWeight: FontWeight.w700))
                          : null,
                    ),
                    if (unread > 0)
                      Positioned(top: 0, right: 0,
                          child: Container(
                            width: 18, height: 18,
                            decoration: const BoxDecoration(color: Color(0xFF1A6BB5), shape: BoxShape.circle),
                            child: Center(child: Text('$unread',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
                          )),
                  ]),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(name,
                          style: TextStyle(fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 14, color: dark ? kTextDark : const Color(0xFF1A2340)))),
                      Text(_timeAgo(c['last_time']),
                          style: TextStyle(fontSize: 11, color: dark ? kSubDark : Colors.grey)),
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: const Color(0xFF1A6BB5).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(c['other_role'] ?? '',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF1A6BB5), fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text(c['last_message'] ?? '',
                          overflow: TextOverflow.ellipsis, maxLines: 1,
                          style: TextStyle(fontSize: 12,
                              fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
                              color: dark ? kSubDark : Colors.grey))),
                    ]),
                  ])),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF1A6BB5)),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }
}