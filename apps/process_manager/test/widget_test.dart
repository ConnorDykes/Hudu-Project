import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:process_manager/process_manager_app.dart';
import 'package:process_manager/src/controller.dart';
import 'package:process_manager/src/models.dart';

import 'support/fakes.dart';
import 'support/fonts.dart';

class _SnapshotController extends ManagerController {
  _SnapshotController(this.snapshot);
  final ManagerState snapshot;
  @override
  ManagerState build() => snapshot;
  @override
  Future<void> initialize() async {}
}

Future<void> renderApp(
  WidgetTester tester, {
  FakeProcesses? processes,
  FakeAudit? audit,
  ManagerState? snapshot,
  Size size = const Size(1280, 820),
}) async {
  await loadTestFonts();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (snapshot != null)
          managerProvider.overrideWith(() => _SnapshotController(snapshot)),
        processAdapterProvider.overrideWithValue(processes ?? FakeProcesses()),
        auditRepositoryProvider.overrideWithValue(audit ?? FakeAudit()),
        outboxProvider.overrideWithValue(MemoryOutbox()),
      ],
      child: const ProcessManagerApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final auditError in [null, 'Audit pending. API unavailable.']) {
    testWidgets(
      'storage write failure never claims saved locally (auditError: $auditError)',
      (tester) async {
        await renderApp(
          tester,
          snapshot: ManagerState(
            ready: true,
            processes: syntheticProcesses,
            selection: [syntheticProcesses.first],
            pending: [sampleEvent()],
            storageError: 'Process terminated, but its audit could not be saved to disk. Keep this app open and retry delivery.',
            auditError: auditError,
          ),
          size: const Size(960, 680),
        );
        expect(
          find.textContaining(
            'Some events are only in memory. Keep app open and retry.',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('could not be saved to disk'),
          findsOneWidget,
        );
        expect(find.textContaining('Saved locally'), findsNothing);
        final terminate = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Terminate 1 process'),
        );
        expect(terminate.onPressed, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('configurable auto-refresh runs and stops without overlapping', (
    tester,
  ) async {
    final processes = FakeProcesses();
    await renderApp(tester, processes: processes);
    expect(processes.lists, 1);
    await tester.tap(find.text('Off'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 sec').last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(processes.lists, 2);
    await tester.tap(find.text('5 sec'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Off').last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    expect(processes.lists, 2);
  });
  testWidgets('search, select, cancel, then confirm termination', (
    tester,
  ) async {
    final processes = FakeProcesses();
    await renderApp(tester, processes: processes);
    await tester.enterText(find.byType(TextField), '10532');
    await tester.pumpAndSettle();
    expect(find.text('sleep'), findsOneWidget);
    expect(find.text('WindowServer'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('process-10532')));
    await tester.pump();
    await tester.tap(find.text('Terminate 1 process'));
    await tester.pumpAndSettle();
    expect(find.text('Terminate this process?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(processes.kills, 0);
    await tester.tap(find.text('Terminate 1 process'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm termination'));
    await tester.pumpAndSettle();
    expect(processes.kills, 1);
    expect(find.textContaining('Exit confirmed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('minimum desktop size, explicit empty search, history error', (
    tester,
  ) async {
    final audit = FakeAudit()..error = Exception('offline');
    await renderApp(tester, audit: audit, size: const Size(960, 680));
    await tester.enterText(find.byType(TextField), 'nothing-matches');
    await tester.pumpAndSettle();
    expect(find.text('No matching processes'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Audit history'));
    await tester.pumpAndSettle();
    expect(find.text('History unavailable'), findsOneWidget);
    expect(find.text('No termination events yet'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'keyboard: Ctrl+F focuses search, arrows move selection, Esc clears',
    (tester) async {
      await renderApp(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isTrue);
      await tester.enterText(find.byType(TextField), 'sleep');
      await tester.pumpAndSettle();
      expect(find.text('WindowServer'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(field.controller!.text, isEmpty);
      expect(find.text('WindowServer'), findsOneWidget);
      // With an empty search, Escape clears the selection instead.
      await tester.tap(find.byKey(const ValueKey('process-2408')));
      await tester.pump();
      expect(find.text('1 selected'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('inline terminate acts on one row without selection', (
    tester,
  ) async {
    final processes = FakeProcesses();
    await renderApp(tester, processes: processes);
    await tester.tap(find.byKey(const ValueKey('terminate-10532')));
    await tester.pumpAndSettle();
    expect(find.text('Terminate this process?'), findsOneWidget);
    await tester.tap(find.text('Confirm termination'));
    await tester.pumpAndSettle();
    expect(processes.kills, 1);
    expect(processes.rows.any((p) => p.pid == 10532), isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('select all then batch terminate confirms every row', (
    tester,
  ) async {
    final processes = FakeProcesses();
    await renderApp(tester, processes: processes);
    await tester.tap(find.byKey(const Key('select-all')));
    await tester.pumpAndSettle();
    expect(find.text('8 selected'), findsOneWidget);
    await tester.tap(find.text('Terminate 8 processes'));
    await tester.pumpAndSettle();
    expect(find.text('Terminate 8 processes?'), findsOneWidget);
    await tester.tap(find.text('Confirm termination'));
    await tester.pumpAndSettle();
    expect(processes.kills, 8);
    expect(find.textContaining('8 of 8 processes terminated'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('OS error is distinct from empty list', (tester) async {
    await renderApp(
      tester,
      processes: FakeProcesses()..error = Exception('OS unavailable'),
    );
    expect(find.text('Process list unavailable'), findsOneWidget);
    expect(find.text('No processes returned'), findsNothing);
  });
  testWidgets(
    'large batch lists every target with scrolling and supports cancel',
    (tester) async {
      final processes = FakeProcesses()
        ..rows = List.generate(
          20,
          (index) => LocalProcess(
            pid: 20000 + index,
            name: 'worker-${index.toString().padLeft(2, '0')}',
            identity: 'batch-$index',
          ),
        );
      await renderApp(tester, processes: processes, size: const Size(960, 680));
      await tester.tap(find.byKey(const Key('select-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminate 20 processes'));
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      final lastTarget = find.descendant(
        of: dialog,
        matching: find.text('PID 20019'),
      );
      expect(lastTarget, findsOneWidget);
      expect(lastTarget.hitTestable(), findsNothing);
      expect(find.textContaining('and 12 more'), findsNothing);
      await tester.drag(
        find.byKey(const ValueKey('termination-targets')),
        const Offset(0, -1200),
      );
      await tester.pumpAndSettle();
      expect(lastTarget.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(processes.kills, 0);

      await tester.tap(find.text('Terminate 20 processes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm termination'));
      await tester.pumpAndSettle();
      expect(processes.kills, 20);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'offline audit shows confirmed exit and pending delivery independently',
    (tester) async {
      await renderApp(
        tester,
        audit: FakeAudit()..error = Exception('offline'),
        size: const Size(960, 680),
      );
      await tester.tap(find.byKey(const ValueKey('process-2408')));
      await tester.pump();
      await tester.tap(find.text('Terminate 1 process'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm termination'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Exit confirmed'), findsOneWidget);
      expect(find.textContaining('audit pending'), findsOneWidget);
      expect(find.text('Retry audit'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
