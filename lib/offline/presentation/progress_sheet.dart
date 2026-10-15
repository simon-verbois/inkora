import '../../reader/domain/ebook_locator.dart';
import '../../app/l10n/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../reader/domain/reader_manifest.dart';
import '../../reader/data/reader_store.dart';
import '../application/offline_coordinator.dart';
import '../domain/progress.dart';

class ProgressSheet extends ConsumerStatefulWidget {
  const ProgressSheet({
    required this.manifest,
    required this.onChanging,
    this.currentLocator,
    super.key,
  });
  final ReaderManifest manifest;
  final VoidCallback onChanging;
  final ReaderLocator? currentLocator;
  @override
  ConsumerState<ProgressSheet> createState() => _ProgressSheetState();
}

class _ProgressSheetState extends ConsumerState<ProgressSheet> {
  bool _busy = false;
  Future<void> _change(ProgressOperation operation) async {
    setState(() => _busy = true);
    try {
      final service = await ref.read(offlineCoordinatorProvider.future);
      if (service == null) return;
      final saved =
          widget.currentLocator ??
          await ReaderStore(
            service.store.database,
            service.store.accountId,
          ).locator(widget.manifest);
      final locator = switch (operation) {
        ProgressOperation.markUnread => ReaderLocator(0),
        ProgressOperation.complete => ReaderLocator(
          widget.manifest.pages.length - 1,
          0,
          widget.manifest.positions.isEmpty
              ? null
              : EbookLocator(widget.manifest.positions.last).encode(),
        ),
        _ => saved,
      };
      widget.onChanging();
      await service.sync.store.save(
        widget.manifest,
        locator,
        operation: operation,
      );
      service.sync.replay();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: LText('Unable to save reading progress.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolve(ProgressIntent event, bool keepLocal) async {
    setState(() => _busy = true);
    try {
      final service = await ref.read(offlineCoordinatorProvider.future);
      if (service == null) return;
      widget.onChanging();
      await service.sync.store.resolve(event, keepLocal: keepLocal);
      service.sync.replay();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LText(
              'Refresh this book before remapping a changed revision.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(progressIntentsProvider);
    final events =
        pending.asData?.value
            .where((e) => e.bookId == widget.manifest.bookId)
            .toList() ??
        [];
    final conflict = events.where((e) => e.state == 'conflict').firstOrNull;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LText(
              'Reading progress',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            LText(
              events.isEmpty
                  ? 'Progress synchronized.'
                  : 'Saved locally; waiting to sync: {0}.',
              arguments: [
                AppStrings.of(context).quantity(events.length, 'update'),
              ],
            ),
            if (conflict != null) ...[
              const SizedBox(height: 16),
              LText(
                "Your saved intent: {0}, page {1}. Server: {2}.",
                arguments: [
                  context.tr(switch (conflict.operation) {
                    ProgressOperation.markUnread => 'Mark unread and restart',
                    ProgressOperation.complete => 'Mark completed',
                    ProgressOperation.rewind =>
                      'Set progress to my current page',
                    ProgressOperation.advance => 'Reading progress',
                  }),
                  conflict.pageIndex + 1,
                  conflict.remote?.completed == true
                      ? context.tr('Completed')
                      : conflict.remote?.pageIndex == null
                      ? context.tr('Unread')
                      : context.tr('Page {0}', [
                          conflict.remote!.pageIndex! + 1,
                        ]),
                ],
              ),
              if (conflict.remote?.revision != conflict.revision)
                const LText(
                  'Book content changed. Refresh before choosing a new local position.',
                ),
              FilledButton(
                onPressed:
                    _busy || conflict.remote?.revision != conflict.revision
                    ? null
                    : () => _resolve(conflict, true),
                child: const LText('Use my saved intent'),
              ),
              OutlinedButton(
                onPressed: _busy || !pending.hasValue
                    ? null
                    : () => _resolve(conflict, false),
                child: const LText('Use server progress'),
              ),
            ] else ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _change(ProgressOperation.rewind),
                child: const LText('Set progress to my current page'),
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _change(ProgressOperation.markUnread),
                child: const LText('Mark unread and restart'),
              ),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _change(ProgressOperation.complete),
                child: const LText('Mark completed'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
