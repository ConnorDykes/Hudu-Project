import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/native_smoke.dart' as smoke;

void main() {
  test(
    'real OS network cache and interface metadata read (no probes)',
    smoke.main,
    // Three independent production operations (interfaces, neighbors, own IP).
    // Each retains its real deadline; allow their combined worst-case duration.
    timeout: const Timeout(Duration(seconds: 100)),
    skip: !Platform.isMacOS && !Platform.isWindows,
  );
}
