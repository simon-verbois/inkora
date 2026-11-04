import '../../../app/widgets/ink_screen_header.dart';
import '../../../app/icons/inkora_icons.dart';
import 'library_defaults_screen.dart';
import 'setup_introduction.dart';
import '../../../app/l10n/app_strings.dart';
import '../../../reader/presentation/reader_settings_sheet.dart';
import '../../connection/application/session_controller.dart';
import '../../library/application/catalogue_providers.dart';
import '../../library/domain/catalogue.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/ui_preferences_provider.dart';
import 'settings_screen.dart';
import 'settings_adaptive_layout.dart';
import 'settings_navigation.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key, this.editing = false});
  final bool editing;
  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  static const _sections = [
    ('introduction', 'Welcome to Inkora'),
    ('appearance', 'Appearance'),
    ('gestures', 'Gestures'),
    ('library-defaults', 'Library defaults'),
    ('quality', 'Image quality'),
    ('downloads', 'Downloads'),
    ('accessibility', 'Accessibility'),
    ('completion', 'Ready to read'),
  ];
  bool _saving = false;
  late int? _editingStep = widget.editing ? 0 : null;
  String? _error;
  String? _libraryId;
  var _editorKey = GlobalKey<ReaderSettingsSheetState>();
  String? _editorAccount;

  void _back(int step) {
    if (_saving) return;
    if (_libraryId != null) {
      _leaveLibrary();
    } else if (step > 0) {
      _move(step - 1);
    } else if (widget.editing) {
      context.go('/settings');
    }
  }

  Future<void> _leaveLibrary() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _editorKey.currentState?.savePreferences();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _next(int step) async {
    if (_saving) return;
    if (_libraryId != null) {
      setState(() => _saving = true);
      try {
        await _editorKey.currentState?.savePreferences();
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    } else {
      if (_sections.length > step && _sections[step].$1 == 'quality') {
        setState(() => _saving = true);
        bool? saved;
        try {
          saved = await _editorKey.currentState?.savePreferences();
        } finally {
          if (mounted) setState(() => _saving = false);
        }
        if (saved != true || !mounted) return;
      }
      await _move(
        (step + 1).clamp(0, _sections.length - 1),
        finish: step == _sections.length - 1,
      );
    }
  }

  Future<void> _move(int step, {bool finish = false}) async {
    final preferences = ref.read(uiPreferencesProvider).asData?.value;
    if (preferences == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await (await ref.read(uiPreferencesStoreProvider)).update(
        (current) => current.copyWith(
          setupStep: step,
          setupCompleted: finish || current.setupCompleted,
        ),
      );
      if (mounted && widget.editing) setState(() => _editingStep = step);
      if (mounted && finish) context.go('/');
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to save setup. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Start the existing account refresh while the user configures the first
    // steps, and retain its owner when moving between setup sections.
    ref.listen(catalogueRepositoryProvider, (_, _) {});
    final account = ref.watch(
      sessionProvider.select((state) => state.session?.accountId),
    );
    if (account != _editorAccount) {
      _editorAccount = account;
      _libraryId = null;
      _editorKey = GlobalKey<ReaderSettingsSheetState>();
    }
    final preferences = ref.watch(uiPreferencesProvider).asData?.value;
    if (preferences == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final step = (_editingStep ?? preferences.setupStep).clamp(
      0,
      _sections.length - 1,
    );
    final library = _libraryId == null
        ? null
        : ref
              .watch(
                catalogueItemProvider((CatalogueKind.library, _libraryId!)),
              )
              .asData
              ?.value;
    final stepTitle = _sections[step].$2;
    final introduction = _sections[step].$1 == 'introduction';
    final completion = _sections[step].$1 == 'completion';
    final deviceLanguage =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final welcomeLocale = AppStrings.localeFor(
      languageNames.containsKey(deviceLanguage) ? deviceLanguage : 'en',
    );
    final content = LayoutBuilder(
      builder: (context, bounds) {
        final wide = useWideSettings(context, bounds.maxWidth);
        final footer = Padding(
          padding: EdgeInsets.all(
            MediaQuery.textScalerOf(context).scale(1) > 1.5 ? 8 : 16,
          ),
          child: Align(
            alignment: wide ? Alignment.centerRight : Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                key: const Key('setup-footer'),
                padding: const EdgeInsets.all(8),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('setup-back'),
                          onPressed: _saving || (step == 0 && !widget.editing)
                              ? null
                              : () => _back(step),
                          child: const LText(
                            'Back',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          key: const Key('setup-next'),
                          onPressed: _saving ? null : () => _next(step),
                          child: LText(
                            completion ? 'Start reading' : 'Next',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _back(step);
          },
          child: Scaffold(
            appBar: InkScreenHeader(
              automaticallyImplyLeading: false,
              leading: _libraryId == null
                  ? null
                  : IgnorePointer(
                      ignoring: _saving,
                      child: BackButton(
                        key: const Key('setup-library-back'),
                        onPressed: _leaveLibrary,
                      ),
                    ),
              title: _libraryId != null
                  ? Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Tooltip(
                        message:
                            library?.title ?? context.tr('Library defaults'),
                        child: Text(
                          library?.title ?? context.tr('Library defaults'),
                          key: const Key('setup-library-title'),
                          textAlign: TextAlign.start,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                  : LText(wide ? stepTitle : 'Make Inkora yours'),
            ),
            body: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Offstage(
                    offstage: !wide,
                    child: SizedBox(
                      width: 248,
                      child: Padding(
                        key: const Key('setup-sidebar'),
                        padding: const EdgeInsets.fromLTRB(24, 16, 8, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LText(
                              'Make Inkora yours',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            LText(
                              'Step {0} of {1}',
                              arguments: [step + 1, _sections.length],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: ListView(
                                children: [
                                  for (
                                    var index = 0;
                                    index < _sections.length;
                                    index++
                                  )
                                    SettingsNavTile(
                                      key: ValueKey('setup-stage-$index'),
                                      selected: index == step,
                                      leading: ExcludeSemantics(
                                        child: index < step
                                            ? const Icon(
                                                InkIcons.checkCircle,
                                                size: 22,
                                              )
                                            : Text('${index + 1}'),
                                      ),
                                      title: LText(_sections[index].$2),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: wide ? 16 : 0),
                  Expanded(
                    child: Column(
                      children: [
                        Offstage(
                          offstage: wide,
                          child: Padding(
                            padding: EdgeInsets.all(
                              MediaQuery.textScalerOf(context).scale(1) > 1.5
                                  ? 8
                                  : 16,
                            ),
                            child: Column(
                              children: [
                                LText(
                                  'Step {0} of {1}',
                                  arguments: [step + 1, _sections.length],
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  semanticsLabel: context.tr(stepTitle),
                                  value: (step + 1) / (_sections.length),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: SettingsPaneScope(
                            wide: wide,
                            child: _sections[step].$1 == 'library-defaults'
                                ? LibraryDefaultsScreen(
                                    key: ValueKey(_libraryId),
                                    embedded: true,
                                    libraryId: _libraryId,
                                    editorKey: _editorKey,
                                    onLibrarySelected: (id) =>
                                        setState(() => _libraryId = id),
                                    onSaved: () =>
                                        setState(() => _libraryId = null),
                                  )
                                : _sections[step].$1 == 'introduction'
                                ? SetupIntroduction(footer: footer)
                                : completion
                                ? Center(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.all(24),
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 560,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              InkIcons.checkCircle,
                                              size: 56,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                            const SizedBox(height: 20),
                                            if (!wide)
                                              LText(
                                                'Ready to read',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineMedium,
                                                textAlign: TextAlign.center,
                                              ),
                                            const SizedBox(height: 12),
                                            const LText(
                                              'Setup is complete. Enjoy your reading!',
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                : SettingsScreen(
                                    key: ValueKey(step),
                                    section: _sections[step].$1,
                                    embedded: true,
                                    editorKey: _sections[step].$1 == 'quality'
                                        ? _editorKey
                                        : null,
                                    onSaved: _sections[step].$1 == 'quality'
                                        ? () {}
                                        : null,
                                  ),
                          ),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: LText(_error!),
                          ),
                        if (!introduction && _libraryId == null) footer,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    return introduction
        ? Localizations.override(
            context: context,
            locale: welcomeLocale,
            child: content,
          )
        : content;
  }
}
