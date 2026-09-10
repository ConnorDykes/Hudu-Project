import 'dart:async';
import 'dart:convert';
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
  final int? statusCode;
  final Map<String, dynamic>? data;
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
    try {
      final base = baseUrl.replaceFirst(RegExp(r'/+$'), '');
      final uri = Uri.parse(
        '$base/$path'.replaceFirst('$base//', '$base/'),
      ).replace(queryParameters: query);
      if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
        throw const ApiException(
          'The API address is invalid. Check API_BASE_URL.',
          code: 'invalid_url',
        );
      }
      final request = http.Request(method, uri)
        ..headers['Accept'] = 'application/json';
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(timeout);
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded['error'];
        throw ApiException(
          error is Map && error['message'] is String
              ? error['message'] as String
              : 'The API could not complete this request.',
          code: error is Map && error['code'] is String
              ? error['code'] as String
              : 'api_error',
          statusCode: response.statusCode,
          data: decoded['data'] is Map<String, dynamic>
              ? decoded['data'] as Map<String, dynamic>
              : null,
        );
      }
      return decoded;
    } on TimeoutException {
      throw const ApiException(
        'The API took too long to respond. Check the service and try again.',
        code: 'timeout',
      );
    } on http.ClientException {
      throw const ApiException(
        'Cannot reach the Rails API. Start the service and check API_BASE_URL.',
        code: 'unreachable',
      );
    } on FormatException {
      throw const ApiException(
        'The API returned an unexpected response.',
        code: 'invalid_response',
      );
    }
  }

  void close() => _client.close();
}
