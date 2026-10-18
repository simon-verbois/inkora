import '../../../app/widgets/ink_surface.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LText('Unable to open this saved connection. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(SavedSession saved) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const LText('Remove this server?'),
        content: const LText(
          'The saved connection will be removed. Downloads and reading progress stay on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const LText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const LText('Remove server'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).removeServer(saved.accountId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LText('Unable to remove this connection. Try again.'),
          ),
        );
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
      appBar: InkAppBar(title: const LText('Servers and account')),
      body: SafeArea(
        top: false,
        child: InkContent(
          maxWidth: InkoraLayout.maxSettingsWidth,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (state.session != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LText(
                              'Server',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              state.session!.endpoint.uri.toString(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LText(
                              'Active account',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            SelectableText(state.session!.user.email),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(InkIcons.signOut),
                    label: const LText('Sign out'),
                    onPressed: _busy ? null : _signOut,
                  ),
                ),
                const Divider(height: 32),
                LibraryVisibilityPanel(key: ValueKey(state.session!.accountId)),
                const Divider(height: 32),
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
                      subtitle: LText(
                        "{0}\n{1}",
                        arguments: [session.endpoint.uri, session.user.email],
                      ),
                      isThreeLine: true,
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
              ListTile(
                key: const Key('add-server'),
                leading: const Icon(InkIcons.books),
                title: const LText('Add server'),
                trailing: const Icon(InkIcons.caretRight),
                onTap: _busy
                    ? null
                    : () => context.push('/settings/servers/add'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const LText('Sign out of Inkora?'),
        content: const LText(
          'Your downloaded books and saved preferences remain on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const LText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const LText('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(sessionProvider.notifier).logout();
    }
  }
}
