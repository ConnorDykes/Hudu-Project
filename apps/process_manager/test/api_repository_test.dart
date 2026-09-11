import 'dart:convert';

import 'package:desktop_core/desktop_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:process_manager/src/audit_repository.dart';
import 'package:process_manager/src/models.dart';

import 'support/fakes.dart';

void main() {
  test('Rails 3-decimal timestamps acknowledge microsecond input without changing retries', () async {
    final event = AuditEvent(
      eventId: sampleEvent().eventId,
      processName: 'worker',
      pid: 99,
      occurredAt: DateTime.parse('2026-09-10T18:30:00.123456Z'),
    );
    final bodies = <String>[];
    final client = ApiClient(
      client: MockClient((request) async {
        expect(request.url.path, '/process_events');
        expect(request.method, 'POST');
        bodies.add(request.body);
        return http.Response(
          jsonEncode({
            'data': {
              ...event.toJson(),
              'occurred_at': '2026-09-10T18:30:00.123Z',
            },
          }),
          bodies.length == 1 ? 201 : 200,
        );
      }),
    );
    addTearDown(client.close);
    final repository = ApiAuditRepository(client);
    await repository.send(event);
    await repository.send(event);
    expect(bodies[0], bodies[1]);
    expect(jsonDecode(bodies[0])['occurred_at'], '2026-09-10T18:30:00.123456Z');
  });
  test(
    'history reads bounded contract; mismatched acknowledgement fails',
    () async {
      final event = sampleEvent();
      final client = ApiClient(
        client: MockClient((request) async {
          if (request.method == 'GET') {
            expect(request.url.queryParameters, {'limit': '30', 'offset': '0'});
            return http.Response(
              jsonEncode({
                'data': [event.toJson()],
                'meta': {'total': 1},
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'data': {...event.toJson(), 'pid': 1},
            }),
            201,
          );
        }),
      );
      addTearDown(client.close);
      final repository = ApiAuditRepository(client);
      expect((await repository.history()).single.eventId, event.eventId);
      await expectLater(repository.send(event), throwsException);
    },
  );
  test('malformed API records are reported as invalid responses', () async {
    for (final body in ['{"data":[{}]}', '{"data":{}}', '{"data":[1]}']) {
      final client = ApiClient(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      addTearDown(client.close);
      await expectLater(
        ApiAuditRepository(client).history(),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'invalid_response'),
        ),
        reason: body,
      );
    }
  });
}
