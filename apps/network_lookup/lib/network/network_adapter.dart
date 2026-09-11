import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// IPv4 only. Canonical decimal avoids platform-dependent octal interpretation.
String? canonicalIpv4(String input) {
  final parts = input.trim().split('.');
  if (parts.length != 4 ||
      parts.any(
        (part) =>
            !RegExp(r'^(0|[1-9][0-9]{0,2})$').hasMatch(part) ||
            int.parse(part) > 255,
      )) {
    return null;
  }
  return parts.join('.');
}

/// macOS arp may print abbreviated octets, for example 0:1b:63:4:5:e6.
String? normalizeMac(String? input) {
  if (input == null) return null;
  final value = input.trim();
  final List<String> parts;
  if (RegExp(r'^[0-9a-fA-F]{12}$').hasMatch(value)) {
    parts = [for (var i = 0; i < 12; i += 2) value.substring(i, i + 2)];
  } else {
    parts = value.replaceAll('-', ':').split(':');
  }
  if (parts.length != 6 ||
      parts.any((p) => !RegExp(r'^[0-9a-fA-F]{1,2}$').hasMatch(p))) {
    return null;
  }
  final mac = parts.map((p) => p.padLeft(2, '0').toUpperCase()).join(':');
  // All-zero, broadcast and multicast addresses are not a device identity.
  if (mac == '00:00:00:00:00:00' ||
      (int.parse(parts.first, radix: 16) & 1) != 0) {
    return null;
  }
  return mac;
}

class NetworkFailure implements Exception {
  const NetworkFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class LocalInterface {
  const LocalInterface({
    required this.name,
    required this.ip,
    this.mac,
    this.primary = false,
    this.label,
  });
  final String name, ip;
  final String? mac, label;
  final bool primary;
  String get displayName => label ?? name;
}

class InterfaceSnapshot {
  const InterfaceSnapshot(this.interfaces, {this.notice});
  final List<LocalInterface> interfaces;
  final String? notice;
  LocalInterface? get preferred {
    for (final interface in interfaces) {
      if (interface.primary) return interface;
    }
    return interfaces.isEmpty ? null : interfaces.first;
  }
}

class NeighborEntry {
  const NeighborEntry(this.ip, this.mac, this.interfaceName);
  final String ip, mac, interfaceName;
}

class LocalResolution {
  const LocalResolution({
    required this.ip,
    required this.mac,
    required this.interfaceName,
    required this.isOwnInterface,
  });
  final String ip, mac, interfaceName;
  final bool isOwnInterface;
}

abstract interface class NetworkAdapter {
  Future<InterfaceSnapshot> interfaces();
  Future<LocalResolution> resolve(String ip);
}

abstract interface class CommandRunner {
  Future<String> run(
    String executable,
    List<String> arguments, {
    Duration? timeout,
  });
}

typedef ProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments,
);

Future<Process> _startProcess(String executable, List<String> arguments) =>
    Process.start(executable, arguments, runInShell: false);

/// Direct processes only; bounded wall time and bounded captured output.
/// Raw OS output is never included in a UI error (it can contain private data).
class NativeCommandRunner implements CommandRunner {
  const NativeCommandRunner({
    this.timeout = const Duration(seconds: 8),
    this.maxOutputBytes = 1024 * 1024,
    this.startProcess = _startProcess,
  });
  final Duration timeout;
  final int maxOutputBytes;
  final ProcessStarter startProcess;

