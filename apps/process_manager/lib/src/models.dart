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

class ProcessFailure implements Exception {
  const ProcessFailure(this.message);
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
  factory AuditEvent.fromJson(Map<String, dynamic> json) => AuditEvent(
    eventId: json['event_id'] as String,
    processName: json['process_name'] as String,
    pid: json['pid'] as int,
    occurredAt: DateTime.parse(json['occurred_at'] as String).toUtc(),
  );
}
