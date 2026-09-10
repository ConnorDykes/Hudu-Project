import 'package:desktop_core/desktop_core.dart';

import '../network/network_adapter.dart';

enum VendorStatus { resolved, unknown, failed }

class LookupRecord {
  const LookupRecord({
    required this.id,
    required this.ip,
    required this.mac,
    required this.vendor,
    required this.status,
    required this.createdAt,
  });
  final int id;
  final String? ip, vendor;
  final String mac;
  final VendorStatus status;
  final DateTime createdAt;

  factory LookupRecord.fromJson(Map<String, dynamic> json) {
    try {
      final mac = normalizeMac(json['mac'] as String?);
      final ip = json['ip'] as String?;
      final status = VendorStatus.values.byName(json['status'] as String);
      final vendor = json['vendor'] as String?;
      if (mac == null ||
          (ip != null && canonicalIpv4(ip) == null) ||
          json['id'] is! int ||
          (json['id'] as int) <= 0 ||
          (status == VendorStatus.resolved &&
              (vendor == null || vendor.trim().isEmpty))) {
        throw const FormatException();
      }
      return LookupRecord(
        id: json['id'] as int,
        ip: ip,
        mac: mac,
        vendor: vendor,
        status: status,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
    } catch (_) {
      throw const ApiException(
        'The API returned an invalid lookup record.',
        code: 'invalid_response',
      );
    }
  }
}

class LookupSubmission {
  const LookupSubmission({this.record, this.warning});
  final LookupRecord? record;
  final String? warning;
}

abstract interface class LookupRepository {
  Future<LookupSubmission> submit(LocalResolution resolution);
  Future<List<LookupRecord>> history();
}

class RailsLookupRepository implements LookupRepository {
  RailsLookupRepository(this.client);
  final ApiClient client;

  @override
  Future<LookupSubmission> submit(LocalResolution resolution) async {
    try {
      final envelope = await client.post('/lookups', {
        'mac': resolution.mac,
        'ip': resolution.ip,
      });
      return LookupSubmission(record: _record(envelope['data']));
    } on ApiException catch (error) {
      LookupRecord? persisted;
      if (error.data != null) {
        try {
          persisted = _record(error.data);
        } on ApiException {
          /* Preserve original failure. */
        }
      }
      return LookupSubmission(record: persisted, warning: error.message);
    }
  }

  LookupRecord _record(dynamic value) {
    if (value is! Map<String, dynamic>) {
      throw const ApiException(
        'The API response is missing its lookup record.',
        code: 'invalid_response',
      );
    }
    return LookupRecord.fromJson(value);
  }

  @override
  Future<List<LookupRecord>> history() async {
    final envelope = await client.get(
      '/lookups',
      query: {'limit': '30', 'offset': '0'},
    );
    if (envelope['data'] is! List) {
      throw const ApiException(
        'The API returned invalid lookup history.',
        code: 'invalid_response',
      );
    }
    return (envelope['data'] as List).map(_record).toList();
  }
}