  @override
  Future<String> run(
    String executable,
    List<String> arguments, {
    Duration? timeout,
  }) async {
    Process? process;
    final readers = <StreamIterator<List<int>>>[];
    var expired = false;
    try {
      // The deadline covers process creation as well as output/exit. A process
      // that finishes starting after expiry receives a cleanup attempt as well.
      return await (() async {
        final child = await startProcess(executable, arguments);
        process = child;
        if (expired) {
          try {
            child.kill();
          } finally {
            // Subscribe then cancel both pipes, including buffered output. Do
            // not await stream shutdown or extend the already-expired caller.
            child.stdout.listen(null).cancel().ignore();
            child.stderr.listen(null).cancel().ignore();
          }
          throw const NetworkFailure(
            'Network command startup exceeded its deadline.',
          );
        }
        Future<String> read(Stream<List<int>> stream) async {
          final bytes = <int>[];
          final reader = StreamIterator(stream);
          readers.add(reader);
          while (await reader.moveNext()) {
            final chunk = reader.current;
            if (bytes.length + chunk.length > maxOutputBytes) {
              throw const NetworkFailure(
                'The network command returned too much data.',
              );
            }
            bytes.addAll(chunk);
          }
          return utf8.decode(bytes, allowMalformed: false);
        }

        // stderr is drained so the child cannot block on a full pipe, but only
        // the exit code decides success: utilities may warn and still succeed.
        final results = await Future.wait<Object>([
          child.exitCode,
          read(child.stdout),
          read(child.stderr),
        ], eagerError: true);
        if (results[0] != 0) {
          throw const NetworkFailure(
            'The operating system could not read network information. '
            'Check network permissions and native command availability.',
          );
        }
        return results[1] as String;
      })().timeout(
        timeout ?? this.timeout,
        onTimeout: () {
          expired = true;
          throw TimeoutException('Native network command deadline exceeded');
        },
      );
    } on TimeoutException {
      throw const NetworkFailure(
        'Reading network information timed out. Please try again.',
      );
    } on ProcessException {
      throw const NetworkFailure(
        'Cannot start the network utility. Check OS permissions and installation.',
      );
    } on FormatException {
      throw const NetworkFailure(
        'The network utility returned unreadable output.',
      );
    } finally {
      // Only our own disposable command process can be terminated here.
      try {
        process?.kill();
      } finally {
        // Cancellation also releases pipes if the OS refuses termination.
        // Completion of native cleanup is not a prerequisite for the deadline.
        for (final reader in readers) {
          reader.cancel().ignore();
        }
      }
    }
  }
}

/// Lines the parser does not recognize are skipped so one unusual entry cannot
/// fail a whole lookup; output with no recognizable entry at all is an error.
List<NeighborEntry> parseMacArp(String output) {
  final entries = <NeighborEntry>[];
  final pattern = RegExp(r'^\S+\s+\(([^)]+)\)\s+at\s+(\S+)\s+on\s+(\S+)');
  var recognized = 0;
  for (final line in const LineSplitter().convert(output)) {
    final match = pattern.firstMatch(line.trim());
    if (match == null) continue;
    recognized++;
    final ip = canonicalIpv4(match[1]!);
    final mac = normalizeMac(match[2]);
    if (ip != null && mac != null) {
      entries.add(NeighborEntry(ip, mac, match[3]!));
    }
  }
  if (recognized == 0 && output.trim().isNotEmpty) {
    throw const NetworkFailure('The ARP table format was not recognized.');
  }
  return entries;
}

List<LocalInterface> parseMacInterfaces(String output, {String? primaryName}) {
  final sections = output.split(RegExp(r'\n(?=\S+: flags=)'));
  final interfaces = <LocalInterface>[];
  for (final section in sections) {
    final header = RegExp(r'^(\S+): flags=[^\n]*<([^>]+)>').firstMatch(section);
    if (header == null) continue;
    final flags = header[2]!.split(',');
    if (!flags.contains('UP') ||
        flags.contains('LOOPBACK') ||
        section.contains('status: inactive')) {
      continue;
    }
    final name = header[1]!;
    final mac = normalizeMac(
      RegExp(r'\bether\s+(\S+)').firstMatch(section)?[1],
    );
    for (final match in RegExp(r'\binet\s+(\S+)').allMatches(section)) {
      final ip = canonicalIpv4(match[1]!);
      if (ip == null || ip.startsWith('127.') || ip == '0.0.0.0') continue;
      interfaces.add(
        LocalInterface(
          name: name,
          ip: ip,
          mac: mac,
          primary: name == primaryName,
        ),
      );
    }
  }
  if (output.trim().isNotEmpty && !output.contains(': flags=')) {
    throw const NetworkFailure(
      'The interface table format was not recognized.',
    );
  }
  return interfaces;
}

List<Map<String, dynamic>> _jsonRows(String output) {
  try {
    final value = jsonDecode(output.replaceFirst('\uFEFF', '').trim());
    if (value == null) return [];
    final rows = value is List ? value : [value];
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  } catch (_) {
    throw const NetworkFailure(
      'PowerShell returned an unexpected network response.',
    );
  }
}

List<NeighborEntry> parseWindowsNeighbors(String output) {
  final entries = <NeighborEntry>[];
  for (final row in _jsonRows(output)) {
    if (row['IPAddress'] is! String ||
        row['InterfaceIndex'] is! num ||
        row['State'] is! String ||
        (row['LinkLayerAddress'] != null &&
            row['LinkLayerAddress'] is! String)) {
      throw const NetworkFailure(
        'PowerShell returned an incomplete neighbor record.',
      );
    }
    final ip = canonicalIpv4(row['IPAddress'] as String);
    final mac = normalizeMac(row['LinkLayerAddress'] as String?);
    if (![
      'Reachable',
      'Stale',
      'Delay',
      'Probe',
      'Permanent',
    ].contains(row['State'])) {
      continue;
    }
    if (ip != null && mac != null) {
      entries.add(NeighborEntry(ip, mac, row['InterfaceIndex'].toString()));
    }
  }
  return entries;
}

