import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:network_lookup/src/network/network_adapter.dart';

// Controlled process contract only: none of these deadline tests start an OS
// process, use a real PID, or wait on wall-clock time. They run on Windows too.
class ControlledProcess implements Process {
  ControlledProcess({this.acceptKill = true}) {
    output.onCancel = () {
      stdoutCancelled = true;
    };
    errors.onCancel = () {
      stderrCancelled = true;
    };
  }
  final bool acceptKill;
  bool stdoutCancelled = false, stderrCancelled = false;
  final output = StreamController<List<int>>();
  final errors = StreamController<List<int>>();
  final exit = Completer<int>();
  int killCalls = 0;
  @override
  Stream<List<int>> get stdout => output.stream;
  @override
  Stream<List<int>> get stderr => errors.stream;
  @override
  Future<int> get exitCode => exit.future;
  @override
  int get pid => throw UnsupportedError('No native process');
  @override
  IOSink get stdin => throw UnsupportedError('No input required');
  void complete({String text = '', String error = '', int code = 0}) {
    output.add(utf8.encode(text));
    errors.add(utf8.encode(error));
    exit.complete(code);
    output.close();
    errors.close();
  }

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killCalls++;
    if (!acceptKill) return false;
    if (!exit.isCompleted) complete(code: -1);
    return true;
  }
}

class ManualStopwatch extends Stopwatch {
  Duration time = Duration.zero;
  @override
  Duration get elapsed => time;
  @override
  void start() {}
}

class BudgetRunner implements CommandRunner {
  BudgetRunner(this.clock, {this.firstDuration = const Duration(seconds: 12)});
  final ManualStopwatch clock;
  final Duration firstDuration;
  final budgets = <Duration>[];
  @override
  Future<String> run(
    String executable,
    List<String> arguments, {
    Duration? timeout,
  }) async {
    budgets.add(timeout!);
    if (arguments.last == NativeNetworkAdapter.interfaceScript) {
      clock.time += firstDuration;
      return '[{"name":"4","label":"Ethernet","ip":"192.168.1.8",'
          '"mac":"02-11-22-33-44-55","primary":true}]';
    }
    return '[{"IPAddress":"192.168.1.1","LinkLayerAddress":"00-1B-63-04-05-E6",'
        '"InterfaceIndex":4,"State":"Reachable"}]';
  }
}

