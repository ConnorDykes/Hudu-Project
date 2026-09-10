import 'package:flutter/services.dart';

Future<void> loadTestFonts() async {
  await (FontLoader('packages/desktop_core/Inter')..addFont(
        rootBundle.load('packages/desktop_core/assets/fonts/Inter.ttf'),
      ))
      .load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}
