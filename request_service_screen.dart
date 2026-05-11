import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'home_screen.dart' show isDark, bgColor, kCardDark, kTextDark, kSubDark, kBorderDark, kBorder;

class RequestServiceScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String serviceType;
  final String serviceTitle;
  final int targetNurseId;      // 0 = general request, >0 = direct to specific nurse
  final String targetNurseName; // name shown in UI
  const RequestServiceScreen({
    super.key,
    required this.userData,
    required this.serviceType,
    this.serviceTitle = '',
    this.targetNurseId = 0,
    this.targetNurseName = '',
  });

  @override
  State<RequestServiceScreen> createState() => _RequestServiceScreenState();
}

class _RequestServiceScreenState extends State<RequestServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _patientCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingItems = true;
  String? _message;
  bool _isError = false;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool _itemsExpanded = false;
  List<dynamic> _items = [];
  final Map<int, bool> _selected = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  @override
  void dispose() {
    _patientCtrl.dispose(); _ageCtrl.dispose(); _phoneCtrl.dispose();
    _addressCtrl.dispose(); _notesCtrl.dispose(); _dateCtrl.dispose();
    _timeCtrl.dispose(); _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchItems() async {
    setState(() => _isLoadingItems = true);
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/services_api.php?action=get_items&slug=${widget.serviceType}'),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        setState(() => _items = data['items'] ?? []);
      }
    } catch (_) {}
    setState(() => _isLoadingItems = false);
  }

  double get _total {
    double t = 0;
    for (final item in _items) {
      if (_selected[int.tryParse(item['id'].toString()) ?? 0] == true) {
        t += double.tryParse(item['price'].toString()) ?? 0;
      }
    }
    return t;
  }

  List<dynamic> get _selectedItems =>
      _items.where((item) => _selected[int.tryParse(item['id'].toString()) ?? 0] == true).toList();

  List<dynamic> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;
    return _items.where((item) =>
        item['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: tomorrow,
      firstDate: tomorrow,
      lastDate: DateTime(now.year + 2),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF1A6BB5))),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateCtrl.text = '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF1A6BB5))),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _timeCtrl.text = picked.format(context);
      });
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      setState(() { _message = 'Please select a date'; _isError = true; });
      return;
    }
    if (_selectedTime == null) {
      setState(() { _message = 'Please select a time'; _isError = true; });
      return;
    }
    setState(() { _isLoading = true; _message = null; });

    try {
      final dateStr =
          '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';

      String notesText = _notesCtrl.text.trim();
      if (_selectedItems.isNotEmpty) {
        final itemList = _selectedItems.map((i) =>
        '${i['name']} (₹${double.tryParse(i['price'].toString())?.toStringAsFixed(0) ?? '0'})').join(', ');
        final prefix = 'Selected: $itemList | Total: ₹${_total.toStringAsFixed(0)}';
        notesText = notesText.isEmpty ? prefix : '$prefix\n$notesText';
      }

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/client_requests_api.php?action=post_request'),
        body: {
          'client_id': '${widget.userData['user_id']}',
          'service_type': widget.serviceType,
          'patient_name': _patientCtrl.text.trim(),
          'age': _ageCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
          'notes': notesText,
          'date': dateStr,
          'time': _timeCtrl.text,
          'target_nurse_id': '${widget.targetNurseId}',
        },
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      setState(() {
        _message = data['message'];
        _isError = data['status'] != 'success';
      });

      if (data['status'] == 'success') {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context, true);
        });
      }
    } catch (e) {
      setState(() { _message = 'Connection error: $e'; _isError = true; });
    }
    setState(() => _isLoading = false);
  }

  // Banner widget shown when direct booking
  Widget _directBookingBanner(bool dark) {
    if (widget.targetNurseId == 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFF1A6BB5).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1A6BB5).withOpacity(0.3))),
      child: Row(children: [
        const Icon(Icons.person_pin_rounded, color: Color(0xFF1A6BB5), size: 20),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Direct Booking', style: TextStyle(
              color: Color(0xFF1A6BB5), fontWeight: FontWeight.w700, fontSize: 12)),
          Text('This request will be sent directly to ${widget.targetNurseName}',
              style: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 12)),
        ])),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.serviceTitle.isNotEmpty ? widget.serviceTitle : widget.serviceType;
    final dark = isDark(context);

    return Scaffold(
      backgroundColor: bgColor(context),
      appBar: AppBar(
        backgroundColor: dark ? kCardDark : Colors.white,
        elevation: 1,
        title: Text('Request $title',
            style: TextStyle(fontWeight: FontWeight.w700, color: dark ? kTextDark : const Color(0xFF1A2340))),
        iconTheme: IconThemeData(color: dark ? kTextDark : const Color(0xFF1A2340)),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── PATIENT DETAILS ──────────────────────────
              _sectionCard(
                icon: Icons.person_outline,
                title: 'Patient Details',
                dark: dark,
                children: [
                  _buildLabel('Patient Name *', dark),
                  _buildField(_patientCtrl, 'Full name of patient', Icons.person_outline, dark,
                      validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 12),
                  _buildLabel('Age', dark),
                  _buildField(_ageCtrl, 'Patient age', Icons.cake_outlined, dark,
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  _buildLabel('Phone Number *', dark),
                  _buildField(_phoneCtrl, 'Contact number', Icons.phone_outlined, dark,
                      keyboardType: TextInputType.phone,
                      validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 12),
                  _buildLabel('Address *', dark),
                  _buildField(_addressCtrl, 'Full address', Icons.location_on_outlined, dark,
                      validator: (v) => v!.isEmpty ? 'Required' : null),
                ],
              ),
              const SizedBox(height: 14),

              // ── DATE & TIME ───────────────────────────────
              _sectionCard(
                icon: Icons.calendar_today,
                title: 'Schedule',
                dark: dark,
                children: [
                  _buildLabel('Service Date *', dark),
                  GestureDetector(
                    onTap: _pickDate,
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: _dateCtrl,
                        style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A2340)),
                        decoration: _inputDecoration('Select date (future only)', Icons.calendar_today, dark).copyWith(
                          suffixIcon: const Icon(Icons.calendar_month, color: Color(0xFF1A6BB5)),
                        ),
                        validator: (v) => v!.isEmpty ? 'Please select a date' : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildLabel('Service Time *', dark),
                  GestureDetector(
                    onTap: _pickTime,
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: _timeCtrl,
                        style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A2340)),
                        decoration: _inputDecoration('Select time (AM/PM)', Icons.access_time, dark).copyWith(
                          suffixIcon: const Icon(Icons.schedule, color: Color(0xFF1A6BB5)),
                        ),
                        validator: (v) => v!.isEmpty ? 'Please select a time' : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── SERVICE ITEMS (collapsible, optional) ────
              Container(
                decoration: BoxDecoration(
                  color: dark ? kCardDark : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(dark ? 0.25 : 0.05), blurRadius: 8)],
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _itemsExpanded = !_itemsExpanded),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: dark ? kCardDark : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.checklist, color: Color(0xFF1A6BB5), size: 18),
                            const SizedBox(width: 8),
                            Text('Select Services',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                                    color: dark ? kTextDark : const Color(0xFF1A2340))),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: dark ? const Color(0xFF0F1624) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('Optional',
                                  style: TextStyle(fontSize: 11, color: dark ? kSubDark : Colors.grey)),
                            ),
                            const Spacer(),
                            if (_selectedItems.isNotEmpty)
                              Text('₹${_total.toStringAsFixed(0)}',
                                  style: const TextStyle(color: Color(0xFF1A6BB5), fontWeight: FontWeight.w800, fontSize: 14)),
                            const SizedBox(width: 6),
                            Icon(
                              _itemsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              color: const Color(0xFF1A6BB5),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_itemsExpanded) ...[
                      Divider(height: 1, color: dark ? kBorderDark : Colors.grey.shade200),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchCtrl,
                              style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A2340)),
                              decoration: InputDecoration(
                                hintText: 'Search items...',
                                hintStyle: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 13),
                                prefixIcon: Icon(Icons.search, color: dark ? kSubDark : Colors.grey, size: 18),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                  icon: Icon(Icons.clear, size: 16, color: dark ? kSubDark : Colors.grey),
                                  onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
                                )
                                    : null,
                                filled: true,
                                fillColor: dark ? const Color(0xFF0F1624) : const Color(0xFFF0F5FB),
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: dark ? kBorderDark : Colors.transparent)),
                              ),
                              onChanged: (v) => setState(() => _searchQuery = v),
                            ),
                            const SizedBox(height: 8),
                            _isLoadingItems
                                ? const Center(child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator()))
                                : _items.isEmpty
                                ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text('No items for this service.',
                                    style: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 12)))
                                : Column(
                              children: _filteredItems.map((item) {
                                final isChecked = _selected[item['id']] == true;
                                final price = double.tryParse(item['price'].toString()) ?? 0;
                                return GestureDetector(
                                  onTap: () => setState(() => _selected[item['id']] = !isChecked),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 5),
                                    decoration: BoxDecoration(
                                      color: isChecked
                                          ? const Color(0xFF1A6BB5).withOpacity(0.06)
                                          : (dark ? const Color(0xFF0F1624) : const Color(0xFFF8F9FF)),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isChecked ? const Color(0xFF1A6BB5) : (dark ? kBorderDark : Colors.grey.shade200),
                                        width: isChecked ? 1.5 : 1,
                                      ),
                                    ),
                                    child: ListTile(
                                      dense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                      leading: Checkbox(
                                        value: isChecked,
                                        onChanged: (_) => setState(() => _selected[item['id']] = !isChecked),
                                        activeColor: const Color(0xFF1A6BB5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      title: Text(item['name'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                                            color: isChecked ? const Color(0xFF1A6BB5) : (dark ? kTextDark : const Color(0xFF1A2340)),
                                          )),
                                      trailing: Text(
                                        price > 0 ? '₹${price.toStringAsFixed(0)}' : 'Free',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isChecked ? const Color(0xFF1A6BB5) : (dark ? kSubDark : Colors.grey),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            if (_selectedItems.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A6BB5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Text('${_selectedItems.length} item${_selectedItems.length != 1 ? 's' : ''} selected',
                                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                    const Spacer(),
                                    Text('Total: ₹${_total.toStringAsFixed(0)}',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── ADDITIONAL NOTES ──────────────────────────
              _sectionCard(
                icon: Icons.note_outlined,
                title: 'Additional Notes',
                dark: dark,
                children: [
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A2340)),
                    decoration: _inputDecoration('Any specific requirements or conditions...', Icons.note_outlined, dark),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── MESSAGE ───────────────────────────────────
              if (_message != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: _isError ? const Color(0xFFFFEEEE) : const Color(0xFFEEFFEE),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _isError ? Colors.red.shade200 : Colors.green.shade200),
                  ),
                  child: Text(_message!,
                      style: TextStyle(color: _isError ? Colors.red.shade700 : Colors.green.shade700)),
                ),

              // ── SUBMIT ────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitRequest,
                  icon: _isLoading
                      ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: Text(_isLoading ? 'Submitting...' : 'Submit Request',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A6BB5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required IconData icon, required String title, required List<Widget> children,
    required bool dark, Widget? trailing}) {
    return Container(
      decoration: BoxDecoration(
        color: dark ? kCardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(dark ? 0.25 : 0.05), blurRadius: 8)],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: const Color(0xFF1A6BB5), size: 18),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                color: dark ? kTextDark : const Color(0xFF1A2340))),
            const Spacer(),
            if (trailing != null) trailing,
          ]),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLabel(String text, bool dark) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
        color: dark ? kSubDark : const Color(0xFF1A2340))),
  );

  Widget _buildField(TextEditingController ctrl, String hint, IconData icon, bool dark,
      {TextInputType keyboardType = TextInputType.text, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A2340)),
      decoration: _inputDecoration(hint, icon, dark),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon, bool dark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 13),
      prefixIcon: Icon(icon, color: dark ? kSubDark : Colors.grey, size: 18),
      filled: true,
      fillColor: dark ? const Color(0xFF0F1624) : const Color(0xFFF8F9FF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dark ? kBorderDark : const Color(0xFFE0E6FF))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dark ? kBorderDark : const Color(0xFFE0E6FF))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1A6BB5), width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red)),
    );
  }
}
