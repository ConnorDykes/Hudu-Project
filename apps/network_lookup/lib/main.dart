import 'package:desktop_core/desktop_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lookup/lookup_controller.dart';
import 'lookup/lookup_repository.dart';
import 'network/network_adapter.dart';

void main() => runApp(const ProviderScope(child: NetworkLookupApp()));

class NetworkLookupApp extends StatelessWidget {
  const NetworkLookupApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Hudu Network Lookup',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ThemeMode.system,
    themeAnimationDuration: AppMotion.slow,
    home: const NetworkLookupPage(),
  );
}

class NetworkLookupPage extends ConsumerStatefulWidget {
  const NetworkLookupPage({super.key});
  @override
  ConsumerState<NetworkLookupPage> createState() => _NetworkLookupPageState();
}

class _NetworkLookupPageState extends ConsumerState<NetworkLookupPage> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  int _page = 0;
  String? _interface;

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final available = ref.read(interfacesProvider).value?.interfaces;
    final selected = available?.any((i) => i.name == _interface) == true
        ? _interface
        : null;
    ref
        .read(lookupControllerProvider.notifier)
        .lookup(_input.text, interfaceName: selected);
  }

  void _refresh() {
    ref.invalidate(historyProvider);
    if (_page == 0) ref.invalidate(interfacesProvider);
  }

  void _focusInput() {
    setState(() => _page = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _inputFocus.requestFocus();
        _input.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _input.text.length,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lookupControllerProvider);
    final history = ref.watch(historyProvider);
    final interfaces = ref.watch(interfacesProvider);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyL, meta: true): _focusInput,
        const SingleActivator(LogicalKeyboardKey.keyL, control: true):
            _focusInput,
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): _refresh,
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): _refresh,
      },
      child: Focus(
        autofocus: true,
        child: DesktopShell(
          productName: 'Network Lookup',
          title: _page == 0 ? 'Network Lookup' : 'Lookup history',
          subtitle: _page == 0
              ? 'Resolve a local IPv4 address to its MAC and vendor'
              : 'Latest 30 lookups saved by the API',
          busy: state.busy,
          destinations: const [
            DesktopDestination(label: 'Lookup', icon: Icons.lan_outlined),
            DesktopDestination(label: 'History', icon: Icons.history_rounded),
          ],
          selectedIndex: _page,
          onDestinationSelected: (index) {
            setState(() => _page = index);
            if (index == 1) ref.invalidate(historyProvider);
          },
          actions: [
            OutlinedButton.icon(
              onPressed: _refresh,
              icon: SpinningIcon(
                active: history.isLoading || interfaces.isLoading,
              ),
              label: const Text('Refresh'),
            ),
          ],
          footer: _ApiStatus(
            authority: Uri.tryParse(ref.watch(apiClientProvider).baseUrl)
                ?.authority,
            history: history,
          ),
          child: _page == 1
              ? _HistoryPage(
                  history: history,
                  onRefresh: () => ref.invalidate(historyProvider),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _queryRow(state),
                      const SizedBox(height: 10),
                      _interfaceRow(state, interfaces),
                      const SizedBox(height: 18),
                      SectionCard(
                        padding: EdgeInsets.zero,
                        child: StateSwitcher(
                          child: KeyedSubtree(
                            key: ValueKey(
                              '${state.phase}-${state.record?.id}-'
                              '${state.resolution?.mac}-${state.message}',
                            ),
                            child: LookupResultCard(state: state),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Text(
                            'Recent lookups',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => setState(() => _page = 1),
                            child: const Text('View all'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SectionCard(
                        padding: EdgeInsets.zero,
                        child: LookupTable(
                          history: history,
                          limit: 5,
                          onRefresh: () => ref.invalidate(historyProvider),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _queryRow(LookupState state) => Row(
    children: [
      Expanded(
        child: TextField(
          key: const Key('ip-input'),
          controller: _input,
          focusNode: _inputFocus,
          autofocus: true,
          enabled: !state.busy,
          onSubmitted: (_) => _submit(),
          style: AppText.mono.copyWith(
            fontSize: 13.5,
            color: context.colors.text,
          ),
          decoration: const InputDecoration(
            hintText: 'IPv4 address, for example 192.168.1.10',
            prefixIcon: Icon(Icons.lan_outlined, size: 16),
            prefixIconConstraints: BoxConstraints(minWidth: 34, minHeight: 0),
          ),
        ),
      ),
      const SizedBox(width: 8),
      FilledButton(
        key: const Key('lookup-button'),
        onPressed: state.busy ? null : _submit,
        child: Text(state.busy ? 'Looking up…' : 'Look up'),
      ),
    ],
  );

  Widget _interfaceRow(
    LookupState state,
    AsyncValue<InterfaceSnapshot> interfaces,
  ) {
    final c = context.colors;
    final isWindows = Theme.of(context).platform == TargetPlatform.windows;
    return interfaces.when(
      skipLoadingOnRefresh: false,
      loading: () => Row(
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isWindows
                  ? 'Reading active interfaces… $_windowsDiscoveryHint'
                  : 'Reading active interfaces…',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
      error: (error, _) => InlineNotice(
        kind: NoticeKind.error,
        message: friendlyError(error),
        action: TextButton(
          onPressed: () => ref.invalidate(interfacesProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (snapshot) {
        final names = <String, LocalInterface>{
          for (final i in snapshot.interfaces) i.name: i,
        };
        final selected = names.containsKey(_interface) ? _interface : null;
        final own = selected == null ? snapshot.preferred : names[selected];
        final summary = snapshot.interfaces.isEmpty
            ? 'No active IPv4 interfaces found. Check your network connection.'
            : snapshot.notice ??
                  'Primary interface: ${snapshot.preferred!.displayName} · ${snapshot.preferred!.ip}';
        return Row(
          children: [
            Text('Interface', style: AppText.label(context)),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300, minWidth: 140),
              child: DropdownButton<String>(
                value: selected ?? '',
                isDense: true,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                focusColor: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                iconSize: 18,
                iconEnabledColor: c.textSecondary,
                style: Theme.of(context).textTheme.bodyMedium,
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('All interfaces'),
                  ),
                  for (final i in names.values)
                    DropdownMenuItem(
                      value: i.name,
                      child: Text(
                        '${i.displayName} · ${i.ip}${i.primary ? ' · primary' : ''}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: state.busy
                    ? null
                    : (value) => setState(
                        () => _interface = value == '' ? null : value,
                      ),
              ),
            ),
            const SizedBox(width: 6),
            TextButton.icon(
              onPressed: own == null || state.busy
                  ? null
                  : () {
                      _input.text = own.ip;
                      setState(() => _interface = own.name);
                      _inputFocus.requestFocus();
                    },
              icon: const Icon(Icons.my_location_rounded, size: 14),
              label: const Text('Use my IP'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The result panel. Its content is keyed by phase so state changes cross-fade.
class LookupResultCard extends StatelessWidget {
  const LookupResultCard({super.key, required this.state});
  final LookupState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    final resolution = state.resolution;
    final record = state.record;
    final status = record?.status;
    final isWindows = theme.platform == TargetPlatform.windows;

    if (state.phase == LookupPhase.idle) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 16, color: c.textTertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Enter a local IPv4 address to resolve its hardware address and vendor.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }
    if (state.busy) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.phase == LookupPhase.discovering
                  ? 'Reading the local network cache…'
                  : 'Identifying vendor & saving lookup…',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              state.ip ?? '',
              style: AppText.mono.copyWith(color: c.textSecondary),
            ),
            if (state.phase == LookupPhase.discovering && isWindows) ...[
              const SizedBox(height: 6),
              Text(_windowsDiscoveryHint, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      );
    }
    if (resolution == null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InlineNotice(
              kind: NoticeKind.error,
              message: state.message ?? 'No device identity found.',
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                state.ip == null
                    ? 'IPv4 is supported. IPv6 is outside the scope of ARP.'
                    : '${state.ip} · No lookup was sent to the API.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    final unknown = status == VendorStatus.unknown;
    final failed = status == VendorStatus.failed;
    final title = status == VendorStatus.resolved
        ? record!.vendor!
        : unknown
        ? 'Vendor not identified'
        : failed
        ? 'Vendor service unavailable'
        : 'Hardware address found';
    final source = resolution.isOwnInterface
        ? 'local interface metadata'
        : 'the neighbor cache';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        color: status == VendorStatus.resolved
                            ? c.text
                            : c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      unknown
                          ? 'No vendor match. Private or locally assigned MACs may be unknown.'
                          : 'Identified from $source.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (record != null)
                StatusPill(
                  status == VendorStatus.resolved
                      ? 'Resolved'
                      : unknown
                      ? 'Unknown vendor'
                      : 'Provider error',
                  color: status == VendorStatus.resolved
                      ? c.success
                      : unknown
                      ? c.warning
                      : c.danger,
                )
              else
                StatusPill('Save unconfirmed', color: c.warning),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 14),
          Wrap(
            spacing: 36,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              DetailField(label: 'IP address', value: resolution.ip),
              DetailField(
                label: 'MAC address',
                value: resolution.mac,
                trailing: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: IconButton(
                    tooltip: 'Copy MAC address',
                    visualDensity: VisualDensity.compact,
                    iconSize: 13,
                    constraints: const BoxConstraints.tightFor(
                      width: 22,
                      height: 20,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: resolution.mac),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('MAC address copied'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
              DetailField(label: 'Interface', value: resolution.interfaceName),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            record == null
                ? 'History save unconfirmed · check History before repeating.'
                : 'Saved to history · ${formatTimestamp(record.createdAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: record == null ? c.warning : c.textTertiary,
            ),
          ),
          if (state.message != null) ...[
            const SizedBox(height: 10),
            InlineNotice(kind: NoticeKind.warning, message: state.message!),
          ],
        ],
      ),
    );
  }
}

final _windowsDiscoveryHint =
    'Windows network initialization may take up to '
    '${NativeNetworkAdapter.windowsDiscoveryTimeout.inSeconds} seconds on first use.';

class _HistoryPage extends StatelessWidget {
  const _HistoryPage({required this.history, required this.onRefresh});
  final AsyncValue<List<LookupRecord>> history;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Text('Saved lookups', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 10),
          Text(
            'Newest first · resolved, unknown, and failed attempts',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      const SizedBox(height: 8),
      Expanded(
        child: SectionCard(
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            child: LookupTable(history: history, onRefresh: onRefresh),
          ),
        ),
      ),
    ],
  );
}

/// History rows straight from the API. Never shows an invented row.
class LookupTable extends StatelessWidget {
  const LookupTable({
    super.key,
    required this.history,
    required this.onRefresh,
    this.limit,
  });
  final AsyncValue<List<LookupRecord>> history;
  final VoidCallback onRefresh;
  final int? limit;

  @override
  Widget build(BuildContext context) => history.when(
    skipLoadingOnRefresh: false,
    loading: () => const SkeletonRows(rows: 3),
    error: (error, _) => EmptyState(
      title: 'History is unavailable',
      message: friendlyError(error),
      icon: Icons.cloud_off_rounded,
      action: OutlinedButton.icon(
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh_rounded, size: 15),
        label: const Text('Retry history'),
      ),
    ),
    data: (records) {
      if (records.isEmpty) {
        return const EmptyState(
          title: 'No lookups yet',
          message:
              'Completed lookups are saved by the API, including unknown '
              'vendors and provider failures.',
          icon: Icons.history_rounded,
        );
      }
      final visible = limit == null ? records : records.take(limit!).toList();
      return LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 760;
          return Column(
            children: [
              _TableRow(
                header: true,
                wide: wide,
                cells: const [
                  Text('Vendor'),
                  Text('MAC address'),
                  Text('IP address'),
                  Text('Time'),
                  Text('Status'),
                ],
              ),
              for (final record in visible)
                _HistoryRow(record: record, wide: wide),
            ],
          );
        },
      );
    },
  );
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.cells,
    required this.wide,
    this.header = false,
  });
  final List<Widget> cells;
  final bool wide, header;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final labelStyle = AppText.label(context);
    Widget cell(int index, Widget child) =>
        header ? DefaultTextStyle(style: labelStyle, child: child) : child;
    return Container(
      height: header ? 34 : 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: header ? null : Border(top: BorderSide(color: c.hairline)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: cell(0, cells[0])),
          Expanded(flex: 2, child: cell(1, cells[1])),
          Expanded(flex: 2, child: cell(2, cells[2])),
          if (wide) Expanded(flex: 2, child: cell(3, cells[3])),
          SizedBox(width: 120, child: cell(4, cells[4])),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatefulWidget {
  const _HistoryRow({required this.record, required this.wide});
  final LookupRecord record;
  final bool wide;
  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  var _hovered = false;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final record = widget.record;
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        color: _hovered ? c.hover : Colors.transparent,
        child: _TableRow(
          wide: widget.wide,
          cells: [
            Text(
              record.vendor ??
                  (record.status == VendorStatus.unknown
                      ? 'Unknown vendor'
                      : 'Provider error'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: record.vendor == null ? c.textSecondary : c.text,
              ),
            ),
            SelectableText(record.mac, style: AppText.mono),
            SelectableText(
              record.ip ?? '—',
              style: AppText.mono.copyWith(
                color: record.ip == null ? c.textTertiary : c.text,
              ),
            ),
            Text(
              formatTimestamp(record.createdAt),
              style: theme.textTheme.bodySmall,
            ),
            StatusPill(
              switch (record.status) {
                VendorStatus.resolved => 'Resolved',
                VendorStatus.unknown => 'Unknown',
                VendorStatus.failed => 'Failed',
              },
              color: switch (record.status) {
                VendorStatus.resolved => c.success,
                VendorStatus.unknown => c.warning,
                VendorStatus.failed => c.danger,
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Sidebar footer: whether the API answered the last history request.
class _ApiStatus extends StatelessWidget {
  const _ApiStatus({required this.authority, required this.history});
  final String? authority;
  final AsyncValue<List<LookupRecord>> history;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (color, label) = switch (history) {
      AsyncValue(isLoading: true) => (c.textTertiary, 'Checking API'),
      AsyncValue(hasError: true) => (c.danger, 'API unreachable'),
      _ => (c.success, 'API connected'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusPill(label, color: color),
        if (authority != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Text(
              authority!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.mono.copyWith(fontSize: 11, color: c.textTertiary),
            ),
          ),
        ],
      ],
    );
  }
}

String formatTimestamp(DateTime value) {
  final date = value.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
}