List<LocalInterface> parseWindowsInterfaces(String output) {
  final interfaces = <LocalInterface>[];
  for (final row in _jsonRows(output)) {
    if (row['ip'] is! String ||
        row['name'] is! String ||
        row['label'] is! String ||
        row['primary'] is! bool ||
        (row['mac'] != null && row['mac'] is! String)) {
      throw const NetworkFailure(
        'PowerShell returned an incomplete interface record.',
      );
    }
    final ip = canonicalIpv4(row['ip'] as String);
    if (ip != null && !ip.startsWith('127.') && ip != '0.0.0.0') {
      interfaces.add(
        LocalInterface(
          name: row['name'] as String,
          ip: ip,
          label: row['label'] as String,
          mac: normalizeMac(row['mac'] as String?),
          primary: row['primary'] as bool,
        ),
      );
    }
  }
  return interfaces;
}

/// Never uses routing's next-hop address for resolution: only exact target IPs.
LocalResolution selectResolution(
  String ip,
  List<LocalInterface> interfaces,
  List<NeighborEntry> neighbors,
) {
  final own = interfaces.where((i) => i.ip == ip).toList();
  if (own.isNotEmpty) {
    if (own.any((i) => i.mac == null)) {
      throw const NetworkFailure(
        'This address belongs to a local interface without a hardware MAC '
        '(common for VPNs), so there is no vendor to look up.',
      );
    }
    if (own.map((i) => i.mac).toSet().length > 1) {
      throw const NetworkFailure(
        'This IP is assigned to more than one local interface, so its MAC is ambiguous.',
      );
    }
    return LocalResolution(
      ip: ip,
      mac: own.first.mac!,
      interfaceName: own.first.displayName,
      isOwnInterface: true,
    );
  }
  final matches = neighbors.where((entry) => entry.ip == ip).toList();
  if (matches.isEmpty) {
    throw const NetworkFailure(
      'No complete entry in the local neighbor cache. '
      'This does not mean the device is offline. ARP covers the local link; '
      'remote networks and uncached devices may have no entry.',
    );
  }
  if (matches.map((e) => e.mac).toSet().length > 1) {
    throw const NetworkFailure(
      'Different MAC addresses were found for this IP on multiple adapters, '
      'so it cannot be identified unambiguously.',
    );
  }
  return LocalResolution(
    ip: ip,
    mac: matches.first.mac,
    interfaceName: matches.first.interfaceName,
    isOwnInterface: false,
  );
}

class NativeNetworkAdapter implements NetworkAdapter {
  NativeNetworkAdapter({
    CommandRunner? runner,
    String? operatingSystem,
    Stopwatch Function()? stopwatchFactory,
  }) : runner = runner ?? const NativeCommandRunner(),
       operatingSystem = operatingSystem ?? Platform.operatingSystem,
       _stopwatchFactory = stopwatchFactory ?? Stopwatch.new;
  final CommandRunner runner;
  final String operatingSystem;
  final Stopwatch Function() _stopwatchFactory;

  // Windows PowerShell must initialize CLR, NetTCPIP/NetAdapter modules and CIM
  // providers. The former 8s per-command limit failed a cold Windows CI host.
  // 30s is an interactive UX cap with startup headroom, not an OS guarantee.
  // All commands within ONE discovery share this deadline (not 30s each).
  static const windowsDiscoveryTimeout = Duration(seconds: 30);
  static const macCommandTimeout = Duration(seconds: 8);
  static const macDiscoveryTimeout = Duration(seconds: 24);

  Stopwatch _startDeadline() => _stopwatchFactory()..start();

  Future<String> _run(
    String executable,
    List<String> arguments,
    Stopwatch elapsed,
  ) {
    final total = operatingSystem == 'windows'
        ? windowsDiscoveryTimeout
        : macDiscoveryTimeout;
    final remaining = total - elapsed.elapsed;
    if (remaining <= Duration.zero) {
      throw const NetworkFailure(
        'Reading network information timed out. Please try again.',
      );
    }
    final budget = operatingSystem != 'windows' && remaining > macCommandTimeout
        ? macCommandTimeout
        : remaining;
    return runner.run(executable, arguments, timeout: budget);
  }

