import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'request_service_screen.dart';

class ServiceItemsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String serviceType;
  final String serviceTitle;
  const ServiceItemsScreen({
    super.key,
    required this.userData,
    required this.serviceType,
    required this.serviceTitle,
  });

  @override
  State<ServiceItemsScreen> createState() => _ServiceItemsScreenState();
}

class _ServiceItemsScreenState extends State<ServiceItemsScreen> {
  List<dynamic> _items = [];
  bool _isLoading = true;
  final Map<int, bool> _selected = {};
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/services_api.php?action=get_items&slug=${widget.serviceType}'),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        setState(() => _items = data['items'] ?? []);
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  double get _total {
    double t = 0;
    for (final item in _items) {
      if (_selected[item['id']] == true) {
        t += double.tryParse(item['price'].toString()) ?? 0;
      }
    }
    return t;
  }

  List<dynamic> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;
    return _items.where((item) =>
        item['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  List<dynamic> get _selectedItems =>
      _items.where((item) => _selected[item['id']] == true).toList();

  void _proceedToRequest() {
    if (_selectedItems.isEmpty && _items.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one item'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RequestServiceScreen(
          userData: widget.userData,
          serviceType: widget.serviceType,
          selectedItems: _selectedItems,
          totalAmount: _total,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNurse = widget.userData['role'] == 'Nurse';
    final hasItems = _items.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(widget.serviceTitle,
            style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
        iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
        actions: [
          if (!isNurse && _selectedItems.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _selected.clear()),
              child: const Text('Clear', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar (only shown if items exist)
          if (hasItems) ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search items...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),

            // Selected count + total
            if (!isNurse)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D6EFD).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0D6EFD).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Text(
                      '${_selectedItems.length} item${_selectedItems.length != 1 ? 's' : ''} selected',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF0D6EFD), fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      'Total: ₹${_total.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 15, color: Color(0xFF0D6EFD), fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
          ],

          // Items list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.medical_services_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(widget.serviceTitle,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 8),
                  const Text('No specific items for this service.',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  if (!isNurse)
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => RequestServiceScreen(
                          userData: widget.userData,
                          serviceType: widget.serviceType,
                          selectedItems: [],
                          totalAmount: 0,
                        ),
                      )),
                      icon: const Icon(Icons.send),
                      label: const Text('Request This Service'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D6EFD),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _fetchItems,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                itemCount: _filteredItems.length,
                itemBuilder: (_, i) {
                  final item = _filteredItems[i];
                  final isChecked = _selected[item['id']] == true;
                  final price = double.tryParse(item['price'].toString()) ?? 0;
                  return GestureDetector(
                    onTap: isNurse
                        ? null
                        : () => setState(() => _selected[item['id']] = !isChecked),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: isChecked
                            ? const Color(0xFF0D6EFD).withOpacity(0.06)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isChecked
                              ? const Color(0xFF0D6EFD)
                              : Colors.grey.shade200,
                          width: isChecked ? 1.5 : 1,
                        ),
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        leading: isNurse
                            ? Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D6EFD).withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.science_outlined, size: 16, color: Color(0xFF0D6EFD)),
                        )
                            : Checkbox(
                          value: isChecked,
                          onChanged: (_) => setState(() => _selected[item['id']] = !isChecked),
                          activeColor: const Color(0xFF0D6EFD),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        title: Text(
                          item['name'],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                            color: isChecked ? const Color(0xFF0D6EFD) : const Color(0xFF1A1A2E),
                          ),
                        ),
                        trailing: Text(
                          price > 0 ? '₹${price.toStringAsFixed(0)}' : 'Free',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isChecked ? const Color(0xFF0D6EFD) : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),

      // Bottom bar with total and proceed button
      bottomNavigationBar: !isNurse && hasItems
          ? Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12)],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_selectedItems.length} selected',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    '₹${_total.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0D6EFD)),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _proceedToRequest,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Proceed to Request',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D6EFD),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      )
          : null,
    );
  }
}