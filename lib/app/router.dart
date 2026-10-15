import '../offline/presentation/download_queue_screen.dart';
import 'inkora_page.dart';
import '../app/l10n/app_strings.dart';
import '../features/settings/presentation/setup_screen.dart';
import 'icons/inkora_icons.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/connection/application/session_controller.dart';
import '../features/connection/presentation/connection_screen.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/library/presentation/catalogue_screen.dart';
import '../features/library/presentation/catalogue_detail_screen.dart';
import '../features/library/domain/catalogue.dart';
import '../features/settings/application/ui_preferences_provider.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/servers_screen.dart';
import '../features/settings/presentation/library_defaults_screen.dart';
import '../reader/presentation/configured_reader_screen.dart';
import '../offline/presentation/downloads_screen.dart';
import 'widgets/inkora_shell.dart';
import 'widgets/inkora_widgets.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final rootNavigator = GlobalKey<NavigatorState>();
  ref.watch(sessionProvider.select((state) => state.session?.accountId));
  final refresh = _RouterRefresh();
  ref.listen(
    sessionProvider.select((state) => state.phase),
    (_, _) => refresh.notify(),
  );
  ref.listen(
    uiPreferencesProvider.select((value) => value.asData?.value.setupCompleted),
    (_, _) => refresh.notify(),
  );
  Page<void> page(GoRouterState state, Widget child) =>
      ref.read(uiPreferencesProvider).asData?.value.reduceMotion == true
      ? NoTransitionPage(key: state.pageKey, child: child)
      : InkoraPage(key: state.pageKey, child: child);
  final router = GoRouter(
    navigatorKey: rootNavigator,
    refreshListenable: refresh,
    redirect: (context, route) {
      final phase = ref.read(sessionProvider).phase;
      final path = route.uri.path;
      if (phase == SessionPhase.restoring) {
        return path == '/loading' ? null : '/loading';
      }
      if (phase != SessionPhase.ready) {
        return path == '/connections' ? null : '/connections';
      }
      final preferences = ref.read(uiPreferencesProvider).asData?.value;
      if (preferences != null &&
          !preferences.setupCompleted &&
          path != '/setup' &&
          !path.startsWith('/settings/library-defaults')) {
        return '/setup';
      }
      if (path == '/loading' || path == '/connections') return '/';
      return null;
    },
    errorBuilder: (context, _) => Scaffold(
      body: Center(
        child: InkEmptyState(
          icon: InkIcons.compass,
          title: 'Page unavailable',
          message: 'This destination could not be found.',
          label: 'Go home',
          action: () => context.go('/'),
        ),
      ),
    ),
    routes: [
      GoRoute(
        path: '/setup',
        pageBuilder: (_, state) => page(
          state,
          SetupScreen(editing: state.uri.queryParameters['edit'] == 'true'),
        ),
      ),
      GoRoute(
        name: 'reader',
        path: '/reader/:id',
        pageBuilder: (_, state) => page(
          state,
          ConfiguredReaderScreen(bookId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/loading',
        pageBuilder: (context, state) => page(
          state,
          Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                semanticsLabel: context.tr('Restoring session'),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/connections',
        pageBuilder: (_, state) => page(state, const ConnectionScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => InkoraShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                pageBuilder: (_, state) => page(state, const LibraryScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/libraries',
                pageBuilder: (_, state) => page(
                  state,
                  const CatalogueScreen(
                    kind: CatalogueKind.series,
                    embedded: true,
                  ),
                ),
              ),
              GoRoute(
                path: '/search',
                pageBuilder: (_, state) => page(
                  state,
                  const CatalogueScreen(
                    kind: CatalogueKind.series,
                    searchMode: true,
                  ),
                ),
              ),
              GoRoute(
                name: 'catalogue',
                path: '/catalogue/:kind',
                redirect: (_, state) {
                  if (state.pathParameters['kind'] != 'book') return null;
                  final series = state.uri.queryParameters['series'];
                  if (series == null) return null;
                  return '/catalogue/series/${Uri.encodeComponent(series)}';
                },
                pageBuilder: (_, state) {
                  final kind = CatalogueKind.values
                      .where(
                        (value) => value.name == state.pathParameters['kind'],
                      )
                      .firstOrNull;
                  if (kind == null) {
                    return page(
                      state,
                      const Center(child: LText('Unknown catalogue section.')),
                    );
                  }
                  final query = state.uri.queryParameters;
                  final groupKind = CatalogueKind.values
                      .where(
                        (value) =>
                            value.name == query['groupKind'] &&
                            (value == CatalogueKind.collection ||
                                value == CatalogueKind.readlist),
                      )
                      .firstOrNull;
                  return page(
                    state,
                    CatalogueScreen(
                      kind: kind,
                      libraryId: query['library'],
                      seriesId: query['series'],
                      groupKind: groupKind,
                      groupId: groupKind == null ? null : query['group'],
                      ordered: query['ordered'] == 'true',
                      initialSort: CatalogueSort.values
                          .where((value) => value.name == query['sort'])
                          .firstOrNull,
                    ),
                  );
                },
              ),
              GoRoute(
                name: 'catalogue-detail',
                path: '/catalogue/:kind/:id',
                routes: [
                  GoRoute(
                    name: 'series-reader',
                    path: 'read/:bookId',
                    parentNavigatorKey: rootNavigator,
                    pageBuilder: (_, state) => page(
                      state,
                      ConfiguredReaderScreen(
                        bookId: state.pathParameters['bookId']!,
                      ),
                    ),
                  ),
                ],
                redirect: (_, state) => state.pathParameters['kind'] == 'book'
                    ? '/reader/${Uri.encodeComponent(state.pathParameters['id']!)}'
                    : null,
                pageBuilder: (_, state) {
                  final kind = CatalogueKind.values
                      .where(
                        (value) => value.name == state.pathParameters['kind'],
                      )
                      .firstOrNull;
                  return page(
                    state,
                    kind == null
                        ? const Center(child: LText('Unknown catalogue item.'))
                        : CatalogueDetailScreen(
                            kind: kind,
                            id: state.pathParameters['id']!,
                          ),
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: 'downloads',
                path: '/downloads',
                pageBuilder: (_, state) => page(state, const DownloadsScreen()),
                routes: [
                  GoRoute(
                    path: 'queue',
                    pageBuilder: (_, state) =>
                        page(state, const DownloadQueueScreen()),
                  ),
                  GoRoute(
                    path: 'series/:id',
                    pageBuilder: (_, state) => page(
                      state,
                      DownloadsScreen(seriesId: state.pathParameters['id']),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (_, state) => page(state, const SettingsScreen()),
                routes: [
                  GoRoute(
                    path: 'servers',
                    pageBuilder: (_, state) =>
                        page(state, const ServersScreen()),
                    routes: [
                      GoRoute(
                        path: 'add',
                        pageBuilder: (_, state) => page(
                          state,
                          const ConnectionScreen(addServer: true),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'library-defaults',
                    redirect: (_, state) =>
                        state.uri.path == '/settings/library-defaults'
                        ? '/settings/reading'
                        : null,
                    pageBuilder: (_, state) =>
                        page(state, const LibraryDefaultsScreen()),
                    routes: [
                      GoRoute(
                        path: ':id',
                        pageBuilder: (_, state) => page(
                          state,
                          LibraryDefaultsScreen(
                            libraryId: state.pathParameters['id'],
                          ),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: ':section',
                    redirect: (_, state) =>
                        state.pathParameters['section'] == 'sync'
                        ? '/settings'
                        : state.pathParameters['section'] == 'account'
                        ? '/settings/servers'
                        : null,
                    pageBuilder: (_, state) {
                      final section = state.pathParameters['section'];
                      return page(
                        state,
                        const {
                              'appearance',
                              'language',
                              'gestures',
                              'reading',
                              'reading-defaults',
                              'quality',
                              'downloads',
                              'accessibility',
                              'about',
                            }.contains(section)
                            ? SettingsScreen(section: section)
                            : const Center(
                                child: LText('Unknown settings section.'),
                              ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}
