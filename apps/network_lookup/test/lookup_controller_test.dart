import 'dart:async';

import 'package:desktop_core/desktop_core.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_lookup/lookup/lookup_controller.dart';
import 'package:network_lookup/lookup/lookup_repository.dart';
import 'package:network_lookup/network/network_adapter.dart';

import 'test_support.dart';

void main() {
  ProviderContainer container(
    FakeNetworkAdapter adapter,
    FakeLookupRepository repository,
  ) {
    final value = ProviderContainer(
      overrides: [
        networkAdapterProvider.overrideWithValue(adapter),
        lookupRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(value.dispose);
    return value;
  }

  test('invalid IP never invokes OS or API', () async {
    final adapter = FakeNetworkAdapter();
    final repository = FakeLookupRepository();
    final scope = container(adapter, repository);
    await scope.read(lookupControllerProvider.notifier).lookup('invalid');
    expect(adapter.resolveCalls, 0);
    expect(repository.submitCalls, 0);
    expect(scope.read(lookupControllerProvider).phase, LookupPhase.failed);
  });
  test('cache miss never persists an attempt', () async {
    final repository = FakeLookupRepository();
    final scope = container(
      FakeNetworkAdapter(failure: const NetworkFailure('cache miss')),
      repository,
    );
    await scope.read(lookupControllerProvider.notifier).lookup('192.168.1.24');
    expect(repository.submitCalls, 0);
    expect(scope.read(lookupControllerProvider).message, 'cache miss');
  });
  test('async stages are exposed and duplicate submits are ignored', () async {
    final pending = Completer<LocalResolution>();
    final adapter = FakeNetworkAdapter(pending: pending.future);
    final repository = FakeLookupRepository();
    final scope = container(adapter, repository);
    final phases = <LookupPhase>[];
    scope.listen(lookupControllerProvider, (_, next) => phases.add(next.phase));
    final controller = scope.read(lookupControllerProvider.notifier);
    final first = controller.lookup('192.168.1.24');
    await controller.lookup('192.168.1.25');
    expect(scope.read(lookupControllerProvider).busy, isTrue);
    expect(adapter.resolveCalls, 1);
    pending.complete(exampleResolution);
    await first;
    expect(repository.submitCalls, 1);
    expect(phases, [
      LookupPhase.discovering,
      LookupPhase.submitting,
      LookupPhase.complete,
    ]);
  });
  test('API unavailable preserves the actual hardware result and unconfirmed persistence', () async {
    final scope = container(
      FakeNetworkAdapter(),
      FakeLookupRepository(
        submission: const LookupSubmission(warning: 'Cannot reach Rails'),
      ),
    );
    await scope.read(lookupControllerProvider.notifier).lookup('192.168.1.24');
    final state = scope.read(lookupControllerProvider);
    expect(state.resolution!.mac, exampleResolution.mac);
    expect(state.record, isNull);
    expect(state.message, 'Cannot reach Rails');
    expect(state.busy, isFalse);
  });
  test('disposed async request cannot submit or mutate state', () async {
    final pending = Completer<LocalResolution>();
    final repository = FakeLookupRepository();
    final scope = ProviderContainer(
      overrides: [
        networkAdapterProvider.overrideWithValue(
          FakeNetworkAdapter(pending: pending.future),
        ),
        lookupRepositoryProvider.overrideWithValue(repository),
      ],
    );
    final request = scope
        .read(lookupControllerProvider.notifier)
        .lookup('192.168.1.24');
    scope.dispose();
    pending.complete(exampleResolution);
    await request;
    expect(repository.submitCalls, 0);
  });
  test(
    'history is read from repository after persistence, not appended locally',
    () async {
      final scope = container(FakeNetworkAdapter(), FakeLookupRepository());
      scope.listen(historyProvider, (_, _) {});
      expect(await scope.read(historyProvider.future), isEmpty);
      await scope
          .read(lookupControllerProvider.notifier)
          .lookup('192.168.1.24');
      expect(await scope.read(historyProvider.future), isEmpty);
    },
  );
  test(
    'native timeout clears busy state without retrying or persisting',
    () async {
      final pending = Completer<LocalResolution>();
      final adapter = FakeNetworkAdapter(pending: pending.future);
      final repository = FakeLookupRepository();
      final scope = container(adapter, repository);
      final request = scope
          .read(lookupControllerProvider.notifier)
          .lookup('192.168.1.24');
      expect(scope.read(lookupControllerProvider).busy, isTrue);
      pending.completeError(
        const NetworkFailure(
          'Reading network information timed out. Please try again.',
        ),
      );
      await request;
      expect(scope.read(lookupControllerProvider).phase, LookupPhase.failed);
      expect(scope.read(lookupControllerProvider).busy, isFalse);
      expect(adapter.resolveCalls, 1);
      expect(repository.submitCalls, 0);
    },
  );
  test('naming an unknown vendor saves it and repeats the lookup', () async {
    final repository = FakeLookupRepository(
      submission: LookupSubmission(record: exampleHistory.last),
    );
    final scope = container(FakeNetworkAdapter(), repository);
    final controller = scope.read(lookupControllerProvider.notifier);
    await controller.lookup('192.168.1.82');
    expect(scope.read(lookupControllerProvider).canNameVendor, isTrue);
    await controller.nameVendor('  Lab sensor ');
    expect(repository.vendors, {exampleResolution.mac: 'Lab sensor'});
    expect(repository.submitCalls, 2);
    expect(scope.read(lookupControllerProvider).phase, LookupPhase.complete);
  });
  test('vendor save failure keeps the unknown result and explains', () async {
    final repository =
        FakeLookupRepository(
            submission: LookupSubmission(record: exampleHistory.last),
          )
          ..vendorFailure = const ApiException(
            'Vendor exists',
            code: 'vendor_exists',
          );
    final scope = container(FakeNetworkAdapter(), repository);
    final controller = scope.read(lookupControllerProvider.notifier);
    await controller.lookup('192.168.1.82');
    await controller.nameVendor('Lab sensor');
    final state = scope.read(lookupControllerProvider);
    expect(repository.submitCalls, 1);
    expect(state.record!.status, VendorStatus.unknown);
    expect(state.message, 'Vendor exists');
    expect(state.canNameVendor, isTrue);
  });
  test('resolved lookups cannot be renamed', () async {
    final repository = FakeLookupRepository();
    final scope = container(FakeNetworkAdapter(), repository);
    final controller = scope.read(lookupControllerProvider.notifier);
    await controller.lookup('192.168.1.24');
    expect(scope.read(lookupControllerProvider).canNameVendor, isFalse);
    await controller.nameVendor('Nope');
    expect(repository.vendors, isEmpty);
    expect(repository.submitCalls, 1);
  });
}
