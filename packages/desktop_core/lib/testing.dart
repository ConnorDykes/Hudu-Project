/// Helpers for the apps' widget and golden tests. Import as
/// `package:desktop_core/testing.dart`; production code never does.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the bundled Inter and JetBrains Mono faces plus Material icons so
/// tests render with production metrics instead of the test-environment
/// placeholder font.
Future<void> loadBundledFonts() async {
  const fonts = {
    'packages/desktop_core/Inter': 'packages/desktop_core/assets/fonts/Inter.ttf',
    'packages/desktop_core/JetBrainsMono':
        'packages/desktop_core/assets/fonts/JetBrainsMono-Regular.ttf',
    'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
  };
  for (final MapEntry(key: family, value: asset) in fonts.entries) {
    await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
  }
}

/// Fixes the window size, pixel ratio, and platform brightness for one test
/// and restores them afterwards.
void configureTestView(
  WidgetTester tester, {
  Size size = const Size(1440, 1000),
  Brightness? brightness,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  if (brightness != null) {
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  }
}
