import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../main.dart';
import 'home_screen.dart' show isDark, bgColor, kCardDark, kTextDark, kSubDark, kBorderDark, kBorder;

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const ProfileScreen({super.key, required this.userData});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic> _profile = {};
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  double get _fontSize => fontSizeNotifier.value * 14.0;

  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _bioCtrl     = TextEditingController();
  final _locationCtrl= TextEditingController();

  @override
  void initState() { super.initState(); _fetchProfile(); }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _addressCtrl.dispose();
    _bioCtrl.dispose(); _locationCtrl.dispose(); super.dispose();
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    try {
      final r = await http.get(Uri.parse(
          '${ApiService.baseUrl}/profile_api.php?action=get_profile&user_id=${widget.userData['user_id']}'))
          .timeout(const Duration(seconds: 15));
      final d = jsonDecode(r.body);
      if (d['status'] == 'success') {
        setState(() {
          _profile = d['user'];
          _nameCtrl.text    = _profile['name'] ?? '';
          _phoneCtrl.text   = _profile['phone'] ?? '';
          _addressCtrl.text = _profile['address'] ?? '';
          _bioCtrl.text     = _profile['bio'] ?? '';
          _locationCtrl.text= _profile['location'] ?? '';
        });
        final photoUrl = d['user']['photo_url'] ?? '';
        if (photoUrl.isNotEmpty) profilePhotoNotifier.value = photoUrl;
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final r = await http.post(
        Uri.parse('${ApiService.baseUrl}/profile_api.php?action=update_profile'),
        body: {
          'user_id': '${widget.userData['user_id']}',
          'name': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
          'bio': _bioCtrl.text.trim(),
          'location': _locationCtrl.text.trim(),
        },
      ).timeout(const Duration(seconds: 15));
      final d = jsonDecode(r.body);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(d['message'] ?? 'Updated'),
        backgroundColor: d['status'] == 'success' ? Colors.green : Colors.red,
      ));
      if (d['status'] == 'success') {
        setState(() => _isEditing = false);
        _fetchProfile();
      }
    } catch (_) {}
    setState(() => _isSaving = false);
  }

  // ── PICK PHOTO → SHOW CROP DIALOG → UPLOAD ───────────────────────────────
  Future<void> _uploadPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final pickedFile = File(result.files.single.path!);

    // Show built-in crop dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CropDialog(imageFile: pickedFile),
    );

    // If user tapped "Upload" (confirmed = true), upload original file
    // (crop is visual preview only — actual server-side crop happens via upload)
    if (confirmed != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploading photo...'), duration: Duration(seconds: 2)),
    );

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/upload_photo.php'),
      );
      request.fields['user_id'] = '${widget.userData['user_id']}';
      request.files.add(await http.MultipartFile.fromPath('photo', pickedFile.path));
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);

      if (response.body.trim().startsWith('<')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Server error - check upload_photo.php'), backgroundColor: Colors.red),
        );
        return;
      }

      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (data['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo uploaded! ✅'), backgroundColor: Colors.green),
        );
        _fetchProfile();
        profilePhotoNotifier.value = data['photo_url'] ?? '';
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Upload failed'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ── VIEW FULL PHOTO ───────────────────────────────────────────────────────
  void _viewPhoto(String photoUrl) {
    if (photoUrl.isEmpty) return;
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                photoUrl,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const Center(child: CircularProgressIndicator(color: Colors.white)),
                errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image, color: Colors.white, size: 64),
              ),
            ),
            Positioned(
              top: 0, right: 0,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePassword() {
    final oldCtrl     = TextEditingController();
    final newCtrl     = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool showOld = false, showNew = false, showConfirm = false;
    final dark = isDark(context);

    InputDecoration pwDeco(String label, bool show, VoidCallback toggle) => InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: dark ? kSubDark : Colors.grey),
      prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF1A6BB5)),
      suffixIcon: IconButton(
        icon: Icon(show ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            color: const Color(0xFF1A6BB5), size: 22),
        onPressed: toggle,
      ),
      filled: true,
      fillColor: dark ? const Color(0xFF0F1624) : const Color(0xFFF0F5FB),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dark ? kBorderDark : const Color(0xFFE0E6FF))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1A6BB5), width: 1.5)),
    );

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: dark ? kCardDark : Colors.white,
          title: Text('Change Password',
              style: TextStyle(fontWeight: FontWeight.w700,
                  color: dark ? kTextDark : const Color(0xFF1A2340))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: oldCtrl, obscureText: !showOld,
                  style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A2340)),
                  decoration: pwDeco('Current Password', showOld, () => setS(() => showOld = !showOld))),
              const SizedBox(height: 12),
              TextField(controller: newCtrl, obscureText: !showNew,
                  style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A2340)),
                  decoration: pwDeco('New Password', showNew, () => setS(() => showNew = !showNew))),
              const SizedBox(height: 12),
              TextField(controller: confirmCtrl, obscureText: !showConfirm,
                  style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A2340)),
                  decoration: pwDeco('Confirm New Password', showConfirm, () => setS(() => showConfirm = !showConfirm))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (newCtrl.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Min 6 characters'), backgroundColor: Colors.orange));
                  return;
                }
                if (newCtrl.text != confirmCtrl.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.red));
                  return;
                }
                Navigator.pop(context);
                final r = await http.post(
                  Uri.parse('${ApiService.baseUrl}/profile_api.php?action=change_password'),
                  body: {'user_id': '${widget.userData['user_id']}',
                    'old_password': oldCtrl.text, 'new_password': newCtrl.text},
                );
                final d = jsonDecode(r.body);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(d['message'] ?? 'Done'),
                  backgroundColor: d['status'] == 'success' ? Colors.green : Colors.red,
                ));
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A6BB5), foregroundColor: Colors.white),
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Text Size'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Preview text size', style: TextStyle(fontSize: fontSizeNotifier.value * 14)),
              const SizedBox(height: 4),
              const Text('This affects the entire app', style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 16),
              Row(children: [
                const Text('A', style: TextStyle(fontSize: 12)),
                Expanded(child: Slider(
                    value: fontSizeNotifier.value, min: 0.8, max: 1.4, divisions: 6,
                    activeColor: const Color(0xFF1A6BB5),
                    onChanged: (v) async {
                      setS(() {}); setState(() => fontSizeNotifier.value = v);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setDouble('bawlpu_font_scale', v);
                    })),
                const Text('A', style: TextStyle(fontSize: 20)),
              ]),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  {'label': 'Small', 'value': 0.85}, {'label': 'Normal', 'value': 1.0},
                  {'label': 'Large', 'value': 1.15}, {'label': 'XLarge', 'value': 1.3},
                ].map((item) => GestureDetector(
                  onTap: () async {
                    final v = item['value'] as double;
                    setS(() {}); setState(() => fontSizeNotifier.value = v);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setDouble('bawlpu_font_scale', v);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: fontSizeNotifier.value == item['value'] ? const Color(0xFF1A6BB5) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(item['label'] as String,
                        style: TextStyle(
                            color: fontSizeNotifier.value == item['value'] ? Colors.white : Colors.grey,
                            fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                )).toList(),
              ),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    final name = _profile['name'] ?? widget.userData['name'] ?? 'User';
    final role = _profile['role'] ?? widget.userData['role'] ?? 'Client';
    final photoUrl = _profile['photo_url'] ?? '';

    return Scaffold(
      backgroundColor: bgColor(context),
      appBar: AppBar(
        backgroundColor: dark ? kCardDark : Colors.white,
        elevation: 0,
        title: Text('My Profile',
            style: TextStyle(fontWeight: FontWeight.w800,
                color: dark ? kTextDark : const Color(0xFF1A2340), fontSize: _fontSize + 4)),
        iconTheme: IconThemeData(color: dark ? kTextDark : const Color(0xFF1A2340)),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close_rounded : Icons.edit_rounded,
                color: const Color(0xFF1A6BB5)),
            onPressed: () => setState(() => _isEditing = !_isEditing),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(child: Column(children: [
        // ── HEADER ─────────────────────────────────────────────
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1A6BB5), Color(0xFF3B9EE8)]),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28))),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(children: [
            Stack(children: [
              // Tap = view full photo
              GestureDetector(
                onTap: photoUrl.isNotEmpty ? () => _viewPhoto(photoUrl) : _uploadPhoto,
                onLongPress: _uploadPhoto,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white.withOpacity(0.25),
                  backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl.isEmpty
                      ? Text(name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 36))
                      : null,
                ),
              ),
              // Camera button
              Positioned(
                bottom: 0, right: 0,
                child: GestureDetector(
                  onTap: _uploadPhoto,
                  child: Container(
                    width: 32, height: 32,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt_rounded, size: 17, color: Color(0xFF1A6BB5)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Text(name,
                style: TextStyle(color: Colors.white, fontSize: _fontSize + 4, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(role, style: TextStyle(color: Colors.white, fontSize: _fontSize - 2)),
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.touch_app_rounded, color: Colors.white60, size: 13),
              const SizedBox(width: 4),
              Text(
                  photoUrl.isNotEmpty ? 'Tap to view  •  Hold or 📷 to change' : 'Tap 📷 to upload photo',
                  style: TextStyle(color: Colors.white70, fontSize: _fontSize - 3)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),

        // ── INFO CARD ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
                color: dark ? kCardDark : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(dark ? 0.25 : 0.05), blurRadius: 10)]),
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Basic Information',
                  style: TextStyle(fontSize: _fontSize + 2, fontWeight: FontWeight.w800,
                      color: dark ? kTextDark : const Color(0xFF1A2340))),
              const SizedBox(height: 16),
              _buildField('Full Name', _nameCtrl, Icons.person_outline, dark),
              const SizedBox(height: 12),
              _buildField('Phone Number', _phoneCtrl, Icons.phone_outlined, dark, keyboard: TextInputType.phone),
              const SizedBox(height: 12),
              _buildField('Address', _addressCtrl, Icons.location_on_outlined, dark),
              if (role == 'Nurse') ...[
                const SizedBox(height: 12),
                _buildField('Location/City', _locationCtrl, Icons.map_outlined, dark),
                const SizedBox(height: 12),
                _buildField('Bio', _bioCtrl, Icons.info_outline, dark, maxLines: 3),
              ],
              if (_isEditing) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveProfile,
                    icon: _isSaving
                        ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_rounded),
                    label: Text(_isSaving ? 'Saving...' : 'Save Changes',
                        style: TextStyle(fontSize: _fontSize)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A6BB5), foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0),
                  ),
                ),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 12),

        // ── ACTIONS ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            _actionBtn(Icons.text_fields_rounded, 'Text Size', const Color(0xFF7B3FC4), dark, _showFontSizeDialog),
            const SizedBox(height: 8),
            _actionBtn(Icons.lock_outline_rounded, 'Change Password', const Color(0xFF1A6BB5), dark, _showChangePassword),
            const SizedBox(height: 8),
            _actionBtn(Icons.logout_rounded, 'Logout', Colors.redAccent, dark,
                    () => Navigator.pushReplacementNamed(context, '/login'), isRed: true),
          ]),
        ),
        const SizedBox(height: 20),
      ])),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon, bool dark,
      {TextInputType keyboard = TextInputType.text, int maxLines = 1}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: _fontSize - 1,
          color: dark ? kSubDark : Colors.grey, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      TextFormField(
        controller: ctrl, enabled: _isEditing, keyboardType: keyboard, maxLines: maxLines,
        style: TextStyle(fontSize: _fontSize, color: dark ? kTextDark : const Color(0xFF1A2340)),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: dark ? kSubDark : Colors.grey, size: 18),
          filled: true,
          fillColor: _isEditing
              ? (dark ? const Color(0xFF0F1624) : const Color(0xFFF0F5FB))
              : (dark ? const Color(0xFF0F1624) : Colors.grey.shade50),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: dark ? kBorderDark : const Color(0xFFE0E6FF))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1A6BB5), width: 1.5)),
          disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    ]);
  }

  Widget _actionBtn(IconData icon, String label, Color color, bool dark, VoidCallback onTap, {bool isRed = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isRed ? Colors.red.withOpacity(dark ? 0.15 : 0.05) : (dark ? kCardDark : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isRed ? Colors.red.withOpacity(0.3) : (dark ? kBorderDark : const Color(0xFFE0E6FF))),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(dark ? 0.15 : 0.03), blurRadius: 6)],
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20), const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: _fontSize, fontWeight: FontWeight.w600,
              color: isRed ? Colors.red : (dark ? kTextDark : const Color(0xFF1A2340)))),
          const Spacer(),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BUILT-IN CROP DIALOG — no external package needed
