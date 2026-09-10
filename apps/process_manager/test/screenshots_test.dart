import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:process_manager/process_manager_app.dart';
import 'package:process_manager/src/controller.dart';

import 'support/fakes.dart';
import 'support/fonts.dart';

// Actual production widgets with injected synthetic data, never a fake app mode.
// Opt in on the golden's host platform to avoid cross-platform raster differences:
// UPDATE_GOLDENS=true flutter test --update-goldens test/screenshots_test.dart
void main() {
  testWidgets(
    'process manager production widgets with synthetic process data',
    (tester) async {
      await loadTestFonts();
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(
            () => DateTime(2026, 9, 10, 14, 32, 8),
          ),
          processAdapterProvider.overrideWithValue(FakeProcesses()),
          auditRepositoryProvider.overrideWithValue(FakeAudit()),
          outboxProvider.overrideWithValue(MemoryOutbox()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ProcessManagerApp(),
        ),
      );
      await tester.pumpAndSettle();
      container.read(managerProvider.notifier).select(syntheticProcesses[2]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(ProcessManagerApp),
        matchesGoldenFile('goldens/process-manager.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    },
    skip: Platform.environment['UPDATE_GOLDENS'] != 'true',
  );
}
