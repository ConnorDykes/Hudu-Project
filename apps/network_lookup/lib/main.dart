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
    theme: AppTheme.dark,
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
          eyebrow: 'NETWORK INTELLIGENCE',
          title: _page == 0 ? 'Network Lookup' : 'Recent history',
          subtitle: _page == 0
              ? 'From a local IP to a hardware identity. A clearer picture of your network.'
              : 'Your latest 30 vendor lookups, saved by the Rails service.',
          destinations: const [
            DesktopDestination(label: 'Lookup', icon: Icons.radar_rounded),
            DesktopDestination(
              label: 'Recent history',
              icon: Icons.history_rounded,
            ),
          ],
          selectedIndex: _page,
          onDestinationSelected: (index) {
            setState(() => _page = index);
            if (index == 1) ref.invalidate(historyProvider);
          },
          actions: [
            OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
            ),
          ],
          footer: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusPill('IPv4 · local link', icon: Icons.lan_outlined),
              SizedBox(height: 16),
              Text(
                'DISCOVER. IDENTIFY. REMEMBER.',
                style: TextStyle(
                  fontSize: 9,
                  color: AppTheme.muted,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Network Lookup\nHudu Desktop Suite',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.muted,
                  height: 1.8,
                ),
              ),
            ],
          ),
          child: _page == 1
              ? SingleChildScrollView(
                  child: _HistorySection(
                    history: history,
                    full: true,
                    onRefresh: () => ref.invalidate(historyProvider),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _searchCard(state, interfaces),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final result = LookupResultCard(state: state);
                          if (constraints.maxWidth < 1000) return result;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: result),
                              const SizedBox(width: 20),
                              const SizedBox(width: 250, child: _ScopeCard()),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _HistorySection(
                        history: history,
                        full: false,
                        onRefresh: () => ref.invalidate(historyProvider),
                        onViewAll: () => setState(() => _page = 1),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Cache reads are passive. No devices are scanned or probed.',
                        style: TextStyle(fontSize: 11, color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
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

  Widget _searchCard(
    LookupState state,
    AsyncValue<InterfaceSnapshot> interfaces,
  ) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.travel_explore_rounded,
              size: 20,
              color: AppTheme.mint,
            ),
            const SizedBox(width: 10),
            Text(
              'Find a device',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            const Text(
              'IPv4 LOOKUP',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 10,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const Key('ip-input'),
                controller: _input,
                focusNode: _inputFocus,
                autofocus: true,
                enabled: !state.busy,
                onSubmitted: (_) => _submit(),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                  fontSize: 16,
                  letterSpacing: .6,
                ),
                decoration: const InputDecoration(
                  labelText: 'IP address',
                  hintText: '192.168.1.10',
                  prefixIcon: Icon(Icons.lan_outlined, size: 20),
                  helperText: 'Enter a device address on your local network.',
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              key: const Key('lookup-button'),
              onPressed: state.busy ? null : _submit,
              icon: state.busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(state.busy ? 'Looking up…' : 'Look up device'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        interfaces.when(
          skipLoadingOnRefresh: false,
          loading: () => const Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text(
                'Reading active interfaces…',
                style: TextStyle(color: AppTheme.muted, fontSize: 12),
              ),
            ],
          ),
          error: (error, _) => _Notice(
            message: friendlyError(error),
            action: TextButton(
              onPressed: () => ref.invalidate(interfacesProvider),
              child: const Text('Retry'),
            ),
          ),
          data: (snapshot) {
            final values = snapshot.interfaces;
            final names = <String, LocalInterface>{
              for (final i in values) i.name: i,
            };
            final selected = names.containsKey(_interface) ? _interface : null;
            final own = selected == null ? snapshot.preferred : names[selected];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(
                          'interface-$selected-${names.keys.join(',')}',
                        ),
                        initialValue: selected ?? '',
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Interface',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text(
                              'All interfaces',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          for (final i in names.values)
                            DropdownMenuItem(
                              value: i.name,
                              child: Text(
                                '${i.displayName} · ${i.ip}${i.primary ? ' · primary' : ''}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
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
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: own == null || state.busy
                          ? null
                          : () {
                              _input.text = own.ip;
                              setState(() => _interface = own.name);
                              _inputFocus.requestFocus();
                            },
                      icon: const Icon(Icons.my_location_rounded, size: 16),
                      label: const Text('Use my IP'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  values.isEmpty
                      ? 'No active IPv4 interfaces found. Check your network connection.'
                      : snapshot.notice ??
                            'Primary interface: ${snapshot.preferred!.displayName} · ${snapshot.preferred!.ip}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class LookupResultCard extends StatelessWidget {
  const LookupResultCard({super.key, required this.state});
  final LookupState state;

  @override
  Widget build(BuildContext context) {
    final resolution = state.resolution;
    final record = state.record;
    final status = record?.status;
    final localMac = resolution?.mac;
    final unknown = status == VendorStatus.unknown;
    final failed = status == VendorStatus.failed;
    final title = status == VendorStatus.resolved
        ? record!.vendor!
        : unknown
        ? 'Vendor not identified'
        : failed
        ? 'Vendor service unavailable'
        : 'Hardware address found';
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Device identity',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              if (record != null)
                StatusPill(
                  status == VendorStatus.resolved
                      ? 'Resolved'
                      : unknown
                      ? 'Unknown vendor'
                      : 'Provider error',
                  color: status == VendorStatus.resolved
                      ? AppTheme.mint
                      : _amber,
                ),
              if (state.busy)
                const StatusPill('In progress', color: AppTheme.muted),
            ],
          ),
          if (state.phase == LookupPhase.idle)
            const EmptyState(
              title: 'A little clarity starts with an IP.',
              message:
                  'Look up a local device to see its hardware address and vendor. '
                  'Completed vendor attempts appear in your history.',
              icon: Icons.radar_rounded,
            )
          else if (state.busy) ...[
            const SizedBox(height: 30),
            Text(
              state.phase == LookupPhase.discovering
                  ? 'Reading the local network cache…'
                  : 'Identifying vendor & saving lookup…',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.ip ?? '',
              style: const TextStyle(
                color: AppTheme.muted,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 24),
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 20),
          ] else if (resolution == null) ...[
            const SizedBox(height: 20),
            _Notice(message: state.message ?? 'No device identity found.'),
            const SizedBox(height: 14),
            Text(
              state.ip == null
                  ? 'IPv4 is supported. IPv6 is outside the scope of ARP.'
                  : '${state.ip} · No lookup was sent to the API.',
              style: const TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ] else ...[
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppTheme.mint.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    resolution.isOwnInterface
                        ? Icons.computer_rounded
                        : Icons.router_outlined,
                    color: AppTheme.mint,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'HARDWARE VENDOR',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.muted,
                          letterSpacing: 1.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        unknown
                            ? 'No vendor match. Private or locally assigned MACs may be unknown.'
                            : 'Identified from ${resolution.isOwnInterface ? 'local interface metadata' : 'the neighbor cache'}.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Divider(height: 1),
            const SizedBox(height: 20),
            Wrap(
              spacing: 32,
              runSpacing: 16,
              children: [
                _IdentityField(label: 'IP ADDRESS', value: resolution.ip),
                _IdentityField(label: 'MAC ADDRESS', value: localMac!),
                _IdentityField(
                  label: 'INTERFACE',
                  value: resolution.interfaceName,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    record == null
                        ? 'History save unconfirmed · check Recent history before repeating.'
                        : 'Saved to history · ${formatTimestamp(record.createdAt)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: record == null ? _amber : AppTheme.muted,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy MAC address',
                  icon: const Icon(Icons.copy_rounded, size: 17),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: localMac));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('MAC address copied')),
                      );
                    }
                  },
                ),
              ],
            ),
            if (state.message != null) ...[
              const SizedBox(height: 10),
              _Notice(message: state.message!),
            ],
          ],
        ],
      ),
    );
  }
}

