import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:seawatch/config/app_config.dart';
import 'package:seawatch/services/core/app_state_store.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() {
    return message;
  }
}

class ApiClient {
  ApiClient({AppStateStore? store}) : _store = store ?? AppStateStore();

  final AppStateStore _store;

  Uri _buildUri(String path, [Map<String, String>? query]) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path).replace(queryParameters: query);
    }

    final base = Uri.parse('${AppConfig.apiBaseUrl}/');
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return base.resolve(normalizedPath).replace(queryParameters: query);
  }

  Future<bool> isBackendReachable() async {
    try {
      final response =
          await http.get(_buildUri('/')).timeout(const Duration(seconds: 4));
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _authToken() {
    return _store.getToken();
  }

  String _extractErrorMessage(http.Response response) {
    if (response.body.isEmpty) {
      return 'Errore HTTP ${response.statusCode}';
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message =
            decoded['message'] ?? decoded['error'] ?? decoded['msg'];
        if (message is List) {
          return message.map((e) => e.toString()).join(', ');
        }
        if (message != null) {
          return message.toString();
        }
      }
    } catch (_) {
      // fall back to raw body
    }

    return response.body;
  }

  Future<dynamic> _decodeBody(http.Response response) async {
    if (response.body.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(response.body);
    } catch (_) {
      return response.body;
    }
  }

  String? _fallbackMimeTypeFromExtension(String filePath) {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }
    if (lower.endsWith('.bmp')) {
      return 'image/bmp';
    }
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
      return 'image/heic';
    }
    return null;
  }

  Future<MediaType?> _detectContentType(String filePath) async {
    List<int>? headerBytes;
    try {
      headerBytes = await File(filePath)
          .openRead(0, 64)
          .expand((chunk) => chunk)
          .take(64)
          .toList();
    } catch (_) {
      headerBytes = null;
    }

    final detected = lookupMimeType(filePath, headerBytes: headerBytes);
    final mimeType = detected ?? _fallbackMimeTypeFromExtension(filePath);
    if (mimeType == null) {
      return null;
    }

    final parts = mimeType.split('/');
    if (parts.length != 2) {
      return null;
    }

    return MediaType(parts[0], parts[1]);
  }

  Future<dynamic> requestJson({
    required String method,
    required String path,
    Map<String, String>? query,
    Object? body,
    bool authRequired = true,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (authRequired) {
      final token = await _authToken();
      if (token == null || token.isEmpty) {
        throw const ApiException(
            'Sessione non valida, effettua di nuovo il login.');
      }
      headers['Authorization'] = 'Bearer $token';
    }

    late final http.Response response;
    final uri = _buildUri(path, query);

    try {
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: headers).timeout(timeout);
          break;
        case 'POST':
          response = await http
              .post(uri,
                  headers: headers,
                  body: body == null ? null : jsonEncode(body))
              .timeout(timeout);
          break;
        case 'PUT':
          response = await http
              .put(uri,
                  headers: headers,
                  body: body == null ? null : jsonEncode(body))
              .timeout(timeout);
          break;
        case 'PATCH':
          response = await http
              .patch(uri,
                  headers: headers,
                  body: body == null ? null : jsonEncode(body))
              .timeout(timeout);
          break;
        case 'DELETE':
          response = await http
              .delete(uri,
                  headers: headers,
                  body: body == null ? null : jsonEncode(body))
              .timeout(timeout);
          break;
        default:
          throw ApiException('Metodo HTTP non supportato: $method');
      }
    } on TimeoutException {
      throw const ApiException('Timeout di rete. Riprova.');
    } on SocketException {
      throw const ApiException('Nessuna connessione disponibile.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(response),
        statusCode: response.statusCode,
      );
    }

    return _decodeBody(response);
  }

  Future<Map<String, dynamic>> getJsonMap(
    String path, {
    Map<String, String>? query,
    bool authRequired = true,
  }) async {
    final data = await requestJson(
      method: 'GET',
      path: path,
      query: query,
      authRequired: authRequired,
    );

    if (data is Map<String, dynamic>) {
      return data;
    }

    throw const ApiException('Formato risposta non valido (mappa attesa).');
  }

  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, String>? query,
    bool authRequired = true,
  }) async {
    final data = await requestJson(
      method: 'GET',
      path: path,
      query: query,
      authRequired: authRequired,
    );

    if (data is List) {
      return data;
    }

    throw const ApiException('Formato risposta non valido (lista attesa).');
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? body,
    bool authRequired = true,
  }) async {
    final data = await requestJson(
      method: 'POST',
      path: path,
      body: body,
      authRequired: authRequired,
    );

    if (data is Map<String, dynamic>) {
      return data;
    }

    throw const ApiException('Formato risposta non valido (mappa attesa).');
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    Object? body,
    bool authRequired = true,
  }) async {
    final data = await requestJson(
      method: 'PUT',
      path: path,
      body: body,
      authRequired: authRequired,
    );

    if (data is Map<String, dynamic>) {
      return data;
    }

    throw const ApiException('Formato risposta non valido (mappa attesa).');
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Object? body,
    bool authRequired = true,
  }) async {
    final data = await requestJson(
      method: 'PATCH',
      path: path,
      body: body,
      authRequired: authRequired,
    );

    if (data is Map<String, dynamic>) {
      return data;
    }

    throw const ApiException('Formato risposta non valido (mappa attesa).');
  }

  Future<void> delete(
    String path, {
    Object? body,
    bool authRequired = true,
  }) async {
    await requestJson(
      method: 'DELETE',
      path: path,
      body: body,
      authRequired: authRequired,
    );
  }

  Future<Map<String, dynamic>> uploadFile({
    required String path,
    required String fieldName,
    required String filePath,
    Map<String, String>? fields,
    bool authRequired = true,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final uri = _buildUri(path);
    final request = http.MultipartRequest('POST', uri);

    if (authRequired) {
      final token = await _authToken();
      if (token == null || token.isEmpty) {
        throw const ApiException(
            'Sessione non valida, effettua di nuovo il login.');
      }
      request.headers['Authorization'] = 'Bearer $token';
    }

    if (fields != null) {
      request.fields.addAll(fields);
    }

    final contentType = await _detectContentType(filePath);
    request.files.add(
      await http.MultipartFile.fromPath(
        fieldName,
        filePath,
        contentType: contentType,
      ),
    );

    http.StreamedResponse streamed;
    try {
      streamed = await request.send().timeout(timeout);
    } on TimeoutException {
      throw const ApiException('Timeout upload immagine.');
    } on SocketException {
      throw const ApiException('Nessuna connessione disponibile.');
    }

    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(response),
        statusCode: response.statusCode,
      );
    }

    final data = await _decodeBody(response);
    if (data is Map<String, dynamic>) {
      return data;
    }

    return {
      'ok': true,
      'raw': data,
    };
  }
}
