import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/icons/inkora_icons.dart';
import '../../../app/l10n/app_strings.dart';
import '../../../app/widgets/inkora_widgets.dart';
import '../data/saved_search_store.dart';
import '../domain/catalogue.dart';
import '../domain/saved_catalogue_search.dart';
import '../../connection/application/session_controller.dart';

/// A named search is a reusable query: results always come from the current
/// account catalogue and its current library-visibility rules.
class SavedSearchesSheet extends ConsumerStatefulWidget {
  const SavedSearchesSheet({
    super.key,
    required this.store,
    required this.query,
    required this.isCurrent,
  });
  final SavedSearchStore store;
  final CatalogueQuery query;
  final bool Function() isCurrent;
  @override
  ConsumerState<SavedSearchesSheet> createState() => _SavedSearchesSheetState();
}

class _SavedSearchesSheetState extends ConsumerState<SavedSearchesSheet> {
  final _name = TextEditingController();
  late final _searches = widget.store.watch();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _mutate(Future<void> Function() operation) async {
    if (_busy || !widget.isCurrent()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to save searches. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionProvider.select((s) => (s.phase, s.session?.accountId)));
    if (!widget.isCurrent()) return const LText('Saved catalogue unavailable.');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InkSheetHeader(title: 'Saved searches'),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: StreamBuilder<List<SavedCatalogueSearch>>(
              stream: _searches,
              builder: (context, snapshot) {
                final searches =
                    snapshot.data ?? const <SavedCatalogueSearch>[];
                final duplicate = searches.any(
                  (search) => search.name == _name.text.trim(),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      key: const Key('saved-search-name'),
                      controller: _name,
                      enabled: !_busy,
                      maxLength: 80,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: context.tr('Search name'),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      key: const Key('saved-search-save'),
                      icon: const Icon(InkIcons.bookmarks),
                      onPressed:
                          _busy ||
                              !snapshot.hasData ||
                              _name.text.trim().isEmpty ||
                              duplicate ||
                              searches.length >= SavedSearchStore.maximum
                          ? null
                          : () => _mutate(() async {
                              await widget.store.save(
                                SavedCatalogueSearch(
                                  _name.text.trim(),
                                  widget.query,
                                ),
                              );
                              if (mounted && widget.isCurrent()) _name.clear();
                            }),
                      label: const LText('Save current search'),
                    ),
                    if (duplicate)
                      const LText('A search with this name already exists.'),
                    if (searches.length >= SavedSearchStore.maximum)
                      const LText(
                        'Saved search limit reached. Remove a search to add another.',
                      ),
                    if (_error != null) LText(_error!),
                    const SizedBox(height: 16),
                    if (snapshot.hasError)
                      const LText('Saved catalogue unavailable.')
                    else if (!snapshot.hasData)
                      const LinearProgressIndicator()
                    else if (searches.isEmpty)
                      const LText('Save a search to reuse its filters later.')
                    else
                      for (final search in searches)
                        ListTile(
                          key: ValueKey('saved-search-${search.name}'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(search.name),
                          subtitle: search.query.search.isEmpty
                              ? null
                              : Text(search.query.search),
                          onTap: _busy
                              ? null
                              : () {
                                  if (widget.isCurrent()) {
                                    Navigator.pop(context, search);
                                  }
                                },
                          trailing: IconButton(
                            key: ValueKey('saved-search-remove-${search.name}'),
                            tooltip: context.tr('Remove saved search'),
                            icon: const Icon(InkIcons.trash),
                            onPressed: _busy
                                ? null
                                : () => _mutate(
                                    () => widget.store.remove(search.name),
                                  ),
                          ),
                        ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
