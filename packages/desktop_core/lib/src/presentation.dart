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

class DesktopDestination {
  const DesktopDestination({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

/// Compact toolbar header, plus sidebar navigation when there are views to
/// switch between. No hero copy: the title is the name of the current view and
/// the header carries only its actions.
class DesktopShell extends StatelessWidget {
  const DesktopShell({
    super.key,
    required this.title,
    required this.child,
    this.destinations = const [],
    this.selectedIndex = 0,
    this.onDestinationSelected,
    this.subtitle,
    this.productName = 'Hudu',
    this.actions = const [],
    this.footer,
    this.busy = false,
  });
  final String title, productName;
  final String? subtitle;
  final Widget child;
  final List<DesktopDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;
  final List<Widget> actions;
  final Widget? footer;

  /// Shows a thin indeterminate bar under the toolbar while true.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sidebar = destinations.length > 1;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 840;
          return Row(
            children: [
              if (sidebar)
                AnimatedContainer(
                  duration: AppMotion.normal,
                  curve: AppMotion.curve,
                  width: compact ? 56 : 212,
                  decoration: BoxDecoration(
                    color: c.sidebar,
                    border: Border(right: BorderSide(color: c.hairline)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Brand(productName: productName, compact: compact),
                      const SizedBox(height: 8),
                      for (var i = 0; i < destinations.length; i++)
                        _NavItem(
                          destination: destinations[i],
                          selected: selectedIndex == i,
                          compact: compact,
                          onTap: () => onDestinationSelected?.call(i),
                        ),
                      const Spacer(),
                      if (footer != null && !compact)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: footer,
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 56,
                      padding: const EdgeInsets.fromLTRB(24, 0, 16, 0),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: c.hairline)),
                      ),
                      child: Row(
                        children: [
                          if (!sidebar) ...[
                            _Monogram(color: c),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: AppMotion.normal,
                              switchInCurve: AppMotion.curve,
                              switchOutCurve: AppMotion.curve,
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                              layoutBuilder: (current, previous) => Stack(
                                alignment: Alignment.centerLeft,
                                children: [...previous, ?current],
                              ),
                              child: Column(
                                key: ValueKey(title),
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  if (subtitle != null)
                                    Text(
                                      subtitle!,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (!sidebar && footer != null) ...[
                            footer!,
                            const SizedBox(width: 16),
                          ],
                          for (final action in actions) ...[
                            const SizedBox(width: 8),
                            action,
                          ],
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 2,
                      child: AnimatedOpacity(
                        duration: AppMotion.normal,
                        opacity: busy ? 1 : 0,
                        child: busy
                            ? const LinearProgressIndicator(minHeight: 2)
                            : const SizedBox.shrink(),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 16 : 24,
                          18,
                          compact ? 16 : 24,
                          16,
                        ),
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.productName, required this.compact});
  final String productName;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 16),
      child: Row(
        mainAxisAlignment: compact
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          _Monogram(color: c),
          if (!compact) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.color});
  final AppColors color;
  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      color: color.accent,
      borderRadius: BorderRadius.circular(6),
    ),
    alignment: Alignment.center,
    child: Text(
      'H',
      style: TextStyle(
        color: color.onAccent,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        height: 1,
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.compact,
    required this.onTap,
  });
  final DesktopDestination destination;
  final bool selected, compact;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = selected ? c.text : c.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: _MaybeTooltip(
        message: compact ? destination.label : null,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            hoverColor: c.hover,
            onTap: onTap,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              height: 32,
              padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 10),
              decoration: BoxDecoration(
                color: selected ? c.selection : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: compact
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Icon(
                    destination.icon,
                    size: 17,
                    color: selected ? c.accent : c.textSecondary,
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MaybeTooltip extends StatelessWidget {
  const _MaybeTooltip({required this.message, required this.child});
  final String? message;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      message == null ? child : Tooltip(message: message!, child: child);
}

/// A bordered surface. Use sparingly: one per table or result, not per label.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.hairline),
      ),
      child: child,
    );
  }
}

/// A small colored dot followed by a label. Status without a pill.
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.color, this.icon});
  final String label;
  final Color? color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = color ?? c.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Icon(icon, size: 13, color: tone)
        else
          AnimatedContainer(
            duration: AppMotion.normal,
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
          ),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: c.textSecondary,
          ),
        ),
      ],
    );
  }
}

enum NoticeKind { info, warning, error }

