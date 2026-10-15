import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inkora/reader/application/reader_providers.dart';
import 'package:inkora/reader/data/reader_repository.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_screen.dart';
import 'package:inkora/reader/presentation/reader_system_ui.dart';

import '../test/support/reader_fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native reader hides Android bars, toggles controls and restores bars on exit',
    (tester) async {
      final manifest = readerManifest();
      final container = ProviderContainer(
        overrides: [
          openReaderProvider(manifest.bookId).overrideWith(
            (ref) async =>
                OpenReader(manifest, FixturePageSource(), ReaderLocator(0)),
          ),
          readingSettingsProvider(manifest.bookId).overrideWith(
            (ref) =>
                Stream.value(const ReadingSettings(mode: ReadingMode.webtoon)),
          ),
          readerRepositoryProvider.overrideWith((ref) async => null),
        ],
      );
      Future<void> settleBars() async {
        await tester.pumpAndSettle();
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
      }

      Future<bool?> hidden() =>
          ReaderSystemUi.channel.invokeMethod<bool>('systemBarsHidden');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: ReaderScreen(bookId: manifest.bookId)),
        ),
      );
      await settleBars();
      expect(find.byType(AppBar), findsNothing);
      expect(await hidden(), true);
      await tester.tapAt(tester.getCenter(find.byType(ReaderScreen)));
      await settleBars();
      expect(find.byTooltip('Reading preferences'), findsOneWidget);
      expect(find.byKey(const Key('reader-page-slider')), findsOneWidget);
      expect(await hidden(), false);
      await tester.tapAt(tester.getCenter(find.byType(ReaderScreen)));
      await settleBars();
      expect(find.byType(AppBar), findsNothing);
      expect(await hidden(), true);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Reader closed'))),
      );
      await settleBars();
      expect(await hidden(), false);
      container.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}
