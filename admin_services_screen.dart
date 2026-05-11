import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'home_screen.dart' show isDark, bgColor, kCardDark, kTextDark, kSubDark, kBorderDark;

class AdminServicesScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const AdminServicesScreen({super.key, required this.userData});

  @override
  State<AdminServicesScreen> createState() => _AdminServicesScreenState();
}

class _AdminServicesScreenState extends State<AdminServicesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Map<String, String>> _services = [
    {'slug': 'LabTesting', 'title': 'Lab Testing'},
    {'slug': 'ElderlyCare', 'title': 'Elderly Care'},
    {'slug': 'PatientCare', 'title': 'Patient Care'},
    {'slug': 'Babysitting', 'title': 'Babysitting'},
  ];
  Map<String, List<dynamic>> _itemsMap = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _services.length, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _fetchAllItems();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllItems() async {
    setState(() => _isLoading = true);
    for (final s in _services) {
      try {
        final response = await http.get(
          Uri.parse('${ApiService.baseUrl}/services_api.php?action=get_items&slug=${s['slug']}'),
        ).timeout(const Duration(seconds: 15));
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          _itemsMap[s['slug']!] = data['items'] ?? [];
        }
      } catch (_) {}
    }
    setState(() => _isLoading = false);
  }

  Future<void> _fetchItems(String slug) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/services_api.php?action=get_items&slug=$slug'),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        setState(() => _itemsMap[slug] = data['items'] ?? []);
      }
    } catch (_) {}
  }

  void _showAddDialog(String slug) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add New Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Item Name', hintText: 'e.g. Blood Test'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price (₹)', hintText: '0'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(context);
              await http.post(
                Uri.parse('${ApiService.baseUrl}/services_api.php?action=add_item'),
                body: {'slug': slug, 'name': nameCtrl.text.trim(), 'price': priceCtrl.text.trim()},
              );
              _fetchItems(slug);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Item added!'), backgroundColor: Colors.green),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D6EFD), foregroundColor: Colors.white),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> item, String slug) {
    final nameCtrl = TextEditingController(text: item['name']);
    final priceCtrl = TextEditingController(text: item['price'].toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Item Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price (₹)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await http.post(
                Uri.parse('${ApiService.baseUrl}/services_api.php?action=update_item'),
                body: {'id': '${item['id']}', 'name': nameCtrl.text.trim(), 'price': priceCtrl.text.trim(), 'active': '1'},
              );
              _fetchItems(slug);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Item updated!'), backgroundColor: Colors.green),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D6EFD), foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(int id, String slug) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    await http.post(
      Uri.parse('${ApiService.baseUrl}/services_api.php?action=delete_item'),
      body: {'id': '$id'},
    );
    _fetchItems(slug);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Item deleted!'), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    final currentSlug = _services[_tabController.index]['slug']!;
    final currentItems = _itemsMap[currentSlug] ?? [];
    final filtered = _searchQuery.isEmpty
        ? currentItems
        : currentItems.where((i) => i['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: bgColor(context),
      appBar: AppBar(
        backgroundColor: dark ? kCardDark : Colors.white,
        elevation: 1,
        title: Text('Manage Services',
            style: TextStyle(fontWeight: FontWeight.w700,
                color: dark ? kTextDark : const Color(0xFF1A1A2E))),
        iconTheme: IconThemeData(color: dark ? kTextDark : const Color(0xFF1A1A2E)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF0D6EFD)), onPressed: _fetchAllItems),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0D6EFD),
          unselectedLabelColor: dark ? kSubDark : Colors.grey,
          indicatorColor: const Color(0xFF0D6EFD),
          isScrollable: true,
          tabs: _services.map((s) => Tab(text: s['title'])).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(currentSlug),
        backgroundColor: const Color(0xFF0D6EFD),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              style: TextStyle(color: dark ? kTextDark : const Color(0xFF1A1A2E)),
              decoration: InputDecoration(
                hintText: 'Search items...',
                hintStyle: TextStyle(color: dark ? kSubDark : Colors.grey),
                prefixIcon: Icon(Icons.search, size: 20, color: dark ? kSubDark : Colors.grey),
                filled: true,
                fillColor: dark ? kCardDark : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: dark ? kBorderDark : Colors.transparent)),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              Text('${filtered.length} items',
                  style: TextStyle(fontSize: 12, color: dark ? kSubDark : Colors.grey, fontWeight: FontWeight.w600)),
            ]),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.inventory_2_outlined, size: 64, color: dark ? kSubDark : Colors.grey),
              const SizedBox(height: 16),
              Text('No items yet', style: TextStyle(color: dark ? kSubDark : Colors.grey, fontSize: 16)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => _showAddDialog(currentSlug),
                icon: const Icon(Icons.add),
                label: const Text('Add First Item'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6EFD), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ]))
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final item = filtered[i];
                final price = double.tryParse(item['price'].toString()) ?? 0;
                final isActive = item['active'] == 1 || item['active'] == '1';
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? (dark ? kCardDark : Colors.white)
                        : (dark ? const Color(0xFF1A1A2E) : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(dark ? 0.2 : 0.04), blurRadius: 6)],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(item['name'],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? (dark ? kTextDark : const Color(0xFF1A1A2E))
                              : (dark ? kSubDark : Colors.grey),
                        )),
                    subtitle: Text(
                      price > 0 ? '₹${price.toStringAsFixed(0)}' : 'Free',
                      style: TextStyle(
                        color: isActive ? const Color(0xFF0D6EFD) : (dark ? kSubDark : Colors.grey),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Color(0xFF0D6EFD), size: 20),
                          onPressed: () => _showEditDialog(item, currentSlug),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          onPressed: () => _deleteItem(item['id'], currentSlug),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}