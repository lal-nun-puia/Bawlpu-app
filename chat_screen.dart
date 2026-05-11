import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'home_screen.dart' show isDark, bgColor, kCardDark, kTextDark, kSubDark, kBorderDark;

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final int otherUserId;
  final String otherUserName;
  final String otherUserRole;
  final String? otherUserPhoto;

  const ChatScreen({
    super.key,
    required this.userData,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserRole,
    this.otherUserPhoto,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<dynamic> _messages = [];
  bool _isLoading  = true;
  bool _isSending  = false;
  Timer? _timer;

  // Edit mode
  Map<String, dynamic>? _editingMessage;

  // Selected messages for delete
  Set<int> _selected = {};
  bool _selectMode = false;

  int get _myId => int.tryParse(widget.userData['user_id'].toString()) ?? 0;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchMessages(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final r = await http.get(Uri.parse(
          '${ApiService.baseUrl}/chat_api.php?action=get_messages'
              '&user_id=$_myId&other_id=${widget.otherUserId}'))
          .timeout(const Duration(seconds: 10));
      final d = jsonDecode(r.body);
      if (d['status'] == 'success' && mounted) {
        final newMsgs = d['messages'] as List;
        if (newMsgs.length != _messages.length) {
          setState(() => _messages = newMsgs);
          _scrollToBottom();
        }
      }
    } catch (_) {}
    if (!silent && mounted) setState(() => _isLoading = false);
  }

  Future<void> _sendMessage() async {
    if (_editingMessage != null) {
      await _confirmEdit();
      return;
    }
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    _msgCtrl.clear();

    // Optimistic UI
    final tempMsg = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'sender_id': _myId,
      'receiver_id': widget.otherUserId,
      'message': text,
      'image_url': null,
      'is_read': 0,
      'is_edited': 0,
      'is_deleted': 0,
      'created_at': DateTime.now().toIso8601String(),
    };
    setState(() => _messages.add(tempMsg));
    _scrollToBottom();

    try {
      await http.post(
        Uri.parse('${ApiService.baseUrl}/chat_api.php?action=send_message'),
        body: {
          'sender_id':   '$_myId',
          'receiver_id': '${widget.otherUserId}',
          'message':     text,
        },
      ).timeout(const Duration(seconds: 10));
      _fetchMessages(silent: true);
    } catch (_) {}
    if (mounted) setState(() => _isSending = false);
  }

  Future<void> _sendImage() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.image, allowMultiple: false);
    if (result == null || result.files.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final request = http.MultipartRequest(
          'POST', Uri.parse('${ApiService.baseUrl}/chat_api.php?action=send_image'));
      request.fields['sender_id']   = '$_myId';
      request.fields['receiver_id'] = '${widget.otherUserId}';
      request.files.add(await http.MultipartFile.fromPath('image', result.files.single.path!));
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        _fetchMessages(silent: true);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Image send failed'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _isSending = false);
  }

  void _startEdit(Map<String, dynamic> msg) {
    setState(() {
      _editingMessage = msg;
      _msgCtrl.text = msg['message'] ?? '';
      _selectMode = false;
      _selected.clear();
    });
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _cancelEdit() {
    setState(() { _editingMessage = null; _msgCtrl.clear(); });
  }

  Future<void> _confirmEdit() async {
    final newText = _msgCtrl.text.trim();
    if (newText.isEmpty || _editingMessage == null) return;
    final msgId = int.tryParse(_editingMessage!['id'].toString()) ?? 0;
    if (msgId == 0) return;

    try {
      final r = await http.post(
        Uri.parse('${ApiService.baseUrl}/chat_api.php?action=edit_message'),
        body: {'message_id': '$msgId', 'sender_id': '$_myId', 'message': newText},
      ).timeout(const Duration(seconds: 10));
      final d = jsonDecode(r.body);
      if (d['status'] == 'success') {
        setState(() { _editingMessage = null; _msgCtrl.clear(); });
        _fetchMessages(silent: true);
      }
    } catch (_) {}
  }

  Future<void> _deleteMessages(List<int> ids) async {
    for (final id in ids) {
      try {
        await http.post(
          Uri.parse('${ApiService.baseUrl}/chat_api.php?action=delete_message'),
          body: {'message_id': '$id', 'sender_id': '$_myId'},
        ).timeout(const Duration(seconds: 10));
      } catch (_) {}
    }
    setState(() { _selected.clear(); _selectMode = false; });
    _fetchMessages(silent: true);
  }

  void _onLongPress(Map<String, dynamic> msg) {
    final isMe = msg['sender_id'].toString() == _myId.toString();
    final isDeleted = msg['is_deleted'] == 1 || msg['is_deleted'] == '1';
    if (isDeleted) return;
    final msgId = int.tryParse(msg['id'].toString()) ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final dark = isDark(context);
        return Container(
          decoration: BoxDecoration(
              color: dark ? kCardDark : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
            // Copy
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: Color(0xFF1A6BB5)),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: msg['message'] ?? ''));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)));
              },
            ),
            if (isMe) ...[
              // Edit (only text messages)
              if ((msg['image_url'] == null || msg['image_url'].toString().isEmpty))
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: Colors.orange),
                  title: const Text('Edit'),
                  onTap: () { Navigator.pop(context); _startEdit(msg); },
                ),
              // Delete
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(context: context, builder: (_) => AlertDialog(
                    title: const Text('Delete Message'),
                    content: const Text('Delete this message?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      TextButton(onPressed: () { Navigator.pop(context); _deleteMessages([msgId]); },
                          child: const Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ));
                },
              ),
            ],
          ]),
        );
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  String _formatTime(String? dt) {
    if (dt == null) return '';
    try {
      final d = DateTime.parse(dt).toLocal();
      return '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    } catch (_) { return ''; }
  }

  String _formatDate(String? dt) {
    if (dt == null) return '';
    try {
      final d = DateTime.parse(dt).toLocal();
      final now = DateTime.now();
      if (d.day == now.day && d.month == now.month && d.year == now.year) return 'Today';
      if (d.day == now.day - 1 && d.month == now.month) return 'Yesterday';
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    final photo = widget.otherUserPhoto ?? '';

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0F1624) : const Color(0xFFECE5DD),
      appBar: AppBar(
        backgroundColor: dark ? kCardDark : const Color(0xFF1A6BB5),
        elevation: 1,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white.withOpacity(0.25),
            backgroundImage: photo.isNotEmpty && photo.startsWith('http') ? NetworkImage(photo) : null,
            child: !photo.startsWith('http') || photo.isEmpty
                ? Text(widget.otherUserName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))
                : null,
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.otherUserName,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            Text(widget.otherUserRole,
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ]),
        ]),
        actions: [
          if (_selectMode) ...[
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.red),
              onPressed: () {
                final mySelected = _selected.where((id) {
                  final msg = _messages.firstWhere(
                          (m) => int.tryParse(m['id'].toString()) == id,
                      orElse: () => {});
                  return msg.isNotEmpty && msg['sender_id'].toString() == _myId.toString();
                }).toList();
                if (mySelected.isNotEmpty) _deleteMessages(mySelected);
                else setState(() { _selectMode = false; _selected.clear(); });
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => setState(() { _selectMode = false; _selected.clear(); }),
            ),
          ],
        ],
      ),
      body: Column(children: [
        // ── MESSAGES ────────────────────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 64,
                color: dark ? kSubDark : Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No messages yet',
                style: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 15)),
            const SizedBox(height: 4),
            Text('Say hello! 👋',
                style: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 13)),
          ]))
              : ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            itemCount: _messages.length,
            itemBuilder: (_, i) {
              final msg = _messages[i];
              final isMe = msg['sender_id'].toString() == _myId.toString();
              final isDeleted = msg['is_deleted'] == 1 || msg['is_deleted'] == '1';
              final isEdited  = msg['is_edited']  == 1 || msg['is_edited']  == '1';
              final isRead    = msg['is_read']    == 1 || msg['is_read']    == '1';
              final imageUrl  = msg['image_url']  ?? '';
              final msgId     = int.tryParse(msg['id'].toString()) ?? 0;
              final isSelected = _selected.contains(msgId);

              // Date divider
              bool showDate = i == 0;
              if (!showDate) {
                final prev = _messages[i-1]['created_at'] ?? '';
                final curr = msg['created_at'] ?? '';
                try {
                  showDate = DateTime.parse(prev).day != DateTime.parse(curr).day;
                } catch (_) {}
              }

              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (showDate)
                  Center(child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                        color: dark ? const Color(0xFF1A2235) : Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(_formatDate(msg['created_at']),
                        style: TextStyle(fontSize: 11,
                            color: dark ? kSubDark : Colors.grey.shade600)),
                  )),
                GestureDetector(
                  onLongPress: () {
                    if (!_selectMode) _onLongPress(msg);
                  },
                  onTap: _selectMode ? () {
                    setState(() {
                      if (isSelected) _selected.remove(msgId);
                      else _selected.add(msgId);
                      if (_selected.isEmpty) _selectMode = false;
                    });
                  } : null,
                  child: _MessageBubble(
                    message: msg['message'] ?? '',
                    imageUrl: imageUrl,
                    isMe: isMe,
                    isDeleted: isDeleted,
                    isEdited: isEdited,
                    isRead: isRead,
                    isSelected: isSelected,
                    time: _formatTime(msg['created_at']),
                    dark: dark,
                  ),
                ),
              ]);
            },
          ),
        ),

        // ── EDIT BANNER ──────────────────────────────────────────────────────
        if (_editingMessage != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: dark ? const Color(0xFF1A2235) : const Color(0xFFE8F4FD),
            child: Row(children: [
              const Icon(Icons.edit_rounded, color: Color(0xFF1A6BB5), size: 18),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Editing message',
                    style: TextStyle(color: Color(0xFF1A6BB5), fontSize: 11, fontWeight: FontWeight.w600)),
                Text(_editingMessage!['message'] ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: dark ? kSubDark : Colors.grey)),
              ])),
              IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.grey), onPressed: _cancelEdit),
            ]),
          ),

        // ── INPUT BAR ────────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
              color: dark ? kCardDark : const Color(0xFFF0F2F5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08),
                  blurRadius: 8, offset: const Offset(0, -2))]),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            // Photo picker
            GestureDetector(
              onTap: _sendImage,
              child: Container(
                width: 40, height: 40, margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                    color: const Color(0xFF1A6BB5).withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.photo_rounded, color: Color(0xFF1A6BB5), size: 20),
              ),
            ),
            // Text input
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                    color: dark ? const Color(0xFF1A2235) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: dark ? kBorderDark : Colors.grey.shade300)),
                child: TextField(
                  controller: _msgCtrl,
                  maxLines: null,
                  style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A2340), fontSize: 14),
                  decoration: InputDecoration(
                    hintText: _editingMessage != null ? 'Edit message...' : 'Message',
                    hintStyle: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Send button
            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                    color: _isSending ? Colors.grey : const Color(0xFF1A6BB5),
                    shape: BoxShape.circle),
                child: _isSending
                    ? const Padding(padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(_editingMessage != null ? Icons.check_rounded : Icons.send_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── MESSAGE BUBBLE ────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final String message;
  final String imageUrl;
  final bool isMe;
  final bool isDeleted;
  final bool isEdited;
  final bool isRead;
  final bool isSelected;
  final String time;
  final bool dark;

  const _MessageBubble({
    required this.message, required this.imageUrl, required this.isMe,
    required this.isDeleted, required this.isEdited, required this.isRead,
    required this.isSelected, required this.time, required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 3,
          left: isMe ? 60 : 0,
          right: isMe ? 0 : 60,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1A6BB5).withOpacity(0.3)
              : isMe
              ? (dark ? const Color(0xFF1A4A80) : const Color(0xFFDCF8C6))
              : (dark ? const Color(0xFF1A2235) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.2 : 0.06), blurRadius: 3)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // Image
          if (imageUrl.isNotEmpty && !isDeleted)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18), topRight: Radius.circular(18)),
              child: GestureDetector(
                onTap: () => _viewImage(context, imageUrl),
                child: Image.network(imageUrl, width: 220, fit: BoxFit.cover,
                    loadingBuilder: (_, child, prog) => prog == null ? child
                        : Container(width: 220, height: 150,
                        color: Colors.grey.shade200,
                        child: const Center(child: CircularProgressIndicator())),
                    errorBuilder: (_, __, ___) => Container(width: 220, height: 100,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, size: 40, color: Colors.grey))),
              ),
            ),

          // Text
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (!isDeleted && message.isNotEmpty)
                Text(message,
                    style: TextStyle(
                      color: isMe
                          ? (dark ? Colors.white : const Color(0xFF1A2340))
                          : (dark ? kTextDark : const Color(0xFF1A2340)),
                      fontSize: 14, height: 1.4,
                      fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                    )),
              if (isDeleted)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.block_rounded, size: 13, color: dark ? kSubDark : Colors.grey),
                  const SizedBox(width: 4),
                  Text('This message was deleted',
                      style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic,
                          color: dark ? kSubDark : Colors.grey)),
                ]),
              const SizedBox(height: 2),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (isEdited && !isDeleted)
                  Text('edited  ',
                      style: TextStyle(fontSize: 10,
                          color: isMe ? (dark ? Colors.white54 : Colors.grey.shade600) : (dark ? kSubDark : Colors.grey))),
                Text(time, style: TextStyle(fontSize: 10,
                    color: isMe ? (dark ? Colors.white54 : Colors.grey.shade600) : (dark ? kSubDark : Colors.grey))),
                if (isMe) ...[
                  const SizedBox(width: 3),
                  Icon(isRead ? Icons.done_all_rounded : Icons.done_rounded,
                      size: 14,
                      color: isRead ? const Color(0xFF53BDEB) : (dark ? Colors.white54 : Colors.grey.shade500)),
                ],
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  void _viewImage(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(alignment: Alignment.center, children: [
          InteractiveViewer(
              child: ClipRRect(borderRadius: BorderRadius.circular(12),
                  child: Image.network(url, fit: BoxFit.contain))),
          Positioned(top: 0, right: 0,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 22)),
              )),
        ]),
      ),
    );
  }
}