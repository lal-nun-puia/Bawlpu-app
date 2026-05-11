import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'home_screen.dart' show isDark, bgColor, kCardDark, kTextDark, kSubDark, kBorderDark, kBorder;

const _kPrimary = Color(0xFF1A6BB5);
const _kOrange  = Color(0xFFE8870A);

class GiveFeedbackScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const GiveFeedbackScreen({super.key, required this.userData});
  @override
  State<GiveFeedbackScreen> createState() => _GiveFeedbackScreenState();
}

class _GiveFeedbackScreenState extends State<GiveFeedbackScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<dynamic> _acceptedRequests = [];
  List<dynamic> _myReviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _fetchData();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final uid = widget.userData['user_id'];
      final r1 = await http.get(Uri.parse('${ApiService.baseUrl}/client_requests_api.php?action=my_requests&client_id=$uid')).timeout(const Duration(seconds: 15));
      final r2 = await http.get(Uri.parse('${ApiService.baseUrl}/feedback_api.php?action=get_my_reviews&client_id=$uid')).timeout(const Duration(seconds: 15));
      final d1 = jsonDecode(r1.body);
      final d2 = jsonDecode(r2.body);
      if (mounted) setState(() {
        _acceptedRequests = (d1['requests'] ?? []).where((r) => r['status'] == 'Accepted' && r['nurse_id'] != null).toList();
        _myReviews = d2['reviews'] ?? [];
      });
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _submitFeedback(int nurseId, int rating, String comment, bool isAnon) async {
    final d = await http.post(
      Uri.parse('${ApiService.baseUrl}/feedback_api.php?action=submit'),
      body: {
        'client_id': '${widget.userData['user_id']}',
        'nurse_id': '$nurseId',
        'rating': '$rating',
        'comment': comment,
        'is_anonymous': isAnon ? '1' : '0',
      },
    ).timeout(const Duration(seconds: 10));
    final data = jsonDecode(d.body);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(data['message'] ?? 'Done'),
      backgroundColor: data['status'] == 'success' ? Colors.green : Colors.red,
    ));
    if (data['status'] == 'success') _fetchData();
  }

  Future<void> _editFeedback(Map<String, dynamic> review) async {
    final dark = isDark(context);
    int rating = int.tryParse(review['rating'].toString()) ?? 5;
    final commentCtrl = TextEditingController(text: review['comment'] ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => Container(
        decoration: BoxDecoration(color: dark ? kCardDark : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Edit Review', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: dark ? kTextDark : const Color(0xFF1A2340))),
          const SizedBox(height: 16),
          // Star rating
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => GestureDetector(
            onTap: () => setS(() => rating = i + 1),
            child: Icon(i < rating ? Icons.star_rounded : Icons.star_border_rounded, color: const Color(0xFFFFC107), size: 36),
          ))),
          const SizedBox(height: 12),
          TextField(
            controller: commentCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Your comment...',
              hintStyle: TextStyle(color: dark ? kSubDark : Colors.grey),
              filled: true, fillColor: dark ? const Color(0xFF0F1624) : const Color(0xFFF0F5FB),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A2340)),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                final d = await http.post(
                  Uri.parse('${ApiService.baseUrl}/feedback_api.php?action=edit'),
                  body: {'id': '${review['id']}', 'client_id': '${widget.userData['user_id']}', 'rating': '$rating', 'comment': commentCtrl.text},
                ).timeout(const Duration(seconds: 10));
                final data = jsonDecode(d.body);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Done'), backgroundColor: data['status'] == 'success' ? Colors.green : Colors.red));
                if (data['status'] == 'success') _fetchData();
              },
              child: const Text('Save'),
            )),
          ]),
        ]),
      )),
    );
  }

  Future<void> _deleteFeedback(Map<String, dynamic> review) async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Delete Review'),
      content: const Text('Delete this review permanently?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (confirm != true) return;
    final d = await http.post(
      Uri.parse('${ApiService.baseUrl}/feedback_api.php?action=delete'),
      body: {'id': '${review['id']}', 'client_id': '${widget.userData['user_id']}'},
    ).timeout(const Duration(seconds: 10));
    final data = jsonDecode(d.body);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Done'), backgroundColor: data['status'] == 'success' ? Colors.orange : Colors.red));
    if (data['status'] == 'success') _fetchData();
  }

  void _showSubmitSheet(Map<String, dynamic> req) {
    final dark = isDark(context);
    int rating = 5;
    bool isAnon = false;
    final commentCtrl = TextEditingController();

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => Container(
        decoration: BoxDecoration(color: dark ? kCardDark : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Review ${req['nurse_name'] ?? 'Nurse'}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: dark ? kTextDark : const Color(0xFF1A2340))),
          const SizedBox(height: 4),
          Text(req['service_type'] ?? '', style: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 13)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => GestureDetector(
            onTap: () => setS(() => rating = i + 1),
            child: Icon(i < rating ? Icons.star_rounded : Icons.star_border_rounded, color: const Color(0xFFFFC107), size: 40),
          ))),
          const SizedBox(height: 12),
          TextField(
            controller: commentCtrl, maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Write your comment...',
              hintStyle: TextStyle(color: dark ? kSubDark : Colors.grey),
              filled: true, fillColor: dark ? const Color(0xFF0F1624) : const Color(0xFFF0F5FB),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A2340)),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Checkbox(value: isAnon, onChanged: (v) => setS(() => isAnon = v ?? false), activeColor: _kPrimary),
            Text('Post anonymously', style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A2340), fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: () { Navigator.pop(ctx); _submitFeedback(int.parse(req['nurse_id'].toString()), rating, commentCtrl.text, isAnon); },
            child: const Text('Submit Review', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ]),
      )),
    );
  }

  Widget _starRow(int n) => Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i) => Icon(i < n ? Icons.star_rounded : Icons.star_border_rounded, color: const Color(0xFFFFC107), size: 16)));

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return Scaffold(
      backgroundColor: bgColor(context),
      appBar: AppBar(
        backgroundColor: dark ? kCardDark : Colors.white,
        elevation: 1,
        title: Text('Feedback & Reviews', style: TextStyle(fontWeight: FontWeight.w800, color: dark ? kTextDark : const Color(0xFF1A2340))),
        iconTheme: IconThemeData(color: dark ? kTextDark : const Color(0xFF1A2340)),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: _kPrimary), onPressed: _fetchData)],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: _kPrimary,
          unselectedLabelColor: dark ? kSubDark : Colors.grey,
          indicatorColor: _kPrimary,
          tabs: const [Tab(text: 'Give Review'), Tab(text: 'My Reviews')],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabCtrl, children: [
        // ── GIVE REVIEW TAB ──────────────────────────────────────────
        _acceptedRequests.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.star_border, size: 64, color: dark ? kSubDark : Colors.grey),
          const SizedBox(height: 16),
          Text('No completed bookings', style: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Accept a nurse first to give feedback!', style: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 13)),
        ]))
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _acceptedRequests.length,
          itemBuilder: (_, i) {
            final req = _acceptedRequests[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: dark ? kCardDark : Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)], border: Border.all(color: dark ? kBorderDark : kBorder)),
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(radius: 20, backgroundColor: _kPrimary.withOpacity(0.12), child: Text((req['nurse_name'] ?? 'N')[0].toUpperCase(), style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.w800))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(req['nurse_name'] ?? 'Nurse', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: dark ? kTextDark : const Color(0xFF1A2340))),
                    Text(req['service_type'] ?? '', style: TextStyle(fontSize: 12, color: dark ? kSubDark : Colors.grey)),
                  ])),
                ]),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  onPressed: () => _showSubmitSheet(req),
                  icon: const Icon(Icons.star_rounded, size: 18),
                  label: const Text('Write a Review', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                )),
              ]),
            );
          },
        ),

        // ── MY REVIEWS TAB ───────────────────────────────────────────
        _myReviews.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.rate_review_outlined, size: 64, color: dark ? kSubDark : Colors.grey),
          const SizedBox(height: 16),
          Text('No reviews yet', style: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 16)),
        ]))
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _myReviews.length,
          itemBuilder: (_, i) {
            final r = _myReviews[i];
            final ratingNum = int.tryParse(r['rating'].toString()) ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: dark ? kCardDark : Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)], border: Border.all(color: dark ? kBorderDark : kBorder)),
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(radius: 18, backgroundColor: const Color(0xFF0F9B8E).withOpacity(0.12), child: Text((r['nurse_name'] ?? 'N')[0].toUpperCase(), style: const TextStyle(color: Color(0xFF0F9B8E), fontWeight: FontWeight.w800, fontSize: 14))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r['nurse_name'] ?? 'Nurse', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: dark ? kTextDark : const Color(0xFF1A2340))),
                    _starRow(ratingNum),
                  ])),
                  // Edit & Delete buttons
                  IconButton(icon: const Icon(Icons.edit_rounded, size: 18, color: _kPrimary), onPressed: () => _editFeedback(r), tooltip: 'Edit'),
                  IconButton(icon: const Icon(Icons.delete_rounded, size: 18, color: Colors.red), onPressed: () => _deleteFeedback(r), tooltip: 'Delete'),
                ]),
                if ((r['comment'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(r['comment'].toString(), style: TextStyle(fontSize: 13, color: dark ? kSubDark : Colors.grey, height: 1.4)),
                ],
                const SizedBox(height: 6),
                Text(r['created_at'] ?? '', style: TextStyle(fontSize: 11, color: dark ? kSubDark : Colors.grey)),
              ]),
            );
          },
        ),
      ]),
    );
  }
}