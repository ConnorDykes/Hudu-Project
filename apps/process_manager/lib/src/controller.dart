import 'dart:async';
import 'dart:io';

import 'package:desktop_core/desktop_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'audit_repository.dart';
import 'models.dart';
import 'process_adapter.dart';
import 'windows_process_adapter.dart';

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final processAdapterProvider = Provider<ProcessAdapter>((ref) {
  if (Platform.isMacOS) return MacProcessAdapter();
  if (Platform.isWindows) return WindowsProcessAdapter();
  throw const ProcessFailure('This app supports macOS and Windows.');
});
final auditRepositoryProvider = Provider<AuditRepository>((ref) {
  final client = ApiClient();
  ref.onDispose(client.close);
  return ApiAuditRepository(client);
});
final outboxProvider = Provider<AuditOutbox>(
  (ref) => FileAuditOutbox(FileAuditOutbox.applicationDirectory),
);
final managerProvider = NotifierProvider<ManagerController, ManagerState>(
  ManagerController.new,
);

class ManagerState {
  const ManagerState({
    this.processes = const [],
    this.history = const [],
    this.pending = const [],
    this.selected,
    this.query = '',
    this.sortPid = false,
    this.ascending = true,
    this.refreshing = false,
    this.historyLoading = false,
    this.terminating = false,
    this.delivering = false,
    this.ready = false,
    this.interval = 0,
    this.updatedAt,
    this.processError,
    this.historyError,
    this.auditError,
    this.storageError,
    this.notice,
  });
  final List<LocalProcess> processes;
  final List<AuditEvent> history, pending;
  final LocalProcess? selected;
  final String query;
  final bool sortPid,
      ascending,
      refreshing,
      historyLoading,
      terminating,
      delivering,
      ready;
  final int interval;
  final DateTime? updatedAt;
  final String? processError, historyError, auditError, storageError, notice;
  List<LocalProcess> get visible {
    final q = query.trim().toLowerCase();
    final rows = processes
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) || p.pid.toString().contains(q),
        )
        .toList();
    rows.sort((a, b) {
      var c = sortPid
          ? a.pid.compareTo(b.pid)
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (c == 0) c = a.pid.compareTo(b.pid);
      return ascending ? c : -c;
    });
    return rows;
  }

  ManagerState copy({
    List<LocalProcess>? processes,
    List<AuditEvent>? history,
    List<AuditEvent>? pending,
    LocalProcess? selected,
    bool clearSelection = false,
    String? query,
    bool? sortPid,
    bool? ascending,
    bool? refreshing,
    bool? historyLoading,
    bool? terminating,
    bool? delivering,
    bool? ready,
    int? interval,
    DateTime? updatedAt,
    String? processError,
    String? historyError,
    String? auditError,
    String? storageError,
    String? notice,
    bool clearProcessError = false,
    bool clearHistoryError = false,
    bool clearAuditError = false,
    bool clearStorageError = false,
  }) => ManagerState(
    processes: processes ?? this.processes,
    history: history ?? this.history,
    pending: pending ?? this.pending,
    selected: clearSelection ? null : selected ?? this.selected,
    query: query ?? this.query,
    sortPid: sortPid ?? this.sortPid,
    ascending: ascending ?? this.ascending,
    refreshing: refreshing ?? this.refreshing,
    historyLoading: historyLoading ?? this.historyLoading,
    terminating: terminating ?? this.terminating,
    delivering: delivering ?? this.delivering,
    ready: ready ?? this.ready,
    interval: interval ?? this.interval,
    updatedAt: updatedAt ?? this.updatedAt,
    processError: clearProcessError ? null : processError ?? this.processError,
    historyError: clearHistoryError ? null : historyError ?? this.historyError,
    auditError: clearAuditError ? null : auditError ?? this.auditError,
    storageError: clearStorageError ? null : storageError ?? this.storageError,
    notice: notice ?? this.notice,
  );
}

