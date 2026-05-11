import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'home_screen.dart' show isDark, bgColor, cardColor, textColor, subColor, kCardDark, kTextDark, kSubDark, kBorderDark, kBorder;
import 'nurse_reviews_screen.dart';
import 'chat_screen.dart';
import 'request_service_screen.dart';
import 'conversations_screen.dart';

class SearchNursesScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const SearchNursesScreen({super.key, required this.userData});

  @override
  State<SearchNursesScreen> createState() => _SearchNursesScreenState();
}

class _SearchNursesScreenState extends State<SearchNursesScreen> {
  List<dynamic> _nurses = [];
  bool _isLoading = false;
  String _selectedService = '';
  final _searchCtrl = TextEditingController();

  final List<String> _services = ['All', 'ElderlyCare', 'PatientCare', 'Babysitting', 'LabTesting'];
  final Map<String, String> _serviceLabels = {
    'All': 'All',
    'ElderlyCare': 'Elderly Care',
    'PatientCare': 'Patient Care',
    'Babysitting': 'Babysitting',
    'LabTesting': 'Lab Testing',
  };

  @override
  void initState() {
    super.initState();
    _fetchNurses();
  }

  // Build full photo URL from relative path
  String _buildPhotoUrl(dynamic path) {
    if (path == null || path.toString().isEmpty) return '';
    final p = path.toString();
    if (p.startsWith('http')) return p;
    final base = ApiService.baseUrl.replaceAll('/api', '');
    return '$base/$p';
  }

