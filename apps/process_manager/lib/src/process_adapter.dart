import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models.dart';

abstract interface class ProcessAdapter {
  Future<List<LocalProcess>> list();
  Future<ExitOutcome> terminate(LocalProcess process);
}

typedef CommandRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// Kills only its own helper on timeout, never a listed process.
Future<ProcessResult> runBounded(
  String executable,
  List<String> arguments,
) async {
  final Process child;
  try {
    child = await Process.start(
      executable,
      arguments,
      environment: {'LC_ALL': 'C', 'LANG': 'C'},
    );
  } on ProcessException {
    throw const ProcessFailure(
      'Cannot start the system process utility. Check OS permissions and installation.',
    );
  }
  final output = child.stdout.transform(utf8.decoder).join();
  final errors = child.stderr.transform(utf8.decoder).join();
  try {
    return await (() async => ProcessResult(
      child.pid,
      await child.exitCode,
      await output,
      await errors,
    ))().timeout(const Duration(seconds: 12));
  } on TimeoutException {
    child.kill(ProcessSignal.sigkill);
    throw const ProcessFailure(
      'The operating system took too long to respond. Try refreshing.',
    );
  }
}

class MacProcessAdapter implements ProcessAdapter {
  MacProcessAdapter({
    CommandRunner? runner,
    bool Function(int, ProcessSignal)? signal,
    int? ownPid,
    this.exitTimeout = const Duration(seconds: 4),
  }) : _run = runner ?? runBounded,
       _signal = signal ?? Process.killPid,
       _ownPid = ownPid ?? pid;
  final CommandRunner _run;
  final bool Function(int, ProcessSignal) _signal;
  final int _ownPid;
  final Duration exitTimeout;

  /// Unrecognized lines are skipped so one odd entry cannot hide every process;
  /// output with no recognizable row at all is an error.
  static List<LocalProcess> parse(String output) {
    final rows = <LocalProcess>[];
    final pattern = RegExp(
      r'^\s*(\d+)\s+([A-Za-z]{3}\s+[A-Za-z]{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}\s+\d{4})\s+(\S+)\s+(.+)$',
    );
    for (final line in const LineSplitter().convert(output)) {
      final match = pattern.firstMatch(line);
      if (match == null) continue;
      final command = match[4]!.trim();
      rows.add(
        LocalProcess(
          pid: int.parse(match[1]!),
          name: command.split('/').last,
          identity: '${match[2]!.replaceAll(RegExp(r'\s+'), ' ')}|$command',
          status: match[3]!.contains('Z') ? 'Exited' : 'Running',
        ),
      );
    }
    if (rows.isEmpty && output.trim().isNotEmpty) {
      throw const ProcessFailure(
        'Unexpected process data from macOS. The list was not updated.',
      );
    }
    return rows;
  }

  Future<List<LocalProcess>> _read(List<String> scope) async {
    final result = await _run('/bin/ps', [
      ...scope,
      '-o',
      'pid=,lstart=,stat=,comm=',
    ]);
    if (result.exitCode == 1 &&
        result.stdout.toString().trim().isEmpty &&
        scope.first == '-p') {
      return [];
    }
    if (result.exitCode != 0) {
      throw const ProcessFailure(
        'macOS could not read the process list. Check your local permissions.',
      );
    }
    return parse(result.stdout as String);
  }

  @override
  Future<List<LocalProcess>> list() => _read(['-ax']);

  @override
  Future<ExitOutcome> terminate(LocalProcess process) async {
    if (process.pid <= 0 || process.pid == _ownPid) {
      return ExitOutcome.forbidden;
    }
    if (process.identity == null) return ExitOutcome.accessDenied;
    final current = await _read(['-p', '${process.pid}']);
    if (current.isEmpty || current.first.status == 'Exited') {
      return ExitOutcome.alreadyExited;
    }
    if (!current.first.sameIdentity(process)) {
      return ExitOutcome.identityChanged;
    }
    // PID reuse between ps and kill is unavoidable; ps timestamps have
    // one-second precision. Never claim atomic identity validation on macOS.
    bool sent;
    try {
      sent = _signal(process.pid, ProcessSignal.sigterm);
    } on ProcessException {
      return ExitOutcome.accessDenied;
    }
    if (!sent) {
      final remaining = await _read(['-p', '${process.pid}']);
      return remaining.isEmpty
          ? ExitOutcome.alreadyExited
          : ExitOutcome.accessDenied;
    }
    final timer = Stopwatch()..start();
    while (timer.elapsed < exitTimeout) {
      List<LocalProcess> remaining;
      try {
        remaining = await _read(['-p', '${process.pid}'])
            .timeout(exitTimeout - timer.elapsed);
      } on TimeoutException {
        return ExitOutcome.notExiting;
      }
      if (remaining.isEmpty ||
          remaining.first.identity?.split('|').first !=
              process.identity?.split('|').first ||
          remaining.first.status == 'Exited') {
        return ExitOutcome.terminated;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return ExitOutcome.notExiting;
  }
}
