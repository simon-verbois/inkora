import '../data/download_store.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_strings.dart';
import '../../features/library/application/catalogue_providers.dart';
import '../../features/library/domain/catalogue.dart';
import '../../features/library/domain/catalogue_filters.dart';
import '../application/offline_coordinator.dart';

/// Metadata is paged before selection; the existing scheduler owns every job.
class BatchDownloadSheet extends ConsumerStatefulWidget {
  const BatchDownloadSheet({super.key, required this.seriesId});
  final String seriesId;
  @override
  ConsumerState<BatchDownloadSheet> createState() => _BatchDownloadSheetState();
}

class _BatchDownloadSheetState extends ConsumerState<BatchDownloadSheet> {
  late final Future<List<CatalogueItem>> _books = _load();
  final _selected = <String>{};
  bool _busy = false, _cancel = false;
  int _done = 0, _failed = 0;
  Future<List<CatalogueItem>> _load() async {
    final repository = await ref.read(catalogueRepositoryProvider.future);
    if (repository == null) throw StateError('No account');
    final items = <CatalogueItem>[];
    for (var page = 0; ; page++) {
      final result = await repository.store.read(
        CatalogueQuery(
          kind: CatalogueKind.book,
          seriesId: widget.seriesId,
          sort: CatalogueSort.sequence,
          showUnavailable: false,
          page: page,
          pageSize: 200,
        ),
      );
      items.addAll(result.items);
      if (items.length >= result.total || result.items.isEmpty) return items;
      if (!mounted) return [];
    }
  }

  Future<void> _selectUnread(int? limit, Set<String> excluded) async {
    setState(() => _busy = true);
    try {
      final repository = await ref.read(catalogueRepositoryProvider.future);
      if (repository == null) return;
      final ids = <String>{};
      for (var page = 0; ; page++) {
        final result = await repository.store.read(
          CatalogueQuery(
            kind: CatalogueKind.book,
            seriesId: widget.seriesId,
            sort: CatalogueSort.sequence,
            showUnavailable: false,
            filters: const MetadataFilters(readingStatus: ReadingStatus.unread),
            page: page,
            pageSize: 200,
          ),
        );
        for (final book in result.items) {
          if (!excluded.contains(book.id)) ids.add(book.id);
          if (limit != null && ids.length >= limit) break;
        }
        if (!mounted ||
            limit != null && ids.length >= limit ||
            (page + 1) * 200 >= result.total ||
            result.items.isEmpty) {
          break;
        }
      }
      if (mounted) {
        setState(() {
          _selected.clear();
          _selected.addAll(ids);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed++);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enqueue() async {
    setState(() {
      _busy = true;
      _cancel = false;
      _done = 0;
      _failed = 0;
    });
    try {
      final coordinator = await ref.read(offlineCoordinatorProvider.future);
      if (coordinator == null || !coordinator.current) {
        throw StateError('No account');
      }
      final ids = List<String>.of(_selected);
      for (final id in ids) {
        if (_cancel || !mounted || !coordinator.current) break;
        try {
          final paused = ref
              .read(downloadsProvider)
              .asData
              ?.value
              .where(
                (j) =>
                    j.bookId == id &&
                    {'paused', 'failed'}.contains(j.state.name),
              )
              .lastOrNull;
          if (paused == null) {
            await coordinator.enqueue(id);
          } else {
            await coordinator.downloads.resume(paused.id);
          }
          _selected.remove(id);
          _done++;
        } catch (_) {
          _failed++;
        }
        if (mounted) setState(() {});
      }
    } catch (_) {
      _failed++;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: LText(
                      'Download volumes',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (!_busy) const CloseButton(),
                ],
              ),
              Expanded(
                child: FutureBuilder<List<CatalogueItem>>(
                  future: _books,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const LText('Saved catalogue unavailable.'),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const LText('Close'),
                            ),
                          ],
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final books = snapshot.data!;
                    final List<DownloadJob>? jobs = ref.watch(
                      downloadsProvider.select((value) => value.asData?.value),
                    );
                    final excluded = <String>{
                      for (final job in jobs ?? const <DownloadJob>[])
                        if (!{
                          'failed',
                          'paused',
                          'cancelled',
                        }.contains(job.state.name))
                          job.bookId,
                    };
                    return CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: _busy || jobs == null
                                    ? null
                                    : () => _selectUnread(3, excluded),
                                child: const LText('Next 3 unread volumes'),
                              ),
                              TextButton(
                                onPressed: _busy || jobs == null
                                    ? null
                                    : () => _selectUnread(null, excluded),
                                child: const LText('All unread volumes'),
                              ),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => setState(_selected.clear),
                                child: const LText('Clear selection'),
                              ),
                            ],
                          ),
                        ),
                        SliverList.builder(
                          itemCount: books.length,
                          itemBuilder: (_, index) {
                            final book = books[index];
                            return CheckboxListTile(
                              value: _selected.contains(book.id),
                              title: Text(book.title),
                              subtitle: excluded.contains(book.id)
                                  ? const LText('Already queued or downloaded')
                                  : null,
                              onChanged:
                                  _busy ||
                                      jobs == null ||
                                      !book.canOpen ||
                                      excluded.contains(book.id)
                                  ? null
                                  : (value) => setState(() {
                                      if (value == true) {
                                        _selected.add(book.id);
                                      } else {
                                        _selected.remove(book.id);
                                      }
                                    }),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (_done > 0 || _failed > 0)
                LText('Queued: {0} · Failed: {1}', arguments: [_done, _failed]),
              if (_busy) ...[
                const LinearProgressIndicator(),
                TextButton(
                  onPressed: () => setState(() => _cancel = true),
                  child: const LText('Stop adding volumes'),
                ),
              ] else
                FilledButton(
                  onPressed: _selected.isEmpty ? null : _enqueue,
                  child: LText(
                    'Download selection ({0})',
                    arguments: [_selected.length],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
