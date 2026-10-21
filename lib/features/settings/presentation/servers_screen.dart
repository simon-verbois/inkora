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
              if (state.session != null) ...[
                InkPanel(
                  title: 'Active account',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(InkIcons.checkCircle),
                        title: Text(
                          state.session!.endpoint.uri.host,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        subtitle: Text(state.session!.user.email),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 56, bottom: 12),
                        child: SelectableText(
                          state.session!.endpoint.uri.toString(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: OutlinedButton.icon(
                          icon: const Icon(InkIcons.signOut),
                          label: const LText('Sign out'),
                          onPressed: _busy ? null : _signOut,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                LibraryVisibilityPanel(key: ValueKey(state.session!.accountId)),
                const SizedBox(height: 24),
              ],
              LText(
                'Saved servers',
                style: Theme.of(context).textTheme.titleMedium,
              ),
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
                      trailing: IconButton(
                        tooltip: context.tr('Remove server {0}', [
                          session.endpoint.uri.host,
                        ]),
                        icon: const Icon(InkIcons.trash),
                        onPressed: _busy ? null : () => _remove(session),
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

  Future<void> _signOut() async {
    final confirmed = await confirmInk(
      context,
      title: 'Sign out of Inkora?',
      message:
          'Your downloaded books and saved preferences remain on this device.',
      confirmLabel: 'Sign out',
    );
    if (confirmed && mounted) {
      await ref.read(sessionProvider.notifier).logout();
    }
  }
}