  // Fixed scripts: target IP and user input are never interpolated in PowerShell.
  static const neighborScript = r'''
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
@(Get-NetNeighbor -AddressFamily IPv4 | ForEach-Object {
  [pscustomobject]@{ IPAddress=$_.IPAddress; LinkLayerAddress=$_.LinkLayerAddress;
    InterfaceIndex=$_.InterfaceIndex; State=$_.State.ToString() }
}) | ConvertTo-Json -Compress
''';
  static const interfaceScript = r'''
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$adapters = @(Get-NetAdapter -IncludeHidden)
$routes = @(Get-NetRoute -AddressFamily IPv4 | Where-Object { $_.DestinationPrefix -eq '0.0.0.0/0' } |
  Sort-Object @{Expression={$_.RouteMetric + $_.InterfaceMetric}}, InterfaceIndex)
$primary = if ($routes.Count -gt 0) { $routes[0].InterfaceIndex } else { -1 }
@(Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
  $_.AddressState -eq 'Preferred' -and $_.IPAddress -ne '127.0.0.1'
} | ForEach-Object {
  $address = $_
  $adapter = $adapters | Where-Object { $_.ifIndex -eq $address.InterfaceIndex } | Select-Object -First 1
  if ($adapter -and $adapter.Status -eq 'Up') {
    [pscustomobject]@{ name=$address.InterfaceIndex.ToString(); label=$address.InterfaceAlias;
      ip=$address.IPAddress; mac=$adapter.MacAddress; primary=($address.InterfaceIndex -eq $primary) }
  }
}) | ConvertTo-Json -Compress
''';

  Future<String> _powershell(String script, Stopwatch elapsed) async {
    final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    final output = await _run(
      '$systemRoot\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
      ['-NoLogo', '-NoProfile', '-NonInteractive', '-Command', script],
      elapsed,
    );
    // PowerShell emits nothing for an empty pipeline.
    return output.trim().isEmpty ? '[]' : output;
  }

  @override
  Future<InterfaceSnapshot> interfaces() => _interfaces(_startDeadline());

  Future<InterfaceSnapshot> _interfaces(Stopwatch elapsed) async {
    List<LocalInterface> values;
    String? notice;
    if (operatingSystem == 'macos') {
      String? primary;
      try {
        final route = await _run('/sbin/route', [
          '-n',
          'get',
          'default',
        ], elapsed);
        primary = RegExp(r'interface:\s*(\S+)').firstMatch(route)?[1];
      } on NetworkFailure {
        notice = 'Default route unavailable; using the first active interface.';
      }
      values = parseMacInterfaces(
        await _run('/sbin/ifconfig', ['-a'], elapsed),
        primaryName: primary,
      );
    } else if (operatingSystem == 'windows') {
      values = parseWindowsInterfaces(
        await _powershell(interfaceScript, elapsed),
      );
    } else {
      throw const NetworkFailure(
        'Network discovery supports macOS and Windows desktop.',
      );
    }
    if (!values.any((i) => i.primary)) {
      notice ??=
          'No default route found; using the first active IPv4 interface.';
    } else if (values.length > 1) {
      notice = 'Other active interfaces are ignored.';
    }
    return InterfaceSnapshot(values, notice: notice);
  }

  Future<List<NeighborEntry>> neighbors() => _neighbors(_startDeadline());

  Future<List<NeighborEntry>> _neighbors(Stopwatch elapsed) async {
    if (operatingSystem == 'macos') {
      return parseMacArp(await _run('/usr/sbin/arp', ['-an'], elapsed));
    }
    if (operatingSystem == 'windows') {
      return parseWindowsNeighbors(await _powershell(neighborScript, elapsed));
    }
    throw const NetworkFailure(
      'Network discovery supports macOS and Windows desktop.',
    );
  }

  @override
  Future<LocalResolution> resolve(String ip) async {
    final canonical = canonicalIpv4(ip);
    if (canonical == null) {
      throw const NetworkFailure(
        'Enter a valid IPv4 address, such as 192.168.1.10.',
      );
    }
    final elapsed = _startDeadline();
    final local = await _interfaces(elapsed);
    // Self resolution must not depend on ARP access or a self cache entry.
    final isOwn = local.interfaces.any((i) => i.ip == canonical);
    return selectResolution(
      canonical,
      local.interfaces,
      isOwn ? [] : await _neighbors(elapsed),
    );
  }
}
