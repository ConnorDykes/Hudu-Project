import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:process_manager/process_manager_app.dart';
import 'package:process_manager/src/controller.dart';

import 'support/fakes.dart';
import 'support/fonts.dart';

Future<void> renderApp(
  WidgetTester tester, {
  FakeProcesses? processes,
  FakeAudit? audit,
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
    await tester.tap(find.text('Terminate process'));
    await tester.pumpAndSettle();
    expect(find.text('Terminate this process?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(processes.kills, 0);
    await tester.tap(find.text('Terminate process'));
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
  testWidgets('OS error is distinct from empty list', (tester) async {
    await renderApp(
      tester,
      processes: FakeProcesses()..error = Exception('OS unavailable'),
    );
    expect(find.text('Process list unavailable'), findsOneWidget);
    expect(find.text('No processes returned'), findsNothing);
  });
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
      await tester.tap(find.text('Terminate process'));
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
