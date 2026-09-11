import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:network_lookup/network/network_adapter.dart';

const macInterfaces = '''
lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> mtu 16384
    inet 127.0.0.1 netmask 0xff000000
en0: flags=8863<UP,BROADCAST,RUNNING,SIMPLEX,MULTICAST> mtu 1500
    ether 0:1b:63:4:5:e6
    inet 192.168.1.8 netmask 0xffffff00 broadcast 192.168.1.255
    status: active
en5: flags=8863<UP,BROADCAST,RUNNING,SIMPLEX,MULTICAST> mtu 1500
    ether 02:22:33:44:55:66
    inet 10.0.0.8 netmask 0xffffff00
    status: inactive
utun4: flags=8051<UP,POINTOPOINT,RUNNING,MULTICAST> mtu 1380
    inet 10.20.0.8 --> 10.20.0.8 netmask 0xffffffff
''';

class FixtureRunner implements CommandRunner {
  FixtureRunner(this.outputs);
  final Map<String, Object> outputs;
  final calls = <(String, List<String>)>[];
  @override
  Future<String> run(
    String executable,
    List<String> arguments, {
    Duration? timeout,
  }) async {
    calls.add((executable, arguments));
    final output = outputs[executable];
    if (output is String) return output;
    throw output ?? const NetworkFailure('Missing test command');
  }
}

