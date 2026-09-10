import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'models.dart';
import 'process_adapter.dart';

abstract interface class WindowsProcessApi {
  int open(int pid);
  int get lastError;
  String? creationTime(int handle);
  bool terminate(int handle);
  int wait(int handle, int milliseconds);
  void close(int handle);
}

final class NativeFileTime extends Struct {
  @Uint32()
  external int low;
  @Uint32()
  external int high;
}

class KernelProcessApi implements WindowsProcessApi {
  final DynamicLibrary _dll = DynamicLibrary.open('kernel32.dll');
  late final _open = _dll
      .lookupFunction<
        IntPtr Function(Uint32, Int32, Uint32),
        int Function(int, int, int)
      >('OpenProcess');
  late final _error = _dll.lookupFunction<Uint32 Function(), int Function()>(
    'GetLastError',
  );
  late final _times = _dll
      .lookupFunction<
        Int32 Function(
          IntPtr,
          Pointer<NativeFileTime>,
          Pointer<NativeFileTime>,
          Pointer<NativeFileTime>,
          Pointer<NativeFileTime>,
        ),
        int Function(
          int,
          Pointer<NativeFileTime>,
          Pointer<NativeFileTime>,
          Pointer<NativeFileTime>,
          Pointer<NativeFileTime>,
        )
      >('GetProcessTimes');
  late final _terminate = _dll
      .lookupFunction<Int32 Function(IntPtr, Uint32), int Function(int, int)>(
        'TerminateProcess',
      );
  late final _wait = _dll
      .lookupFunction<Uint32 Function(IntPtr, Uint32), int Function(int, int)>(
        'WaitForSingleObject',
      );
  late final _close = _dll
      .lookupFunction<Int32 Function(IntPtr), int Function(int)>('CloseHandle');
  @override
  int open(int pid) => _open(0x00100000 | 0x1000 | 0x0001, 0, pid); // SYNCHRONIZE | QUERY_LIMITED_INFORMATION | TERMINATE
  @override
  int get lastError => _error();
  @override
  String? creationTime(int handle) {
    final times = calloc<NativeFileTime>(4);
    try {
      if (_times(handle, times, times + 1, times + 2, times + 3) == 0) {
        return null;
      }
      return ((BigInt.from(times.ref.high) << 32) | BigInt.from(times.ref.low))
          .toString();
    } finally {
      calloc.free(times);
    }
  }

  @override
  bool terminate(int handle) => _terminate(handle, 1) != 0;
  @override
  int wait(int handle, int milliseconds) => _wait(handle, milliseconds);
  @override
  void close(int handle) {
    _close(handle);
  }
}

ExitOutcome terminateWindows(
  LocalProcess process,
  WindowsProcessApi api,
  int ownPid,
) {
  if (process.pid <= 0 || process.pid == ownPid || process.pid > 0xffffffff) {
    return ExitOutcome.forbidden;
  }
  if (process.identity == null) return ExitOutcome.accessDenied;
  final handle = api.open(process.pid);
  if (handle == 0) {
    return api.lastError == 87
        ? ExitOutcome.alreadyExited
        : ExitOutcome.accessDenied;
  }
  try {
    final initialState = api.wait(handle, 0);
    if (initialState == 0) return ExitOutcome.alreadyExited;
    if (initialState != 258) {
      throw const ProcessFailure(
        'Windows could not inspect process exit state. Termination was refused.',
      );
    }
    final identity = api.creationTime(handle);
    if (identity == null) return ExitOutcome.accessDenied;
    if (identity != process.identity) return ExitOutcome.identityChanged;
    // Validation and termination use this same retained kernel handle.
    if (!api.terminate(handle)) {
      return api.wait(handle, 0) == 0
          ? ExitOutcome.alreadyExited
          : ExitOutcome.accessDenied;
    }
    final result = api.wait(handle, 4000);
    if (result == 0) return ExitOutcome.terminated;
    if (result == 258) return ExitOutcome.notExiting;
    throw const ProcessFailure(
      'Windows could not confirm exit. No audit event was recorded. Refresh to inspect the process.',
    );
  } finally {
    api.close(handle);
  }
}

class WindowsProcessAdapter implements ProcessAdapter {
  WindowsProcessAdapter({CommandRunner? runner}) : _run = runner ?? runBounded;
  final CommandRunner _run;
  static const script =
      r'''$ErrorActionPreference = 'Stop'; [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false); $rows = @(Get-Process | ForEach-Object { $p = $_; $stamp = $null; try { $stamp = $p.StartTime.ToUniversalTime().ToFileTimeUtc().ToString([Globalization.CultureInfo]::InvariantCulture) } catch {}; [pscustomobject]@{ pid = $p.Id; name = $p.ProcessName; identity = $stamp } }); ConvertTo-Json -InputObject $rows -Compress''';
  static List<LocalProcess> parse(String output) {
    try {
      final decoded = jsonDecode(output.replaceFirst('\uFEFF', ''));
      if (decoded is! List) throw const FormatException();
      return decoded
          .map(
            (row) => LocalProcess(
              pid: row['pid'] as int,
              name: row['name'] as String,
              identity: row['identity'] as String?,
              status: row['identity'] == null ? 'Protected' : 'Running',
            ),
          )
          .toList();
    } catch (_) {
      throw const ProcessFailure(
        'Unexpected process data from Windows. The list was not updated.',
      );
    }
  }

  @override
  Future<List<LocalProcess>> list() async {
    final root = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    final result = await _run(
      '$root\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
      ['-NoLogo', '-NoProfile', '-NonInteractive', '-Command', script],
    );
    if (result.exitCode != 0) {
      throw const ProcessFailure(
        'Windows could not read processes. Check PowerShell availability and local permissions.',
      );
    }
    return parse(result.stdout as String);
  }

  @override
  Future<ExitOutcome> terminate(LocalProcess process) {
    final ownPid = pid;
    return Isolate.run(
      () => terminateWindows(process, KernelProcessApi(), ownPid),
    );
  }
}
