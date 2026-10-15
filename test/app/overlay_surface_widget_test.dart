import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/theme/inkora_theme.dart';

void main() {
  for (final theme in [
    InkoraTheme.light(),
    InkoraTheme.dark(),
    InkoraTheme.dark(amoled: true),
  ]) {
    for (final (size, scale) in [
      (const Size(390, 844), 1.0),
      (const Size(320, 640), 2.0),
    ]) {
      testWidgets(
        'shared overlays use app surfaces at $size/$scale/${theme.scaffoldBackgroundColor}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var selection = 'First';
          final panel = theme.extension<InkoraColors>()!.panel;
          const capture = Key('overlay-capture');
          await tester.pumpWidget(
            RepaintBoundary(
              key: capture,
              child: MaterialApp(
                theme: theme,
                home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                    body: StatefulBuilder(
                      builder: (context, update) => ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          DropdownButton<String>(
                            isExpanded: true,
                            itemHeight: null,
                            value: selection,
                            items: const [
                              DropdownMenuItem(
                                value: 'First',
                                child: Text('First'),
                              ),
                              DropdownMenuItem(
                                value: 'Second',
                                child: Text('Second'),
                              ),
                            ],
                            onChanged: (value) =>
                                update(() => selection = value!),
                          ),
                          PopupMenuButton<String>(
                            child: const Text('Open menu'),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'action',
                                child: Text('Action'),
                              ),
                            ],
                          ),
                          FilledButton(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirmation'),
                                content: const Text(
                                  'A message that can wrap at larger text sizes.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                ],
                              ),
                            ),
                            child: const Text('Open dialog'),
                          ),
                          FilledButton(
                            onPressed: () => ScaffoldMessenger.of(context)
                                .showSnackBar(
                                  const SnackBar(
                                    content: Text('Saved on this device'),
                                  ),
                                ),
                            child: const Text('Show message'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          Material paintedAncestor(Finder child) => tester
              .widgetList<Material>(
                find.ancestor(of: child, matching: find.byType(Material)),
              )
              .firstWhere(
                (material) => material.type != MaterialType.transparency,
              );
          await tester.tap(find.byType(DropdownButton<String>));
          await tester.pumpAndSettle();
          final list = find
              .ancestor(
                of: find.text('Second').last,
                matching: find.byType(ListView),
              )
              .first;
          final point = Offset(
            tester.getRect(list).left + 8,
            tester.getCenter(find.text('Second').last).dy,
          );
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(capture),
          );
          final actual = await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            final offset =
                (point.dy.floor() * image.width + point.dx.floor()) * 4;
            final color = Color.fromARGB(
              bytes.getUint8(offset + 3),
              bytes.getUint8(offset),
              bytes.getUint8(offset + 1),
              bytes.getUint8(offset + 2),
            );
            image.dispose();
            return color;
          });
          expect(
            actual,
            panel,
            reason: 'The open dropdown paints the app panel color',
          );
          await tester.tap(find.text('Second').last);
          await tester.pumpAndSettle();
          expect(selection, 'Second');
          await tester.tap(find.text('Open menu'));
          await tester.pumpAndSettle();
          final menu = paintedAncestor(find.text('Action'));
          expect(menu.color, panel);
          expect(menu.surfaceTintColor, Colors.transparent);
          await tester.tap(find.text('Action'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Open dialog'));
          await tester.pumpAndSettle();
          final dialog = tester.widget<Material>(
            find
                .descendant(
                  of: find.byType(Dialog),
                  matching: find.byType(Material),
                )
                .first,
          );
          expect(dialog.color, panel);
          expect(dialog.surfaceTintColor, Colors.transparent);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsNothing);
          await tester.tap(find.text('Show message'));
          await tester.pumpAndSettle();
          expect(
            paintedAncestor(find.text('Saved on this device')).color,
            theme.extension<InkoraColors>()!.raised,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
