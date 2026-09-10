import 'package:desktop_core/desktop_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/network_adapter.dart';
import 'lookup_repository.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.close);
  return client;
});
final networkAdapterProvider = Provider<NetworkAdapter>(
  (ref) => NativeNetworkAdapter(),
);
final lookupRepositoryProvider = Provider<LookupRepository>(
  (ref) => RailsLookupRepository(ref.watch(apiClientProvider)),
);
final interfacesProvider = FutureProvider<InterfaceSnapshot>(
  (ref) => ref.watch(networkAdapterProvider).interfaces(),
  retry: (_, _) => null,
);
final historyProvider = FutureProvider<List<LookupRecord>>(
  (ref) => ref.watch(lookupRepositoryProvider).history(),
  retry: (_, _) => null,
);

enum LookupPhase { idle, discovering, submitting, complete, failed }

class LookupState {
  const LookupState({
    this.phase = LookupPhase.idle,
    this.ip,
    this.resolution,
    this.record,
    this.message,
  });
  final LookupPhase phase;
  final String? ip, message;
  final LocalResolution? resolution;
  final LookupRecord? record;
  bool get busy =>
      phase == LookupPhase.discovering || phase == LookupPhase.submitting;
}

final lookupControllerProvider =
    NotifierProvider<LookupController, LookupState>(LookupController.new);

class LookupController extends Notifier<LookupState> {
  @override
  LookupState build() => const LookupState();

  Future<void> lookup(String input, {String? interfaceName}) async {
    // A double click / Enter while busy must never create a second API row.
    if (state.busy) return;
    final ip = canonicalIpv4(input);
    if (ip == null) {
      state = const LookupState(
        phase: LookupPhase.failed,
        message: 'Enter a valid IPv4 address, such as 192.168.1.10.',
      );
      return;
    }
    state = LookupState(phase: LookupPhase.discovering, ip: ip);
    LocalResolution? resolution;
    try {
      resolution = await ref
          .read(networkAdapterProvider)
          .resolve(ip, interfaceName: interfaceName);
      if (!ref.mounted) return;
      state = LookupState(
        phase: LookupPhase.submitting,
        ip: ip,
        resolution: resolution,
      );
      final submission = await ref
          .read(lookupRepositoryProvider)
          .submit(resolution);
      if (!ref.mounted) return;
      state = LookupState(
        phase: LookupPhase.complete,
        ip: ip,
        resolution: resolution,
        record: submission.record,
        message: submission.warning,
      );
      // Read through Rails even on uncertain delivery; never invent a history row.
      ref.invalidate(historyProvider);
    } catch (error) {
      if (!ref.mounted) return;
      state = LookupState(
        phase: LookupPhase.failed,
        ip: ip,
        resolution: resolution,
        message: friendlyError(error),
      );
    }
  }
}

String friendlyError(Object error) => switch (error) {
  NetworkFailure(:final message) => message,
  ApiException(:final message) => message,
  _ => 'The lookup could not be completed. Please try again.',
};
