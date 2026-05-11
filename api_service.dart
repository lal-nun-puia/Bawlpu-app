import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://10.104.0.102/nurse_complete/api';

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login_api.php'),
        body: {'email': email, 'password': password},
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } on SocketException {
      return {'status': 'error', 'message': 'No internet connection.'};
    } on TimeoutException {
      return {'status': 'error', 'message': 'Connection timed out.'};
    } catch (e) {
      return {'status': 'error', 'message': 'Something went wrong: $e'};
    }
  }

  static Future<Map<String, dynamic>> registerClient({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String address,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register_api.php'),
        body: {
          'role': 'Client',
          'name': name,
          'email': email,
          'password': password,
          'phone': phone,
          'address': address,
        },
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } on SocketException {
      return {'status': 'error', 'message': 'No internet connection.'};
    } on TimeoutException {
      return {'status': 'error', 'message': 'Connection timed out.'};
    } catch (e) {
      return {'status': 'error', 'message': 'Something went wrong: $e'};
    }
  }

  static Future<Map<String, dynamic>> registerNurse({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String address,
    required String skills,
    required String service,
    required String salary,
    required String experience,
    required String location,
    required String bio,
    required String role,
    File? certificate,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/register_api.php'),
      );
      request.fields.addAll({
        'role': role,
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        'address': address,
        'skills': skills,
        'service': service,
        'salary': salary,
        'experience': experience,
        'location': location,
        'bio': bio,
      });
      if (certificate != null) {
        request.files.add(
          await http.MultipartFile.fromPath('certificate', certificate.path),
        );
      }
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      return jsonDecode(response.body);
    } on SocketException {
      return {'status': 'error', 'message': 'No internet connection.'};
    } on TimeoutException {
      return {'status': 'error', 'message': 'Connection timed out.'};
    } catch (e) {
      return {'status': 'error', 'message': 'Something went wrong: $e'};
    }
  }
}