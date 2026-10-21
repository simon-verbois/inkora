import '../../../app/widgets/ink_screen_header.dart';
import 'settings_adaptive_layout.dart';
import '../../../app/l10n/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/icons/inkora_icons.dart';
import '../../../app/widgets/inkora_widgets.dart';
import '../../../app/theme/inkora_theme.dart';
import '../../../reader/data/reader_store.dart';
import '../../../reader/domain/reading_settings.dart';
import '../../../reader/presentation/reader_settings_sheet.dart';
import '../../connection/application/session_controller.dart';
import '../../library/application/catalogue_providers.dart';
import '../../library/domain/catalogue.dart';

class LibraryDefaultsScreen extends ConsumerStatefulWidget {
  const LibraryDefaultsScreen({
    super.key,
    this.libraryId,
    this.embedded = false,
    this.onLibrarySelected,
    this.onSaved,
    this.editorKey,
    this.includeGlobal = false,
  });
  final bool embedded;
  final bool includeGlobal;
  final String? libraryId;
  final ValueChanged<String>? onLibrarySelected;
  final VoidCallback? onSaved;
  final GlobalKey<ReaderSettingsSheetState>? editorKey;
  @override
  ConsumerState<LibraryDefaultsScreen> createState() =>
      _LibraryDefaultsScreenState();
}

class _LibraryDefaultsScreenState extends ConsumerState<LibraryDefaultsScreen> {
  static const _query = CatalogueQuery(
    kind: CatalogueKind.library,
    showUnavailable: false,
  );
  final _scroll = ScrollController();
  ReaderStore? _store;
  Stream<Map<String, ReadingOverrides>>? _defaults;
  @override
  void initState() {
    super.initState();
    _scroll.addListener(_more);
  }

  void _more() {
    if (widget.libraryId == null &&
        _scroll.hasClients &&
        _scroll.position.extentAfter < _scroll.position.viewportDimension) {
      ref.read(catalogueFeedProvider(_query)).asData?.value?.loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Widget _globalEntry(BuildContext context) => InkSettingsRow(
    icon: InkIcons.bookOpen,
    title: context.tr('Global defaults'),
    subtitle: 'Profiles, direction and page layout',
    onTap: () => context.push('/settings/reading-defaults'),
  );

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(
      sessionProvider.select((state) => state.session?.accountId),
    );
    final libraryId = widget.libraryId;
    final libraries = libraryId == null
        ? ref.watch(catalogueFeedStateProvider(_query))
        : null;
    if (libraryId == null) {
      ref.listen(catalogueFeedStateProvider(_query), (_, next) {
        if (next.asData?.value.loading == false) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _more();
          });
        }
      });
    }
    final refresh = libraryId == null
        ? ref.watch(catalogueRefreshProvider)
        : null;
    final library = libraryId == null
        ? null
        : ref.watch(catalogueItemProvider((CatalogueKind.library, libraryId)));
    return Scaffold(
      appBar: widget.embedded || SettingsPaneScope.wideOf(context)
          ? null
          : InkScreenHeader(
              title: Text(
                library?.asData?.value?.title ??
                    context.tr(
                      widget.includeGlobal
                          ? 'Reading profiles'
                          : 'Library defaults',
                    ),
              ),
            ),
      body: SafeArea(
        top: false,
        child: InkContent(
          maxWidth: InkoraLayout.maxSettingsWidth,
          child: FutureBuilder(
            future: ref.watch(databaseProvider),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return InkEmptyState(
                  icon: InkIcons.warningCircle,
                  title: "Settings unavailable",
                  message: "Unable to open saved reading settings.",
                );
              }
              if (!snapshot.hasData || account == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (_store?.database != snapshot.data ||
                  _store?.accountId != account) {
                _store = ReaderStore(snapshot.requireData, account);
                _defaults = _store!.libraryDefaults();
              }
              if (libraryId != null) {
                final editor = ReaderSettingsSheet(
                  key: widget.editorKey ?? ValueKey((account, libraryId)),
                  store: _store!,
                  libraryId: libraryId,
                  onSaved: widget.onSaved,
                );
                return Column(
                  children: [
                    Offstage(
                      offstage:
                          !widget.embedded &&
                          !SettingsPaneScope.wideOf(context),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          library?.asData?.value?.title ??
                              context.tr('Library defaults'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                    Expanded(child: editor),
                  ],
                );
              }
              return StreamBuilder<Map<String, ReadingOverrides>>(
                stream: _defaults,
                builder: (context, defaults) {
                  final items =
                      libraries?.asData?.value.page.items ??
                      const <CatalogueItem>[];
                  final firstPublicationPending =
                      libraries?.asData?.value.page.lastUpdated == null &&
                      (refresh?.isLoading == true ||
                          refresh?.asData?.value.busy == true);
                  if (libraries?.hasError == true ||
                      defaults.hasError ||
                      (items.isEmpty &&
                          (refresh?.hasError == true ||
                              refresh?.asData?.value.message != null))) {
                    final error = InkEmptyState(
                      icon: InkIcons.warningCircle,
                      title: "Library defaults unavailable",
                      message: "Unable to load saved libraries or settings.",
                      label: "Retry",
                      action: () {
                        final repository = ref
                            .read(catalogueRepositoryProvider)
                            .asData
                            ?.value;
                        repository?.refresh();
                        ref.invalidate(catalogueFeedProvider(_query));
                        setState(() => _defaults = _store!.libraryDefaults());
                      },
                    );
                    return widget.includeGlobal
                        ? ListView(
                            padding: const EdgeInsets.all(16),
                            children: [_globalEntry(context), error],
                          )
                        : error;
                  }
                  if (items.isEmpty &&
                      (firstPublicationPending ||
                          libraries?.isLoading == true ||
                          libraries?.asData?.value.loading == true)) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (items.isEmpty && !widget.includeGlobal) {
                    return InkEmptyState(
                      icon: InkIcons.books,
                      title: "No saved libraries",
                      message: "Refresh the catalogue to manage your library defaults.",
                    );
                  }
                  return ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.includeGlobal) _globalEntry(context),
                            const Padding(
                              padding: EdgeInsets.only(bottom: 16),
                              child: LText(
                                'Choose a library to set its default reading profile and page settings. Specific series and book settings still take priority.',
                              ),
                            ),
                            if (items.isEmpty)
                              const LText('No saved libraries'),
                          ],
                        );
                      }
                      final item = items[index - 1];
                      final value = defaults.data?[item.id];
                      final profile = value?.mode;
                      final customized =
                          value?.toJson().entries.any(
                            (entry) =>
                                entry.key != 'libraryDefaults' &&
                                entry.value != null,
                          ) ??
                          false;
                      return InkSettingsRow(
                        icon: InkIcons.books,
                        title: item.title,
                        subtitle: profile == null
                            ? customized
                                  ? 'Custom settings'
                                  : 'Global defaults'
                            : switch (profile) {
                                ReadingMode.manga => 'Manga',
                                ReadingMode.comics => 'Comics',
                                ReadingMode.webtoon => 'Webtoon',
                                ReadingMode.ebook => 'Ebooks',
                              },
                        onTap: () {
                          if (widget.onLibrarySelected != null) {
                            widget.onLibrarySelected!(item.id);
                          } else {
                            context.push(
                              '/settings/library-defaults/${Uri.encodeComponent(item.id)}',
                            );
                          }
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
