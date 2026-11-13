import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';

final backendApiProvider = Provider<BackendApi>((ref) {
  final api = BackendApi(baseUrl: AppConfig.apiBaseUrl);
  ref.onDispose(api.close);
  return api;
});

class BackendApi {
  BackendApi({required this.baseUrl, HttpClient? client})
    : _client = client ?? HttpClient();

  static const _timeout = Duration(seconds: 30);

  final String baseUrl;
  final HttpClient _client;

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) {
    return _send('POST', path, body: body, accessToken: accessToken);
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    String? accessToken,
  }) {
    return _send('GET', path, query: query, accessToken: accessToken);
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) {
    return _send('PATCH', path, body: body, accessToken: accessToken);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    Map<String, String>? query,
    String? accessToken,
  }) async {
    if (baseUrl.isEmpty) {
      throw const ApiConfigurationException(
        'API belum dikonfigurasi. Jalankan aplikasi dengan '
        '--dart-define=API_BASE_URL=<alamat-backend>.',
      );
    }

    Uri uri;
    try {
      uri = Uri.parse(baseUrl).resolve(path);
    } on FormatException {
      throw const ApiConfigurationException(
        'API_BASE_URL bukan alamat yang valid.',
      );
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const ApiConfigurationException(
        'API_BASE_URL harus menggunakan HTTP atau HTTPS.',
      );
    }
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }

    try {
      final request = await _client.openUrl(method, uri).timeout(_timeout);
      if (accessToken != null) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $accessToken',
        );
      }
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }

      final response = await request.close().timeout(_timeout);
      final responseBody = await utf8.decoder
          .bind(response)
          .join()
          .timeout(_timeout);
      // 204 No Content (mis. ubah kata sandi) tidak punya isi: anggap objek kosong.
      final decoded = responseBody.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(responseBody);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('API returned a non-object response.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded['detail'];
        throw BackendApiException(
          statusCode: response.statusCode,
          message: detail is String ? detail : 'Permintaan gagal.',
        );
      }
      return decoded;
    } on TimeoutException {
      throw const ApiNetworkException(
        'Permintaan ke server melewati batas waktu.',
      );
    } on SocketException {
      throw const ApiNetworkException(
        'Tidak dapat terhubung ke server. Periksa jaringan dan alamat backend.',
      );
    } on HttpException {
      throw const ApiNetworkException('Koneksi ke server terputus.');
    } on FormatException catch (error) {
      throw ApiResponseFormatException(error.message);
    }
  }

  void close() {
    _client.close();
  }
}

class BackendApiException implements Exception {
  const BackendApiException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  @override
  String toString() => 'BackendApiException($statusCode): $message';
}

class ApiConfigurationException implements Exception {
  const ApiConfigurationException(this.message);

  final String message;
}

class ApiNetworkException implements Exception {
  const ApiNetworkException(this.message);

  final String message;
}

class ApiResponseFormatException implements Exception {
  const ApiResponseFormatException(this.message);

  final String message;
}
