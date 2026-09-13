import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Exit code and decoded standard output of a finished helper command.
class CommandOutput {
  const CommandOutput({required this.exitCode, required this.stdout});
  final int exitCode;
  final String stdout;
}

enum CommandFailureKind {
  /// The executable could not be started (missing, blocked, or denied).
  startupFailed,

  /// The deadline passed before the command started or finished.
  timedOut,

  /// Standard output exceeded the configured byte limit.
  tooMuchOutput,

  /// Standard output was not valid UTF-8.
  unreadableOutput,
}

/// Why a bounded command produced no usable output. Carries no OS text: raw
/// output and error streams can contain private machine information, so each
/// app maps the [kind] to its own wording.
class CommandFailure implements Exception {
  const CommandFailure(this.kind);
  final CommandFailureKind kind;
  @override
  String toString() => 'CommandFailure(${kind.name})';
}

typedef ProcessStarter =
    Future<Process> Function(String executable, List<String> arguments);

/// Starts a direct child process; never a shell.
Future<Process> defaultProcessStarter(
  String executable,
  List<String> arguments,
) => Process.start(executable, arguments, runInShell: false);

/// The full path and fixed flags for Windows PowerShell 5.1, so no app spells
/// them out itself. [script] is a constant; user input is never interpolated.
({String executable, List<String> arguments}) powershellCommand(
  String script,
) {
  final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
  return (
    executable: '$systemRoot\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
    arguments: ['-NoLogo', '-NoProfile', '-NonInteractive', '-Command', script],
  );
}

/// Runs one helper command with a wall-clock deadline that covers process
/// creation as well as output and exit, and a cap on captured output. Only the
/// command's own child is ever terminated. Standard error is drained so the
/// child cannot block on a full pipe, but it is discarded: the exit code alone
/// decides success, because utilities may warn and still succeed.
class BoundedCommandRunner {
  const BoundedCommandRunner({
    this.timeout = const Duration(seconds: 8),
    this.maxOutputBytes = 1024 * 1024,
    this.startProcess = defaultProcessStarter,
  });
  final Duration timeout;
  final int maxOutputBytes;
  final ProcessStarter startProcess;

  Future<CommandOutput> run(
    String executable,
    List<String> arguments, {
    Duration? timeout,
  }) async {
    Process? process;
    final readers = <StreamIterator<List<int>>>[];
    var expired = false;
    try {
      return await (() async {
        final child = await startProcess(executable, arguments);
        process = child;
        if (expired) {
          // Started after the deadline: stop it and release both pipes,
          // including buffered output, without extending the caller's wait.
          try {
            child.kill();
          } finally {
            child.stdout.listen(null).cancel().ignore();
            child.stderr.listen(null).cancel().ignore();
          }
          throw const CommandFailure(CommandFailureKind.timedOut);
        }
        Future<String> read(Stream<List<int>> stream) async {
          final bytes = <int>[];
          final reader = StreamIterator(stream);
          readers.add(reader);
          while (await reader.moveNext()) {
            final chunk = reader.current;
            if (bytes.length + chunk.length > maxOutputBytes) {
              throw const CommandFailure(CommandFailureKind.tooMuchOutput);
            }
            bytes.addAll(chunk);
          }
          return utf8.decode(bytes, allowMalformed: false);
        }

        final results = await Future.wait<Object>([
          child.exitCode,
          read(child.stdout),
          read(child.stderr),
        ], eagerError: true);
        return CommandOutput(
          exitCode: results[0] as int,
          stdout: results[1] as String,
        );
      })().timeout(
        timeout ?? this.timeout,
        onTimeout: () {
          expired = true;
          throw TimeoutException('Native command deadline exceeded');
        },
      );
    } on TimeoutException {
      throw const CommandFailure(CommandFailureKind.timedOut);
    } on ProcessException {
      throw const CommandFailure(CommandFailureKind.startupFailed);
    } on FormatException {
      throw const CommandFailure(CommandFailureKind.unreadableOutput);
    } finally {
      // Only our own disposable command process can be terminated here.
      // Cancellation also releases pipes if the OS refuses termination.
      try {
        process?.kill();
      } finally {
        for (final reader in readers) {
          reader.cancel().ignore();
        }
      }
    }
  }
}
