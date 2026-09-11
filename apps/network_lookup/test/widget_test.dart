import 'dart:async';

import 'package:desktop_core/desktop_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_lookup/main.dart';
import 'package:network_lookup/lookup/lookup_controller.dart';
import 'package:network_lookup/lookup/lookup_repository.dart';
import 'package:network_lookup/network/network_adapter.dart';

import 'test_support.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    FakeNetworkAdapter? adapter,
    FakeLookupRepository? repository,
    Size size = const Size(960, 680),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Match production font metrics, independently of platform-installed fonts.
    final font = FontLoader(
      'packages/desktop_core/Inter',
    )..addFont(rootBundle.load('packages/desktop_core/assets/fonts/Inter.ttf'));
    await font.load();
    final mono = FontLoader('packages/desktop_core/JetBrainsMono')
      ..addFont(
        rootBundle.load(
          'packages/desktop_core/assets/fonts/JetBrainsMono-Regular.ttf',
        ),
      );
    await mono.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkAdapterProvider.overrideWithValue(
            adapter ?? FakeNetworkAdapter(),
          ),
          lookupRepositoryProvider.overrideWithValue(
            repository ?? FakeLookupRepository(),
          ),
        ],
        child: const NetworkLookupApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Windows loading explains the bounded first-use wait', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      final pending = Completer<LocalResolution>();
      await mount(tester, adapter: FakeNetworkAdapter(pending: pending.future));
      await tester.enterText(find.byKey(const Key('ip-input')), '192.168.1.24');
      await tester.tap(find.byKey(const Key('lookup-button')));
      await tester.pump();
      expect(
        find.text(
          'Windows network initialization may take up to 30 seconds on first use.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      pending.complete(exampleResolution);
      await tester.pumpAndSettle();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'empty state and lookup fit minimum desktop size; Enter submits',
    (tester) async {
      final repo = FakeLookupRepository();
      await mount(tester, repository: repo);
      expect(
        find.textContaining('Enter a local IPv4 address to resolve'),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const Key('ip-input')), '192.168.1.24');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(repo.submitCalls, 1);
      expect(find.text('Apple, Inc.'), findsOneWidget);
      expect(find.text('00:1B:63:84:45:E6'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'my IP fills primary interface metadata and exposes manual selection',
    (tester) async {
      final adapter = FakeNetworkAdapter();
      await mount(tester, adapter: adapter);
      await tester.tap(find.text('Use my IP'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('ip-input')))
            .controller!
            .text,
        '192.168.1.8',
      );
      await tester.tap(find.byKey(const Key('lookup-button')));
      await tester.pumpAndSettle();
      expect(adapter.lastInterface, 'en0');
      expect(
        find.text('Identified from local interface metadata.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'input validation and cache miss are actionable without fake persistence',
    (tester) async {
      await mount(
        tester,
        adapter: FakeNetworkAdapter(
          failure: const NetworkFailure(
            'No complete cache entry. This does not mean the device is offline.',
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('lookup-button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Enter a valid IPv4'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('ip-input')), '192.168.1.24');
      await tester.tap(find.byKey(const Key('lookup-button')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('does not mean the device is offline'),
        findsOneWidget,
      );
      expect(
        find.textContaining('No lookup was sent to the API'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('loading disables submission while showing async progress', (
    tester,
  ) async {
    final pending = Completer<LocalResolution>();
    await mount(tester, adapter: FakeNetworkAdapter(pending: pending.future));
    await tester.enterText(find.byKey(const Key('ip-input')), '192.168.1.24');
    await tester.tap(find.byKey(const Key('lookup-button')));
    await tester.pump();
    expect(find.text('Reading the local network cache…'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('lookup-button')))
          .onPressed,
      isNull,
    );
    pending.complete(exampleResolution);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('unknown vendor and unconfirmed save retain distinct semantics', (
    tester,
  ) async {
    await mount(
      tester,
      repository: FakeLookupRepository(
        submission: LookupSubmission(record: exampleHistory.last),
      ),
    );
    await tester.enterText(find.byKey(const Key('ip-input')), '192.168.1.82');
    await tester.tap(find.byKey(const Key('lookup-button')));
    await tester.pumpAndSettle();
    expect(find.text('Vendor not identified'), findsOneWidget);
    expect(find.textContaining('Saved to history'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'API down shows local MAC, unconfirmed save, and retryable history',
    (tester) async {
      await mount(
        tester,
        repository: FakeLookupRepository(
          submission: const LookupSubmission(warning: 'Cannot reach Rails'),
          failure: const ApiException('Cannot reach Rails'),
        ),
      );
      await tester.enterText(find.byKey(const Key('ip-input')), '192.168.1.24');
      await tester.tap(find.byKey(const Key('lookup-button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('History save unconfirmed'), findsOneWidget);
      expect(find.text(exampleResolution.mac), findsOneWidget);
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('History is unavailable'), findsOneWidget);
      expect(find.text('Retry history'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'history navigation uses API rows and remains scrollable after resize',
    (tester) async {
      await mount(
        tester,
        repository: FakeLookupRepository(records: exampleHistory),
        size: const Size(1440, 1000),
      );
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Saved lookups'), findsOneWidget);
      expect(find.text('Example Networks'), findsOneWidget);
      tester.view.physicalSize = const Size(960, 680);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ip-input')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('ip-input')))
            .focusNode!
            .hasFocus,
        isTrue,
      );
    },
  );
}
