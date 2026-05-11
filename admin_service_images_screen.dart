import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'home_screen.dart' show isDark, bgColor, kCardDark, kTextDark, kSubDark, kBorderDark;

const _kPrimary = Color(0xFF1A6BB5);
const _kBg      = Color(0xFFF0F5FB);
const _kText    = Color(0xFF1A2340);
const _kSub     = Color(0xFF6B7A9B);

class AdminServiceImagesScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const AdminServiceImagesScreen({super.key, required this.userData});
  @override
  State<AdminServiceImagesScreen> createState() => _AdminServiceImagesScreenState();
}

class _AdminServiceImagesScreenState extends State<AdminServiceImagesScreen> {
  List<dynamic> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    setState(() => _isLoading = true);
    try {
      final r = await http.get(Uri.parse('${ApiService.baseUrl}/service_images_api.php?action=get_all'))
          .timeout(const Duration(seconds: 15));
      final d = jsonDecode(r.body);
      if (d['status'] == 'success') setState(() => _services = d['services']);
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _uploadImage(String slug, String name, {int serviceId = 0}) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    final file = File(result.files.single.path!);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading...'), duration: Duration(seconds: 2)));

    try {
      final request = http.MultipartRequest(
          'POST', Uri.parse('${ApiService.baseUrl}/service_images_api.php?action=upload_image'));
      request.fields['service_slug'] = slug;
      request.fields['service_id']   = '$serviceId';
      request.files.add(await http.MultipartFile.fromPath('image', file.path));
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      if (!mounted) return;
      if (response.body.trim().startsWith('<')) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Server error'), backgroundColor: Colors.red));
        return;
      }
      final data = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(data['message'] ?? 'Done'),
          backgroundColor: data['status'] == 'success' ? Colors.green : Colors.red));
      if (data['status'] == 'success') _fetchServices();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  void _editDescription(Map<String, dynamic> service) {
    final ctrl = TextEditingController(text: service['description'] ?? '');
    final dark = isDark(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: dark ? kCardDark : Colors.white,
        title: Text('Edit ${service['service_name']} Description',
            style: TextStyle(color: dark ? kTextDark : _kText)),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          style: TextStyle(color: dark ? kTextDark : _kText),
          decoration: InputDecoration(
            hintText: 'Enter service description...',
            hintStyle: TextStyle(color: dark ? kSubDark : _kSub),
            filled: true,
            fillColor: dark ? const Color(0xFF0F1624) : _kBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: dark ? kBorderDark : const Color(0xFFE0E6FF))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await http.post(
                  Uri.parse('${ApiService.baseUrl}/service_images_api.php?action=update_description'),
                  body: {'service_slug': (service['slug'] ?? service['service_slug'] ?? '').toString(), 'description': ctrl.text.trim()});
              _fetchServices();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
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
        title: Text('Service Images',
            style: TextStyle(fontWeight: FontWeight.w700, color: dark ? kTextDark : _kText)),
        iconTheme: IconThemeData(color: dark ? kTextDark : _kText),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: _kPrimary), onPressed: _fetchServices)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _services.length,
        itemBuilder: (_, i) {
          final s = _services[i];
          final images = s['images'] as List? ?? [];
          final imageUrl = images.isNotEmpty
              ? (images.first['image_url'] ?? images.first['image_path'] ?? '').toString()
              : (s['image_url'] ?? '').toString();
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: dark ? kCardDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(dark ? 0.25 : 0.05), blurRadius: 10)],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _uploadImage(s['slug']?.toString() ?? s['service_slug']?.toString() ?? '', s['name']?.toString() ?? s['service_name']?.toString() ?? '', serviceId: int.tryParse(s['id']?.toString() ?? '0') ?? 0),
                  child: Stack(
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: dark ? const Color(0xFF0F1624) : _kBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: dark ? kBorderDark : const Color(0xFFE0E6FF), width: 2),
                        ),
                        child: imageUrl.isNotEmpty
                            ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(imageUrl, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(Icons.broken_image,
                                    color: dark ? kSubDark : _kSub)))
                            : Icon(Icons.add_photo_alternate_rounded,
                            color: dark ? kSubDark : _kSub, size: 32),
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: _kPrimary, shape: BoxShape.circle),
                          child: const Icon(Icons.edit_rounded, color: Colors.white, size: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['name']?.toString() ?? s['service_name']?.toString() ?? '',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15,
                              color: dark ? kTextDark : _kText)),
                      const SizedBox(height: 4),
                      Text(
                        s['description'] != null && s['description'].toString().isNotEmpty
                            ? s['description']
                            : 'No description yet',
                        style: TextStyle(fontSize: 12,
                            color: s['description'] != null && s['description'].toString().isNotEmpty
                                ? (dark ? kSubDark : _kSub)
                                : Colors.grey.shade400),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _uploadImage(s['slug']?.toString() ?? s['service_slug']?.toString() ?? '', s['name']?.toString() ?? s['service_name']?.toString() ?? '', serviceId: int.tryParse(s['id']?.toString() ?? '0') ?? 0),
                            icon: const Icon(Icons.upload_rounded, size: 14),
                            label: const Text('Image', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _kPrimary,
                              side: const BorderSide(color: _kPrimary),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _editDescription(s),
                            icon: const Icon(Icons.edit_note_rounded, size: 14),
                            label: const Text('Description', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}