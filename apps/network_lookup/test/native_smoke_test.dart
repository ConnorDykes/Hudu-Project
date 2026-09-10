import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/native_smoke.dart' as smoke;

void main() {
  test(
    'real OS network cache and interface metadata read (no probes)',
    smoke.main,
    skip: !Platform.isMacOS && !Platform.isWindows,
  );
}
