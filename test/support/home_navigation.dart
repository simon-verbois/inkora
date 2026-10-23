import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Return to the retained Home before opening one of its header destinations.
Future<void> openHomeDestination(
  WidgetTester tester,
  String destination,
) async {
  final router = GoRouter.of(
    tester.element(find.byKey(const ValueKey('shell-pages'))),
  );
  router.go('/');
  await tester.pumpAndSettle();
  if (destination == 'libraries') return;
  await tapHomeAction(tester, destination);
}

/// Use the overflow menu when the current header cannot fit direct actions.
Future<void> tapHomeAction(WidgetTester tester, String destination) async {
  final menu = find.byKey(const Key('home-menu'));
  if (menu.evaluate().isNotEmpty) {
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('home-menu-$destination')));
  } else {
    await tester.tap(
      find.byKey(
        ValueKey(
          destination == 'history'
              ? 'reading-history-action'
              : 'open-$destination',
        ),
      ),
    );
  }
  await tester.pumpAndSettle();
}
