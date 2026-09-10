import 'dart:async';
import 'dart:io';

import 'package:desktop_core/desktop_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/controller.dart';
import 'src/models.dart';

class ProcessManagerApp extends StatelessWidget {
  const ProcessManagerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Hudu Process Manager',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(managerProvider);
    final controller = ref.read(managerProvider.notifier);
    return DesktopShell(
      title: _page == 0 ? 'Process manager' : 'Termination history',
      subtitle: _page == 0
          ? 'A clear view of what’s running. You stay in control.'
          : 'Confirmed exits, recorded by your Rails API.',
      eyebrow: 'SYSTEM TOOLS / ${_page == 0 ? 'PROCESSES' : 'AUDIT TRAIL'}',
      destinations: const [
        DesktopDestination(label: 'Processes', icon: Icons.memory_outlined),
        DesktopDestination(label: 'Audit history', icon: Icons.history_rounded),
      ],
      selectedIndex: _page,
      onDestinationSelected: (index) {
        setState(() => _page = index);
        if (index == 1) unawaited(controller.refreshHistory());
      },
      actions: [
        OutlinedButton.icon(
          onPressed:
              (_page == 0
                  ? state.refreshing || state.terminating
                  : state.historyLoading)
              ? null
              : () {
                  unawaited(
                    _page == 0
                        ? controller.refresh()
                        : controller.refreshHistory(),
                  );
                },
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Refresh'),
        ),
      ],
      footer: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusPill('LOCAL MACHINE'),
          SizedBox(height: 16),
          Text(
            'Current user permissions\nNo elevation. No process trees.',
            style: TextStyle(fontSize: 11, color: AppTheme.muted, height: 1.8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.storageError != null)
            _Notice(state.storageError!, warning: true),
          if (state.notice != null) _Notice(state.notice!),
          if (state.pending.isNotEmpty) _pendingBanner(state, controller),
          Expanded(
            child: _page == 0 ? _processes(state, controller) : _history(state),
          ),
        ],
      ),
    );
  }

  Widget _pendingBanner(
    ManagerState state,
    ManagerController controller,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF302B20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_upload_outlined,
            color: Color(0xFFF0CA80),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${state.pending.length} confirmed ${state.pending.length == 1 ? 'exit' : 'exits'} · audit pending\n${state.storageError != null ? 'Some events are only in memory. Keep app open and retry.' : state.auditError ?? 'Saved locally. Delivery retries automatically every 30 seconds.'}',
              style: const TextStyle(fontSize: 12, color: Color(0xFFF0CA80)),
            ),
          ),
          TextButton(
            onPressed: state.delivering
                ? null
                : () => unawaited(controller.retryAudits()),
            child: Text(state.delivering ? 'Delivering…' : 'Retry audit'),
          ),
        ],
      ),
    ),
  );

  Widget _processes(ManagerState state, ManagerController controller) {
    final rows = state.visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (MediaQuery.sizeOf(context).height >= 780) ...[
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'LOCAL PROCESSES',
                  value: '${state.processes.length}',
                  detail: 'Visible to this machine',
                  icon: Icons.memory_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _Metric(
                  label: 'REFRESH MODE',
                  value: state.interval == 0 ? 'Manual' : '${state.interval}s',
                  detail: state.updatedAt == null
                      ? 'Waiting for first refresh'
                      : 'Updated ${_time(state.updatedAt!)}',
                  icon: Icons.sync,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _Metric(
                  label: 'AUDIT OUTBOX',
                  value: '${state.pending.length}',
                  detail: state.pending.isEmpty
                      ? 'No pending events'
                      : 'Waiting for API delivery',
                  icon: Icons.cloud_done_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: controller.search,
                decoration: const InputDecoration(
                  hintText: 'Search process name or PID',
                  prefixIcon: Icon(Icons.search, size: 21),
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Text(
              'Auto-refresh',
              style: TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
            const SizedBox(width: 12),
            DropdownButton<int>(
              value: state.interval,
              borderRadius: BorderRadius.circular(12),
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
        const SizedBox(height: 16),
        if (state.processError != null)
          _Notice(state.processError!, warning: true),
        Expanded(
          child: SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Running processes',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      StatusPill('${rows.length} shown', color: AppTheme.muted),
                      const Spacer(),
                      if (state.refreshing)
                        const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _tableHeading(state, controller),
                Expanded(
                  child: rows.isEmpty
                      ? _PanelEmpty(
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
                          icon: Icons.manage_search,
                        )
                      : ListView.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, index) =>
                              _processRow(rows[index], state, controller),
                        ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          state.selected == null
                              ? 'Select a process to inspect or terminate'
                              : '${state.selected!.name}  ·  PID ${state.selected!.pid}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed:
                            state.selected == null ||
                                state.terminating ||
                                state.refreshing ||
                                !state.ready ||
                                state.storageError != null ||
                                state.selected!.identity == null ||
                                state.selected!.pid <= 0 ||
                                state.selected!.pid == pid ||
                                state.selected!.status == 'Exited'
                            ? null
                            : () => _confirm(state.selected!),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFEEAB9A),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        icon: const Icon(Icons.stop_circle_outlined, size: 17),
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
        const SizedBox(height: 10),
        const Text(
          'Process identities are checked again before termination. Only confirmed exits create audit events.',
          style: TextStyle(fontSize: 11, color: AppTheme.muted),
        ),
      ],
    );
  }

  Widget _tableHeading(ManagerState state, ManagerController controller) =>
      Container(
        color: const Color(0xFF111B24),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        child: Row(
          children: [
            const SizedBox(width: 38),
            Expanded(
              child: _sortButton('PROCESS NAME', false, state, controller),
            ),
            SizedBox(
              width: 105,
              child: _sortButton('PID', true, state, controller),
            ),
            const SizedBox(
              width: 118,
              child: Text(
                'STATUS',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 10,
                  letterSpacing: 1.3,
                ),
              ),
            ),
          ],
        ),
      );
  Widget _sortButton(
    String label,
    bool byPid,
    ManagerState state,
    ManagerController controller,
  ) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton(
      onPressed: () => controller.sort(byPid),
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        foregroundColor: AppTheme.muted,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, letterSpacing: 1.2)),
          const SizedBox(width: 6),
          Icon(
            state.sortPid == byPid
                ? (state.ascending ? Icons.arrow_upward : Icons.arrow_downward)
                : Icons.unfold_more,
            size: 13,
          ),
        ],
      ),
    ),
  );
  Widget _processRow(
    LocalProcess process,
    ManagerState state,
    ManagerController controller,
  ) {
    final selected = state.selected?.sameIdentity(process) ?? false;
    return Semantics(
      selected: selected,
      button: true,
      label: '${process.name}, PID ${process.pid}',
      child: Material(
        color: selected
            ? AppTheme.mint.withValues(alpha: .08)
            : Colors.transparent,
        child: InkWell(
          key: ValueKey('process-${process.pid}'),
          onTap: () => controller.select(selected ? null : process),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: .6),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 17,
                  color: selected ? AppTheme.mint : AppTheme.muted,
                ),
                const SizedBox(width: 21),
                Expanded(
                  child: Text(
                    process.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
                SizedBox(
                  width: 105,
                  child: Text(
                    '${process.pid}',
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 13,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                SizedBox(
                  width: 118,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: StatusPill(
                      process.pid == pid ? 'This app' : process.status,
                      color: process.status == 'Running'
                          ? AppTheme.mint
                          : AppTheme.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _history(ManagerState state) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (state.historyError != null)
        _Notice(state.historyError!, warning: true),
      Expanded(
        child: SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_outlined,
                      color: AppTheme.mint,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Recent confirmed terminations',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (state.historyLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: state.history.isEmpty
                    ? _PanelEmpty(
                        title: state.historyLoading
                            ? 'Loading audit history…'
                            : state.historyError != null
                            ? 'History unavailable'
                            : 'No termination events yet',
                        message: state.historyError != null
                            ? 'Start the Rails API and refresh to load persisted history.'
                            : 'Confirmed terminations appear here after the API accepts their audit events.',
                        icon: Icons.history_rounded,
                      )
                    : ListView.separated(
                        itemCount: state.history.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final event = state.history[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            leading: const Icon(
                              Icons.check_circle_outline,
                              color: AppTheme.mint,
                            ),
                            title: Text(
                              event.processName,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'PID ${event.pid}  ·  ${_utc(event.occurredAt)}',
                              style: const TextStyle(
                                color: AppTheme.muted,
                                fontSize: 12,
                              ),
                            ),
                            trailing: const StatusPill('Recorded'),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'Latest 30 events · newest exit first · occurrence times shown in UTC',
        style: TextStyle(fontSize: 11, color: AppTheme.muted),
      ),
    ],
  );

  Future<void> _confirm(LocalProcess process) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminate this process?'),
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                process.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'PID ${process.pid}',
                style: const TextStyle(color: AppTheme.mint),
              ),
              const SizedBox(height: 20),
              const Text(
                'Unsaved work may be lost. Only this process is targeted, using your current permissions.',
              ),
              const SizedBox(height: 12),
              Text(
                Platform.isWindows
                    ? 'Windows terminates the process through the same handle used to verify its creation time.'
                    : 'macOS sends SIGTERM and waits up to 4 seconds for exit. PID reuse between verification and signaling cannot be fully prevented; creation times have one-second precision.',
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEEAB9A),
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

class _PanelEmpty extends StatelessWidget {
  const _PanelEmpty({
    required this.title,
    required this.message,
    required this.icon,
  });
  final String title, message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: EmptyState(title: title, message: message, icon: icon),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
  });
  final String label, value, detail;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SectionCard(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  color: AppTheme.muted,
                  letterSpacing: 1.3,
                ),
              ),
            ),
            Icon(icon, size: 18, color: AppTheme.mint),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: AppTheme.muted),
        ),
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.message, {this.warning = false});
  final String message;
  final bool warning;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (warning ? const Color(0xFFEEAB9A) : AppTheme.mint).withValues(
          alpha: .08,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning ? Icons.info_outline : Icons.check_circle_outline,
            size: 17,
            color: warning ? const Color(0xFFEEAB9A) : AppTheme.mint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: warning ? const Color(0xFFEEAB9A) : AppTheme.mint,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
String _utc(DateTime value) =>
    '${value.toUtc().toIso8601String().substring(0, 10)}  ${_time(value.toUtc())} UTC';