// ═══════════════════════════════════════════════════════════════════════════════
class _CropDialog extends StatefulWidget {
  final File imageFile;
  const _CropDialog({required this.imageFile});
  @override
  State<_CropDialog> createState() => _CropDialogState();
}

class _CropDialogState extends State<_CropDialog> {
  final TransformationController _transformCtrl = TransformationController();
  bool _isSquare = true;

  @override
  void dispose() { _transformCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(0),
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Column(children: [
          // ── TOP BAR ─────────────────────────────────────────────────
          Container(
            color: Colors.black,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
            child: Row(children: [
              GestureDetector(
                  onTap: () => Navigator.pop(context, false),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 26)),
              const SizedBox(width: 12),
              const Text('Crop Photo',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _isSquare = !_isSquare),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: _isSquare ? const Color(0xFF1A6BB5) : Colors.white24,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Icon(_isSquare ? Icons.crop_square_rounded : Icons.crop_free_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(_isSquare ? 'Square' : 'Free',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ),

          // ── HINT ────────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Pinch to zoom • Drag to position',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),

          // ── IMAGE + CROP OVERLAY ─────────────────────────────────────
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                final dim = min(w, h) * 0.82;
                final cropRect = Rect.fromCenter(
                  center: Offset(w / 2, h / 2),
                  width: dim,
                  height: _isSquare ? dim : dim * 1.25,
                );
                return Stack(fit: StackFit.expand, children: [
                  // ── Zoomable image (background) ─────────────────────
                  InteractiveViewer(
                    transformationController: _transformCtrl,
                    minScale: 0.5,
                    maxScale: 5.0,
                    boundaryMargin: const EdgeInsets.all(80),
                    child: Center(
                      child: Image.file(widget.imageFile, fit: BoxFit.contain),
                    ),
                  ),
                  // ── Overlay with transparent hole ────────────────────
                  IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size(w, h),
                        painter: _CropOverlayPainter(
                          cropRect: cropRect,
                          isSquare: _isSquare,
                        ),
                      ),
                    ),
                  ),
                ]);
              },
            ),
          ),