/// Inline message for the state of an operation. Fades in when it appears.
class InlineNotice extends StatelessWidget {
  const InlineNotice({
    super.key,
    required this.message,
    this.kind = NoticeKind.info,
    this.action,
    this.detail,
  });
  final String message;
  final String? detail;
  final NoticeKind kind;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = switch (kind) {
      NoticeKind.info => c.accent,
      NoticeKind.warning => c.warning,
      NoticeKind.error => c.danger,
    };
    return FadeRise(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: tone.withValues(alpha: .25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              switch (kind) {
                NoticeKind.info => Icons.check_circle_outline_rounded,
                NoticeKind.warning => Icons.warning_amber_rounded,
                NoticeKind.error => Icons.error_outline_rounded,
              },
              size: 15,
              color: tone,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: c.text,
                      height: 1.4,
                    ),
                  ),
                  if (detail != null)
                    Text(
                      detail!,
                      style: TextStyle(
                        fontSize: 12,
                        color: c.textSecondary,
                        height: 1.4,
                      ),
                    ),
                ],
              ),
            ),
            if (action != null) ...[const SizedBox(width: 8), action!],
          ],
        ),
      ),
    );
  }
}

/// Quiet empty/error placeholder for a panel.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });
  final String title, message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: FadeRise(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: c.textTertiary),
              const SizedBox(height: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (action != null) ...[const SizedBox(height: 14), action!],
            ],
          ),
        ),
      ),
    );
  }
}

/// One-shot entrance: fade in and rise 4px. Wrap content that appears.
class FadeRise extends StatelessWidget {
  const FadeRise({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: AppMotion.normal,
    curve: AppMotion.curve,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, (1 - value) * 4),
        child: child,
      ),
    ),
    child: child,
  );
}

/// Cross-fades between children keyed by state.
class StateSwitcher extends StatelessWidget {
  const StateSwitcher({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: AppMotion.normal,
    switchInCurve: AppMotion.curve,
    switchOutCurve: AppMotion.curve,
    transitionBuilder: AppMotion.fadeRise,
    layoutBuilder: (current, previous) => Stack(
      alignment: Alignment.topCenter,
      children: [...previous, ?current],
    ),
    child: child,
  );
}

/// Placeholder rows that pulse gently while a table loads.
class SkeletonRows extends StatefulWidget {
  const SkeletonRows({super.key, this.rows = 3, this.height = 40});
  final int rows;
  final double height;
  @override
  State<SkeletonRows> createState() => _SkeletonRowsState();
}

class _SkeletonRowsState extends State<SkeletonRows>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opacity = .35 + _controller.value * .35;
        return Column(
          children: [
            for (var i = 0; i < widget.rows; i++)
              Container(
                height: widget.height,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  border: i == 0
                      ? null
                      : Border(top: BorderSide(color: c.hairline)),
                ),
                child: Row(
                  children: [
                    for (final flex in const [3, 2, 2])
                      Expanded(
                        flex: flex,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: .6,
                            child: Container(
                              height: 10,
                              decoration: BoxDecoration(
                                color: c.hairline.withValues(alpha: opacity),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Refresh icon that rotates while [active]; stops cleanly when done.
class SpinningIcon extends StatefulWidget {
  const SpinningIcon({
    super.key,
    required this.active,
    this.icon = Icons.refresh_rounded,
    this.size = 16,
  });
  final bool active;
  final IconData icon;
  final double size;
  @override
  State<SpinningIcon> createState() => _SpinningIconState();
}

class _SpinningIconState extends State<SpinningIcon>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant SpinningIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.animateTo(1, duration: AppMotion.slow).then((_) {
        if (mounted) _controller.reset();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _controller,
    child: Icon(widget.icon, size: widget.size),
  );
}

/// Column header cell for hand-built tables.
class TableLabel extends StatelessWidget {
  const TableLabel(this.text, {super.key, this.alignEnd = false});
  final String text;
  final bool alignEnd;
  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: alignEnd ? TextAlign.end : TextAlign.start,
    style: AppText.label(context),
  );
}

/// Label-over-value pair for identity details.
class DetailField extends StatelessWidget {
  const DetailField({
    super.key,
    required this.label,
    required this.value,
    this.mono = true,
  });
  final String label, value;
  final bool mono;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: AppText.label(context)),
      const SizedBox(height: 4),
      SelectableText(
        value,
        style: mono
            ? AppText.mono.copyWith(fontSize: 13)
            : Theme.of(context).textTheme.bodyMedium,
      ),
    ],
  );
}
