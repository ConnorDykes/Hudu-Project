import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_lookup/main.dart';
import 'package:network_lookup/lookup/lookup_controller.dart';

import 'test_support.dart';

void main() {
  testWidgets(
    'actual application with synthetic injected lookup and API history',
    (tester) async {
      final font = FontLoader('packages/desktop_core/Inter')
        ..addFont(
          rootBundle.load('packages/desktop_core/assets/fonts/Inter.ttf'),
        );
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
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkAdapterProvider.overrideWithValue(FakeNetworkAdapter()),
            lookupRepositoryProvider.overrideWithValue(
              FakeLookupRepository(records: exampleHistory),
            ),
          ],
          child: const RepaintBoundary(
            key: Key('capture'),
            child: NetworkLookupApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();
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
    },
    skip: Platform.environment['UPDATE_GOLDENS'] != 'true',
  );
}
