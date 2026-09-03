import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BaknusDriveService {
  static const String baseUrl = 'https://baknusdrive.smkbn666.sch.id';
  static const String defaultEmail = 'osis-baknus';
  static const String defaultPassword = 'baknus666?!';
  static const String _keyToken = 'baknusdrive_token';

  static String? _cachedToken;
  static final Map<String, int> _folderIdCache = {};

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

  /// Mengekstrak ID file dari URL BaknusDrive (contoh: https://baknusdrive.smkbn666.sch.id/api/public/file/595/download -> 595)
  static int? extractFileId(String url) {
    if (!url.contains('baknusdrive.smkbn666.sch.id')) return null;
    final regex = RegExp(r'/file/(\d+)');
    final match = regex.firstMatch(url);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '');
    }
    return null;
  }

  /// Mencari atau membuat folder di BaknusDrive berdasarkan path
  static Future<int?> ensureFolderExists(String folderPath) async {
    final clean = folderPath.trim();
    if (clean.isEmpty || clean.toLowerCase() == 'root') return null;

    if (_folderIdCache.containsKey(clean)) {
      return _folderIdCache[clean];
    }

    String? token = await getToken();
    token ??= await login();
    if (token == null) return null;

    try {
      // 1. Cek folder yang sudah ada
      final listRes = await http.get(
        Uri.parse('$baseUrl/api/drive'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (listRes.statusCode == 200) {
        final data = jsonDecode(listRes.body);
        final folders = data['folders'] as List? ?? [];
        for (final f in folders) {
          final name = f['name']?.toString() ?? '';
          final id = f['id'] as int?;
          if (id != null) {
            _folderIdCache[name] = id;
          }
          if (name == clean && id != null) {
            return id;
          }
        }
      }

      // 2. Jika belum ada, buat foldernya
      final createRes = await http.post(
        Uri.parse('$baseUrl/api/drive/folder'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': clean,
          'parent_id': null,
        }),
      ).timeout(const Duration(seconds: 10));

      if (createRes.statusCode == 200) {
        final fData = jsonDecode(createRes.body);
        final id = (fData['id'] ?? fData['folder']?['id']) as int?;
        if (id != null) {
          _folderIdCache[clean] = id;
          return id;
        }
      }
    } catch (e) {
      debugPrint('BaknusDriveService ensureFolderExists error: $e');
    }
    return null;
  }

  /// Mengunggah berkas ke BaknusDrive secara chunked dan menjadikannya tautan publik
  static Future<String> uploadFile(Uint8List bytes, String fileName, {String? folderPath}) async {
    String? token = await getToken();
    token ??= await login();
    if (token == null) {
      throw Exception('Gagal melakukan autentikasi ke BaknusDrive.');
    }

    int? folderId;
    if (folderPath != null && folderPath.isNotEmpty) {
      folderId = await ensureFolderExists(folderPath);
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

  /// Menghapus file dari BaknusDrive berdasarkan URL
  static Future<bool> deleteFileByUrl(String fileUrl) async {
    final fileId = extractFileId(fileUrl);
    if (fileId == null) return false;

    String? token = await getToken();
    token ??= await login();
    if (token == null) return false;

    try {
      final url = Uri.parse('$baseUrl/api/drive/file/$fileId');
      final res = await http.delete(
        url,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      debugPrint('BaknusDriveService deleteFile ($fileId) status: ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('BaknusDriveService deleteFile error: $e');
      return false;
    }
  }

  /// Mengubah nama file di BaknusDrive berdasarkan URL
  static Future<bool> renameFileByUrl(String fileUrl, String newName) async {
    final fileId = extractFileId(fileUrl);
    if (fileId == null) return false;

    String? token = await getToken();
    token ??= await login();
    if (token == null) return false;

    try {
      final url = Uri.parse('$baseUrl/api/drive/file/$fileId/rename');
      final res = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'name': newName}),
      ).timeout(const Duration(seconds: 15));
      debugPrint('BaknusDriveService renameFile ($fileId -> $newName) status: ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('BaknusDriveService renameFile error: $e');
      return false;
    }
  }

  /// Memindahkan file di BaknusDrive ke folder lain
  static Future<bool> moveFileByUrl(String fileUrl, String targetFolderName) async {
    final fileId = extractFileId(fileUrl);
    if (fileId == null) return false;

    final targetFolderId = await ensureFolderExists(targetFolderName);

    String? token = await getToken();
    token ??= await login();
    if (token == null) return false;

    try {
      final url = Uri.parse('$baseUrl/api/drive/file/$fileId/move');
      final res = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'target_folder_id': targetFolderId}),
      ).timeout(const Duration(seconds: 15));
      debugPrint('BaknusDriveService moveFile ($fileId -> $targetFolderName) status: ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('BaknusDriveService moveFile error: $e');
      return false;
    }
  }

  /// Membuat folder baru di BaknusDrive
  static Future<int?> createFolder(String folderName, {int? parentId}) async {
    String? token = await getToken();
    token ??= await login();
    if (token == null) return null;

    try {
      final url = Uri.parse('$baseUrl/api/drive/folder');
      final res = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': folderName,
          'parent_id': parentId,
        }),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final id = (data['id'] ?? data['folder']?['id']) as int?;
        if (id != null) {
          _folderIdCache[folderName] = id;
          return id;
        }
      }
    } catch (e) {
      debugPrint('BaknusDriveService createFolder error: $e');
    }
    return null;
  }

  /// Mengubah nama folder di BaknusDrive
  static Future<bool> renameFolder(String oldName, String newName) async {
    final folderId = await ensureFolderExists(oldName);
    if (folderId == null) return false;

    String? token = await getToken();
    token ??= await login();
    if (token == null) return false;

    try {
      final url = Uri.parse('$baseUrl/api/drive/folder/$folderId/rename');
      final res = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'name': newName}),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        _folderIdCache.remove(oldName);
        _folderIdCache[newName] = folderId;
        return true;
      }
    } catch (e) {
      debugPrint('BaknusDriveService renameFolder error: $e');
    }
    return false;
  }

  /// Menghapus folder di BaknusDrive
  static Future<bool> deleteFolderByName(String folderName) async {
    final folderId = await ensureFolderExists(folderName);
    if (folderId == null) return false;

    String? token = await getToken();
    token ??= await login();
    if (token == null) return false;

    try {
      final url = Uri.parse('$baseUrl/api/drive/folder/$folderId');
      final res = await http.delete(
        url,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      _folderIdCache.remove(folderName);
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('BaknusDriveService deleteFolderByName error: $e');
      return false;
    }
  }

  /// Mengunduh file dari URL dan menyimpannya di folder sementara dengan nama dan ekstensi yang benar
  static Future<File?> downloadToTemp(String fileUrl, String defaultTitle) async {
    try {
      final uri = Uri.parse(fileUrl);
      final response = await http.get(uri).timeout(const Duration(seconds: 45));

      if (response.statusCode != 200) {
        debugPrint('BaknusDriveService download failed HTTP ${response.statusCode}');
        return null;
      }

      // 1. Cek nama file dari Content-Disposition header
      String finalFileName = '';
      final cd = response.headers['content-disposition'];
      if (cd != null && cd.contains('filename=')) {
        final match = RegExp(r'filename="?([^";]+)"?').firstMatch(cd);
        if (match != null) {
          finalFileName = match.group(1)?.trim() ?? '';
        }
      }

      // 2. Jika tidak ada di header, gunakan defaultTitle & cek ekstensi
      if (finalFileName.isEmpty) {
        finalFileName = defaultTitle.trim();
        final seg = uri.pathSegments.lastOrNull ?? '';
        if (seg.contains('.')) {
          final ext = '.${seg.split('.').last}';
          if (!finalFileName.toLowerCase().endsWith(ext.toLowerCase())) {
            finalFileName = '$finalFileName$ext';
          }
        }
      }

      // 3. Jika belum memiliki ekstensi, tebak dari Content-Type
      if (!finalFileName.contains('.')) {
        final ct = response.headers['content-type']?.toLowerCase() ?? '';
        if (ct.contains('pdf')) {
          finalFileName += '.pdf';
        } else if (ct.contains('word') || ct.contains('docx')) {
          finalFileName += '.docx';
        } else if (ct.contains('sheet') || ct.contains('excel') || ct.contains('xlsx')) {
          finalFileName += '.xlsx';
        } else if (ct.contains('presentation') || ct.contains('pptx')) {
          finalFileName += '.pptx';
        } else if (ct.contains('jpeg') || ct.contains('jpg')) {
          finalFileName += '.jpg';
        } else if (ct.contains('png')) {
          finalFileName += '.png';
        } else if (ct.contains('zip')) {
          finalFileName += '.zip';
        } else if (ct.contains('text')) {
          finalFileName += '.txt';
        }
      }

      final dir = await getTemporaryDirectory();
      // Hilangkan karakter ilegal pada nama berkas
      final cleanName = finalFileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${dir.path}/$cleanName');
      await file.writeAsBytes(response.bodyBytes);
      return file;
    } catch (e) {
      debugPrint('BaknusDriveService downloadToTemp error: $e');
      return null;
    }
  }
}
