import 'dart:convert';

import 'package:desktop_core/desktop_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:network_lookup/src/lookup/lookup_repository.dart';

import 'test_support.dart';

Map<String, dynamic> recordJson({String status = 'resolved'}) => {
  'id': 1,
  'ip': '192.168.1.24',
  'mac': '00:1B:63:84:45:E6',
  'vendor': status == 'resolved' ? 'Apple, Inc.' : null,
  'status': status,
  'created_at': '2026-09-10T18:00:00.000Z',
};

void main() {
  RailsLookupRepository repository(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final client = ApiClient(client: MockClient(handler));
    addTearDown(client.close);
    return RailsLookupRepository(client);
  }

  test('POST sends exact contract and parses resolved 201', () async {
    final repo = repository((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/lookups');
      expect(jsonDecode(request.body), {
        'mac': exampleResolution.mac,
        'ip': exampleResolution.ip,
      });
      return http.Response(jsonEncode({'data': recordJson()}), 201);
    });
    final result = await repo.submit(exampleResolution);
    expect(result.record!.vendor, 'Apple, Inc.');
    expect(result.warning, isNull);
  });
  test('unknown 201 is a successful saved record, not an error', () async {
    final result = await repository(
      (_) async => http.Response(
        jsonEncode({'data': recordJson(status: 'unknown')}),
        201,
      ),
    ).submit(exampleResolution);
    expect(result.record!.status, VendorStatus.unknown);
    expect(result.warning, isNull);
  });
  for (final code in [502, 503, 504]) {
    test('provider error $code preserves failed API data', () async {
      final result = await repository(
        (_) async => http.Response(
          jsonEncode({
            'error': {
              'code': 'vendor_unavailable',
              'message': 'Provider unavailable',
            },
            'data': recordJson(status: 'failed'),
          }),
          code,
        ),
      ).submit(exampleResolution);
      expect(result.record!.status, VendorStatus.failed);
      expect(result.warning, 'Provider unavailable');
    });
  }
  test(
    'GET requests newest 30 API rows and rejects malformed records',
    () async {
      final repo = repository((request) async {
        expect(request.url.queryParameters, {'limit': '30', 'offset': '0'});
        return http.Response(
          jsonEncode({
            'data': [recordJson()],
            'meta': {'total': 1},
          }),
          200,
        );
      });
      expect(await repo.history(), hasLength(1));
      await expectLater(
        repository((_) async => http.Response('{"data":[{}]}', 200)).history(),
        throwsA(isA<ApiException>()),
      );
    },
  );
  test(
    'malformed success and unreachable API never claim a saved lookup',
    () async {
      final malformed = await repository(
        (_) async => http.Response('{"data":null}', 201),
      ).submit(exampleResolution);
      expect(malformed.record, isNull);
      expect(malformed.warning, isNotNull);
      final unreachable = await repository(
        (_) async => throw http.ClientException('offline'),
      ).submit(exampleResolution);
      expect(unreachable.record, isNull);
      expect(unreachable.warning, contains('Cannot reach'));
    },
  );
}
