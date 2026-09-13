import 'package:desktop_core/desktop_core.dart';

class LocalProcess {
  const LocalProcess({
    required this.pid,
    required this.name,
    required this.identity,
    this.status = 'Running',
  });
  final int pid;
  final String name;

  /// OS creation time; null means the OS denied identity access.
  final String? identity;
  final String status;
  bool sameIdentity(LocalProcess other) =>
      pid == other.pid &&
      identity != null &&
      identity == other.identity &&
      name == other.name;
}

enum ExitOutcome {
  terminated,
  alreadyExited,
  identityChanged,
  accessDenied,
  notExiting,
  forbidden,
}

class ProcessFailure implements UserFacingFailure {
  const ProcessFailure(this.message);
  @override
  final String message;
  @override
  String toString() => message;
}

class AuditEvent {
  const AuditEvent({
    required this.eventId,
    required this.processName,
    required this.pid,
    required this.occurredAt,
  });
  final String eventId, processName;
  final int pid;
  final DateTime occurredAt;
  Map<String, dynamic> toJson() => {
    'event_id': eventId,
    'process_name': processName,
    'pid': pid,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
  };

  /// Throws [FormatException] for any shape the contract does not allow.
  factory AuditEvent.fromJson(Map<String, dynamic> json) {
    final eventId = json['event_id'];
    final processName = json['process_name'];
    final pid = json['pid'];
    final occurredAt = json['occurred_at'];
    if (eventId is! String ||
        processName is! String ||
        pid is! int ||
        pid <= 0 ||
        occurredAt is! String) {
      throw const FormatException('Invalid audit event');
    }
    return AuditEvent(
      eventId: eventId,
      processName: processName,
      pid: pid,
      occurredAt: DateTime.parse(occurredAt).toUtc(),
    );
  }
}
