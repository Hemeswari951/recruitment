// lib/services/oncampus_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:file_picker/file_picker.dart';


class OnCampusService {
  static const String baseUrl = 'https://company-04bz.onrender.com';  // CHANGE if needed

  /// GET all drives
  static Future<List<dynamic>> fetchDrives() async {
    final resp = await http.get(Uri.parse('$baseUrl/api/oncampus'));
    return resp.statusCode == 200 ? jsonDecode(resp.body) as List<dynamic> : [];
  }

  /// GET single drive by ID
  static Future<Map<String, dynamic>?> fetchDrive(String id) async {
    final resp = await http.get(Uri.parse('$baseUrl/api/oncampus/$id'));
    if (resp.statusCode == 200) return jsonDecode(resp.body);
    return null;
  }

  /// CREATE a drive
  static Future<bool> createDrive(Map<String, dynamic> payload) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/api/oncampus'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    return resp.statusCode == 201;
  }

  /// UPDATE a drive
  static Future<bool> updateDrive(String id, Map<String, dynamic> payload) async {
    final resp = await http.put(
      Uri.parse('$baseUrl/api/oncampus/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    return resp.statusCode == 200;
  }

  /// DELETE a drive
  static Future<bool> deleteDrive(String id) async {
    final resp = await http.delete(Uri.parse('$baseUrl/api/oncampus/$id'));
    return resp.statusCode == 200;
  }

  static Future<void> addStudent(
    String driveId,
    Map<String, dynamic> fields,
    PlatformFile? file,
  ) async {
    final url = Uri.parse('$baseUrl/api/oncampus/$driveId/students');
    final request = http.MultipartRequest('POST', url);

    fields.forEach((key, value) {
      request.fields[key] = value.toString();
    });

    if (file != null && file.bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'resume',
          file.bytes!,
          filename: file.name,
          contentType: MediaType('application', 'pdf'),
        ),
      );
    }

    final response = await request.send();
    final resp = await http.Response.fromStream(response);

    if (resp.statusCode != 201) {
      throw Exception('Failed to add student: ${resp.body}');
    }
  }

  static Future<bool> updateStudent(
    String driveId,
    String studentId,
    Map<String, String> fields,
    PlatformFile? resume,
  ) async {
    final uri = Uri.parse('$baseUrl/api/oncampus/$driveId/students/$studentId');
    final request = http.MultipartRequest('PUT', uri);

    request.fields.addAll(fields);

    if (resume != null && resume.bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'resume',
          resume.bytes!,
          filename: resume.name,
          contentType: MediaType('application', 'pdf'),
        ),
      );
    }

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    return resp.statusCode == 200;
  }

  // /// DELETE student
  // static Future<bool> deleteStudent(String driveId, String studentId) async {
  //   final resp = await http.delete(
  //     Uri.parse('$baseUrl/api/oncampus/$driveId/students/$studentId'),
  //   );
  //   return resp.statusCode == 200;
  // }

  static Future<void> deleteStudent(String driveId, String studentId) async {
  final url = Uri.parse('$baseUrl/api/oncampus/$driveId/students/$studentId');
  final resp = await http.delete(url);
 
  // Helpful debug log (you can remove later)
  // ignore: avoid_print
  print('DELETE $url -> ${resp.statusCode} ${resp.body}');
 
  if (resp.statusCode >= 200 && resp.statusCode < 300) {
    return; // success (200..299)
  }
 
  final body = resp.body.isNotEmpty ? resp.body : 'no response body';
  throw Exception('Delete failed: ${resp.statusCode} - $body');
}


  /// EXPORT drive PDF (backend should return application/pdf bytes)
  static Future<http.Response> exportDrivePdf(String driveId) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/api/oncampus/$driveId/export'),
    );
    return resp;
  }
}
