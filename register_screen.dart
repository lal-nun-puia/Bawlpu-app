import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

const kPrimary = Color(0xFF1A6BB5);
const kAccent  = Color(0xFF3B9EE8);
const kBg      = Color(0xFFF0F5FB);
const kText    = Color(0xFF1A2340);
const kSub     = Color(0xFF6B7A9B);

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey       = GlobalKey<FormState>();
  final _nameCtrl      = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _passwordCtrl  = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _addressCtrl   = TextEditingController();
  final _skillsCtrl    = TextEditingController();
  final _salaryCtrl    = TextEditingController();
  final _experienceCtrl= TextEditingController();
  final _locationCtrl  = TextEditingController();
  final _bioCtrl       = TextEditingController();

  // Multi-select services
  final Set<String> _selectedServices = {};
  final List<Map<String,String>> _serviceOptions = [
    {'slug':'ElderlyCare',  'label':'Elderly Care'},
    {'slug':'PatientCare',  'label':'Patient Care'},
    {'slug':'Babysitting',  'label':'Babysitting'},
    {'slug':'LabTesting',   'label':'Lab Testing'},
  ];

  String _selectedRole = 'Client';
  bool _showPassword   = false;
  bool _isLoading      = false;
  String? _message;
  bool _isError        = false;
  File? _certificateFile;
  String? _certificateFileName;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  bool get _isProfessional => _selectedRole == 'Nurse' || _selectedRole == 'LabTechnician';

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
    // Auto-lowercase email
    _emailCtrl.addListener(() {
      final lower = _emailCtrl.text.toLowerCase();
      if (_emailCtrl.text != lower) {
        _emailCtrl.value = _emailCtrl.value.copyWith(
          text: lower,
          selection: TextSelection.collapsed(offset: lower.length),
        );
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _passwordCtrl.dispose();
    _phoneCtrl.dispose(); _addressCtrl.dispose(); _skillsCtrl.dispose();
    _salaryCtrl.dispose(); _experienceCtrl.dispose(); _locationCtrl.dispose();
    _bioCtrl.dispose(); _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCertificate() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf','jpg','jpeg','png']);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _certificateFile = File(result.files.single.path!);
        _certificateFileName = result.files.single.name;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isProfessional && _selectedServices.isEmpty) {
      setState(() { _message = 'Please select at least one service'; _isError = true; });
      return;
    }
    if (_isProfessional && _certificateFile == null) {
      setState(() { _message = 'Please upload your certificate'; _isError = true; });
      return;
    }
    setState(() { _isLoading = true; _message = null; });

    try {
      Map<String, dynamic> result;
      final serviceString = _selectedServices.join(',');
      if (_selectedRole == 'Client') {
        result = await ApiService.registerClient(
          name: _nameCtrl.text.trim(), email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text, phone: _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
        );
      } else {
        result = await ApiService.registerNurse(
          name: _nameCtrl.text.trim(), email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text, phone: _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim(), skills: _skillsCtrl.text.trim(),
          service: serviceString, salary: _salaryCtrl.text.trim(),
          experience: _experienceCtrl.text.trim(), location: _locationCtrl.text.trim(),
          bio: _bioCtrl.text.trim(), role: _selectedRole,
          certificate: _certificateFile,
        );
      }
      setState(() { _message = result['message']; _isError = result['status'] != 'success'; });
      if (result['status'] == 'success') {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pushReplacementNamed(context, '/login');
        });
      }
    } catch (e) {
      setState(() { _message = 'Error: $e'; _isError = true; });
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // ── LOGO ─────────────────────────────────────────────────
                    Image.asset(
                      'assets/bawlpu_icon.png',
                      width: 90,
                      height: 90,
                    ),
                    const SizedBox(height: 4),
                    const Text('Create your account', style: TextStyle(fontSize: 13, color: kSub)),
                    const SizedBox(height: 20),

                    // Role selector
                    _card('Register as', Icons.badge_outlined, [
                      Row(
                        children: ['Client', 'Nurse', 'LabTechnician'].map((role) {
                          final selected = _selectedRole == role;
                          final label = role == 'LabTechnician' ? 'Lab Tech' : role;
                          final icon = role == 'Client' ? Icons.person_rounded
                              : role == 'Nurse' ? Icons.medical_services_rounded
                              : Icons.biotech_rounded;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _selectedRole = role;
                                _selectedServices.clear();
                              }),
                              child: Container(
                                margin: EdgeInsets.only(right: role != 'LabTechnician' ? 6 : 0),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: selected ? kPrimary : kBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: selected ? kPrimary : Colors.grey.shade300),
                                ),
                                child: Column(
                                  children: [
                                    Icon(icon, color: selected ? Colors.white : kSub, size: 18),
                                    const SizedBox(height: 4),
                                    Text(label, style: TextStyle(
                                        color: selected ? Colors.white : kSub,
                                        fontWeight: FontWeight.w700, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ]),
                    const SizedBox(height: 14),

                    // Basic info
                    _card('Basic Information', Icons.person_outline, [
                      _field(_nameCtrl, 'Full Name', Icons.person_outline,
                          validator: (v) => v!.isEmpty ? 'Required' : null),
                      _field(_emailCtrl, 'Email (@gmail.com)', Icons.email_outlined,
                          keyboard: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (v != v.toLowerCase()) return 'Email must be in lowercase';
                            if (!RegExp(r'^[^@]+@gmail\.com$').hasMatch(v)) return 'Only @gmail.com allowed';
                            return null;
                          }),
                      _field(_passwordCtrl, 'Password', Icons.lock_outlined,
                          isPassword: true,
                          validator: (v) {
                            if (v == null || v.length < 6) return 'Min 6 characters';
                            if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=]').hasMatch(v)) {
                              return 'Must contain at least 1 special character (!@#\$%...)';
                            }
                            return null;
                          }),
                      _field(_phoneCtrl, '10-digit Phone Number', Icons.phone_outlined,
                          keyboard: TextInputType.number,
                          validator: (v) {
                            if (v!.isEmpty) return 'Required';
                            if (!RegExp(r'^\d{10}$').hasMatch(v)) return 'Must be 10 digits';
                            return null;
                          }),
                      _field(_addressCtrl, 'Address', Icons.location_on_outlined,
                          validator: (v) => v!.isEmpty ? 'Required' : null),
                    ]),

                    // Professional fields
                    if (_isProfessional) ...[
                      const SizedBox(height: 14),
                      _card('Professional Details', Icons.medical_services_outlined, [
                        // Multi-select services
                        const Text('Services Offered *',
                            style: TextStyle(fontSize: 12, color: kSub, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: _serviceOptions.map((s) {
                            final selected = _selectedServices.contains(s['slug']);
                            return GestureDetector(
                              onTap: () => setState(() {
                                if (selected) _selectedServices.remove(s['slug']);
                                else _selectedServices.add(s['slug']!);
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selected ? kPrimary : kBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: selected ? kPrimary : Colors.grey.shade300),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (selected) const Icon(Icons.check, color: Colors.white, size: 14),
                                    if (selected) const SizedBox(width: 4),
                                    Text(s['label']!,
                                        style: TextStyle(
                                            color: selected ? Colors.white : kSub,
                                            fontWeight: FontWeight.w600, fontSize: 13)),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        _field(_skillsCtrl, 'Skills & Specializations', Icons.star_outline,
                            validator: (v) => v!.isEmpty ? 'Required' : null),
                        _field(_salaryCtrl, 'Expected Salary (₹)', Icons.currency_rupee,
                            keyboard: TextInputType.number,
                            validator: (v) => v!.isEmpty ? 'Required' : null),
                        _field(_experienceCtrl, 'Years of Experience', Icons.work_outline,
                            keyboard: TextInputType.text,
                            validator: (v) => v!.isEmpty ? 'Required' : null),
                        _field(_locationCtrl, 'City / Location', Icons.map_outlined,
                            validator: (v) => v!.isEmpty ? 'Required' : null),
                        _field(_bioCtrl, 'Bio / About Me', Icons.info_outline,
                            maxLines: 3,
                            validator: (v) => v!.isEmpty ? 'Required' : null),
                      ]),
                      const SizedBox(height: 14),

                      // Certificate upload
                      _card('Certificate / License', Icons.upload_file_outlined, [
                        const Text('Required for nurse/health worker registration',
                            style: TextStyle(color: kSub, fontSize: 12)),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: _pickCertificate,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _certificateFile != null ? kPrimary.withOpacity(0.05) : kBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _certificateFile != null ? kPrimary : Colors.grey.shade300,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(_certificateFile != null ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                                    color: _certificateFile != null ? kPrimary : kSub, size: 28),
                                const SizedBox(height: 6),
                                Text(
                                  _certificateFileName ?? 'Tap to upload PDF or Image',
                                  style: TextStyle(
                                      color: _certificateFile != null ? kPrimary : kSub,
                                      fontWeight: FontWeight.w600, fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ]),
                    ],

                    const SizedBox(height: 14),

                    // Message
                    if (_message != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isError ? const Color(0xFFFFEEEE) : const Color(0xFFEEFFEE),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _isError ? Colors.red.shade200 : Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(_isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                                color: _isError ? Colors.red : Colors.green, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_message!,
                                style: TextStyle(color: _isError ? Colors.red.shade700 : Colors.green.shade700, fontSize: 13))),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Submit
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary, foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : Text(
                            _isProfessional ? 'Register as ${_selectedRole == 'LabTechnician' ? 'Lab Technician' : _selectedRole}' : 'Create Account',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Already have an account? ', style: TextStyle(color: kSub, fontSize: 14)),
                        GestureDetector(
                          onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                          child: const Text('Login', style: TextStyle(color: kPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: kPrimary, size: 18),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kText)),
          ]),
          const SizedBox(height: 14),
          ...children.map((w) => Padding(padding: const EdgeInsets.only(bottom: 10), child: w)),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, IconData icon,
      {TextInputType keyboard = TextInputType.text, bool isPassword = false,
        int maxLines = 1, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      obscureText: isPassword && !_showPassword,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: kText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kSub, fontSize: 13),
        prefixIcon: Icon(icon, color: kSub, size: 18),
        suffixIcon: isPassword ? IconButton(
          icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: kSub, size: 18),
          onPressed: () => setState(() => _showPassword = !_showPassword),
        ) : null,
        filled: true, fillColor: kBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E6FF))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
      ),
    );
  }
}