          // ── BOTTOM ACTIONS ───────────────────────────────────────────
          Container(
            color: Colors.black,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A6BB5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Upload', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── CROP OVERLAY PAINTER ──────────────────────────────────────────────────────
class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;
  final bool isSquare;
  _CropOverlayPainter({required this.cropRect, required this.isSquare});

  @override
  void paint(Canvas canvas, Size size) {
    // saveLayer is REQUIRED so BlendMode.clear punches a real transparent hole
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // 1. Draw dark overlay over everything
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withOpacity(0.6),
    );

    // 2. Punch transparent hole for crop area
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    if (isSquare) {
      canvas.drawRect(cropRect, clearPaint);
    } else {
      canvas.drawRRect(
          RRect.fromRectAndRadius(cropRect, const Radius.circular(12)), clearPaint);
    }

    // 3. Restore layer (hole now reveals image underneath)
    canvas.restore();

    // 4. Draw border on top
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    if (isSquare) {
      canvas.drawRect(cropRect, borderPaint);
      _drawCorners(canvas, cropRect);
    } else {
      canvas.drawRRect(
          RRect.fromRectAndRadius(cropRect, const Radius.circular(12)), borderPaint);
    }

    // 5. Draw grid lines inside crop area
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 0.8;
    for (int i = 1; i <= 2; i++) {
      final x = cropRect.left + (cropRect.width / 3) * i;
      final y = cropRect.top + (cropRect.height / 3) * i;
      canvas.drawLine(Offset(x, cropRect.top), Offset(x, cropRect.bottom), gridPaint);
      canvas.drawLine(Offset(cropRect.left, y), Offset(cropRect.right, y), gridPaint);
    }
  }

  void _drawCorners(Canvas canvas, Rect r) {
    final p = Paint()
      ..color = const Color(0xFF1A6BB5)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    const len = 22.0;
    canvas.drawLine(r.topLeft, r.topLeft + const Offset(len, 0), p);
    canvas.drawLine(r.topLeft, r.topLeft + const Offset(0, len), p);
    canvas.drawLine(r.topRight, r.topRight + const Offset(-len, 0), p);
    canvas.drawLine(r.topRight, r.topRight + const Offset(0, len), p);
    canvas.drawLine(r.bottomLeft, r.bottomLeft + const Offset(len, 0), p);
    canvas.drawLine(r.bottomLeft, r.bottomLeft + const Offset(0, -len), p);
    canvas.drawLine(r.bottomRight, r.bottomRight + const Offset(-len, 0), p);
    canvas.drawLine(r.bottomRight, r.bottomRight + const Offset(0, -len), p);
  }

  @override
  bool shouldRepaint(_CropOverlayPainter old) =>
      old.isSquare != isSquare || old.cropRect != cropRect;
}