import 'dart:io';

import 'package:process_manager/src/process_adapter.dart';
import 'package:process_manager/src/windows_process_adapter.dart';

ProcessAdapter nativeAdapter() =>
    Platform.isWindows ? WindowsProcessAdapter() : MacProcessAdapter();

/// No existing machine PID can enter this harness. Its only termination target
/// is the child returned by Process.start below, selected by that child's PID.
Future<Process> spawnDisposableChild() async {
  if (Platform.isWindows) {
    final root = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    return Process.start(
      '$root\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
      [
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        'Start-Sleep -Seconds 60',
      ],
    );
  }
  return Process.start('/bin/sleep', ['60']);
}
