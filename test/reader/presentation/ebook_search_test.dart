import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_readium/flutter_readium.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/domain/page_source.dart';
import 'package:inkora/reader/presentation/ebook_search_sheet.dart';

void main() {
  for (final background in [false, true]) {
    testWidgets(
      'search fits keyboard and cancels on ${background ? "background" : "close"}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        CancellationSignal? signal;
        final result = Completer<List<TextSearchResult>>();
        var requests = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                viewInsets: EdgeInsets.only(bottom: 300),
                textScaler: TextScaler.linear(2),
              ),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: EbookSearchSheet(
                    search: (query, cancellation) {
                      expect(query, 'lantern');
                      signal = cancellation;
                      requests++;
                      return result.future;
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.enterText(find.byType(TextField), 'lantern');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();
        expect(requests, 1);
        expect(tester.takeException(), isNull);
        // Starting another search during the in-flight request is coalesced.
        await tester.tap(find.byTooltip('Search'));
        await tester.pump();
        expect(requests, 1);
        if (background) {
          for (final state in [
            AppLifecycleState.inactive,
            AppLifecycleState.hidden,
            AppLifecycleState.paused,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
        } else {
          await tester.pumpWidget(const SizedBox.shrink());
        }
        expect(signal!.isCancelled, isTrue);
        result.complete([]);
        await tester.pump();
        expect(find.text('No matches found.'), findsNothing);
        expect(tester.takeException(), isNull);
        if (background) {
          for (final state in [
            AppLifecycleState.hidden,
            AppLifecycleState.inactive,
            AppLifecycleState.resumed,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
        }
      },
    );
  }
}
