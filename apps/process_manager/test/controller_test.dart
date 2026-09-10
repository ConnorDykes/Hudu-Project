import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:process_manager/src/controller.dart';
import 'package:process_manager/src/models.dart';

import 'support/fakes.dart';

void main() {
  late FakeProcesses processes;
  late FakeAudit audit;
  late MemoryOutbox outbox;
  late ProviderContainer container;
  late ManagerController controller;
  setUp(() {
    processes = FakeProcesses();
    audit = FakeAudit();
    outbox = MemoryOutbox();
    container = ProviderContainer(
      overrides: [
        processAdapterProvider.overrideWithValue(processes),
        auditRepositoryProvider.overrideWithValue(audit),
        outboxProvider.overrideWithValue(outbox),
      ],
    );
    controller = container.read(managerProvider.notifier);
  });
  tearDown(() => container.dispose());
  test(
    'older audit retry cannot clear a concurrent memory-only event warning',
    () async {
      final first = sampleEvent();
      outbox.events[first.eventId] = first;
      audit.error = Exception('offline');
      await controller.initialize();
      audit.error = null;
      final sendingFirst = Completer<void>();
      final acceptFirst = Completer<void>();
      audit.onSend = (event) async {
        if (event.eventId == first.eventId) {
          sendingFirst.complete();
          await acceptFirst.future;
        }
      };
      final retry = controller.retryAudits();
      await sendingFirst.future;
      outbox.putFailure = Exception('disk full');
      final selected = processes.rows.first;
      controller.select(selected);
      await controller.terminate(selected);
      final memoryOnly = container.read(managerProvider).pending.last;
      expect(memoryOnly.pid, selected.pid);
      expect(outbox.events.containsKey(memoryOnly.eventId), isFalse);
      expect(
        container.read(managerProvider).storageError,
        contains('could not be saved'),
      );
      acceptFirst.complete();
      await retry;
      expect(
        container.read(managerProvider).pending.single.eventId,
        memoryOnly.eventId,
      );
      expect(
        container.read(managerProvider).storageError,
        contains('could not be saved'),
      );
      final other = processes.rows.first;
      controller.select(other);
      await controller.terminate(other);
      expect(
        processes.kills,
        1,
        reason: 'Memory-only audit must keep termination disabled',
      );
      outbox.putFailure = null;
      audit.onSend = null;
      await controller.retryAudits();
      expect(container.read(managerProvider).pending, isEmpty);
      expect(container.read(managerProvider).storageError, isNull);
      expect(
        audit.records.any((event) => event.eventId == memoryOnly.eventId),
        isTrue,
      );
      expect(processes.kills, 1);
    },
  );
  test(
    'delivery queues a second history GET after an older GET completes',
    () async {
      await controller.initialize();
      final olderGet = Completer<List<AuditEvent>>();
      final newerGet = Completer<List<AuditEvent>>();
      final secondStarted = Completer<void>();
      var requests = 0;
      var active = 0;
      var maxActive = 0;
      audit.onHistory = () async {
        requests++;
        active++;
        if (active > maxActive) maxActive = active;
        try {
          if (requests == 1) return await olderGet.future;
          if (requests == 2) {
            secondStarted.complete();
            return await newerGet.future;
          }
          fail('Unexpected extra history request');
        } finally {
          active--;
        }
      };
      final history = controller.refreshHistory();
      final removed = Completer<void>();
      final subscription = container.listen(managerProvider, (_, next) {
        if (audit.records.isNotEmpty &&
            next.pending.isEmpty &&
            !next.delivering &&
            !removed.isCompleted) {
          removed.complete();
        }
      });
      addTearDown(subscription.close);
      final selected = processes.rows.first;
      controller.select(selected);
      final termination = controller.terminate(selected);
      await removed.future;
      // Drain the delivery continuation that requests fresh history.
      await Future<void>.delayed(Duration.zero);
      expect(container.read(managerProvider).pending, isEmpty);
      expect(requests, 1, reason: 'GETs must not overlap');
      olderGet.complete([]);
      await Future<void>.delayed(Duration.zero);
      expect(
        requests,
        2,
        reason: 'Successful delivery must not lose its history refresh',
      );
      expect(secondStarted.isCompleted, isTrue);
      expect(container.read(managerProvider).historyLoading, isTrue);
      newerGet.complete([...audit.records]);
      await history.timeout(const Duration(seconds: 2));
      await termination.timeout(const Duration(seconds: 2));
      expect(
        requests,
        2,
        reason: 'Successful delivery must not lose its history refresh',
      );
      expect(secondStarted.isCompleted, isTrue);
      expect(maxActive, 1);
      expect(container.read(managerProvider).history.single.pid, selected.pid);
    },
  );
  test(
    'numeric PID ordering, name/PID search, and identity selection',
    () async {
      await controller.initialize();
      controller.sort(true);
      expect(container.read(managerProvider).visible.map((p) => p.pid), [
        128,
        812,
        2280,
        2408,
        4156,
        6340,
        9124,
        10532,
      ]);
      controller.search('WINDOW');
      expect(
        container.read(managerProvider).visible.single.name,
        'WindowServer',
      );
      controller.search('10532');
      expect(container.read(managerProvider).visible.single.name, 'sleep');
      controller.select(processes.rows.first);
      await controller.refresh();
      expect(container.read(managerProvider).selected, isNotNull);
      processes.rows[0] = LocalProcess(
        pid: processes.rows[0].pid,
        name: processes.rows[0].name,
        identity: 'reused',
      );
      await controller.refresh();
      expect(container.read(managerProvider).selected, isNull);
    },
  );
  test('refresh is single flight and keeps stale rows on error', () async {
    await controller.initialize();
    processes.blocked = Completer();
    final refresh = controller.refresh();
    await controller.refresh();
    expect(processes.lists, 2);
    processes.blocked!.complete([...syntheticProcesses]);
    await refresh;
    processes.blocked = null;
    processes.error = Exception('offline');
    await controller.refresh();
    expect(container.read(managerProvider).processError, isNotNull);
    expect(container.read(managerProvider).processes, isNotEmpty);
  });
  test(
    'confirmed exit survives offline API and restart; retry never kills again',
    () async {
      audit.error = Exception('offline');
      await controller.initialize();
      final selected = processes.rows.last;
      controller.select(selected);
      await controller.terminate(selected);
      final event = outbox.events.values.single;
      expect(event.occurredAt.isUtc, isTrue);
      expect(event.occurredAt.microsecond, 0);
      expect(
        container.read(managerProvider).notice,
        contains('Exit confirmed'),
      );
      expect(container.read(managerProvider).auditError, isNotNull);
      expect(processes.kills, 1);
      await controller.retryAudits();
      expect(processes.kills, 1);
      expect(audit.sent.last.toJson(), event.toJson());
      container.dispose();
      audit.error = null;
      container = ProviderContainer(
        overrides: [
          processAdapterProvider.overrideWithValue(processes),
          auditRepositoryProvider.overrideWithValue(audit),
          outboxProvider.overrideWithValue(outbox),
        ],
      );
      await container.read(managerProvider.notifier).initialize();
      expect(outbox.events, isEmpty);
      expect(audit.records.single.toJson(), event.toJson());
      expect(processes.kills, 1);
    },
  );
  for (final outcome in ExitOutcome.values.where(
    (o) => o != ExitOutcome.terminated,
  )) {
    test('$outcome never creates audit event', () async {
      processes.outcome = outcome;
      await controller.initialize();
      final selected = processes.rows.first;
      controller.select(selected);
      await controller.terminate(selected);
      expect(outbox.events, isEmpty);
      expect(audit.sent, isEmpty);
      expect(container.read(managerProvider).notice, isNotEmpty);
    });
  }
  test('unwritable outbox disables termination before OS call', () async {
    outbox.failure = Exception('read only');
    await controller.initialize();
    final selected = processes.rows.first;
    controller.select(selected);
    await controller.terminate(selected);
    expect(processes.kills, 0);
    expect(container.read(managerProvider).storageError, isNotNull);
  });
  test('failed post-exit disk write stays in memory and can recover without another kill', () async {
    await controller.initialize();
    outbox.putFailure = Exception('disk full');
    final selected = processes.rows.first;
    controller.select(selected);
    await controller.terminate(selected);
    expect(processes.kills, 1);
    expect(
      container.read(managerProvider).storageError,
      contains('could not be saved'),
    );
    final original = container.read(managerProvider).pending.single.toJson();
    outbox.putFailure = null;
    await controller.retryAudits();
    expect(processes.kills, 1);
    expect(audit.sent.single.toJson(), original);
    expect(container.read(managerProvider).pending, isEmpty);
    expect(container.read(managerProvider).storageError, isNull);
  });
  test(
    'confirmed exit persists even when UI is disposed during native wait',
    () async {
      await controller.initialize();
      processes.termination = Completer<ExitOutcome>();
      final selected = processes.rows.first;
      controller.select(selected);
      final operation = controller.terminate(selected);
      await Future<void>.delayed(Duration.zero);
      container.dispose();
      processes.termination!.complete(ExitOutcome.terminated);
      await operation;
      expect(outbox.events.values.single.pid, selected.pid);
      expect(audit.sent, isEmpty);
    },
  );
  test('disposed refresh completion is ignored', () async {
    await controller.initialize();
    processes.blocked = Completer();
    final pending = controller.refresh();
    container.dispose();
    processes.blocked!.complete([]);
    await pending;
  });
}
