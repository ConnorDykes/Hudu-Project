import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_lookup/lookup/lookup_controller.dart';
import 'package:network_lookup/lookup/lookup_repository.dart';
import 'package:network_lookup/main.dart';

import 'test_support.dart';

// Actual production widgets with injected synthetic data, never a fake app mode.
// Opt in on the golden's host platform to avoid cross-platform raster differences:
// UPDATE_GOLDENS=true flutter test --update-goldens test/screenshots_test.dart
Future<void> _loadFonts() async {
  final font = FontLoader('packages/desktop_core/Inter')
    ..addFont(rootBundle.load('packages/desktop_core/assets/fonts/Inter.ttf'));
  await font.load();
  final mono = FontLoader('packages/desktop_core/JetBrainsMono')
    ..addFont(
      rootBundle.load(
        'packages/desktop_core/assets/fonts/JetBrainsMono-Regular.ttf',
      ),
    );
  await mono.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

Future<void> _mount(
  WidgetTester tester, {
  required FakeLookupRepository repository,
  Size size = const Size(1440, 1000),
}) async {
  await _loadFonts();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        networkAdapterProvider.overrideWithValue(FakeNetworkAdapter()),
        lookupRepositoryProvider.overrideWithValue(repository),
      ],
      child: const RepaintBoundary(
        key: Key('capture'),
        child: NetworkLookupApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final skip = Platform.environment['UPDATE_GOLDENS'] != 'true';

  testWidgets('resolved lookup with API history', (tester) async {
    await _mount(
      tester,
      repository: FakeLookupRepository(records: exampleHistory),
    );
    await tester.enterText(find.byKey(const Key('ip-input')), '192.168.1.24');
    await tester.tap(find.byKey(const Key('lookup-button')));
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const Key('capture')),
      matchesGoldenFile('goldens/network-lookup.png'),
    );
  }, skip: skip);

  testWidgets('unknown vendor with the naming dialog open', (tester) async {
    await _mount(
      tester,
      repository: FakeLookupRepository(
        records: exampleHistory,
        submission: LookupSubmission(record: exampleHistory.last),
      ),
    );
    await tester.enterText(find.byKey(const Key('ip-input')), '192.168.1.82');
    await tester.tap(find.byKey(const Key('lookup-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('name-vendor-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('vendor-name-input')),
      'Lab sensor',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(NetworkLookupApp),
      matchesGoldenFile('goldens/network-lookup-name-vendor.png'),
    );
  }, skip: skip);
}
