import '../support/home_navigation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/presentation/catalogue_detail_screen.dart';
import 'package:inkora/features/library/domain/resume_entry.dart';
import 'package:inkora/features/settings/presentation/settings_screen.dart';
import 'package:inkora/reader/presentation/reader_screen.dart';

import '../support/catalogue_fakes.dart';
import '../support/ui_harness.dart';

Future<Object?> _backEvent(WidgetTester tester, String method, int edge) async {
  final channel = SystemChannels.backGesture;
  final response = await tester.binding.defaultBinaryMessenger
      .handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          MethodCall(method, {
            'touchOffset': [edge == 0 ? 0.0 : 390.0, 300.0],
            'progress': method == 'updateBackGestureProgress' ? .4 : 0.0,
            'swipeEdge': edge,
          }),
        ),
        null,
      );
  return response == null ? null : channel.codec.decodeEnvelope(response);
}

void main() {
  for (final fromHome in [false, true]) {
    for (final edge in [0, 1]) {
      for (final cancelFirst in [false, true]) {
        testWidgets(
          'predictive back pops only the visible reader (Home $fromHome, edge $edge, cancel $cancelFirst)',
          (tester) async {
            final harness = await UiHarness.create(
              tester,
              resumeEntries: fromHome
                  ? [
                      ResumeEntry(
                        item: entry('book-a'),
                        seriesTitle: 'Moonlit District',
                        pageIndex: 2,
                        pageCount: 10,
                        fraction: 0,
                      ),
                    ]
                  : null,
            );
            addTearDown(() => harness.close(tester));
            await harness.mount(tester);
            final router = harness.container.read(routerProvider);
            // Visit another secondary page first. Only the root reader may
            // accept gestures over the covered Home or series navigator.
            router.go('/settings/appearance');
            await tester.pumpAndSettle();
            router.go('/');
            await tester.pumpAndSettle();
            if (fromHome) {
              await tester.tap(find.byKey(const ValueKey('resume-book-a')));
            } else {
              router.push<void>('/catalogue/series/series-a');
              await tester.pumpAndSettle();
              await tester.tap(find.byKey(const Key('detail-read')));
            }
            await tester.pumpAndSettle();
            expect(find.byType(ReaderScreen), findsOneWidget);
            expect(
              tester.widget<ReaderScreen>(find.byType(ReaderScreen)).bookId,
              'book-a',
            );
            if (fromHome) {
              expect(router.canPop(), isTrue);
              expect(find.byType(CatalogueDetailScreen), findsNothing);
            }
            final originalRect = tester.getRect(find.byType(ReaderScreen));
            if (cancelFirst) {
              expect(
                await _backEvent(tester, 'startBackGesture', edge),
                isTrue,
              );
              await _backEvent(tester, 'updateBackGestureProgress', edge);
              await tester.pump();
              await _backEvent(tester, 'cancelBackGesture', edge);
              await tester.pumpAndSettle();
              expect(find.byType(ReaderScreen), findsOneWidget);
            }
            expect(await _backEvent(tester, 'startBackGesture', edge), isTrue);
            await _backEvent(tester, 'updateBackGestureProgress', edge);
            await tester.pump();
            final slidingRect = tester.getRect(find.byType(ReaderScreen));
            expect(slidingRect.size, originalRect.size);
            expect(slidingRect, originalRect);
            await _backEvent(tester, 'commitBackGesture', edge);
            await tester.pumpAndSettle();
            expect(find.byType(ReaderScreen), findsNothing);
            if (fromHome) {
              expect(router.routeInformationProvider.value.uri.path, '/');
              expect(router.canPop(), isFalse);
            } else {
              expect(find.byType(CatalogueDetailScreen), findsOneWidget);
              await tester.binding.handlePopRoute();
              await tester.pumpAndSettle();
            }
            expect(find.byType(CatalogueDetailScreen), findsNothing);
            await openHomeDestination(tester, 'settings');
            await tester.pumpAndSettle();
            expect(
              find.byWidgetPredicate(
                (widget) => widget is SettingsScreen && widget.section == null,
              ),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            await harness.close(tester);
          },
        );
      }
    }
  }
}
