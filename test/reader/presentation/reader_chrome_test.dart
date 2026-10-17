import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:inkora/app/icons/inkora_icons.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/reader/presentation/reader_chrome.dart';

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(1024, 768),
    const Size(844, 390),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('reader panels retain accessible actions at $size/$scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final actions = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('de'),
            supportedLocales: AppStrings.supportedLocales,
            localizationsDelegates: const [
              AppStrings.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                padding: const EdgeInsets.only(top: 24, bottom: 24),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: ReaderTopBar(
                        title:
                            'A deliberately long publication title · Volume 12',
                        onBack: () => actions.add('back'),
                        actions: [
                          IconButton(
                            tooltip: 'Book details',
                            onPressed: () => actions.add('details'),
                            icon: const Icon(InkIcons.info),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: ReaderPanel(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ReaderSeekBar(
                              position: 2,
                              count: 12,
                              onSeek: (page) => actions.add('$page'),
                              onPrevious: () => actions.add('previous'),
                              onNext: () => actions.add('next'),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final label in [
                                  'Table of contents',
                                  'Bookmarks',
                                  'Reading preferences',
                                ])
                                  Expanded(
                                    child: ReaderQuickAction(
                                      label: label,
                                      icon: InkIcons.bookOpen,
                                      onPressed: () => actions.add(label),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final settings = find.byTooltip(
          AppStrings('de').text('Reading preferences'),
        );
        expect(settings.hitTestable(), findsOneWidget);
        await tester.tap(settings);
        await tester.tap(find.byTooltip('Book details'));
        expect(actions, ['Reading preferences', 'details']);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
