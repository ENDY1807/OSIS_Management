import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BaknusDriveService {
  static const String baseUrl = 'https://baknusdrive.smkbn666.sch.id';
  static const String defaultEmail = 'osis-baknus';
  static const String defaultPassword = 'baknus666?!';
  static const String _keyToken = 'baknusdrive_token';

  static String? _cachedToken;

  /// Mendapatkan atau memperbarui Bearer token BaknusDrive
  static Future<String?> getToken({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedToken != null && _cachedToken!.isNotEmpty) {
      return _cachedToken;
    }

    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final saved = prefs.getString(_keyToken);
      if (saved != null && saved.isNotEmpty) {
        _cachedToken = saved;
        return saved;
      }
    }

    return await login();
  }

  /// Login ke BaknusDrive dengan akun osis-baknus
  static Future<String?> login({
    String email = defaultEmail,
    String password = defaultPassword,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/login');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token']?.toString();
        if (token != null && token.isNotEmpty) {
          _cachedToken = token;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keyToken, token);
          debugPrint('BaknusDriveService: Login berhasil, token diperoleh.');
          return token;
        }
      } else {
        debugPrint('BaknusDriveService: Gagal login (HTTP ${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('BaknusDriveService login error: $e');
    }
    return null;
  }

  /// Mengunggah berkas ke BaknusDrive secara chunked dan menjadikannya tautan publik
  static Future<String> uploadFile(Uint8List bytes, String fileName, {String? folderId}) async {
    String? token = await getToken();
    token ??= await login();
    if (token == null) {
      throw Exception('Gagal melakukan autentikasi ke BaknusDrive.');
    }

    final uploadId = '${DateTime.now().millisecondsSinceEpoch}_${(bytes.length % 100000)}';
    const int chunkSize = 5 * 1024 * 1024; // 5MB per chunk
    final int totalChunks = (bytes.length / chunkSize).ceil().clamp(1, 999999);

    // 1. Upload Chunks
    for (int chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
      final start = chunkIndex * chunkSize;
      final end = (start + chunkSize > bytes.length) ? bytes.length : (start + chunkSize);
      final chunkData = bytes.sublist(start, end);

      final chunkReq = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/drive/upload-chunk'),
      );
      chunkReq.headers['Authorization'] = 'Bearer $token';
      chunkReq.fields['upload_id'] = uploadId;
      chunkReq.fields['chunk_index'] = chunkIndex.toString();
      chunkReq.files.add(http.MultipartFile.fromBytes(
        'file',
        chunkData,
        filename: fileName,
      ));

      final streamedRes = await chunkReq.send().timeout(const Duration(seconds: 45));
      final chunkRes = await http.Response.fromStream(streamedRes);

      if (chunkRes.statusCode == 401) {
        // Token kedaluwarsa, segarkan dan coba sekali lagi
        token = await getToken(forceRefresh: true);
        if (token == null) throw Exception('Sesi BaknusDrive kedaluwarsa.');

        final retryReq = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/api/drive/upload-chunk'),
        );
        retryReq.headers['Authorization'] = 'Bearer $token';
        retryReq.fields['upload_id'] = uploadId;
        retryReq.fields['chunk_index'] = chunkIndex.toString();
        retryReq.files.add(http.MultipartFile.fromBytes(
          'file',
          chunkData,
          filename: fileName,
        ));
        final retryStreamed = await retryReq.send().timeout(const Duration(seconds: 45));
        final retryRes = await http.Response.fromStream(retryStreamed);
        if (retryRes.statusCode != 200) {
          throw Exception('Gagal mengunggah potongan file ke BaknusDrive: ${retryRes.body}');
        }
      } else if (chunkRes.statusCode != 200) {
        throw Exception('Gagal mengunggah potongan file ke BaknusDrive (HTTP ${chunkRes.statusCode}): ${chunkRes.body}');
      }
    }

    // 2. Complete Upload
    final completeUrl = Uri.parse('$baseUrl/api/drive/upload-complete');
    final completeRes = await http.post(
      completeUrl,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'upload_id': uploadId,
        'file_name': fileName,
        'total_chunks': totalChunks,
        'total_size': bytes.length,
        'folder_id': folderId,
      }),
    ).timeout(const Duration(seconds: 30));

    if (completeRes.statusCode != 200) {
      throw Exception('Gagal menyelesaikan proses unggah di BaknusDrive: ${completeRes.body}');
    }

    final fileInfo = jsonDecode(completeRes.body);
    final dynamic fileId = fileInfo['id'];
    if (fileId == null) {
      throw Exception('Respon BaknusDrive tidak memiliki ID file.');
    }

    // 3. Make File Public
    try {
      final publicUrl = Uri.parse('$baseUrl/api/drive/file/$fileId/public');
      await http.put(
        publicUrl,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'is_public': true,
          'public_password': null,
          'public_expiration': null,
        }),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Warning: Gagal mengatur status publik di BaknusDrive: $e');
    }

    // 4. Return Public Direct Download URL
    final publicDownloadUrl = '$baseUrl/api/public/file/$fileId/download';
    debugPrint('BaknusDriveService: Berkas berhasil diunggah -> $publicDownloadUrl');
    return publicDownloadUrl;
  }
}
