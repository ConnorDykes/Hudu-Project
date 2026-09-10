import 'dart:async';

import 'package:process_manager/src/audit_repository.dart';
import 'package:process_manager/src/models.dart';
import 'package:process_manager/src/process_adapter.dart';

const syntheticProcesses = [
  LocalProcess(pid: 2408, name: 'Activity Monitor', identity: 'sample-1'),
  LocalProcess(pid: 812, name: 'WindowServer', identity: 'sample-2'),
  LocalProcess(pid: 9124, name: 'design-preview', identity: 'sample-3'),
  LocalProcess(pid: 4156, name: 'flutter', identity: 'sample-4'),
  LocalProcess(pid: 128, name: 'launchd', identity: 'sample-5'),
  LocalProcess(pid: 6340, name: 'rails', identity: 'sample-6'),
  LocalProcess(pid: 10532, name: 'sleep', identity: 'sample-7'),
  LocalProcess(pid: 2280, name: 'terminal', identity: 'sample-8'),
];
AuditEvent sampleEvent() => AuditEvent(
  eventId: '09b0ec53-d806-4e90-b279-0444dca1b543',
  processName: 'sample-worker',
  pid: 7000,
  occurredAt: DateTime.utc(2026, 9, 10, 18, 30),
);

class FakeProcesses implements ProcessAdapter {
  List<LocalProcess> rows = [...syntheticProcesses];
  int kills = 0, lists = 0;
  Object? error;
  Completer<List<LocalProcess>>? blocked;
  Completer<ExitOutcome>? termination;
  ExitOutcome outcome = ExitOutcome.terminated;
  @override
  Future<List<LocalProcess>> list() async {
    lists++;
    if (error != null) throw error!;
    if (blocked != null) return blocked!.future;
    return [...rows];
  }

  @override
  Future<ExitOutcome> terminate(LocalProcess process) async {
    kills++;
    if (termination != null) return termination!.future;
    if (outcome == ExitOutcome.terminated) {
      rows.removeWhere(process.sameIdentity);
    }
    return outcome;
  }
}

class FakeAudit implements AuditRepository {
  Object? error;
  Future<List<AuditEvent>> Function()? onHistory;
  Future<void> Function(AuditEvent)? onSend;
  final List<AuditEvent> sent = [];
  List<AuditEvent> records = [];
  @override
  Future<List<AuditEvent>> history() async {
    if (error != null) throw error!;
    if (onHistory != null) return onHistory!();
    return [...records];
  }

  @override
  Future<void> send(AuditEvent event) async {
    sent.add(event);
    if (error != null) throw error!;
    if (onSend != null) await onSend!(event);
    records = [event, ...records.where((e) => e.eventId != event.eventId)];
  }
}

class MemoryOutbox implements AuditOutbox {
  final Map<String, AuditEvent> events = {};
  Object? failure;
  Object? putFailure;
  @override
  Future<void> prepare() async {
    if (failure != null) throw failure!;
  }

  @override
  Future<List<AuditEvent>> load() async => events.values.toList();
  @override
  Future<void> put(AuditEvent event) async {
    if (failure != null) throw failure!;
    if (putFailure != null) throw putFailure!;
    events[event.eventId] = event;
  }

  @override
  Future<void> remove(String eventId) async {
    events.remove(eventId);
  }
}
