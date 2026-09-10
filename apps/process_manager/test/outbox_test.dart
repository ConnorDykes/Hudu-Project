import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:process_manager/src/audit_repository.dart';

import 'support/fakes.dart';

void main() {
  late Directory temp;
  late FileAuditOutbox outbox;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('hudu-outbox-test-');
    outbox = FileAuditOutbox(() async => temp);
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });
  test('durable event roundtrip through fresh instance; repeated writes and removal', () async {
    await outbox.prepare();
    final event = sampleEvent();
    await outbox.put(event);
    await outbox.put(event);
    final restarted = FileAuditOutbox(() async => temp);
    expect((await restarted.load()).single.toJson(), event.toJson());
    await restarted.remove(event.eventId);
    expect(await outbox.load(), isEmpty);
  });
  test('recovers complete pending file from interrupted rename', () async {
    final event = sampleEvent();
    await File('${temp.path}/${event.eventId}.pending')
        .writeAsString(jsonEncode(event.toJson()), flush: true);
    expect((await outbox.load()).single.eventId, event.eventId);
    await outbox.put(event);
    await outbox.remove(event.eventId);
    expect(await outbox.load(), isEmpty);
  });
  test('corrupt event is reported and preserved', () async {
    final file = File('${temp.path}/${sampleEvent().eventId}.json');
    await file.writeAsString('{broken');
    await expectLater(outbox.load(), throwsException);
    expect(await file.readAsString(), '{broken');
  });
}
