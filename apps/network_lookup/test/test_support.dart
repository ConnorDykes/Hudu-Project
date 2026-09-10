import 'package:network_lookup/lookup/lookup_repository.dart';
import 'package:network_lookup/network/network_adapter.dart';

const exampleResolution = LocalResolution(
  ip: '192.168.1.24',
  mac: '00:1B:63:84:45:E6',
  interfaceName: 'en0',
  isOwnInterface: false,
);
final exampleRecord = LookupRecord(
  id: 3,
  ip: exampleResolution.ip,
  mac: exampleResolution.mac,
  vendor: 'Apple, Inc.',
  status: VendorStatus.resolved,
  createdAt: DateTime(2026, 9, 10, 14, 32),
);
final exampleHistory = [
  exampleRecord,
  LookupRecord(
    id: 2,
    ip: '192.168.1.1',
    mac: '00:1A:2B:30:40:50',
    vendor: 'Example Networks',
    status: VendorStatus.resolved,
    createdAt: DateTime(2026, 9, 10, 14, 26),
  ),
  LookupRecord(
    id: 1,
    ip: '192.168.1.82',
    mac: '02:11:22:33:44:55',
    vendor: null,
    status: VendorStatus.unknown,
    createdAt: DateTime(2026, 9, 10, 14, 18),
  ),
];
const exampleInterfaces = InterfaceSnapshot(
  [
    LocalInterface(
      name: 'en0',
      ip: '192.168.1.8',
      mac: '02:12:34:56:78:90',
      primary: true,
    ),
    LocalInterface(name: 'en5', ip: '10.20.0.8', mac: '02:12:34:56:78:92'),
  ],
  notice: 'Default-route interface suggested. Choose another for a different network.',
);

class FakeNetworkAdapter implements NetworkAdapter {
  FakeNetworkAdapter({
    this.failure,
    this.pending,
    this.snapshot = exampleInterfaces,
  });
  final Object? failure;
  final Future<LocalResolution>? pending;
  final InterfaceSnapshot snapshot;
  int resolveCalls = 0;
  String? lastInterface;
  @override
  Future<InterfaceSnapshot> interfaces() async => snapshot;
  @override
  Future<LocalResolution> resolve(String ip, {String? interfaceName}) async {
    resolveCalls++;
    lastInterface = interfaceName;
    if (failure != null) throw failure!;
    return pending ??
        LocalResolution(
          ip: ip,
          mac: exampleResolution.mac,
          interfaceName: interfaceName ?? 'en0',
          isOwnInterface: ip == '192.168.1.8',
        );
  }
}

class FakeLookupRepository implements LookupRepository {
  FakeLookupRepository({
    this.records = const [],
    this.failure,
    this.submission,
  });
  final List<LookupRecord> records;
  final Object? failure;
  final LookupSubmission? submission;
  int submitCalls = 0;
  @override
  Future<List<LookupRecord>> history() async {
    if (failure != null) throw failure!;
    return records;
  }

  @override
  Future<LookupSubmission> submit(LocalResolution resolution) async {
    submitCalls++;
    return submission ?? LookupSubmission(record: exampleRecord);
  }
}
