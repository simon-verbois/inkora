import '../../../app/widgets/ink_screen_header.dart';
import 'settings_adaptive_layout.dart';
import '../../../app/l10n/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/icons/inkora_icons.dart';
import '../../../app/widgets/inkora_widgets.dart';
import '../../../app/theme/inkora_theme.dart';
import '../../connection/application/session_controller.dart';
import '../../connection/domain/session.dart';
import 'library_visibility_panel.dart';
import '../../connection/presentation/connection_screen.dart';

class ServersScreen extends ConsumerStatefulWidget {
  const ServersScreen({super.key});
  @override
  ConsumerState<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends ConsumerState<ServersScreen> {
  bool _busy = false;
  Future<void> _select(SavedSession saved) async {
    if (_busy) return;
    if (saved.accountId == ref.read(sessionProvider).session?.accountId) {
      context.go('/');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).selectServer(saved.accountId);
    } catch (_) {
      if (mounted) {
        notifyInk(context, 'Unable to open this saved connection. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(SavedSession saved) async {
    final confirmed = await confirmInk(
      context,
      title: 'Remove this server?',
      message: 'The saved connection will be removed. Downloads and reading progress stay on this device.',
      confirmLabel: 'Remove server',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).removeServer(saved.accountId);
    } catch (_) {
      if (mounted) {
        notifyInk(context, 'Unable to remove this connection. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sessionProvider);
    final saved = ref.watch(savedSessionsProvider);
    return Scaffold(
      appBar: SettingsPaneScope.wideOf(context)
          ? null
          : InkScreenHeader(title: const LText('Servers and account')),
      body: SafeArea(
        top: false,
        child: InkContent(
          maxWidth: InkoraLayout.maxSettingsWidth,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              LText(
                'Saved servers',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: InkSpace.md),
              ...saved.when(
                loading: () => [const LinearProgressIndicator()],
                error: (_, _) => [
                  TextButton(
                    onPressed: () => ref.invalidate(savedSessionsProvider),
                    child: const LText('Retry loading servers'),
                  ),
                ],
                data: (sessions) => [
                  for (final session in sessions)
                    ListTile(
                      key: ValueKey(session.accountId),
                      leading: Icon(
                        session.accountId == state.session?.accountId
                            ? InkIcons.checkCircle
                            : InkIcons.books,
                      ),
                      title: Text(session.endpoint.uri.host),
                      subtitle: Text(session.user.email),
                      shape: RoundedRectangleBorder(
                        borderRadius: InkRadius.medium,
                      ),
                      selectedTileColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: .25),
                      selected: session.accountId == state.session?.accountId,
                      onTap: _busy ? null : () => _select(session),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: ValueKey('edit-server-${session.accountId}'),
                            tooltip: context.tr('Edit connection'),
                            icon: const Icon(InkIcons.gearSix),
                            onPressed: _busy
                                ? null
                                : () => showInkPopup<void>(
                                    context: context,
                                    child: SizedBox(
                                      height:
                                          MediaQuery.sizeOf(context).height *
                                          .72,
                                      child: ConnectionScreen(
                                        addServer: true,
                                        editing: session,
                                        modal: true,
                                      ),
                                    ),
                                  ),
                          ),
                          IconButton(
                            key: ValueKey(
                              'server-libraries-${session.accountId}',
                            ),
                            tooltip: context.tr('Libraries to display'),
                            icon: const Icon(InkIcons.books),
                            onPressed: _busy
                                ? null
                                : () => showInkPopup<void>(
                                    context: context,
                                    title: 'Libraries to display',
                                    scrollable: true,
                                    child: LibraryVisibilityPanel(
                                      accountId: session.accountId,
                                      expanded: true,
                                    ),
                                  ),
                          ),
                          IconButton(
                            tooltip: context.tr('Remove server {0}', [
                              session.endpoint.uri.host,
                            ]),
                            icon: const Icon(InkIcons.trash),
                            onPressed: _busy ? null : () => _remove(session),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  key: const Key('add-server'),
                  icon: const Icon(InkIcons.books),
                  label: const LText('Add server'),
                  onPressed: _busy
                      ? null
                      : () => context.push('/settings/servers/add'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
