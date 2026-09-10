import 'dart:io';

import 'package:desktop_core/desktop_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:process_manager/src/audit_repository.dart';
import 'package:process_manager/src/models.dart';
import 'package:uuid/uuid.dart';

import 'support/native_harness.dart';

void main() {
  test(
    'real API accepts confirmed harness child exit and idempotent retry',
    () async {
      final child = await spawnDisposableChild();
      var exited = false;
      final exit = child.exitCode.then((code) {
        exited = true;
        return code;
      });
      addTearDown(() async {
        if (!exited) child.kill();
        await exit.timeout(const Duration(seconds: 8));
      });
      final adapter = nativeAdapter();
      final selected = (await adapter.list()).singleWhere(
        (p) => p.pid == child.pid,
      );
      expect(await adapter.terminate(selected), ExitOutcome.terminated);
      await exit;
      final event = AuditEvent(
        eventId: const Uuid().v4(),
        processName: selected.name,
        pid: selected.pid,
        occurredAt: DateTime.fromMillisecondsSinceEpoch(
          DateTime.now().millisecondsSinceEpoch,
          isUtc: true,
        ),
      );
      final client = ApiClient();
      addTearDown(client.close);
      final repository = ApiAuditRepository(client);
      await repository.send(event);
      await repository.send(event);
      final matching = (await repository.history()).where(
        (e) => e.eventId == event.eventId,
      );
      expect(matching.length, 1);
      expect(matching.single.toJson(), event.toJson());
    },
    skip:
        Platform.environment['HUDU_API_SMOKE'] != 'true' ||
        (!Platform.isMacOS && !Platform.isWindows),
    timeout: const Timeout(Duration(seconds: 50)),
  );
}
