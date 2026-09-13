import 'dart:io';

import 'package:desktop_core/desktop_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_lookup/src/lookup/lookup_repository.dart';

import 'test_support.dart';

void main() {
  test(
    'real Rails history and rejected malformed POST, no vendor dependency',
    () async {
      final client = ApiClient();
      addTearDown(client.close);
      final repository = RailsLookupRepository(client);
      final history = await repository.history();
      expect(history.length, lessThanOrEqualTo(30));
      await expectLater(
        client.post('/lookups', {'mac': 'invalid'}),
        throwsA(
          isA<ApiException>().having(
            (e) => e.statusCode,
            'validation status',
            422,
          ),
        ),
      );
    },
    skip: Platform.environment['HUDU_API_SMOKE'] != 'true',
  );

  test(
    'real Rails repository POST and GET round trip with synthetic input',
    () async {
      final client = ApiClient();
      addTearDown(client.close);
      final repository = RailsLookupRepository(client);
      final result = await repository.submit(exampleResolution);
      expect(result.record, isNotNull, reason: result.warning);
      final history = await repository.history();
      expect(
        history.any(
          (row) =>
              row.id == result.record!.id && row.mac == exampleResolution.mac,
        ),
        isTrue,
      );
    },
    // This creates a persisted row and calls the configured external vendor service.
    // Provider failures and unknown vendors are valid if Rails persists the attempt.
    skip:
        Platform.environment['HUDU_API_SMOKE'] != 'true' ||
        Platform.environment['HUDU_LIVE_VENDOR'] != 'true',
  );
}