const _amber = Color(0xFFF2C77B);

class _IdentityField extends StatelessWidget {
  const _IdentityField({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          letterSpacing: 1.4,
          color: AppTheme.muted,
        ),
      ),
      const SizedBox(height: 7),
      SelectableText(
        value,
        style: const TextStyle(
          fontFeatures: [FontFeature.tabularFigures()],
          fontSize: 13,
        ),
      ),
    ],
  );
}

class _ScopeCard extends StatelessWidget {
  const _ScopeCard();
  @override
  Widget build(BuildContext context) => const SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.hub_outlined, color: AppTheme.mint, size: 25),
        SizedBox(height: 18),
        Text(
          'Local by design',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 10),
        Text(
          'ARP knows your neighbors. It cannot identify hardware across a router.',
          style: TextStyle(fontSize: 12, color: AppTheme.muted, height: 1.7),
        ),
        SizedBox(height: 18),
        Divider(height: 1),
        SizedBox(height: 16),
        Text(
          'A missing cache entry does not mean a device is offline.',
          style: TextStyle(fontSize: 12, color: AppTheme.muted, height: 1.7),
        ),
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, this.action});
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _amber.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _amber.withValues(alpha: .18)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, color: _amber, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 12, color: _amber, height: 1.5),
          ),
        ),
        ?action,
      ],
    ),
  );
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.history,
    required this.full,
    required this.onRefresh,
    this.onViewAll,
  });
  final AsyncValue<List<LookupRecord>> history;
  final bool full;
  final VoidCallback onRefresh;
  final VoidCallback? onViewAll;
  @override
  Widget build(BuildContext context) => SectionCard(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
          child: Row(
            children: [
              Text(
                full ? 'Saved lookups' : 'Recent lookups',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(width: 12),
              const StatusPill('API history', color: AppTheme.muted),
              const Spacer(),
              if (!full)
                TextButton(
                  onPressed: onViewAll,
                  child: const Text('View all →'),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        history.when(
          skipLoadingOnRefresh: false,
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              children: [
                LinearProgressIndicator(minHeight: 2),
                SizedBox(height: 16),
                Text(
                  'Loading saved lookups…',
                  style: TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          error: (error, _) => EmptyState(
            title: 'History is unavailable',
            message: friendlyError(error),
            icon: Icons.cloud_off_rounded,
            action: OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry history'),
            ),
          ),
          data: (records) {
            if (records.isEmpty) {
              return const EmptyState(
                title: 'Your lookup history starts here.',
                message:
                    'Resolve a hardware address to save a vendor lookup. Unknown vendors '
                    'and provider failures are saved too.',
                icon: Icons.history_rounded,
              );
            }
            final visible = full ? records : records.take(3).toList();
            return Column(
              children: [
                for (var index = 0; index < visible.length; index++) ...[
                  if (index > 0) const Divider(height: 1),
                  _HistoryRow(record: visible[index]),
                ],
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.record});
  final LookupRecord record;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 17),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 850;
        return Row(
          children: [
            const Icon(Icons.memory_rounded, size: 19, color: AppTheme.muted),
            const SizedBox(width: 14),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.vendor ??
                        (record.status == VendorStatus.unknown
                            ? 'Unknown vendor'
                            : 'Provider error'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    record.mac,
                    style: const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()],
                      fontSize: 11,
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    record.ip ?? 'No IP supplied',
                    style: const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()],
                      fontSize: 12,
                    ),
                  ),
                  if (!wide) ...[
                    const SizedBox(height: 4),
                    Text(
                      formatTimestamp(record.createdAt),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (wide)
              Expanded(
                flex: 2,
                child: Text(
                  formatTimestamp(record.createdAt),
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                ),
              ),
            const SizedBox(width: 8),
            StatusPill(
              switch (record.status) {
                VendorStatus.resolved => 'Resolved',
                VendorStatus.unknown => 'Unknown',
                VendorStatus.failed => 'Failed',
              },
              color: record.status == VendorStatus.resolved
                  ? AppTheme.mint
                  : _amber,
            ),
          ],
        );
      },
    ),
  );
}

String formatTimestamp(DateTime value) {
  final date = value.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}  ${two(date.hour)}:${two(date.minute)}';
}
