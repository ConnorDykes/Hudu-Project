import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:process_manager/src/models.dart';
import 'package:process_manager/src/process_adapter.dart';
import 'package:process_manager/src/windows_process_adapter.dart';

const psRow =
    '  123 Thu Sep 10 12:03:04 2026 S /Applications/Example App/worker ü\n';

class FakeWindowsApi implements WindowsProcessApi {
  final calls = <String>[];
  String? identity = '123456';
  bool success = true;
  int waitResult = 0;
  int initialWait = 258;
  int handle = 42;
  @override
  int lastError = 5;
  @override
  int open(int pid) {
    calls.add('open:$pid');
    return handle;
  }

  @override
  String? creationTime(int handle) {
    calls.add('identity:$handle');
    return identity;
  }

  @override
  bool terminate(int handle) {
    calls.add('terminate:$handle');
    return success;
  }

  @override
  int wait(int handle, int milliseconds) {
    calls.add('wait:$handle:$milliseconds');
    return milliseconds == 0 ? initialWait : waitResult;
  }

  @override
  void close(int handle) {
    calls.add('close:$handle');
  }
}

void main() {
  test('Windows wait failure refuses termination and closes handle', () {
    final api = FakeWindowsApi()..initialWait = 0xffffffff;
    expect(
      () => terminateWindows(
        const LocalProcess(pid: 123, name: 'worker', identity: '123456'),
        api,
        999,
      ),
      throwsException,
    );
    expect(api.calls.where((s) => s.startsWith('terminate')), isEmpty);
    expect(api.calls.last, 'close:42');
  });
  test(
    'macOS parser preserves spaced unicode names and normalizes timestamp',
    () {
      final process = MacProcessAdapter.parse(psRow).single;
      expect(process.pid, 123);
      expect(process.name, 'worker ü');
      expect(
        process.identity,
        'Thu Sep 10 12:03:04 2026|/Applications/Example App/worker ü',
      );
      expect(MacProcessAdapter.parse(''), isEmpty);
      expect(() => MacProcessAdapter.parse('malformed'), throwsException);
      expect(
        MacProcessAdapter.parse('ps: warning line\n$psRow').single.pid,
        123,
        reason: 'One unrecognized line must not hide the whole process list',
      );
    },
  );
  test('Windows JSON handles null inaccessible identity and Unicode', () {
    final rows = WindowsProcessAdapter.parse(
      '[{"pid":10,"name":"worker ü","identity":"123456"},{"pid":4,"name":"System","identity":null}]',
    );
    expect(rows.first.name, 'worker ü');
    expect(rows.last.identity, isNull);
    expect(rows.last.status, 'Protected');
    expect(() => WindowsProcessAdapter.parse('{}'), throwsException);
  });
  test('macOS refuses reused identity without signaling', () async {
    var signals = 0;
    final adapter = MacProcessAdapter(
      ownPid: 999,
      runner: (_, args) async {
        expect(args, ['-p', '123', '-o', 'pid=,lstart=,stat=,comm=']);
        return ProcessResult(
          9,
          0,
          psRow.replaceFirst('12:03:04', '12:03:05'),
          '',
        );
      },
      signal: (_, _) {
        signals++;
        return true;
      },
    );
    expect(
      await adapter.terminate(MacProcessAdapter.parse(psRow).single),
      ExitOutcome.identityChanged,
    );
    expect(signals, 0);
  });
  test(
    'macOS SIGTERM requires observed exit and forbids self/nonpositive',
    () async {
      var reads = 0, signals = 0;
      final adapter = MacProcessAdapter(
        ownPid: 999,
        runner: (_, _) async =>
            ProcessResult(9, reads++ == 0 ? 0 : 1, reads == 1 ? psRow : '', ''),
        signal: (pid, signal) {
          expect(pid, 123);
          expect(signal, ProcessSignal.sigterm);
          signals++;
          return true;
        },
      );
      expect(
        await adapter.terminate(MacProcessAdapter.parse(psRow).single),
        ExitOutcome.terminated,
      );
      expect(signals, 1);
      for (final pid in [-1, 0, 999]) {
        expect(
          await adapter.terminate(
            LocalProcess(pid: pid, name: 'self', identity: 'x'),
          ),
          ExitOutcome.forbidden,
        );
      }
      expect(signals, 1);
    },
  );
  test(
    'macOS handles already exited, permission denial, and non-exit',
    () async {
      final selected = MacProcessAdapter.parse(psRow).single;
      final exited = MacProcessAdapter(
        runner: (_, _) async => ProcessResult(1, 1, '', ''),
        signal: (_, _) => throw StateError('must not signal'),
      );
      expect(await exited.terminate(selected), ExitOutcome.alreadyExited);
      final denied = MacProcessAdapter(
        runner: (_, _) async => ProcessResult(1, 0, psRow, ''),
        signal: (_, _) => false,
      );
      expect(await denied.terminate(selected), ExitOutcome.accessDenied);
      final stubborn = MacProcessAdapter(
        exitTimeout: const Duration(milliseconds: 1),
        runner: (_, _) async => ProcessResult(1, 0, psRow, ''),
        signal: (_, _) => true,
      );
      expect(await stubborn.terminate(selected), ExitOutcome.notExiting);
    },
  );
  test(
    'macOS executable rename after signal is not mistaken for exit',
    () async {
      var reads = 0;
      final adapter = MacProcessAdapter(
        exitTimeout: const Duration(milliseconds: 1),
        runner: (_, _) async => ProcessResult(
          1,
          0,
          reads++ == 0
              ? psRow
              : psRow.replaceFirst('worker ü', 'new executable'),
          '',
        ),
        signal: (_, _) => true,
      );
      expect(
        await adapter.terminate(MacProcessAdapter.parse(psRow).single),
        ExitOutcome.notExiting,
      );
    },
  );
  test('Windows verifies, terminates and observes exit using same handle; closes it', () {
    final api = FakeWindowsApi();
    const process = LocalProcess(pid: 123, name: 'worker', identity: '123456');
    expect(terminateWindows(process, api, 999), ExitOutcome.terminated);
    expect(api.calls, [
      'open:123',
      'wait:42:0',
      'identity:42',
      'terminate:42',
      'wait:42:4000',
      'close:42',
    ]);
  });
  test(
    'Windows changed identity never calls termination and still closes handle',
    () {
      final api = FakeWindowsApi()..identity = 'different';
      expect(
        terminateWindows(
          const LocalProcess(pid: 123, name: 'worker', identity: '123456'),
          api,
          999,
        ),
        ExitOutcome.identityChanged,
      );
      expect(api.calls.where((s) => s.startsWith('terminate')), isEmpty);
      expect(api.calls.last, 'close:42');
    },
  );
  test(
    'Windows access failure, already exited, wait timeout, self safeguards',
    () {
      const process = LocalProcess(
        pid: 123,
        name: 'worker',
        identity: '123456',
      );
      expect(
        terminateWindows(process, FakeWindowsApi()..handle = 0, 999),
        ExitOutcome.accessDenied,
      );
      expect(
        terminateWindows(process, FakeWindowsApi()..initialWait = 0, 999),
        ExitOutcome.alreadyExited,
      );
      expect(
        terminateWindows(process, FakeWindowsApi()..waitResult = 258, 999),
        ExitOutcome.notExiting,
      );
      final api = FakeWindowsApi();
      expect(terminateWindows(process, api, 123), ExitOutcome.forbidden);
      expect(api.calls, isEmpty);
    },
  );
}
