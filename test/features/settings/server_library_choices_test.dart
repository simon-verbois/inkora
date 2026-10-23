import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/core/network/server_endpoint.dart';
import 'package:inkora/features/connection/application/session_controller.dart';
import 'package:inkora/features/connection/domain/session.dart';
import 'package:inkora/features/settings/presentation/library_visibility_panel.dart';
import 'package:inkora/features/library/data/library_visibility_store.dart';

import '../../support/connection_fakes.dart';

void main() {
  for (final status in [200, 401, 403]) {
    test(
      'uncached inactive libraries use their own credentials and preserve the active session ($status)',
      () async {
        final database = AppDatabase(NativeDatabase.memory());
        final store = MemorySessionStore()..saved = savedSession;
        final second = SavedSession(
          endpoint: ServerEndpoint('https://second.test/proxy/'),
          user: savedSession.user,
          credentials: Credentials.apiKey('second-fixture'),
        );
        await store.remember(second);
        final secondary = FixtureAdapter(
          (options) => jsonResponse([
            {'id': 'fresh', 'name': 'Fresh shelf', 'unavailable': false},
            {'id': 'denied', 'name': 'Unavailable shelf', 'unavailable': true},
          ], status: status),
        );
        final active = FixtureAdapter(
          (options) =>
              jsonResponse(options.path.endsWith('users/me') ? userJson : {}),
        );
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(Future.value(database)),
            sessionStoreProvider.overrideWithValue(store),
            komgaClientFactoryProvider.overrideWithValue(
              (endpoint, credentials) => fixtureClient(
                endpoint,
                credentials,
                endpoint.uri.host == 'second.test' ? secondary : active,
              ),
            ),
          ],
        );
        final provider = accountLibrariesProvider(second.accountId);
        final subscription = container.listen(provider, (_, _) {});
        try {
          if (status == 200) {
            final choices = await container.read(provider.future);
            expect(choices.map((item) => item.id), ['fresh']);
            await LibraryVisibilityStore(
              database,
              second.accountId,
            ).save({'fresh'});
          } else {
            await expectLater(
              container.read(provider.future),
              throwsA(isA<Exception>()),
            );
          }
          await Future<void>.delayed(const Duration(milliseconds: 30));
          expect(secondary.requests, hasLength(1));
          expect(secondary.requests.single.uri.path, '/proxy/api/v1/libraries');
          expect(
            secondary.requests.single.headers['X-API-Key'],
            'second-fixture',
          );
          expect(secondary.closed, isTrue);
          expect((await store.restore())!.accountId, savedSession.accountId);
          expect(
            await LibraryVisibilityStore(
              database,
              savedSession.accountId,
            ).payload(),
            isNull,
          );
        } finally {
          subscription.close();
          container.dispose();
          await database.close();
        }
      },
    );
  }
}