class ManagerController extends Notifier<ManagerState> {
  Timer? _refreshTimer, _retryTimer;
  late ProcessAdapter _adapter;
  late AuditRepository _audit;
  late AuditOutbox _outbox;
  late DateTime Function() _now;
  Future<void>? _initialization;
  Completer<void>? _historyRefresh;
  bool _historyRefreshQueued = false;
  @override
  ManagerState build() {
    _adapter = ref.read(processAdapterProvider);
    _audit = ref.read(auditRepositoryProvider);
    _outbox = ref.read(outboxProvider);
    _now = ref.read(clockProvider);
    ref.onDispose(() {
      _refreshTimer?.cancel();
      _retryTimer?.cancel();
    });
    return const ManagerState();
  }

  Future<void> initialize() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    try {
      await _outbox.prepare();
      final pending = await _outbox.load();
      if (!ref.mounted) return;
      state = state.copy(
        pending: pending,
        ready: true,
        clearStorageError: true,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copy(
        storageError: 'Local audit storage is unavailable. Termination is disabled. Check disk access, then restart the app.',
      );
    }
    if (!ref.mounted) return;
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(retryAudits());
    });
    await Future.wait([refresh(), refreshHistory(), retryAudits()]);
  }

  Future<void> refresh() async {
    if (state.refreshing || state.terminating) return;
    state = state.copy(refreshing: true, clearProcessError: true);
    try {
      final rows = await _adapter.list();
      if (!ref.mounted) return;
      final selection = state.selected;
      state = state.copy(
        processes: rows,
        refreshing: false,
        updatedAt: _now(),
        clearSelection: selection != null && !rows.any(selection.sameIdentity),
      );
    } catch (_) {
      if (ref.mounted) {
        state = state.copy(
          refreshing: false,
          processError: 'Could not refresh local processes. Check OS access and try again. Any rows below are from the previous refresh.',
        );
      }
    }
  }

  Future<void> refreshHistory() async {
    final active = _historyRefresh;
    if (active != null) {
      // A delivery may have happened after the active GET took its snapshot.
      // Coalesce callers into one follow-up GET, and await the whole drain.
      _historyRefreshQueued = true;
      return active.future;
    }
    final completion = Completer<void>();
    _historyRefresh = completion;
    try {
      do {
        _historyRefreshQueued = false;
        state = state.copy(historyLoading: true, clearHistoryError: true);
        try {
          final history = await _audit.history();
          if (!ref.mounted) return;
          state = state.copy(history: history);
        } catch (error) {
          if (!ref.mounted) return;
          state = state.copy(
            historyError: 'Audit history unavailable. ${_message(error)}',
          );
        }
      } while (_historyRefreshQueued);
    } finally {
      _historyRefresh = null;
      if (ref.mounted) state = state.copy(historyLoading: false);
      completion.complete();
    }
  }

  void search(String query) => state = state.copy(query: query);
  void sort(bool byPid) => state = state.copy(
    sortPid: byPid,
    ascending: state.sortPid == byPid ? !state.ascending : true,
  );
  void select(LocalProcess? process) {
    if (!state.terminating) {
      state = state.copy(selected: process, clearSelection: process == null);
    }
  }

  void setInterval(int seconds) {
    if (![0, 5, 10, 30].contains(seconds)) return;
    _refreshTimer?.cancel();
    state = state.copy(interval: seconds);
    if (seconds > 0) {
      _refreshTimer = Timer.periodic(Duration(seconds: seconds), (_) {
        unawaited(refresh());
      });
    }
  }

  Future<void> terminate(LocalProcess confirmed) async {
    if (state.refreshing) {
      state = state.copy(
        notice: 'Refresh is in progress. Wait for it to finish, then confirm termination again.',
      );
      return;
    }
    if (state.terminating || !state.ready || state.storageError != null) {
      return;
    }
    if (state.selected?.sameIdentity(confirmed) != true) {
      state = state.copy(
        notice:
            'Selection changed. Select the process again before terminating.',
      );
      return;
    }
    state = state.copy(terminating: true, notice: 'Checking process identity…');
    try {
      // Fail before an irreversible action when storage is already unavailable.
      await _outbox.prepare();
      final outcome = await _adapter.terminate(confirmed);
      if (outcome == ExitOutcome.terminated) {
        // Capture milliseconds: Rails serializes occurrence times to milliseconds.
        final event = AuditEvent(
          eventId: const Uuid().v4(),
          processName: confirmed.name,
          pid: confirmed.pid,
          occurredAt: DateTime.fromMillisecondsSinceEpoch(
            _now().millisecondsSinceEpoch,
            isUtc: true,
          ),
        );
        // Persist even if the UI was disposed while waiting for the native exit.
        String? storageError;
        try {
          await _outbox.put(event);
        } catch (_) {
          storageError = 'Process terminated, but its audit could not be saved to disk. Keep this app open and retry delivery.';
        }
        if (!ref.mounted) return;
        state = state.copy(
          pending: [...state.pending, event],
          clearSelection: true,
          storageError: storageError,
          notice:
              '${confirmed.name} (PID ${confirmed.pid}) terminated. Exit confirmed.',
        );
      } else {
        if (!ref.mounted) return;
        state = state.copy(
          notice: switch (outcome) {
            ExitOutcome.alreadyExited =>
              'This process already exited. No termination audit was created.',
            ExitOutcome.identityChanged => 'Process identity changed. Termination refused; refresh and select again.',
            ExitOutcome.accessDenied => 'Access denied. The process was not terminated. This app does not elevate permissions.',
            ExitOutcome.notExiting => 'Exit was not confirmed within 4 seconds. The process may still be running; no audit was created.',
            ExitOutcome.forbidden => 'This PID is protected. The app cannot terminate itself or a nonpositive PID.',
            ExitOutcome.terminated => '',
          },
        );
      }
    } catch (error) {
      if (ref.mounted) {
        state = state.copy(
          notice: 'Termination was not confirmed. ${_message(error)}',
        );
      }
    } finally {
      if (ref.mounted) state = state.copy(terminating: false);
    }
    if (!ref.mounted) return;
    await Future.wait([refresh(), retryAudits()]);
  }

  Future<void> retryAudits() async {
    if (!state.ready || state.delivering || state.pending.isEmpty) return;
    state = state.copy(delivering: true, clearAuditError: true);
    Object? firstError;
    try {
      for (final event in List<AuditEvent>.of(state.pending)) {
        try {
          // Idempotent outbox/API operations only. Never call the OS adapter here.
          await _outbox.put(event);
          await _audit.send(event);
          await _outbox.remove(event.eventId);
        } catch (error) {
          firstError ??= error;
          if (!ref.mounted) return;
          // A rejected event (for example 409 or 422) must not block the rest of
          // the queue; a transport or server failure would fail them all, so stop.
          if (error is ApiException && !error.isTransient) continue;
          break;
        }
        if (!ref.mounted) return;
        state = state.copy(
          pending: state.pending
              .where((e) => e.eventId != event.eventId)
              .toList(),
        );
      }
      if (!ref.mounted) return;
      if (firstError != null) {
        state = state.copy(
          auditError: 'Audit pending. ${_message(firstError)}',
        );
      } else if (state.pending.isEmpty) {
        // A newer termination can append a memory-only event while this retry's
        // snapshot is in flight. Keep the storage warning until the live queue
        // is fully delivered, including any events added during this retry.
        state = state.copy(clearStorageError: true);
      }
    } finally {
      if (ref.mounted) state = state.copy(delivering: false);
    }
    if (ref.mounted) await refreshHistory();
  }

  String _message(Object error) =>
      error is ApiException || error is ProcessFailure
      ? error.toString()
      : 'Check service availability and local storage, then retry.';
}
