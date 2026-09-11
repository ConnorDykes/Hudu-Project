import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:process_manager/process_manager_app.dart';
import 'package:process_manager/src/controller.dart';
import 'package:process_manager/src/models.dart';

import 'support/fakes.dart';
import 'support/fonts.dart';

// Actual production widgets with injected synthetic data, never a fake app mode.
// Opt in on the golden's host platform to avoid cross-platform raster differences:
// UPDATE_GOLDENS=true flutter test --update-goldens test/screenshots_test.dart
Future<ProviderContainer> _mount(
  WidgetTester tester, {
  FakeAudit? audit,
}) async {
  await loadTestFonts();
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(() => DateTime(2026, 9, 10, 14, 32, 8)),
      processAdapterProvider.overrideWithValue(FakeProcesses()),
      auditRepositoryProvider.overrideWithValue(audit ?? FakeAudit()),
      outboxProvider.overrideWithValue(MemoryOutbox()),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const ProcessManagerApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  final skip = Platform.environment['UPDATE_GOLDENS'] != 'true';

  testWidgets('process table with a selection', (tester) async {
    final container = await _mount(tester);
    container.read(managerProvider.notifier).select(syntheticProcesses[2]);
    container.read(managerProvider.notifier).select(syntheticProcesses[6]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(ProcessManagerApp),
      matchesGoldenFile('goldens/process-manager.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  }, skip: skip);

  testWidgets('batch termination confirmation', (tester) async {
    final container = await _mount(tester);
    await tester.tap(find.byKey(const Key('select-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('terminate-selected')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(ProcessManagerApp),
      matchesGoldenFile('goldens/process-manager-confirm.png'),
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  }, skip: skip);

  testWidgets('audit history from the API', (tester) async {
    final audit = FakeAudit()
      ..records = [
        AuditEvent(
          eventId: '4d5b6c7e-1111-4222-8333-000000000001',
          processName: 'design-preview',
          pid: 9124,
          occurredAt: DateTime.utc(2026, 9, 10, 20, 31, 12),
        ),
        AuditEvent(
          eventId: '4d5b6c7e-1111-4222-8333-000000000002',
          processName: 'sleep',
          pid: 10532,
          occurredAt: DateTime.utc(2026, 9, 10, 20, 30, 58),
        ),
        AuditEvent(
          eventId: '4d5b6c7e-1111-4222-8333-000000000003',
          processName: 'sample-worker',
          pid: 7000,
          occurredAt: DateTime.utc(2026, 9, 10, 18, 30),
        ),
      ];
    final container = await _mount(tester, audit: audit);
    await tester.tap(find.text('Audit history'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(ProcessManagerApp),
      matchesGoldenFile('goldens/process-manager-history.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  }, skip: skip);
}
