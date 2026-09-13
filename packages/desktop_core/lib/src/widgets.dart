import 'package:flutter/material.dart';

import 'theme.dart';

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

/// Whether the API answered the most recent history request.
class ApiStatusPill extends StatelessWidget {
  const ApiStatusPill({
    super.key,
    required this.loading,
    required this.failed,
    this.tooltip,
  });
  final bool loading, failed;

  /// Typically the API authority, shown on hover.
  final String? tooltip;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (color, label) = loading
        ? (c.textTertiary, 'Checking API')
        : failed
        ? (c.danger, 'API unreachable')
        : (c.success, 'API connected');
    final pill = StatusPill(label, color: color);
    return tooltip == null ? pill : Tooltip(message: tooltip!, child: pill);
  }
}

/// Row hover highlight for hand-built tables.
class HoverRow extends StatefulWidget {
  const HoverRow({super.key, required this.child, this.bottomBorder = false});
  final Widget child;
  final bool bottomBorder;
  @override
  State<HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<HoverRow> {
  var _hovered = false;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        decoration: BoxDecoration(
          color: _hovered ? c.hover : Colors.transparent,
          border: widget.bottomBorder
              ? Border(bottom: BorderSide(color: c.hairline))
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}