  // Nurse avatar with proper error handling
  Widget _nurseAvatar(String photoUrl, String name, double radius) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    if (photoUrl.isEmpty || !photoUrl.startsWith('http')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF4CAF50).withOpacity(0.12),
        child: Text(initial, style: TextStyle(
            color: const Color(0xFF4CAF50),
            fontSize: radius * 0.75, fontWeight: FontWeight.w700)),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF4CAF50).withOpacity(0.12),
      child: ClipOval(
        child: Image.network(
          photoUrl,
          width: radius * 2, height: radius * 2, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Text(initial, style: TextStyle(
              color: const Color(0xFF4CAF50),
              fontSize: radius * 0.75, fontWeight: FontWeight.w700)),
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : Text(initial, style: TextStyle(
              color: const Color(0xFF4CAF50),
              fontSize: radius * 0.75, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Future<void> _fetchNurses() async {
    setState(() => _isLoading = true);
    try {
      String url = '${ApiService.baseUrl}/admin_api.php?action=get_users&role=Nurse&status=Approved';
      if (_searchCtrl.text.isNotEmpty) url += '&q=${Uri.encodeComponent(_searchCtrl.text)}';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        List<dynamic> nurses = (data['users'] as List)
            .where((u) => u['role'] == 'Nurse' && u['approval_status'] == 'Approved')
            .toList();
        if (_selectedService.isNotEmpty && _selectedService != 'All') {
          nurses = nurses.where((u) => u['service'] == _selectedService).toList();
        }
        for (var nurse in nurses) {
          try {
            final rResponse = await http.get(
              Uri.parse('${ApiService.baseUrl}/feedback_api.php?action=get_summary&nurse_id=${nurse['id']}'),
            ).timeout(const Duration(seconds: 5));
            final rData = jsonDecode(rResponse.body);
            if (rData['status'] == 'success') {
              nurse['avg_rating'] = rData['average'];
              nurse['total_reviews'] = rData['total'];
            }
          } catch (_) {
            nurse['avg_rating'] = 0;
            nurse['total_reviews'] = 0;
          }
        }
        setState(() => _nurses = nurses);
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  // ── SHOW NURSE PROFILE BOTTOM SHEET ──────────────────────────────────────
  void _showNurseProfile(Map<String, dynamic> nurse) {
    final dark = isDark(context);
    final avgRating = (nurse['avg_rating'] ?? 0).toDouble();
    final totalReviews = nurse['total_reviews'] ?? 0;
    final photo = _buildPhotoUrl(nurse['profile_photo']);
    final name = nurse['name'] ?? 'Nurse';
    final service = _serviceLabels[nurse['service']] ?? nurse['service'] ?? '';
    final location = nurse['location'] ?? '';
    final bio = nurse['bio'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
              color: dark ? kCardDark : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            // Handle
            Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
            Expanded(
              child: ListView(controller: scrollCtrl, padding: const EdgeInsets.all(20), children: [
                // ── PROFILE HEADER ─────────────────────────────────────────
                Row(children: [
                  _nurseAvatar(photo, name, 36),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                        color: dark ? kTextDark : const Color(0xFF1A2340))),
                    const SizedBox(height: 4),
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                            color: const Color(0xFF1A6BB5).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(service, style: const TextStyle(
                            color: Color(0xFF1A6BB5), fontSize: 12, fontWeight: FontWeight.w600))),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.location_on_outlined, size: 13, color: dark ? kSubDark : Colors.grey),
                        const SizedBox(width: 2),
                        Text(location, style: TextStyle(fontSize: 12, color: dark ? kSubDark : Colors.grey)),
                      ]),
                    ],
                  ])),
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Text('Available', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600))),
                ]),
                const SizedBox(height: 16),

                // ── RATING SUMMARY ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: dark ? const Color(0xFF0F1624) : const Color(0xFFF8F9FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: dark ? kBorderDark : const Color(0xFFE0E6FF))),
                  child: Row(children: [
                    Column(children: [
                      Text(avgRating > 0 ? avgRating.toStringAsFixed(1) : '—',
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900,
                              color: Color(0xFF1A6BB5))),
                      Row(children: List.generate(5, (i) => Icon(
                          i < avgRating.round() ? Icons.star : Icons.star_border,
                          color: const Color(0xFFFFC107), size: 14))),
                      const SizedBox(height: 2),
                      Text('$totalReviews review${totalReviews != 1 ? 's' : ''}',
                          style: TextStyle(fontSize: 11, color: dark ? kSubDark : Colors.grey)),
                    ]),
                    const SizedBox(width: 20),
                    // Rating bars
                    Expanded(child: Column(
                      children: [5, 4, 3, 2, 1].map((star) {
                        // We don't have distribution here, just show average visually
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(children: [
                            Text('$star', style: TextStyle(fontSize: 11, color: dark ? kSubDark : Colors.grey)),
                            const SizedBox(width: 4),
                            const Icon(Icons.star, color: Color(0xFFFFC107), size: 11),
                            const SizedBox(width: 6),
                            Expanded(child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: totalReviews > 0 && star == avgRating.round() ? 0.7 :
                                totalReviews > 0 && (star - avgRating).abs() <= 1 ? 0.3 : 0.05,
                                backgroundColor: dark ? const Color(0xFF2A3550) : Colors.grey.shade200,
                                valueColor: const AlwaysStoppedAnimation(Color(0xFFFFC107)),
                                minHeight: 6,
                              ),
                            )),
                          ]),
                        );
                      }).toList(),
                    )),
                  ]),
                ),
                const SizedBox(height: 16),

                // ── BIO ────────────────────────────────────────────────────
                if (bio.isNotEmpty) ...[
                  Text('About', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                      color: dark ? kTextDark : const Color(0xFF1A2340))),
                  const SizedBox(height: 6),
                  Text(bio, style: TextStyle(fontSize: 13, height: 1.5,
                      color: dark ? kSubDark : const Color(0xFF6B7A9B))),
                  const SizedBox(height: 16),
                ],

                // ── VIEW ALL REVIEWS button ────────────────────────────────
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => NurseReviewsScreen(userData: widget.userData,
                            nurseId: int.tryParse(nurse['id']?.toString() ?? '0') ?? 0, nurseName: name)));
                  },
                  icon: const Icon(Icons.star_rounded, size: 16),
                  label: Text('View All Reviews ($totalReviews)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A6BB5),
                    side: const BorderSide(color: Color(0xFF1A6BB5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),

                // ── ACTION BUTTONS ─────────────────────────────────────────
                Row(children: [
                  // CHAT BUTTON
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            userData: widget.userData,
                            otherUserId: nurse['id'],
                            otherUserName: name,
                            otherUserRole: 'Nurse',
                            otherUserPhoto: photo.isNotEmpty ? photo : null,
                          ),
                        ));
                      },
                      icon: const Icon(Icons.chat_rounded, size: 18),
                      label: const Text('Chat', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F9B8E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // BOOK BUTTON
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showBookDialog(nurse);
                      },
                      icon: const Icon(Icons.calendar_month_rounded, size: 18),
                      label: const Text('Book Now', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A6BB5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ── BOOK NOW — client picks service then goes directly to that nurse ────
  void _showBookDialog(Map<String, dynamic> nurse) {
    final nurseId   = int.tryParse(nurse['id']?.toString() ?? '0') ?? 0;
    final nurseName = nurse['name']?.toString() ?? 'Nurse';
    final dark = isDark(context);
    String? selectedSlug;
    String? selectedLabel;

    final List<Map<String, dynamic>> services = [
      {'slug': 'ElderlyCare', 'label': 'Elderly Care',  'icon': Icons.elderly_rounded,         'color': const Color(0xFF1A6BB5)},
      {'slug': 'PatientCare', 'label': 'Patient Care',  'icon': Icons.medical_services_rounded, 'color': const Color(0xFF0F9B8E)},
      {'slug': 'Babysitting', 'label': 'Babysitting',   'icon': Icons.child_care_rounded,       'color': const Color(0xFFE8870A)},
      {'slug': 'LabTesting',  'label': 'Lab Testing',   'icon': Icons.biotech_rounded,          'color': const Color(0xFF7B3FC4)},
    ];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: dark ? kCardDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Select a Service',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18,
                    color: dark ? kTextDark : const Color(0xFF1A2340))),
            const SizedBox(height: 4),
            Text('Choose which service you need from ${nurse['name']}',
                style: TextStyle(fontSize: 12,
                    color: dark ? kSubDark : Colors.grey, fontWeight: FontWeight.normal)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: services.map((s) {
              final isSelected = selectedSlug == s['slug'];
              final color = s['color'] as Color;
              return GestureDetector(
                onTap: () => setS(() {
                  selectedSlug  = s['slug'] as String;
                  selectedLabel = s['label'] as String;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                      color: isSelected ? color.withOpacity(0.1) : (dark ? const Color(0xFF0F1624) : const Color(0xFFF8F9FF)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: isSelected ? color : (dark ? kBorderDark : const Color(0xFFE0E6FF)),
                          width: isSelected ? 2 : 1)),
                  child: Row(children: [
                    Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                            color: color.withOpacity(isSelected ? 0.2 : 0.08),
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(s['icon'] as IconData, color: color, size: 20)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(s['label'] as String,
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: isSelected ? color : (dark ? kTextDark : const Color(0xFF1A2340))))),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded, color: color, size: 20),
                  ]),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: dark ? kSubDark : Colors.grey))),
            ElevatedButton.icon(
              onPressed: selectedSlug == null ? null : () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => RequestServiceScreen(
                    userData: widget.userData,
                    serviceType: selectedSlug!,
                    serviceTitle: selectedLabel!,
                    targetNurseId: nurseId,
                    targetNurseName: nurseName,
                  ),
                ));
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Book Now', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: selectedSlug != null
                      ? services.firstWhere((s) => s['slug'] == selectedSlug,
                      orElse: () => services[0])['color'] as Color
                      : Colors.grey,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
      ),
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
        title: Text('Search Nurses',
            style: TextStyle(fontWeight: FontWeight.w700,
                color: dark ? kTextDark : const Color(0xFF1A2340))),
        iconTheme: IconThemeData(color: dark ? kTextDark : const Color(0xFF1A2340)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            controller: _searchCtrl,
            style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A2340)),
            decoration: InputDecoration(
              hintText: 'Search by name or location...',
              hintStyle: TextStyle(color: dark ? kSubDark : Colors.grey),
              prefixIcon: Icon(Icons.search, color: dark ? kSubDark : Colors.grey),
              suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                if (_searchCtrl.text.isNotEmpty)
                  IconButton(
                      icon: Icon(Icons.clear, color: dark ? kSubDark : Colors.grey, size: 18),
                      onPressed: () { _searchCtrl.clear(); _fetchNurses(); }),
                IconButton(icon: const Icon(Icons.search, color: Color(0xFF1A6BB5)), onPressed: _fetchNurses),
              ]),
              filled: true,
              fillColor: dark ? kCardDark : Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: dark ? kBorderDark : Colors.transparent)),
            ),
            onSubmitted: (_) => _fetchNurses(),
            onChanged: (v) { setState(() {}); if (v.isEmpty) _fetchNurses(); },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Icon(Icons.info_outline, size: 12, color: dark ? kSubDark : Colors.grey),
            const SizedBox(width: 4),
            Text('Tap a nurse card to view profile, chat & book',
                style: TextStyle(fontSize: 11, color: dark ? kSubDark : Colors.grey)),
          ]),
        ),
        const SizedBox(height: 8),
        // Filter chips
        SizedBox(
          height: 44,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: _services.length,
            itemBuilder: (_, i) {
              final s = _services[i];
              final selected = _selectedService == s || (s == 'All' && _selectedService.isEmpty);
              return GestureDetector(
                onTap: () { setState(() => _selectedService = s == 'All' ? '' : s); _fetchNurses(); },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                      color: selected ? const Color(0xFF1A6BB5) : (dark ? kCardDark : Colors.white),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? const Color(0xFF1A6BB5) : (dark ? kBorderDark : Colors.grey.shade300))),
                  child: Text(_serviceLabels[s] ?? s,
                      style: TextStyle(
                          color: selected ? Colors.white : (dark ? kSubDark : Colors.grey),
                          fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                ),
              );
            },
          ),
        ),
        if (!_isLoading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(children: [
              Text('${_nurses.length} nurse${_nurses.length != 1 ? 's' : ''} found',
                  style: TextStyle(fontSize: 12, color: dark ? kSubDark : Colors.grey, fontWeight: FontWeight.w600)),
            ]),
          ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _nurses.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.person_search, size: 64, color: dark ? kSubDark : Colors.grey),
            const SizedBox(height: 16),
            Text('No nurses found', style: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 16)),
            if (_searchCtrl.text.isNotEmpty)
              Text('Try a different name or location',
                  style: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 13)),
          ]))
              : RefreshIndicator(
            onRefresh: _fetchNurses,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _nurses.length,
              itemBuilder: (_, i) {
                final nurse = _nurses[i];
                final avgRating = (nurse['avg_rating'] ?? 0).toDouble();
                final totalReviews = nurse['total_reviews'] ?? 0;
                final photo = _buildPhotoUrl(nurse['profile_photo']);

                return GestureDetector(
                  onTap: () => _showNurseProfile(nurse),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        color: dark ? kCardDark : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(dark ? 0.25 : 0.05), blurRadius: 8)]),
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        _nurseAvatar(photo, nurse['name'] ?? 'N', 26),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(nurse['name'] ?? '',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15,
                                  color: dark ? kTextDark : const Color(0xFF1A2340))),
                          if (nurse['service'] != null)
                            Text(_serviceLabels[nurse['service']] ?? nurse['service'],
                                style: const TextStyle(fontSize: 12, color: Color(0xFF1A6BB5))),
                          if (nurse['location'] != null && nurse['location'].toString().isNotEmpty)
                            Row(children: [
                              Icon(Icons.location_on_outlined, size: 12, color: dark ? kSubDark : Colors.grey),
                              const SizedBox(width: 2),
                              Text(nurse['location'],
                                  style: TextStyle(fontSize: 12, color: dark ? kSubDark : Colors.grey)),
                            ]),
                          const SizedBox(height: 4),
                          // Stars + count
                          Row(children: [
                            ...List.generate(5, (j) => Icon(
                                j < avgRating.round() ? Icons.star : Icons.star_border,
                                color: const Color(0xFFFFC107), size: 14)),
                            const SizedBox(width: 4),
                            Text(
                                avgRating > 0
                                    ? '${avgRating.toStringAsFixed(1)} ($totalReviews review${totalReviews != 1 ? 's' : ''})'
                                    : 'No reviews yet',
                                style: TextStyle(fontSize: 11, color: dark ? kSubDark : Colors.grey)),
                          ]),
                        ])),
                        Column(children: [
                          Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Text('Available',
                                  style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600))),
                          const SizedBox(height: 4),
                          Icon(Icons.arrow_forward_ios, size: 12, color: dark ? kSubDark : Colors.grey),
                        ]),
                      ]),
                      const SizedBox(height: 12),
                      // ── CHAT + BOOK BUTTONS ─────────────────────
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                userData: widget.userData,
                                otherUserId: nurse['id'],
                                otherUserName: nurse['name'] ?? 'Nurse',
                                otherUserRole: 'Nurse',
                                otherUserPhoto: photo.isNotEmpty ? photo : null,
                              ),
                            )),
                            icon: const Icon(Icons.chat_rounded, size: 15),
                            label: const Text('Chat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0F9B8E),
                              side: const BorderSide(color: Color(0xFF0F9B8E)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showBookDialog(nurse),
                            icon: const Icon(Icons.calendar_month_rounded, size: 15),
                            label: const Text('Book Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A6BB5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ]),
                    ]),
                  ),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}