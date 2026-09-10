import 'dart:convert';
import 'package:desktop_core/desktop_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('builds JSON requests and preserves a base path', () async {
    final client = ApiClient(
      baseUrl: 'http://localhost:3000/api/',
      client: MockClient((request) async {
        expect(request.url.toString(), 'http://localhost:3000/api/lookups');
        expect(request.method, 'POST');
        expect(jsonDecode(request.body), {'mac': '00:11:22:33:44:55'});
        return http.Response('{"data":{"id":1}}', 201);
      }),
    );
    expect(await client.post('/lookups', {'mac': '00:11:22:33:44:55'}), {
      'data': {'id': 1},
    });
    client.close();
  });

  test('retains persisted lookup on a provider failure', () async {
    final client = ApiClient(
      client: MockClient(
        (_) async => http.Response(
          '{"error":{"code":"vendor_timeout","message":"Try later"},"data":{"id":2,"status":"failed"}}',
          504,
        ),
      ),
    );
    await expectLater(
      client.post('/lookups', {}),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'vendor_timeout')
            .having((e) => e.data?['id'], 'persisted id', 2),
      ),
    );
    client.close();
  });

  test('reports an unreachable API', () async {
    final client = ApiClient(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await expectLater(
      client.get('/health'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'unreachable')),
    );
    client.close();
  });

  test('handles malformed successful responses', () async {
    final client = ApiClient(
      client: MockClient((_) async => http.Response('<html>proxy</html>', 200)),
    );
    await expectLater(
      client.get('/health'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'invalid_response'),
      ),
    );
    client.close();
  });

  test('bounds total request time', () async {
    final client = ApiClient(
      timeout: const Duration(milliseconds: 5),
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      client.get('/health'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'timeout')),
    );
    client.close();
  });
}
