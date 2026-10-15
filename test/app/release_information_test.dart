import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/release_information.dart';
import 'package:inkora/features/settings/presentation/about_content.dart';

void main() {
  test(
    'bundled source files load their version and release/development notes',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final info = await ReleaseInformation.load(rootBundle);
      expect(info.version, (await rootBundle.loadString('VERSION')).trim());
      expect(info.sections, isNotEmpty);
      expect(
        info.sections.any((section) => section.title == 'Development history'),
        isTrue,
      );
      expect(
        info.sections.first.blocks.any(
          (block) => block.kind == ChangelogBlockKind.bullet,
        ),
        isTrue,
      );
    },
  );

  test('release parsing skips empty placeholder/preamble and joins multiline notes', () {
    final sections = ReleaseInformation.parse(
      '# Intro\nignored\n\n## [Unreleased]\n\n## [2026.42.1] - 2026-10-15\n### Fixed\n- First line\n  continuation\n\nA paragraph\ncontinued.\n\n## [Development history]\n### 2026-10-12\n- Initial work.\n',
    );
    expect(sections.map((section) => section.title), [
      '2026.42.1 - 2026-10-15',
      'Development history',
    ]);
    expect(sections.first.blocks.map((block) => block.text), [
      'Fixed',
      'First line continuation',
      'A paragraph continued.',
    ]);
  });

  for (final (size, scale, locale) in [
    for (final locale in [
      'en',
      'fr',
      'de',
      'es',
      'it',
      'pl',
      'nl',
      'pt',
      'ro',
      'el',
      'hu',
      'cs',
    ])
      (const Size(320, 640), 2.0, locale),
    (const Size(1024, 768), 1.0, 'en'),
  ]) {
    testWidgets(
      'About shows packaged version and expandable formatted notes at $size/$scale/$locale',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final info = ReleaseInformation(
          '2026.42.7',
          ReleaseInformation.parse(
            '## [2026.42.7] - 2026-10-15\n### Added\n- A long readable release note that wraps on a small screen with enlarged text.\n',
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              releaseInformationProvider.overrideWith((ref) async => info),
            ],
            child: MaterialApp(
              locale: Locale(locale),
              localizationsDelegates: const [
                AppStrings.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppStrings.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: AboutContent(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('2026.42.7'), findsOneWidget);
        expect(find.textContaining('Version 0.1.0'), findsNothing);
        final toggle = find.byKey(const Key('about-changelog'));
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(of: toggle, matching: find.byType(ListTile)).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('2026.42.7 - 2026-10-15'), findsOneWidget);
        expect(find.text('Added'), findsOneWidget);
        expect(find.text('•  '), findsOneWidget);
        expect(find.byType(SelectionArea), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
