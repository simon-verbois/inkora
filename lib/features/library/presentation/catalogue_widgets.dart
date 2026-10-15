import '../../../app/l10n/app_strings.dart';
import '../../../app/icons/inkora_icons.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/catalogue_providers.dart';
import '../application/cover_providers.dart';
import '../domain/catalogue.dart';
import 'book_cover.dart';
import 'catalogue_presentation.dart';
export 'catalogue_presentation.dart';

/// Refresh metadata/progress and conditionally validate currently displayed art.
Future<void> refreshCatalogue(WidgetRef ref) async {
  await Future.wait<void>([
    ref.read(catalogueRepositoryProvider.future).then((repository) async {
      await repository?.refresh();
    }),
    ref.read(resumeRepositoryProvider.future).then((repository) async {
      await repository?.refresh(force: true);
    }),
    ref
        .read(coverRepositoryProvider.future)
        .then((repository) async {
          await repository?.revalidateActive();
        })
        .catchError((Object _) {
          // Best-effort artwork initialization must not block metadata refresh.
        }),
  ]);
}

class CatalogueRefreshStatus extends ConsumerWidget {
  const CatalogueRefreshStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(catalogueRefreshProvider);
    if (status.hasError) {
      return const LText('Local catalogue could not be opened.');
    }
    final value = status.asData?.value;
    // Subscribe to the count query only while a status message is shown.
    if (value?.message == null) return const SizedBox.shrink();
    final hasSavedItems =
        ref.watch(
          catalogueOverviewProvider.select(
            (overview) =>
                overview.asData?.value.values.any((count) => count > 0),
          ),
        ) ??
        false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: LText(
                "{0}{1}",
                arguments: [
                  context.tr(value!.message!),
                  hasSavedItems
                      ? ' ${context.tr('Saved catalogue remains available.')}'
                      : '',
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () => refreshCatalogue(ref),
            child: const LText('Retry'),
          ),
        ],
      ),
    );
  }
}

class CatalogueItemTile extends StatelessWidget {
  const CatalogueItemTile({
    required this.item,
    this.onOpen,
    this.trailing,
    this.coverItem,
    super.key,
  });
  final CatalogueItem item;
  final CatalogueItem? coverItem;
  final ValueChanged<CatalogueItem>? onOpen;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        key: ValueKey('${item.kind.name}:${item.id}'),
        leading:
            item.kind == CatalogueKind.book || item.kind == CatalogueKind.series
            ? BookCover(item: coverItem ?? item, width: 32)
            : Icon(item.canOpen ? catalogueIcon(item.kind) : InkIcons.prohibit),
        title: Text(item.title),
        subtitle: Text(catalogueDescription(item, context: context)),
        trailing:
            trailing ?? (item.canOpen ? const Icon(InkIcons.caretRight) : null),
        enabled: item.canOpen,
        onTap: item.canOpen
            ? () => onOpen == null
                  ? openCatalogueItem(context, item)
                  : onOpen!(item)
            : null,
      ),
    );
  }
}
