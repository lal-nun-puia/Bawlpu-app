import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'home_screen.dart' show isDark, bgColor, kCardDark, kTextDark, kSubDark;

class NurseReviewsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final int nurseId;
  final String nurseName;
  const NurseReviewsScreen({super.key, required this.userData, required this.nurseId, required this.nurseName});

  @override
  State<NurseReviewsScreen> createState() => _NurseReviewsScreenState();
}

class _NurseReviewsScreenState extends State<NurseReviewsScreen> {
  List<dynamic> _reviews = [];
  bool _isLoading = true;
  double _average = 0;
  int _total = 0;
  Map<String, dynamic> _distribution = {'5':0,'4':0,'3':0,'2':0,'1':0};

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    setState(() => _isLoading = true);
    try {
      final url = '${ApiService.baseUrl}/feedback_api.php?action=get_nurse_ratings&nurse_id=${widget.nurseId}';
      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));

      if (response.body.trim().startsWith('<')) {
        setState(() => _isLoading = false);
        return;
      }

      final data = jsonDecode(response.body);
      if (data['status'] == 'success' && mounted) {
        setState(() {
          _reviews      = List<dynamic>.from(data['ratings'] ?? []);
          _average      = double.tryParse((data['average'] ?? 0).toString()) ?? 0.0;
          _total        = int.tryParse((data['total'] ?? 0).toString()) ?? 0;
          _distribution = Map<String, dynamic>.from(
              data['distribution'] ?? {'5':0,'4':0,'3':0,'2':0,'1':0});
        });
      }
    } catch (e) {
      debugPrint('Reviews fetch error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  String _ratingLabel(dynamic num) {
    final labels = {'5': 'Excellent', '4': 'Very Good', '3': 'Good', '2': 'Fair', '1': 'Poor'};
    return labels[num.toString()] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return Scaffold(
      backgroundColor: bgColor(context),
      appBar: AppBar(
        backgroundColor: dark ? kCardDark : Colors.white,
        elevation: 1,
        title: Text('${widget.nurseName}\'s Reviews',
            style: TextStyle(fontWeight: FontWeight.w700, color: dark ? kTextDark : const Color(0xFF1A1A2E))),
        iconTheme: IconThemeData(color: dark ? kTextDark : const Color(0xFF1A1A2E)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF0D6EFD)), onPressed: _fetchReviews),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchReviews,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Rating summary card — gradient kept as-is (looks great in dark too)
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0D6EFD), Color(0xFF0099FF)]),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Column(
                    children: [
                      Text(_average.toStringAsFixed(1),
                          style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w800)),
                      Row(
                        children: List.generate(5, (i) => Icon(
                          i < _average.round() ? Icons.star : Icons.star_border,
                          color: const Color(0xFFFFC107), size: 16,
                        )),
                      ),
                      const SizedBox(height: 4),
                      Text('$_total review${_total != 1 ? 's' : ''}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      children: [5, 4, 3, 2, 1].map((star) {
                        final count = (_distribution[star.toString()] ?? 0) as int;
                        final pct = _total > 0 ? count / _total : 0.0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Text('$star ', style: const TextStyle(color: Colors.white, fontSize: 12)),
                              const Icon(Icons.star, color: Color(0xFFFFC107), size: 12),
                              const SizedBox(width: 6),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct.toDouble(),
                                    backgroundColor: Colors.white24,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFC107)),
                                    minHeight: 6,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text('$count', style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Reviews list
            if (_reviews.isEmpty)
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Icon(Icons.star_border, size: 64, color: dark ? kSubDark : Colors.grey),
                    const SizedBox(height: 12),
                    Text('No reviews yet', style: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 16)),
                  ],
                ),
              )
            else
              ..._reviews.map((r) {
                final ratingNum = int.tryParse((r['rating'] ?? r['rating_number'] ?? '0').toString()) ?? 0;
                final isAnon    = r['is_anonymous'] == 1 || r['is_anonymous'] == '1';
                final clientPhoto = (r['client_photo'] ?? '').toString();
                final clientName  = isAnon ? 'Anonymous' : (r['client_name'] ?? 'Client');

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: dark ? kCardDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(dark ? 0.25 : 0.05), blurRadius: 8)],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // ── AVATAR — photo if not anon, grey icon if anon ──
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: isAnon
                                ? Colors.grey.shade300
                                : const Color(0xFF0D6EFD).withOpacity(0.12),
                            backgroundImage: (!isAnon && clientPhoto.isNotEmpty && clientPhoto.startsWith('http'))
                                ? NetworkImage(clientPhoto) : null,
                            child: (!isAnon && clientPhoto.isNotEmpty && clientPhoto.startsWith('http'))
                                ? null
                                : Icon(
                              isAnon ? Icons.person_off_rounded : Icons.person_rounded,
                              size: 20,
                              color: isAnon ? Colors.grey.shade600 : const Color(0xFF0D6EFD),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(clientName,
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                                      color: dark ? kTextDark : const Color(0xFF1A1A2E))),
                              if (isAnon)
                                Text('Anonymous review',
                                    style: TextStyle(fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                        color: dark ? kSubDark : Colors.grey)),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            children: List.generate(5, (i) => Icon(
                              i < ratingNum ? Icons.star : Icons.star_border,
                              color: const Color(0xFFFFC107), size: 14,
                            )),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC107).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(_ratingLabel(ratingNum),
                            style: const TextStyle(color: Color(0xFFB8860B), fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                      if ((r['comment'] ?? r['review'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text((r['comment'] ?? r['review'] ?? '').toString(),
                            style: TextStyle(fontSize: 13,
                                color: dark ? kTextDark : const Color(0xFF1A1A2E), height: 1.4)),
                      ],
                      const SizedBox(height: 6),
                      Text(r['created_at'] ?? '',
                          style: TextStyle(fontSize: 11, color: dark ? kSubDark : Colors.grey)),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}