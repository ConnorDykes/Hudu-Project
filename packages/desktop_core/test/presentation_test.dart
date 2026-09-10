import 'package:desktop_core/desktop_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [const Size(960, 680), const Size(700, 600)]) {
    testWidgets('desktop shell supports $size and navigation', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var selected = -1;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: DesktopShell(
            title: 'Network lookup',
            subtitle: 'A clear view of your local network.',
            destinations: const [
              DesktopDestination(label: 'Lookup', icon: Icons.radar),
              DesktopDestination(label: 'History', icon: Icons.history),
            ],
            selectedIndex: 0,
            onDestinationSelected: (value) => selected = value,
            child: const SectionCard(
              child: EmptyState(
                title: 'Ready to inspect',
                message: 'Enter a local IPv4 address.',
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.history));
      expect(selected, 1);
    });
  }
}
