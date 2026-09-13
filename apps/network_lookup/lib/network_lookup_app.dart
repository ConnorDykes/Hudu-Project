import 'package:desktop_core/desktop_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/lookup/lookup_controller.dart';
import 'src/lookup/lookup_repository.dart';
import 'src/network/network_adapter.dart';

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

/// One view: address in, identity out, history below.
class NetworkLookupPage extends ConsumerStatefulWidget {
  const NetworkLookupPage({super.key});
  @override
  ConsumerState<NetworkLookupPage> createState() => _NetworkLookupPageState();
}

class _NetworkLookupPageState extends ConsumerState<NetworkLookupPage> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit() =>
      ref.read(lookupControllerProvider.notifier).lookup(_input.text);

  void _refresh() {
    ref.invalidate(historyProvider);
    ref.invalidate(interfacesProvider);
  }

  /// Lets the user name a vendor for a MAC that no source recognized.
  Future<void> _nameVendor() async {
    final mac = ref.read(lookupControllerProvider).resolution?.mac;
    if (mac == null) return;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _VendorNameDialog(oui: mac.substring(0, 8)),
    );
    if (name != null && name.trim().isNotEmpty && mounted) {
      await ref.read(lookupControllerProvider.notifier).nameVendor(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lookupControllerProvider);
    final history = ref.watch(historyProvider);
    final interfaces = ref.watch(interfacesProvider);
    return DesktopShell(
      productName: 'Network Lookup',
      title: 'Network Lookup',
      busy: state.busy,
      actions: [
        OutlinedButton.icon(
          onPressed: _refresh,
          icon: SpinningIcon(active: history.isLoading || interfaces.isLoading),
          label: const Text('Refresh'),
        ),
      ],
      footer: ApiStatusPill(
        loading: history.isLoading,
        failed: history.hasError,
        tooltip: Uri.tryParse(ref.watch(apiClientProvider).baseUrl)?.authority,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('ip-input'),
                    controller: _input,
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
                      prefixIconConstraints: BoxConstraints(
                        minWidth: 34,
                        minHeight: 0,
                      ),
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
            ),
            const SizedBox(height: 8),
            _OwnAddressRow(
              interfaces: interfaces,
              enabled: !state.busy,
              onUse: (ip) {
                _input.text = ip;
                _submit();
              },
              onRetry: () => ref.invalidate(interfacesProvider),
            ),
            const SizedBox(height: 18),
            SectionCard(
              padding: EdgeInsets.zero,
              child: StateSwitcher(
                child: KeyedSubtree(
                  key: ValueKey(
                    '${state.phase}-${state.record?.id}-'
                    '${state.resolution?.mac}-${state.message}',
                  ),
                  child: LookupResultCard(
                    state: state,
                    onNameVendor: state.canNameVendor ? _nameVendor : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  'Lookup history',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 10),
                Text(
                  'Latest 30 saved by the API · newest first',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SectionCard(
              padding: EdgeInsets.zero,
              child: LookupTable(
                history: history,
                onRefresh: () => ref.invalidate(historyProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorNameDialog extends StatefulWidget {
  const _VendorNameDialog({required this.oui});
  final String oui;
  @override
  State<_VendorNameDialog> createState() => _VendorNameDialogState();
}

class _VendorNameDialogState extends State<_VendorNameDialog> {
  final _name = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Name this vendor'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Applies to every address starting with ${widget.oui} and is '
            'saved by the API for future lookups.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('vendor-name-input'),
            controller: _name,
            autofocus: true,
            maxLength: 255,
            decoration: const InputDecoration(
              hintText: 'Vendor name, for example Lab sensor',
              counterText: '',
            ),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _name.text),
        child: const Text('Save vendor'),
      ),
    ],
  );
}

/// Optional challenge: detect the machine's primary active IPv4 address.
class _OwnAddressRow extends StatelessWidget {
  const _OwnAddressRow({
    required this.interfaces,
    required this.enabled,
    required this.onUse,
    required this.onRetry,
  });
  final AsyncValue<InterfaceSnapshot> interfaces;
  final bool enabled;
  final ValueChanged<String> onUse;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWindows = theme.platform == TargetPlatform.windows;
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
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
      error: (error, _) => InlineNotice(
        kind: NoticeKind.error,
        message: friendlyError(error),
        action: TextButton(onPressed: onRetry, child: const Text('Retry')),
      ),
      data: (snapshot) {
        final primary = snapshot.preferred;
        return Row(
          children: [
            TextButton.icon(
              onPressed: primary == null || !enabled
                  ? null
                  : () => onUse(primary.ip),
              icon: const Icon(Icons.my_location_rounded, size: 14),
              label: const Text('Use my IP'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                primary == null
                    ? 'No active IPv4 interfaces found. Check your network connection.'
                    : 'Primary interface: ${primary.displayName} · ${primary.ip}'
                          '${snapshot.notice == null ? '' : ' · ${snapshot.notice}'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
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
  const LookupResultCard({super.key, required this.state, this.onNameVendor});
  final LookupState state;

  /// Offered when the lookup completed but no source knew the vendor.
  final VoidCallback? onNameVendor;

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
            Text(switch (state.phase) {
              LookupPhase.discovering => 'Reading the local network cache…',
              LookupPhase.naming => 'Saving vendor name…',
              _ => 'Identifying vendor & saving lookup…',
            }, style: theme.textTheme.titleSmall),
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
            children: [
              DetailField(label: 'IP address', value: resolution.ip),
              DetailField(label: 'MAC address', value: resolution.mac),
              DetailField(label: 'Interface', value: resolution.interfaceName),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  record == null
                      ? 'History save unconfirmed · check the history below before repeating.'
                      : 'Saved to history · ${formatLocalMinute(record.createdAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: record == null ? c.warning : c.textTertiary,
                  ),
                ),
              ),
              if (onNameVendor != null)
                OutlinedButton.icon(
                  key: const Key('name-vendor-button'),
                  onPressed: onNameVendor,
                  icon: const Icon(Icons.label_outline_rounded, size: 15),
                  label: const Text('Name this vendor'),
                ),
            ],
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

/// History rows straight from the API. Never shows an invented row.
class LookupTable extends StatelessWidget {
  const LookupTable({
    super.key,
    required this.history,
    required this.onRefresh,
  });
  final AsyncValue<List<LookupRecord>> history;
  final VoidCallback onRefresh;

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
              for (final record in records)
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
    Widget cell(Widget child) =>
        header ? DefaultTextStyle(style: labelStyle, child: child) : child;
    return Container(
      height: header ? 34 : 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: header ? null : Border(top: BorderSide(color: c.hairline)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: cell(cells[0])),
          Expanded(flex: 2, child: cell(cells[1])),
          Expanded(flex: 2, child: cell(cells[2])),
          if (wide) Expanded(flex: 2, child: cell(cells[3])),
          SizedBox(width: 120, child: cell(cells[4])),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.record, required this.wide});
  final LookupRecord record;
  final bool wide;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    return HoverRow(
      child: _TableRow(
        wide: wide,
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
            formatLocalMinute(record.createdAt),
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
    );
  }
}
