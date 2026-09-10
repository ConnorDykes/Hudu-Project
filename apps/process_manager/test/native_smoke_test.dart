import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:process_manager/src/models.dart';

import 'support/native_harness.dart';

void main() {
  test(
    'native OS lists and terminates only harness-created disposable child',
    () async {
      final child = await spawnDisposableChild();
      // Reap immediately; cleanup targets this Process object only.
      var exited = false;
      final exit = child.exitCode.then((code) {
        exited = true;
        return code;
      });
      addTearDown(() async {
        if (!exited) child.kill();
        await exit.timeout(const Duration(seconds: 8));
      });
      final adapter = nativeAdapter();
      final rows = await adapter.list();
      final selected = rows.singleWhere((p) => p.pid == child.pid);
      expect(selected.identity, isNotNull);
      expect(await adapter.terminate(selected), ExitOutcome.terminated);
      await exit.timeout(const Duration(seconds: 8));
      expect(
        (await adapter.list()).where(
          (p) => p.sameIdentity(selected) && p.status != 'Exited',
        ),
        isEmpty,
      );
    },
    skip: !Platform.isMacOS && !Platform.isWindows,
    timeout: const Timeout(Duration(seconds: 45)),
  );
}
