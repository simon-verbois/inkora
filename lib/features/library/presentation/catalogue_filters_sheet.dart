import 'catalogue_detail_widgets.dart' show humanizeMetadata;

import 'package:flutter/material.dart';

import '../../../app/icons/inkora_icons.dart';
import '../../../app/l10n/app_strings.dart';
import '../domain/catalogue_filters.dart';

typedef CatalogueFilterResult = ({
  bool showUnavailable,
  MetadataFilters filters,
});

class CatalogueFiltersSheet extends StatefulWidget {
  const CatalogueFiltersSheet({
    super.key,
    required this.options,
    required this.filters,
    this.showUnavailable,
    this.readingOptions = true,
    this.downloadOptions = true,
  });
  final Future<CatalogueFacets> options;
  final MetadataFilters filters;
  final bool? showUnavailable;
  final bool readingOptions, downloadOptions;
  @override
  State<CatalogueFiltersSheet> createState() => _CatalogueFiltersSheetState();
}

class _CatalogueFiltersSheetState extends State<CatalogueFiltersSheet> {
  late ReadingStatus _reading = widget.filters.readingStatus;
  late bool _downloaded = widget.filters.downloadedOnly;
  late bool _unavailable = widget.showUnavailable ?? false;
  late final _selected = Map<CatalogueFacet, String>.of(widget.filters.values);
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: LText(
                'Catalogue filters',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _selected.clear();
                _reading = ReadingStatus.any;
                _downloaded = false;
              }),
              child: const LText('Reset'),
            ),
          ],
        ),
        if (widget.showUnavailable != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const LText('Show unavailable items'),
            subtitle: const LText(
              'Keep removed titles and historical list entries visible.',
            ),
            value: _unavailable,
            onChanged: (value) => setState(() => _unavailable = value),
          ),
        if (widget.readingOptions)
          DropdownButtonFormField<ReadingStatus>(
            key: ValueKey(_reading),
            initialValue: _reading,
            isExpanded: true,
            itemHeight: null,
            decoration: InputDecoration(
              labelText: context.tr('Reading status'),
            ),
            items: [
              for (final status in ReadingStatus.values)
                DropdownMenuItem(
                  value: status,
                  child: LText(switch (status) {
                    ReadingStatus.any => 'Any',
                    ReadingStatus.unread => 'Unread',
                    ReadingStatus.inProgress => 'In progress',
                    ReadingStatus.completed => 'Completed',
                  }),
                ),
            ],
            onChanged: (value) => setState(() => _reading = value!),
          ),
        if (widget.downloadOptions)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const LText('Downloaded only'),
            value: _downloaded,
            onChanged: (value) => setState(() => _downloaded = value),
          ),
        FutureBuilder<CatalogueFacets>(
          future: widget.options,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const LText('Saved catalogue unavailable.');
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            return Column(
              children: [
                for (final facet in CatalogueFacet.values)
                  if (snapshot.data!.containsKey(facet) ||
                      _selected.containsKey(facet))
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: DropdownButtonFormField<String>(
                        key: ValueKey((facet, _selected[facet])),
                        initialValue: _selected[facet] ?? '',
                        isExpanded: true,
                        itemHeight: null,
                        icon: const Icon(InkIcons.caretDown, size: 20),
                        decoration: InputDecoration(
                          labelText: context.tr(facet.label),
                        ),
                        items: [
                          DropdownMenuItem(value: '', child: LText('Any')),
                          for (final value in {
                            ...?snapshot.data![facet],
                            if (_selected[facet] != null) _selected[facet]!,
                          })
                            DropdownMenuItem(
                              value: value,
                              child: Text(
                                facet == CatalogueFacet.mediaType
                                    ? switch (value) {
                                        'application/epub+zip' => 'EPUB',
                                        'application/pdf' => 'PDF',
                                        'application/zip' ||
                                        'application/x-cbz' ||
                                        'application/vnd.comicbook+zip' =>
                                          'CBZ',
                                        'application/x-rar-compressed' ||
                                        'application/x-cbr' ||
                                        'application/vnd.comicbook-rar' =>
                                          'CBR',
                                        _ => value,
                                      }
                                    : facet == CatalogueFacet.status
                                    ? context.tr(humanizeMetadata(value))
                                    : value,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) => setState(() {
                          if (value == null || value.isEmpty) {
                            _selected.remove(facet);
                          } else {
                            _selected[facet] = value;
                          }
                        }),
                      ),
                    ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.pop(context, (
            showUnavailable: _unavailable,
            filters: MetadataFilters.from(
              _selected,
              readingStatus: _reading,
              downloadedOnly: _downloaded,
            ),
          )),
          child: const LText('Apply filters'),
        ),
      ],
    ),
  );
}
