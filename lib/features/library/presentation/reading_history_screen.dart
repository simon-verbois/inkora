import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/widgets/ink_surface.dart';
import '../../../app/icons/inkora_icons.dart';
import '../../../features/connection/application/session_controller.dart';
import '../../../reader/data/reading_history.dart';
import '../../../core/storage/app_database.dart';

final readingHistoryProvider =
    StreamProvider.autoDispose<List<ReadingHistoryData>>((ref) async* {
      final account = ref.watch(
        sessionProvider.select((state) => state.session?.accountId),
      );
      if (account == null) {
        yield [];
        return;
      }
      final database = await ref.watch(databaseProvider);
      yield* ReadingHistoryStore(database, account).watch(500);
    });

class ReadingHistoryScreen extends ConsumerWidget {
  const ReadingHistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: InkAppBar(
      title: const LText('Reading history'),
      actions: [
        IconButton(
          tooltip: context.tr('Clear history'),
          icon: const Icon(InkIcons.trash),
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const LText('Clear history?'),
                content: const LText(
                  'Reading progress and bookmarks will be kept.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const LText('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const LText('Clear history'),
                  ),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) return;
            final account = ref.read(sessionProvider).session?.accountId;
            if (account == null) return;
            try {
              await ReadingHistoryStore(
                await ref.read(databaseProvider),
                account,
              ).clear();
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: LText('Unable to clear history.')),
                );
              }
            }
          },
        ),
      ],
    ),
    body: ref
        .watch(readingHistoryProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Center(child: LText('Reading history unavailable')),
          data: (items) => items.isEmpty
              ? const Center(child: LText('No reading history yet.'))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text(item.title),
                      subtitle: Text(
                        MaterialLocalizations.of(context)
                            .formatMediumDate(item.openedAt.toLocal()),
                      ),
                      onTap: () => context.pushNamed(
                        'reader',
                        pathParameters: {'id': item.bookId},
                      ),
                    );
                  },
                ),
        ),
  );
}
