import 'dart:io';

import 'package:network_lookup/network/network_adapter.dart';

/// Read-only native verification: no probes, API writes, or private output.
Future<void> main() async {
  if (!Platform.isMacOS && !Platform.isWindows) {
    stdout.writeln('SKIP: native network smoke requires macOS or Windows.');
    return;
  }
  final adapter = NativeNetworkAdapter();
  final snapshot = await timedRead('interface metadata', adapter.interfaces);
  for (final interface in snapshot.interfaces) {
    check(
      canonicalIpv4(interface.ip) == interface.ip,
      'Interface IPv4 must be canonical',
    );
    if (interface.mac != null) {
      check(
        normalizeMac(interface.mac) == interface.mac,
        'Interface MAC must be canonical',
      );
    }
  }
  final neighbors = await timedRead('neighbor cache', adapter.neighbors);
  for (final neighbor in neighbors) {
    check(
      canonicalIpv4(neighbor.ip) == neighbor.ip,
      'Neighbor IPv4 must be canonical',
    );
    check(
      normalizeMac(neighbor.mac) == neighbor.mac,
      'Neighbor MAC must be canonical',
    );
    check(
      neighbor.interfaceName.isNotEmpty,
      'Neighbor must identify its interface',
    );
  }
  final own = snapshot.interfaces.where((i) => i.mac != null).firstOrNull;
  if (own != null) {
    final resolution = await timedRead(
      'own-IP metadata',
      () => adapter.resolve(own.ip),
    );
    check(
      resolution.isOwnInterface && resolution.mac == own.mac,
      'Own IP must use interface metadata',
    );
  }
  stdout.writeln(
    'PASS: native interface and neighbor reads; canonical identities; '
    '${own == null ? 'no physical own-IP candidate (self check skipped)' : 'own-IP metadata resolution'}. '
    'No addresses logged or devices probed.',
  );
}

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<T> timedRead<T>(String label, Future<T> Function() read) async {
  stdout.writeln('Native smoke: reading $label.');
  final clock = Stopwatch()..start();
  try {
    return await read();
  } finally {
    // Stage and timing only; useful for cold-start failures without host data.
    stdout.writeln(
      'Native smoke: $label elapsed ${clock.elapsedMilliseconds} ms.',
    );
  }
}