void main() {
  test('IPv4 is exact canonical decimal, with no shell syntax or IPv6', () {
    expect(canonicalIpv4(' 192.168.1.1 '), '192.168.1.1');
    for (final invalid in [
      '192.168.1',
      '192.168.1.256',
      '192.168.01.1',
      '::1',
      '1.2.3.-1',
      '1.2.3.4; echo bad',
      '1.2.3.4\nwhoami',
    ]) {
      expect(canonicalIpv4(invalid), isNull, reason: invalid);
    }
  });
  test('MAC accepts abbreviated, canonical, hyphen and compact forms', () {
    for (final mac in ['0:1b:63:4:5:e6', '00-1b-63-04-05-e6', '001b630405e6']) {
      expect(normalizeMac(mac), '00:1B:63:04:05:E6');
    }
    expect(
      normalizeMac('02:11:22:33:44:55'),
      isNotNull,
      reason: 'Locally assigned is valid',
    );
    for (final mac in [
      '(incomplete)',
      '00:00:00:00:00:00',
      'ff:ff:ff:ff:ff:ff',
      '01:00:5e:00:00:01',
      '00:11:22:33:44',
      '00:11:22:33:44:gg',
    ]) {
      expect(normalizeMac(mac), isNull);
    }
  });
  test('macOS numeric ARP supports incomplete and multiple adapters, exact IP only', () {
    final entries = parseMacArp('''
? (192.168.1.10) at 0:1b:63:4:5:e6 on en0 ifscope [ethernet]
? (192.168.1.1) at 02:11:22:33:44:55 on en0 ifscope [ethernet]
? (192.168.1.11) at (incomplete) on en0 ifscope [ethernet]
? (192.168.1.10) at 02:11:22:33:44:66 on en5 ifscope [ethernet]
''');
    expect(entries, hasLength(3));
    expect(
      selectResolution('192.168.1.1', [], entries).mac,
      '02:11:22:33:44:55',
    );
    expect(
      () => selectResolution('192.168.1.10', [], entries),
      throwsA(isA<NetworkFailure>()),
    );
    expect(
      () => selectResolution('8.8.8.8', [], entries),
      throwsA(
        isA<NetworkFailure>().having(
          (e) => e.message,
          'miss semantics',
          contains('does not mean the device is offline'),
        ),
      ),
    );
    expect(
      () => parseMacArp('arp: permission denied'),
      throwsA(isA<NetworkFailure>()),
    );
    expect(parseMacArp(''), isEmpty);
    expect(
      parseMacArp(
        'arp: warning about one interface\n'
        '? (192.168.1.1) at 02:11:22:33:44:55 on en0 ifscope [ethernet]\n',
      ).single.mac,
      '02:11:22:33:44:55',
      reason: 'One unrecognized line must not fail the whole lookup',
    );
  });
  test('macOS interface metadata excludes loopback and inactive but keeps VPN without MAC', () {
    final interfaces = parseMacInterfaces(macInterfaces, primaryName: 'en0');
    expect(interfaces.map((i) => i.name), ['en0', 'utun4']);
    expect(interfaces.first.primary, isTrue);
    expect(interfaces.first.mac, '00:1B:63:04:05:E6');
    expect(
      selectResolution('192.168.1.8', interfaces, []).isOwnInterface,
      isTrue,
    );
    expect(
      () => selectResolution('10.20.0.8', interfaces, []),
      throwsA(isA<NetworkFailure>()),
    );
    expect(
      () => parseMacInterfaces('permission denied'),
      throwsA(isA<NetworkFailure>()),
    );
  });
  test(
    'Windows structured neighbors handles object, array, stale and incomplete',
    () {
      Map<String, Object> row(String ip, String state, String mac, int index) =>
          {
            'IPAddress': ip,
            'State': state,
            'LinkLayerAddress': mac,
            'InterfaceIndex': index,
          };
      final entries = parseWindowsNeighbors(
        jsonEncode([
          row('192.168.1.1', 'Reachable', '00-1B-63-04-05-E6', 4),
          row('192.168.1.10', 'Stale', '02-11-22-33-44-55', 8),
          row('192.168.1.11', 'Incomplete', '00-00-00-00-00-00', 4),
          row('192.168.1.12', 'Unreachable', '02-11-22-33-44-55', 4),
        ]),
      );
      expect(entries, hasLength(2));
      expect(entries.last.interfaceName, '8');
      expect(
        parseWindowsNeighbors(
          jsonEncode(row('10.0.0.1', 'Permanent', '001B630405E6', 4)),
        ),
        hasLength(1),
      );
      expect(parseWindowsNeighbors('null'), isEmpty);
      expect(
        parseWindowsNeighbors(
          '[{"IPAddress":"192.168.1.19","InterfaceIndex":4,'
          '"State":"Incomplete","LinkLayerAddress":null}]',
        ),
        isEmpty,
      );
      expect(
        () => parseWindowsNeighbors('[{}]'),
        throwsA(isA<NetworkFailure>()),
      );
      expect(
        () => parseWindowsNeighbors('Access denied'),
        throwsA(isA<NetworkFailure>()),
      );
    },
  );
  test('Windows interface metadata keeps unicode labels and missing physical MAC', () {
    final values = parseWindowsInterfaces(
      '[{"name":"4","label":"Wi-Fi – équipe",'
      '"ip":"192.168.1.8","mac":"00-1B-63-04-05-E6","primary":true},'
      '{"name":"9","label":"VPN","ip":"10.0.0.8","mac":null,"primary":false}]',
    );
    expect(values.first.primary, isTrue);
    expect(values.first.displayName, 'Wi-Fi – équipe');
    expect(values.last.mac, isNull);
    expect(
      () => parseWindowsInterfaces('[{"ip":false}]'),
      throwsA(isA<NetworkFailure>()),
    );
  });
  test(
    'own-IP reads metadata and never requests ARP; fixed commands only',
    () async {
      final runner = FixtureRunner({
        '/sbin/route': 'interface: en0',
        '/sbin/ifconfig': macInterfaces,
      });
      final adapter = NativeNetworkAdapter(
        runner: runner,
        operatingSystem: 'macos',
      );
      final result = await adapter.resolve('192.168.1.8');
      expect(result.isOwnInterface, isTrue);
      expect(runner.calls.map((c) => c.$1), ['/sbin/route', '/sbin/ifconfig']);
      expect(runner.calls.last.$2, ['-a']);
      await expectLater(
        adapter.resolve('1.2.3.4; false'),
        throwsA(isA<NetworkFailure>()),
      );
      expect(runner.calls, hasLength(2));
    },
  );
  test('default route unavailable falls back explicitly; ARP errors are not misses', () async {
    final runner = FixtureRunner({
      '/sbin/route': const NetworkFailure('unavailable'),
      '/sbin/ifconfig': macInterfaces,
      '/usr/sbin/arp': const NetworkFailure('permission denied'),
    });
    final adapter = NativeNetworkAdapter(
      runner: runner,
      operatingSystem: 'macos',
    );
    final snapshot = await adapter.interfaces();
    expect(snapshot.preferred!.name, 'en0');
    expect(snapshot.notice, contains('Default route unavailable'));
    await expectLater(
      adapter.resolve('192.168.1.1'),
      throwsA(
        isA<NetworkFailure>().having(
          (e) => e.message,
          'OS failure',
          'permission denied',
        ),
      ),
    );
    expect(runner.calls.last.$2, ['-an']);
  });
  test('Windows commands use only static script and explicit noninteractive arguments', () async {
    final runner = FixtureRunner({});
    final adapter = NativeNetworkAdapter(
      runner: runner,
      operatingSystem: 'windows',
    );
    await expectLater(adapter.neighbors(), throwsA(isA<NetworkFailure>()));
    expect(runner.calls.single.$1, endsWith('powershell.exe'));
    expect(runner.calls.single.$2, [
      '-NoLogo',
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      NativeNetworkAdapter.neighborScript,
    ]);
  });
  test(
    'native command runner bounds child runtime and rejects exit errors',
    () async {
      const runner = NativeCommandRunner(timeout: Duration(milliseconds: 100));
      final clock = Stopwatch()..start();
      await expectLater(
        runner.run('/bin/sleep', ['5']),
        throwsA(
          isA<NetworkFailure>().having(
            (e) => e.message,
            'timeout',
            contains('timed out'),
          ),
        ),
      );
      expect(clock.elapsed, lessThan(const Duration(seconds: 3)));
      await expectLater(
        runner.run('/usr/bin/false', []),
        throwsA(isA<NetworkFailure>()),
      );
      await expectLater(
        runner.run('/usr/bin/ls', ['/path-that-does-not-exist-hudu-test']),
        throwsA(isA<NetworkFailure>()),
      );
      await expectLater(
        const NativeCommandRunner(maxOutputBytes: 2)
            .run('/bin/echo', ['bounded']),
        throwsA(isA<NetworkFailure>()),
      );
      // A warning on stderr with a zero exit code is still a successful read.
      expect(
        await runner.run('/bin/sh', ['-c', 'echo warning >&2; echo ok']),
        'ok\n',
      );
    },
    skip: Platform.isWindows,
  );
}
