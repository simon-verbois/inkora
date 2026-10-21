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
  await tester.tap(find.byKey(ValueKey('open-$destination')));
  await tester.pumpAndSettle();
}
