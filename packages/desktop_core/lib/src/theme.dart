import 'package:flutter/material.dart';

/// Semantic colors shared by both apps. Read them with `context.colors`.
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.sidebar,
    required this.panel,
    required this.hairline,
    required this.hover,
    required this.selection,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.danger,
  });
  final Color background,
      sidebar,
      panel,
      hairline,
      hover,
      selection,
      text,
      textSecondary,
      textTertiary,
      accent,
      onAccent,
      success,
      warning,
      danger;

  static const dark = AppColors(
    background: Color(0xFF111318),
    sidebar: Color(0xFF15181E),
    panel: Color(0xFF191D25),
    hairline: Color(0xFF272C36),
    hover: Color(0x0AFFFFFF),
    selection: Color(0x246C9CFF),
    text: Color(0xFFE6E9EF),
    textSecondary: Color(0xFF98A1B0),
    textTertiary: Color(0xFF6A7382),
    accent: Color(0xFF6C9CFF),
    onAccent: Color(0xFF0B1220),
    success: Color(0xFF45B26B),
    warning: Color(0xFFD9A441),
    danger: Color(0xFFE5645C),
  );
  static const light = AppColors(
    background: Color(0xFFF5F6F8),
    sidebar: Color(0xFFEEF0F4),
    panel: Color(0xFFFFFFFF),
    hairline: Color(0xFFE1E4EA),
    hover: Color(0x0A000000),
    selection: Color(0x1F2F6FE4),
    text: Color(0xFF1A1D24),
    textSecondary: Color(0xFF5C6472),
    textTertiary: Color(0xFF8A92A0),
    accent: Color(0xFF2F6FE4),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF2E9E57),
    warning: Color(0xFFB8860B),
    danger: Color(0xFFD4433B),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      background: mix(background, other.background),
      sidebar: mix(sidebar, other.sidebar),
      panel: mix(panel, other.panel),
      hairline: mix(hairline, other.hairline),
      hover: mix(hover, other.hover),
      selection: mix(selection, other.selection),
      text: mix(text, other.text),
      textSecondary: mix(textSecondary, other.textSecondary),
      textTertiary: mix(textTertiary, other.textTertiary),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      danger: mix(danger, other.danger),
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

/// Motion constants: short, eased, never bouncy.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 120);
  static const normal = Duration(milliseconds: 180);
  static const slow = Duration(milliseconds: 260);
  static const curve = Curves.easeOutCubic;

  /// Standard cross-fade with a 4px rise for panels that change state.
  static Widget fadeRise(Widget child, Animation<double> animation) {
    final eased = CurvedAnimation(parent: animation, curve: curve);
    return FadeTransition(
      opacity: eased,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).animate(eased),
        child: child,
      ),
    );
  }
}

abstract final class AppText {
  static const _mono = [
    'SF Mono',
    'Menlo',
    'Consolas',
    'Cascadia Mono',
    'Courier New',
    'monospace',
  ];

  /// Tabular monospace for addresses, identifiers, and timestamps.
  static const mono = TextStyle(
    fontFamily: 'JetBrainsMono',
    package: 'desktop_core',
    fontFamilyFallback: _mono,
    fontSize: 12.5,
    height: 1.4,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Table header and definition-list labels. Derived from the theme so the
  /// bundled family applies wherever the style is used directly.
  static TextStyle label(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall!.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: .2,
        height: 1.3,
        color: context.colors.textTertiary,
      );
}

abstract final class AppTheme {
  static ThemeData get dark => _theme(AppColors.dark, Brightness.dark);
  static ThemeData get light => _theme(AppColors.light, Brightness.light);

  static ThemeData _theme(AppColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      secondary: c.accent,
      onSecondary: c.onAccent,
      error: c.danger,
      onError: Colors.white,
      surface: c.panel,
      onSurface: c.text,
      onSurfaceVariant: c.textSecondary,
      outline: c.hairline,
      outlineVariant: c.hairline,
      surfaceContainerHighest: c.sidebar,
    );
    const family = 'Inter';
    const package = 'desktop_core';
    const overrides = TextTheme(
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -.2,
        height: 1.3,
      ),
      titleMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      titleSmall: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
      bodyLarge: TextStyle(fontSize: 14, height: 1.45),
      bodyMedium: TextStyle(fontSize: 13, height: 1.45),
      bodySmall: TextStyle(fontSize: 12, height: 1.4),
      labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: family,
      package: package,
      textTheme: overrides,
    );
    final text = base.textTheme
        .apply(bodyColor: c.text, displayColor: c.text)
        .copyWith(
          bodySmall: base.textTheme.bodySmall?.copyWith(color: c.textSecondary),
        );
    final shape6 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
    );
    return base.copyWith(
      extensions: [c],
      scaffoldBackgroundColor: c.background,
      canvasColor: c.panel,
      dividerColor: c.hairline,
      hoverColor: c.hover,
      splashFactory: NoSplash.splashFactory,
      textTheme: text,
      iconTheme: IconThemeData(color: c.textSecondary, size: 18),
      dividerTheme: DividerThemeData(color: c.hairline, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: c.panel,
        hintStyle: TextStyle(color: c.textTertiary, fontSize: 13),
        labelStyle: TextStyle(color: c.textSecondary, fontSize: 13),
        helperStyle: TextStyle(color: c.textTertiary, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        prefixIconColor: c.textTertiary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: c.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: c.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: c.hairline.withValues(alpha: .6)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: shape6,
          textStyle: const TextStyle(
            fontFamily: family,
            package: package,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          animationDuration: AppMotion.fast,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: shape6,
          foregroundColor: c.text,
          side: BorderSide(color: c.hairline),
          textStyle: const TextStyle(
            fontFamily: family,
            package: package,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          animationDuration: AppMotion.fast,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 30),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: shape6,
          foregroundColor: c.accent,
          textStyle: const TextStyle(
            fontFamily: family,
            package: package,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          animationDuration: AppMotion.fast,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.textSecondary,
          hoverColor: c.hover,
          shape: shape6,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 600),
        textStyle: TextStyle(fontSize: 12, color: c.background),
        decoration: BoxDecoration(
          color: c.text,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: c.hairline),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        width: 320,
        backgroundColor: c.text,
        contentTextStyle: TextStyle(fontSize: 13, color: c.background),
        shape: shape6,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.hairline,
        linearMinHeight: 2,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(textStyle: text.bodyMedium),
      popupMenuTheme: PopupMenuThemeData(
        color: c.panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: c.hairline),
        ),
        textStyle: text.bodyMedium,
      ),
    );
  }
}
