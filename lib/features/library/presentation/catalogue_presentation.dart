import '../../../app/l10n/app_strings.dart';
import '../../../app/icons/inkora_icons.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/catalogue.dart';

String catalogueLabel(CatalogueKind kind) => switch (kind) {
  CatalogueKind.library => 'Libraries',
  CatalogueKind.series => 'Series',
  CatalogueKind.book => 'Books',
  CatalogueKind.collection => 'Collections',
  CatalogueKind.readlist => 'Reading lists',
};
IconData catalogueIcon(CatalogueKind kind) => switch (kind) {
  CatalogueKind.library => InkIcons.books,
  CatalogueKind.series => InkIcons.list,
  CatalogueKind.book => InkIcons.bookOpen,
  CatalogueKind.collection => InkIcons.bookmarks,
  CatalogueKind.readlist => InkIcons.listChecks,
};

/// Every available volume uses the shared route. The reader resolves its
/// authoritative manifest before selecting raster, EPUB or PDF rendering.
/// Catalogue page counts and resume presentation flags are not format gates.
void openCatalogueItem(BuildContext context, CatalogueItem item) {
  if (!item.canOpen) return;
  if (item.kind == CatalogueKind.book) {
    if (item.isEbook) {
      context.pushNamed(
        'catalogue-detail',
        pathParameters: {'kind': 'book', 'id': item.id},
      );
    } else {
      openBookReader(context, item);
    }
    return;
  }
  context.pushNamed(
    'catalogue-detail',
    pathParameters: {'kind': item.kind.name, 'id': item.id},
  );
}

/// Explicit reading actions bypass book details, including offline and resume.
void openBookReader(BuildContext context, CatalogueItem item) {
  if (!item.canOpen) return;
  final route = GoRouterState.of(context);
  if (route.name == 'reader-parent') {
    final router = GoRouter.of(context);
    final currentBook = route.uri.queryParameters['book'];
    if (!router.canPop()) {
      router.goNamed('reader', pathParameters: {'id': item.id});
      return;
    }
    router.pop();
    if (currentBook != item.id) {
      // Readium owns one publication; replace the prior reader rather than
      // retaining two native publications on the navigation stack.
      router.pushReplacementNamed('reader', pathParameters: {'id': item.id});
    }
    return;
  }
  if (!item.isEbook && item.seriesId != null && item.seriesId!.isNotEmpty) {
    context.pushNamed(
      'series-reader',
      pathParameters: {
        'kind': 'series',
        'id': item.seriesId!,
        'bookId': item.id,
      },
    );
  } else {
    context.pushNamed('reader', pathParameters: {'id': item.id});
  }
}

String catalogueDescription(CatalogueItem item, {BuildContext? context}) =>
    !item.canOpen
    ? context?.tr('Unavailable or removed') ?? 'Unavailable or removed'
    : item.isEbook
    ? (item.metadata.authors.isNotEmpty
          ? item.metadata.authors
                .map((author) => author.name)
                .toSet()
                .join(', ')
          : item.metadata.mediaType == 'application/pdf'
          ? 'PDF'
          : 'EPUB')
    : switch (item.kind) {
        CatalogueKind.book =>
          context == null
              ? '${item.pageCount} ${item.pageCount == 1 ? 'page' : 'pages'}'
              : AppStrings.of(context).quantity(item.pageCount, 'page'),
        CatalogueKind.series =>
          context == null
              ? '${item.itemCount} ${item.itemCount == 1 ? 'book' : 'books'}'
              : AppStrings.of(context).quantity(item.itemCount, 'book'),
        CatalogueKind.collection =>
          context == null
              ? '${item.itemCount} series'
              : AppStrings.of(context).quantity(item.itemCount, 'series'),
        CatalogueKind.readlist =>
          context == null
              ? '${item.itemCount} ${item.itemCount == 1 ? 'book' : 'books'}'
              : AppStrings.of(context).quantity(item.itemCount, 'book'),
        CatalogueKind.library => context?.tr('Library') ?? 'Library',
      };
