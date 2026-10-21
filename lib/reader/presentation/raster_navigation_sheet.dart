import '../../app/widgets/inkora_widgets.dart';
import '../../features/library/presentation/progress_format.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../../app/l10n/app_strings.dart';
import '../../app/icons/inkora_icons.dart';
import '../data/raster_bookmarks.dart';
import '../data/reader_repository.dart';
import '../domain/reader_manifest.dart';
import 'reader_page_image.dart';

/// Only mounted grid cells acquire pages; leaving cancels their requests.
class RasterNavigationSheet extends StatefulWidget {
  const RasterNavigationSheet({
    super.key,
    required this.reader,
    required this.bookmarks,
    required this.current,
    this.showBookmarks = false,
  });
  final OpenReader reader;
  final RasterBookmarks bookmarks;
  final ReaderLocator current;
  final bool showBookmarks;
  @override
  State<RasterNavigationSheet> createState() => _RasterNavigationSheetState();
}

class _RasterNavigationSheetState extends State<RasterNavigationSheet> {
  late Future<List<RasterBookmark>> _values = widget.bookmarks.read();
  late bool _bookmarks = widget.showBookmarks;
  bool _busy = false;
  final _grid = ScrollController();
  (double, double)? _gridLayout;
  @override
  void dispose() {
    _grid.dispose();
    super.dispose();
  }

  void _alignGrid(double width, double scale) {
    if (_gridLayout == (width, scale)) return;
    _gridLayout = (width, scale);
    final columns = ((width + 12) / (180 + 12)).ceil().clamp(1, 20);
    final offset =
        (widget.current.pageIndex ~/ columns) * (180 + 40 * scale + 12);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _grid.hasClients) {
        _grid.jumpTo(offset.clamp(0, _grid.position.maxScrollExtent));
      }
    });
  }

  String? _error;
  Future<void> _add() async {
    setState(() => _busy = true);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => const _BookmarkNoteDialog(),
    );
    if (mounted) setState(() => _busy = false);
    if (result == null || !mounted) return;
    await _mutate(
      () => widget.bookmarks.add(
        RasterBookmark(
          widget.reader.manifest.revision,
          widget.current.pageIndex,
          widget.current.fraction,
          result,
        ),
      ),
    );
  }

  Future<void> _mutate(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        setState(() {
          _values = widget.bookmarks.read();
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to save bookmarks.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: LText(
                    _bookmarks ? 'Bookmarks' : 'Page overview',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const CloseButton(),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => setState(() => _bookmarks = false),
                  child: const LText('Page overview'),
                ),
                TextButton(
                  onPressed: () => setState(() => _bookmarks = true),
                  child: const LText('Bookmarks'),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _add,
                  icon: const Icon(InkIcons.bookmarks),
                  label: const LText('Add bookmark'),
                ),
              ],
            ),
            if (_error != null) LText(_error!),
            Expanded(
              child: _bookmarks
                  ? FutureBuilder<List<RasterBookmark>>(
                      future: _values,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const SingleChildScrollView(
                            child: InkEmptyState(
                              icon: InkIcons.warningCircle,
                              title: 'Unable to load bookmarks.',
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.data!.isEmpty) {
                          return const SingleChildScrollView(
                            child: InkEmptyState(
                              icon: InkIcons.bookmarks,
                              title: 'No bookmarks yet.',
                            ),
                          );
                        }
                        return ListView.builder(
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            final bookmark = snapshot.data![index];
                            final valid =
                                bookmark.revision ==
                                    widget.reader.manifest.revision &&
                                bookmark.page <
                                    widget.reader.manifest.pages.length;
                            return ListTile(
                              title: Text(
                                pagePositionLabel(
                                  AppStrings.of(context),
                                  bookmark.page,
                                  widget.reader.manifest.pages.length,
                                ),
                              ),
                              subtitle: valid
                                  ? (bookmark.note.isEmpty
                                        ? null
                                        : Text(bookmark.note))
                                  : const LText(
                                      'This bookmark belongs to an older book revision.',
                                    ),
                              onTap: !valid
                                  ? null
                                  : () => Navigator.pop(
                                      context,
                                      bookmark.locator,
                                    ),
                              trailing: IconButton(
                                tooltip: context.tr('Remove bookmark'),
                                onPressed: _busy
                                    ? null
                                    : () => _mutate(
                                        () => widget.bookmarks.remove(bookmark),
                                      ),
                                icon: const Icon(InkIcons.trash),
                              ),
                            );
                          },
                        );
                      },
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        _alignGrid(
                          constraints.maxWidth,
                          MediaQuery.textScalerOf(context).scale(1),
                        );
                        return GridView.builder(
                          controller: _grid,
                          scrollCacheExtent: const ScrollCacheExtent.pixels(0),
                          gridDelegate:
                              SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 180,
                                mainAxisExtent:
                                    180 +
                                    40 *
                                        MediaQuery.textScalerOf(context)
                                            .scale(1),
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: widget.reader.manifest.pages.length,
                          itemBuilder: (context, index) => Semantics(
                            selected: index == widget.current.pageIndex,
                            child: InkWell(
                              onTap: () =>
                                  Navigator.pop(context, ReaderLocator(index)),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: ReaderPageImage(
                                      manifest: widget.reader.manifest,
                                      index: index,
                                      source: widget.reader.source,
                                      visible: false,
                                      decodeBudget: 256 * 1024,
                                    ),
                                  ),
                                  Text(
                                    pagePositionLabel(
                                      AppStrings.of(context),
                                      index,
                                      widget.reader.manifest.pages.length,
                                    ),
                                    maxLines: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BookmarkNoteDialog extends StatefulWidget {
  const _BookmarkNoteDialog();
  @override
  State<_BookmarkNoteDialog> createState() => _BookmarkNoteDialogState();
}

class _BookmarkNoteDialogState extends State<_BookmarkNoteDialog> {
  final _note = TextEditingController();
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InkDialog(
    title: 'Add bookmark',
    content: TextField(
      controller: _note,
      maxLength: 500,
      decoration: InputDecoration(labelText: context.tr('Note (optional)')),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const LText('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _note.text.trim()),
        child: const LText('Save'),
      ),
    ],
  );
}
