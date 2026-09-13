import 'package:flutter/material.dart';

import 'theme.dart';

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
