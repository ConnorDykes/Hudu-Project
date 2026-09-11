import 'dart:async';
import 'dart:io';

import 'package:desktop_core/desktop_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/controller.dart';
import 'src/models.dart';

class ProcessManagerApp extends StatelessWidget {
  const ProcessManagerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Hudu Process Manager',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ThemeMode.system,
    themeAnimationDuration: AppMotion.slow,
    home: const ProcessManagerPage(),
  );
}

class ProcessManagerPage extends ConsumerStatefulWidget {
  const ProcessManagerPage({super.key});
  @override
  ConsumerState<ProcessManagerPage> createState() => _ProcessManagerPageState();
}

class _ProcessManagerPageState extends ConsumerState<ProcessManagerPage> {
  int _page = 0;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _pageFocus = FocusNode(debugLabel: 'process-page');

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) unawaited(ref.read(managerProvider.notifier).initialize());
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _pageFocus.dispose();
    super.dispose();
  }

  void _focusSearch() {
    setState(() => _page = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocus.requestFocus();
        _search.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _search.text.length,
        );
      }
    });
  }

  /// Escape clears the filter and returns focus to the table so the arrow
  /// keys move the selection immediately afterwards.
  void _clearSearch() {
    if (_search.text.isNotEmpty) {
      _search.clear();
      ref.read(managerProvider.notifier).search('');
      setState(() {});
    }
    _pageFocus.requestFocus();
  }

  /// Arrow keys move the selection through the visible, sorted rows.
  void _moveSelection(int delta) {
    if (_page != 0) return;
    final state = ref.read(managerProvider);
    final rows = state.visible;
    if (rows.isEmpty) return;
    final current = state.selected == null
        ? -1
        : rows.indexWhere(state.selected!.sameIdentity);
    final next = (current + delta).clamp(0, rows.length - 1);
    ref.read(managerProvider.notifier).select(rows[next]);
  }

  void _refreshCurrent() {
    final controller = ref.read(managerProvider.notifier);
    unawaited(_page == 0 ? controller.refresh() : controller.refreshHistory());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(managerProvider);
    final controller = ref.read(managerProvider.notifier);
    final c = context.colors;
    final refreshing = _page == 0 ? state.refreshing : state.historyLoading;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _focusSearch,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _focusSearch,
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true):
            _refreshCurrent,
        const SingleActivator(LogicalKeyboardKey.keyR, control: true):
            _refreshCurrent,
        const SingleActivator(LogicalKeyboardKey.escape): _clearSearch,
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _moveSelection(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _moveSelection(-1),
      },
      child: Focus(
        focusNode: _pageFocus,
        autofocus: true,
        child: DesktopShell(
          productName: 'Process Manager',
          title: _page == 0 ? 'Processes' : 'Audit history',
          subtitle: _page == 0
              ? _summary(state)
              : 'Confirmed terminations recorded by the API · UTC',
          busy: _page == 0
              ? state.terminating ||
                    (state.refreshing && state.processes.isEmpty)
              : state.historyLoading && state.history.isEmpty,
          destinations: const [
            DesktopDestination(label: 'Processes', icon: Icons.memory_outlined),
            DesktopDestination(
              label: 'Audit history',
              icon: Icons.history_rounded,
            ),
          ],
          selectedIndex: _page,
          onDestinationSelected: (index) {
            setState(() => _page = index);
            if (index == 1) unawaited(controller.refreshHistory());
          },
          actions: [
            OutlinedButton.icon(
              onPressed:
                  (_page == 0 ? refreshing || state.terminating : refreshing)
                  ? null
                  : () => unawaited(
                      _page == 0
                          ? controller.refresh()
                          : controller.refreshHistory(),
                    ),
              icon: SpinningIcon(active: refreshing),
              label: const Text('Refresh'),
            ),
          ],
          footer: StatusPill(
            state.historyLoading
                ? 'Checking API'
                : state.historyError != null
                ? 'API unreachable'
                : 'API connected',
            color: state.historyLoading
                ? c.textTertiary
                : state.historyError != null
                ? c.danger
                : c.success,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _notices(state, controller),
              Expanded(
                child: _page == 0
                    ? _processes(state, controller)
                    : _history(state),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _summary(ManagerState state) {
    final count = '${state.processes.length} processes';
    final updated = state.updatedAt == null
        ? 'waiting for first refresh'
        : 'updated ${_time(state.updatedAt!)}';
    final pending = state.pending.isEmpty
        ? ''
        : ' · ${state.pending.length} undelivered audit${state.pending.length == 1 ? '' : 's'}';
    return '$count · $updated$pending';
  }

  /// Storage, operation, and delivery notices, animated in and out together.
  Widget _notices(ManagerState state, ManagerController controller) {
    final items = <Widget>[
      if (state.storageError != null)
        InlineNotice(
          key: const ValueKey('storage'),
          kind: NoticeKind.error,
          message: state.storageError!,
        ),
      if (state.notice != null)
        InlineNotice(
          key: ValueKey('notice-${state.notice}'),
          kind: state.notice!.contains('Exit confirmed')
              ? NoticeKind.info
              : NoticeKind.warning,
          message: state.notice!,
        ),
      if (state.pending.isNotEmpty)
        InlineNotice(
          key: const ValueKey('pending'),
          kind: NoticeKind.warning,
          message:
              '${state.pending.length} confirmed ${state.pending.length == 1 ? 'exit' : 'exits'} · audit pending',
          detail: state.storageError != null
              ? 'Some events are only in memory. Keep app open and retry.'
              : state.auditError ?? 'Saved locally. Delivery retries automatically every 30 seconds.',
          action: TextButton(
            onPressed: state.delivering
                ? null
                : () => unawaited(controller.retryAudits()),
            child: Text(state.delivering ? 'Delivering…' : 'Retry audit'),
          ),
        ),
      if (_page == 0 && state.processError != null)
        InlineNotice(
          key: const ValueKey('process-error'),
          kind: NoticeKind.error,
          message: state.processError!,
        ),
      if (_page == 1 && state.historyError != null)
        InlineNotice(
          key: const ValueKey('history-error'),
          kind: NoticeKind.error,
          message: state.historyError!,
        ),
    ];
    return AnimatedSize(
      duration: AppMotion.normal,
      curve: AppMotion.curve,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in items)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: item),
          if (items.isNotEmpty) const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _processes(ManagerState state, ManagerController controller) {
    final c = context.colors;
    final rows = state.visible;
    final selected = state.selected;
    final canTerminate =
        selected != null &&
        !state.terminating &&
        !state.refreshing &&
        state.ready &&
        state.storageError == null &&
        selected.identity != null &&
        selected.pid > 0 &&
        selected.pid != pid &&
        selected.status != 'Exited';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: TextField(
                controller: _search,
                focusNode: _searchFocus,
                onChanged: (value) {
                  controller.search(value);
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: 'Search by name or PID',
                  prefixIcon: const Icon(Icons.search_rounded, size: 16),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 0,
                  ),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          iconSize: 14,
                          icon: const Icon(Icons.close_rounded),
                          onPressed: _clearSearch,
                        ),
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 0,
                  ),
                ),
              ),
            ),
            const Spacer(),
            Text('Auto-refresh', style: AppText.label(context)),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: state.interval,
              isDense: true,
              underline: const SizedBox.shrink(),
              focusColor: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              iconSize: 18,
              iconEnabledColor: c.textSecondary,
              style: Theme.of(context).textTheme.bodyMedium,
              items: const [
                DropdownMenuItem(value: 0, child: Text('Off')),
                DropdownMenuItem(value: 5, child: Text('5 sec')),
                DropdownMenuItem(value: 10, child: Text('10 sec')),
                DropdownMenuItem(value: 30, child: Text('30 sec')),
              ],
              onChanged: (value) {
                if (value != null) controller.setInterval(value);
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _tableHeading(state, controller),
                const Divider(),
                Expanded(
                  child: rows.isEmpty
                      ? EmptyState(
                          title: state.refreshing
                              ? 'Reading local processes…'
                              : state.processError != null
                              ? 'Process list unavailable'
                              : state.query.trim().isNotEmpty
                              ? 'No matching processes'
                              : 'No processes returned',
                          message: state.refreshing
                              ? 'Retrieving process names and identities from your operating system.'
                              : state.processError != null
                              ? 'Use Refresh to try again.'
                              : state.query.trim().isNotEmpty
                              ? 'Try another name or PID, or clear your search.'
                              : 'The operating system returned an empty list. Try refreshing.',
                          icon: Icons.manage_search_rounded,
                        )
                      : ListView.builder(
                          itemCount: rows.length,
                          itemExtent: 36,
                          itemBuilder: (context, index) => _ProcessRow(
                            process: rows[index],
                            selected:
                                state.selected?.sameIdentity(rows[index]) ??
                                false,
                            ownPid: pid,
                            onTap: () => controller.select(
                              state.selected?.sameIdentity(rows[index]) ?? false
                                  ? null
                                  : rows[index],
                            ),
                          ),
                        ),
                ),
                const Divider(),
                Container(
                  height: 50,
                  padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: AppMotion.normal,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          layoutBuilder: (current, previous) => Stack(
                            alignment: Alignment.centerLeft,
                            children: [...previous, ?current],
                          ),
                          child: selected == null
                              ? Text(
                                  key: const ValueKey('none'),
                                  '${rows.length} shown · select a process to inspect or terminate',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                )
                              : Row(
                                  key: ValueKey(
                                    '${selected.pid}-${selected.identity}',
                                  ),
                                  children: [
                                    Flexible(
                                      child: Text(
                                        selected.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'PID ${selected.pid}',
                                      style: AppText.mono.copyWith(
                                        color: c.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: canTerminate
                            ? () => _confirm(selected)
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: c.danger,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: c.danger.withValues(
                            alpha: .18,
                          ),
                          disabledForegroundColor: c.textTertiary,
                        ),
                        icon: const Icon(Icons.stop_circle_outlined, size: 15),
                        label: Text(
                          state.terminating
                              ? 'Confirming exit…'
                              : 'Terminate process',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tableHeading(ManagerState state, ManagerController controller) =>
      Container(
        height: 34,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
        child: Row(
          children: [
            const SizedBox(width: 2),
            Expanded(
              child: _SortHeader(
                label: 'Name',
                active: !state.sortPid,
                ascending: state.ascending,
                onTap: () => controller.sort(false),
              ),
            ),
            SizedBox(
              width: 100,
              child: _SortHeader(
                label: 'PID',
                alignEnd: true,
                active: state.sortPid,
                ascending: state.ascending,
                onTap: () => controller.sort(true),
              ),
            ),
            const SizedBox(width: 24),
            const SizedBox(width: 110, child: TableLabel('Status')),
          ],
        ),
      );

  Widget _history(ManagerState state) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: const Row(
                    children: [
                      Expanded(child: TableLabel('Process')),
                      SizedBox(
                        width: 100,
                        child: TableLabel('PID', alignEnd: true),
                      ),
                      SizedBox(width: 24),
                      SizedBox(width: 210, child: TableLabel('Exit confirmed')),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: state.history.isEmpty
                      ? (state.historyLoading
                            ? const SkeletonRows(rows: 3)
                            : EmptyState(
                                title: state.historyError != null
                                    ? 'History unavailable'
                                    : 'No termination events yet',
                                message: state.historyError != null
                                    ? 'Start the Rails API and refresh to load persisted history.'
                                    : 'Confirmed terminations appear here after the API accepts their audit events.',
                                icon: Icons.history_rounded,
                              ))
                      : ListView.builder(
                          itemCount: state.history.length,
                          itemExtent: 38,
                          itemBuilder: (context, index) {
                            final event = state.history[index];
                            return _HoverRow(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        event.processName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        '${event.pid}',
                                        textAlign: TextAlign.end,
                                        style: AppText.mono.copyWith(
                                          color: c.textSecondary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    SizedBox(
                                      width: 210,
                                      child: Text(
                                        _utc(event.occurredAt),
                                        style: AppText.mono.copyWith(
                                          color: c.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirm(LocalProcess process) async {
    final c = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminate this process?'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: c.hairline),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        process.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'PID ${process.pid}',
                      style: AppText.mono.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                Platform.isWindows
                    ? 'Unsaved work in this process may be lost. Windows ends it immediately.'
                    : 'Unsaved work in this process may be lost. macOS sends SIGTERM and waits up to 4 seconds for it to exit.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: c.textSecondary),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: c.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm termination'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(managerProvider.notifier).terminate(process);
    }
  }
}

class _SortHeader extends StatelessWidget {
  const _SortHeader({
    required this.label,
    required this.active,
    required this.ascending,
    required this.onTap,
    this.alignEnd = false,
  });
  final String label;
  final bool active, ascending, alignEnd;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppText.label(context)
                    .copyWith(color: active ? c.text : c.textTertiary),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                duration: AppMotion.normal,
                curve: AppMotion.curve,
                turns: ascending ? 0 : .5,
                child: Icon(
                  Icons.arrow_upward_rounded,
                  size: 12,
                  color: active ? c.text : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row hover highlight for read-only tables.
class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.child});
  final Widget child;
  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
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
          border: Border(bottom: BorderSide(color: c.hairline)),
        ),
        child: widget.child,
      ),
    );
  }
}

class _ProcessRow extends StatelessWidget {
  const _ProcessRow({
    required this.process,
    required this.selected,
    required this.ownPid,
    required this.onTap,
  });
  final LocalProcess process;
  final bool selected;
  final int ownPid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isSelf = process.pid == ownPid;
    final statusColor = isSelf
        ? c.accent
        : switch (process.status) {
            'Running' => c.success,
            'Protected' => c.warning,
            _ => c.textTertiary,
          };
    return Semantics(
      selected: selected,
      button: true,
      label: '${process.name}, PID ${process.pid}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('process-${process.pid}'),
          onTap: onTap,
          hoverColor: c.hover,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            decoration: BoxDecoration(
              color: selected ? c.selection : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: selected ? c.accent : Colors.transparent,
                  width: 2,
                ),
                bottom: BorderSide(color: c.hairline),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    process.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: process.status == 'Exited'
                          ? c.textTertiary
                          : c.text,
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    '${process.pid}',
                    textAlign: TextAlign.end,
                    style: AppText.mono.copyWith(color: c.textSecondary),
                  ),
                ),
                const SizedBox(width: 24),
                SizedBox(
                  width: 110,
                  child: StatusPill(
                    isSelf ? 'This app' : process.status,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
String _utc(DateTime value) =>
    '${value.toUtc().toIso8601String().substring(0, 10)} ${_time(value.toUtc())} UTC';
