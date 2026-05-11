import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'home_screen.dart' show isDark, bgColor, kCardDark, kTextDark, kSubDark, kBorderDark;

class AvailableJobsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String initialService;
  const AvailableJobsScreen({super.key, required this.userData, this.initialService = ''});

  @override
  State<AvailableJobsScreen> createState() => _AvailableJobsScreenState();
}

class _AvailableJobsScreenState extends State<AvailableJobsScreen> {
  List<dynamic> _jobs = [];
  bool _isLoading = true;
  String _selectedService = '';

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
    _selectedService = widget.initialService;
    _fetchJobs();
  }

  Future<void> _fetchJobs() async {
    setState(() => _isLoading = true);
    try {
      String url = '${ApiService.baseUrl}/nurse_jobs_api.php?action=available_jobs'
          '&nurse_id=${widget.userData['user_id']}';
      if (_selectedService.isNotEmpty && _selectedService != 'All') {
        url += '&service_type=${Uri.encodeComponent(_selectedService)}';
      }
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        setState(() => _jobs = data['jobs'] ?? []);
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _applyJob(Map<String, dynamic> job) async {
    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Apply for Job'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Service: ${job['service_type'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Patient: ${job['patient_name'] ?? ''}'),
            const SizedBox(height: 4),
            Text('Location: ${job['address'] ?? ''}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A6BB5), foregroundColor: Colors.white),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/nurse_jobs_api.php?action=apply_job'),
        body: {
          'nurse_id': '${widget.userData['user_id']}',
          'request_id': '${job['id']}',
        },
      ).timeout(const Duration(seconds: 15));

      if (mounted) Navigator.pop(context); // close loading

      // Check for HTML error page
      if (response.body.trim().startsWith('<')) {
        if (mounted) Navigator.pop(context);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Server error - check nurse_jobs_api.php'),
            backgroundColor: Colors.red, duration: Duration(seconds: 5)));
        return;
      }

      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        // ── SUCCESS DIALOG ─────────────────────────────────────────────────
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 50),
                ),
                const SizedBox(height: 16),
                const Text('Application Sent! 🎉',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text(
                  'Your application has been submitted successfully.\n\nPlease wait for the client to review and approve your application.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFF1A6BB5).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Row(children: [
                    Icon(Icons.info_outline_rounded, color: Color(0xFF1A6BB5), size: 16),
                    SizedBox(width: 8),
                    Expanded(child: Text(
                      'You can track your application status under "My Applications"',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1A6BB5)),
                    )),
                  ]),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () { Navigator.pop(context); _fetchJobs(); },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A6BB5), foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Got it!', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(data['message'] ?? 'Failed to apply'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // close loading
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: ${e.toString().replaceAll('Exception:', '').trim()}'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ));
    }
  }

  IconData _serviceIcon(String service) {
    switch (service) {
      case 'ElderlyCare':  return Icons.elderly_rounded;
      case 'PatientCare':  return Icons.personal_injury_rounded;
      case 'Babysitting':  return Icons.child_care_rounded;
      case 'LabTesting':   return Icons.biotech_rounded;
      default: return Icons.medical_services_rounded;
    }
  }

  Color _serviceColor(String service) {
    switch (service) {
      case 'ElderlyCare':  return const Color(0xFF1A6BB5);
      case 'PatientCare':  return const Color(0xFF2196F3);
      case 'Babysitting':  return const Color(0xFFFF9800);
      case 'LabTesting':   return const Color(0xFF9C27B0);
      default: return const Color(0xFF1A6BB5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return Scaffold(
      backgroundColor: bgColor(context),
      appBar: AppBar(
        backgroundColor: dark ? kCardDark : Colors.white,
        elevation: 1,
        title: Text('Available Jobs', style: TextStyle(fontWeight: FontWeight.w700,
            color: dark ? kTextDark : const Color(0xFF1A2340))),
        iconTheme: IconThemeData(color: dark ? kTextDark : const Color(0xFF1A2340)),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF1A6BB5)), onPressed: _fetchJobs)],
      ),
      body: Column(children: [
        // Filter chips
        SizedBox(
          height: 52,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            scrollDirection: Axis.horizontal,
            itemCount: _services.length,
            itemBuilder: (_, i) {
              final s = _services[i];
              final selected = _selectedService == s || (s == 'All' && _selectedService.isEmpty);
              return GestureDetector(
                onTap: () { setState(() => _selectedService = s == 'All' ? '' : s); _fetchJobs(); },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                      color: selected ? const Color(0xFF1A6BB5) : (dark ? kCardDark : Colors.white),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected
                          ? const Color(0xFF1A6BB5)
                          : (dark ? kBorderDark : Colors.grey.shade300))),
                  child: Text(_serviceLabels[s] ?? s, style: TextStyle(
                      color: selected ? Colors.white : (dark ? kSubDark : Colors.grey),
                      fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                ),
              );
            },
          ),
        ),

        if (!_isLoading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(children: [
              Text('${_jobs.length} job${_jobs.length != 1 ? 's' : ''} available',
                  style: TextStyle(fontSize: 12,
                      color: dark ? kSubDark : Colors.grey, fontWeight: FontWeight.w600)),
            ]),
          ),

        // Jobs list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _jobs.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.work_outline, size: 64, color: dark ? kSubDark : Colors.grey),
            const SizedBox(height: 16),
            Text('No available jobs', style: TextStyle(
                color: dark ? kSubDark : Colors.grey, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Check back later!', style: TextStyle(
                color: dark ? kSubDark : Colors.grey, fontSize: 13)),
          ]))
              : RefreshIndicator(
            onRefresh: _fetchJobs,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _jobs.length,
              itemBuilder: (_, i) {
                final job = _jobs[i];
                final service = job['service_type'] ?? '';
                final color = _serviceColor(service);
                final label = _serviceLabels[service] ?? service;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                      color: dark ? kCardDark : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(dark ? 0.25 : 0.05),
                          blurRadius: 8)]),
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12)),
                        child: Icon(_serviceIcon(service), color: color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(label, style: TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w700, color: color)),
                        Text('Posted by ${job['client_name'] ?? ''}',
                            style: TextStyle(fontSize: 12,
                                color: dark ? kSubDark : Colors.grey)),
                      ])),
                      Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Text('Open',
                              style: TextStyle(color: Colors.orange,
                                  fontSize: 11, fontWeight: FontWeight.w600))),
                    ]),
                    const SizedBox(height: 12),
                    _infoRow(Icons.person_outline,
                        'Patient: ${job['patient_name'] ?? ''}', dark),
                    const SizedBox(height: 4),
                    _infoRow(Icons.location_on_outlined,
                        job['address'] ?? '', dark),
                    const SizedBox(height: 4),
                    _infoRow(Icons.phone_outlined,
                        job['phone'] ?? '', dark),
                    if (job['date'] != null && job['date'].toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _infoRow(Icons.calendar_today_outlined,
                          '${job['date']} ${job['time'] ?? ''}', dark),
                    ],
                    if (job['notes'] != null && job['notes'].toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _infoRow(Icons.note_outlined, job['notes'], dark),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _applyJob(job),
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text('Apply for this Job',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: color, foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0),
                      ),
                    ),
                  ]),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String text, bool dark) {
    return Row(children: [
      Icon(icon, size: 14, color: dark ? kSubDark : Colors.grey),
      const SizedBox(width: 6),
      Expanded(child: Text(text,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: dark ? kSubDark : Colors.grey))),
    ]);
  }
}