void main() {
  test('Windows discovery shares 30s across cold interface and warm neighbor reads', () async {
    final clock = ManualStopwatch();
    final runner = BudgetRunner(clock);
    final adapter = NativeNetworkAdapter(
      runner: runner,
      operatingSystem: 'windows',
      stopwatchFactory: () => clock,
    );
    final result = await adapter.resolve('192.168.1.1');
    expect(result.mac, '00:1B:63:04:05:E6');
    expect(runner.budgets, [
      const Duration(seconds: 30),
      const Duration(seconds: 18),
    ]);
  });
  test(
    'exhausted operation deadline never starts a second command or retries',
    () async {
      final clock = ManualStopwatch();
      final runner = BudgetRunner(
        clock,
        firstDuration: const Duration(seconds: 30),
      );
      final adapter = NativeNetworkAdapter(
        runner: runner,
        operatingSystem: 'windows',
        stopwatchFactory: () => clock,
      );
      await expectLater(
        adapter.resolve('192.168.1.1'),
        throwsA(isA<NetworkFailure>()),
      );
      expect(runner.budgets, [const Duration(seconds: 30)]);
    },
  );
  test('macOS keeps eight-second command budgets', () async {
    final clock = ManualStopwatch();
    final runner = BudgetRunner(clock);
    final adapter = NativeNetworkAdapter(
      runner: runner,
      operatingSystem: 'macos',
      stopwatchFactory: () => clock,
    );
    // Only inspect the timeout argument; JSON is deliberately not macOS output.
    await expectLater(adapter.interfaces(), throwsA(isA<NetworkFailure>()));
    expect(runner.budgets, [
      const Duration(seconds: 8),
      const Duration(seconds: 8),
    ]);
  });
  testWidgets(
    'cold process startup may pass eight seconds and still complete once',
    (tester) async {
      final child = ControlledProcess();
      final startup = Completer<Process>();
      var starts = 0;
      final runner = NativeCommandRunner(
        startProcess: (_, _) {
          starts++;
          return startup.future;
        },
      );
      String? result;
      final request = runner
          .run(
            'test',
            [],
            timeout: NativeNetworkAdapter.windowsDiscoveryTimeout,
          )
          .then((value) => result = value);
      await tester.pump(const Duration(seconds: 12));
      expect(result, isNull);
      expect(child.killCalls, 0);
      startup.complete(child);
      await tester.pump();
      child.complete(text: '[]');
      await tester.pump();
      await request;
      expect(result, '[]');
      expect(starts, 1);
    },
  );
  testWidgets(
    'running process is stopped at 30 seconds, including startup time',
    (tester) async {
      final child = ControlledProcess();
      final startup = Completer<Process>();
      final runner = NativeCommandRunner(
        startProcess: (_, _) => startup.future,
      );
      Object? failure;
      final request = runner
          .run(
            'test',
            [],
            timeout: NativeNetworkAdapter.windowsDiscoveryTimeout,
          )
          .then<void>(
            (_) => fail('Hung process succeeded'),
            onError: (Object error) {
              failure = error;
            },
          );
      await tester.pump(const Duration(seconds: 12));
      startup.complete(child);
      await tester.pump();
      await tester.pump(const Duration(seconds: 17));
      expect(child.killCalls, 0);
      child.output.add(utf8.encode('Partial output does not renew the budget'));
      await tester.pump(const Duration(seconds: 1));
      await request;
      expect(failure, isA<NetworkFailure>());
      expect(child.killCalls, greaterThan(0));
      expect(child.stdoutCancelled, isTrue);
      expect(child.stderrCancelled, isTrue);
    },
  );
  testWidgets(
    'late process creation after timeout is cleaned up, without retry',
    (tester) async {
      final child = ControlledProcess();
      final startup = Completer<Process>();
      var starts = 0;
      final runner = NativeCommandRunner(
        startProcess: (_, _) {
          starts++;
          return startup.future;
        },
      );
      Object? failure;
      final request = runner
          .run('test', [], timeout: const Duration(seconds: 30))
          .then<void>(
            (_) => fail('Late startup succeeded'),
            onError: (Object error) {
              failure = error;
            },
          );
      await tester.pump(const Duration(seconds: 30));
      await request;
      expect(failure, isA<NetworkFailure>());
      child.output.add(utf8.encode('Buffered before Process.start returned'));
      child.errors.add(utf8.encode('Buffered stderr'));
      startup.complete(child);
      await tester.pump();
      expect(child.killCalls, 1);
      expect(starts, 1);
      expect(child.stdoutCancelled, isTrue);
      expect(child.stderrCancelled, isTrue);
    },
  );
  testWidgets(
    'failed cleanup returns a bounded timeout and releases both pipes',
    (tester) async {
      final child = ControlledProcess(acceptKill: false);
      final runner = NativeCommandRunner(startProcess: (_, _) async => child);
      Object? failure;
      final request = runner
          .run('test', [], timeout: const Duration(seconds: 30))
          .then<void>(
            (_) => fail('Hung process succeeded'),
            onError: (Object error) {
              failure = error;
            },
          );
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
      await request;
      expect(child.killCalls, greaterThan(0));
      expect(child.stdoutCancelled, isTrue);
      expect(child.stderrCancelled, isTrue);
      expect(
        failure,
        isA<NetworkFailure>().having(
          (e) => e.message,
          'truthful timeout',
          'Reading network information timed out. Please try again.',
        ),
      );
      child.complete();
      await tester.pump();
    },
  );
  testWidgets(
    'permission errors still fail immediately with a longer deadline',
    (tester) async {
      final child = ControlledProcess();
      final runner = NativeCommandRunner(startProcess: (_, _) async => child);
      Object? failure;
      final request = runner
          .run('test', [], timeout: const Duration(seconds: 30))
          .then<void>(
            (_) => fail('Permission error succeeded'),
            onError: (Object error) {
              failure = error;
            },
          );
      await tester.pump();
      child.complete(error: 'Access denied', code: 1);
      await tester.pump();
      await request;
      expect(
        failure,
        isA<NetworkFailure>().having(
          (e) => e.message,
          'OS error',
          contains('permissions'),
        ),
      );
    },
  );
}
