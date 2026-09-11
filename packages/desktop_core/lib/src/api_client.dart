import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.code = 'api_error',
    this.statusCode,
    this.data,
  });
  final String message;
  final String code;

  /// HTTP status of the failed response; null when no response arrived
  /// (unreachable, timeout, invalid URL), which callers treat as transient.
  final int? statusCode;
  final Map<String, dynamic>? data;

  /// True when retrying the same request later could plausibly succeed.
  bool get isTransient => statusCode == null || statusCode! >= 500;

  @override
  String toString() => message;
}

/// A small injectable transport. Domain parsing belongs in each app repository.
class ApiClient {
  ApiClient({
    String? baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
  }) : baseUrl =
           baseUrl ??
           const String.fromEnvironment(
             'API_BASE_URL',
             defaultValue: 'http://127.0.0.1:3000',
           ),
       _client = client ?? http.Client();
  final String baseUrl;
  final http.Client _client;
  final Duration timeout;

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      _request('GET', path, query: query);
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      _request('POST', path, body: body);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request(method, _uri(path, query))
      ..headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final http.Response response;
    try {
      response = await _send(request).timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        'The API took too long to respond. Check the service and try again.',
        code: 'timeout',
      );
    } on http.ClientException {
      throw _unreachable;
    } on IOException {
      // Socket and TLS failures that package:http does not wrap.
      throw _unreachable;
    }
    final decoded = _decode(response.body);
    final status = response.statusCode;
    if (status < 200 || status >= 300) {
      final error = decoded?['error'];
      throw ApiException(
        error is Map && error['message'] is String
            ? error['message'] as String
            : 'The API request failed (HTTP $status).',
        code: error is Map && error['code'] is String
            ? error['code'] as String
            : 'api_error',
        statusCode: status,
        data: decoded?['data'] is Map<String, dynamic>
            ? decoded!['data'] as Map<String, dynamic>
            : null,
      );
    }
    if (decoded == null) {
      throw ApiException(
        'The API returned an unexpected response.',
        code: 'invalid_response',
        statusCode: status,
      );
    }
    return decoded;
  }

  Future<http.Response> _send(http.Request request) async =>
      http.Response.fromStream(await _client.send(request));

  Uri _uri(String path, Map<String, String>? query) {
    final base = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final relative = path.replaceFirst(RegExp(r'^/+'), '');
    final uri = Uri.tryParse('$base/$relative');
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw const ApiException(
        'The API address is invalid. Check API_BASE_URL.',
        code: 'invalid_url',
      );
    }
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  /// A JSON object body, or null when the body is not one.
  static Map<String, dynamic>? _decode(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  static const _unreachable = ApiException(
    'Cannot reach the Rails API. Start the service and check API_BASE_URL.',
    code: 'unreachable',
  );

  void close() => _client.close();
}
