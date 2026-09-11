import 'dart:convert';
import 'dart:io';

import 'package:desktop_core/desktop_core.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

abstract interface class AuditRepository {
  Future<List<AuditEvent>> history();
  Future<void> send(AuditEvent event);
}

class ApiAuditRepository implements AuditRepository {
  ApiAuditRepository(this.client);
  final ApiClient client;
  @override
  Future<List<AuditEvent>> history() async {
    final response = await client.get(
      '/process_events',
      query: {'limit': '30', 'offset': '0'},
    );
    final rows = response['data'];
    if (rows is! List) throw _invalidResponse;
    return rows.map(_event).toList();
  }

  @override
  Future<void> send(AuditEvent event) async {
    final response = await client.post('/process_events', event.toJson());
    final accepted = _event(response['data']);
    if (accepted.eventId != event.eventId ||
        accepted.pid != event.pid ||
        accepted.processName != event.processName ||
        accepted.occurredAt.millisecondsSinceEpoch !=
            event.occurredAt.millisecondsSinceEpoch) {
      throw const ProcessFailure(
        'The audit response did not match the queued event. It remains pending.',
      );
    }
  }

  static const _invalidResponse = ApiException(
    'The API returned an invalid audit record.',
    code: 'invalid_response',
  );

  static AuditEvent _event(Object? row) {
    if (row is! Map<String, dynamic>) throw _invalidResponse;
    try {
      return AuditEvent.fromJson(row);
    } on FormatException {
      throw _invalidResponse;
    }
  }
}

abstract interface class AuditOutbox {
  Future<void> prepare();
  Future<List<AuditEvent>> load();
  Future<void> put(AuditEvent event);
  Future<void> remove(String eventId);
}

/// One immutable file per confirmed event avoids replacing a shared queue.
/// An interrupted rename is recovered from its fully written .pending file.
class FileAuditOutbox implements AuditOutbox {
  FileAuditOutbox(this.directory);
  final Future<Directory> Function() directory;
  static Future<Directory> applicationDirectory() async => Directory(
    '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}audit-outbox',
  );
  Future<Directory> _directory() async =>
      (await directory()).create(recursive: true);
  String _safeId(String id) {
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id)) {
      throw const FormatException('Invalid outbox event ID');
    }
    return id;
  }

  Future<File> _file(String id, String suffix) async => File(
    '${(await _directory()).path}${Platform.pathSeparator}${_safeId(id)}.$suffix',
  );
  @override
  Future<void> prepare() async {
    final dir = await _directory();
    final probeDir = await dir.createTemp('.write-check-');
    final probe = File('${probeDir.path}${Platform.pathSeparator}probe');
    try {
      await probe.writeAsString('ready', flush: true);
    } finally {
      if (await probe.exists()) await probe.delete();
      await probeDir.delete();
    }
  }

  @override
  Future<List<AuditEvent>> load() async {
    final events = <String, AuditEvent>{};
    await for (final entry in (await _directory()).list()) {
      if (entry is! File ||
          !(entry.path.endsWith('.json') || entry.path.endsWith('.pending'))) {
        continue;
      }
      try {
        final event = AuditEvent.fromJson(
          jsonDecode(await entry.readAsString()) as Map<String, dynamic>,
        );
        _safeId(event.eventId);
        if (!entry.path.endsWith('${event.eventId}.json') &&
            !entry.path.endsWith('${event.eventId}.pending')) {
          throw const FormatException();
        }
        events[event.eventId] = event;
      } catch (_) {
        throw const ProcessFailure(
          'A local audit file could not be read. Preserve the outbox files and repair storage before terminating more processes.',
        );
      }
    }
    return events.values.toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  }

  @override
  Future<void> put(AuditEvent event) async {
    final finalFile = await _file(event.eventId, 'json');
    if (await finalFile.exists()) {
      if (await finalFile.readAsString() != jsonEncode(event.toJson())) {
        throw const ProcessFailure(
          'A different local event has the same ID. Audit delivery paused.',
        );
      }
      return;
    }
    final pending = await _file(event.eventId, 'pending');
    await pending.writeAsString(jsonEncode(event.toJson()), flush: true);
    await pending.rename(finalFile.path);
  }

  @override
  Future<void> remove(String eventId) async {
    for (final suffix in ['json', 'pending']) {
      final file = await _file(eventId, suffix);
      if (await file.exists()) await file.delete();
    }
  }
}
