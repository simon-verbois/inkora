import '../../../app/widgets/ink_surface.dart';
import '../../../app/widgets/inkora_widgets.dart';
import '../../../app/icons/inkora_icons.dart';
import 'preference_labels.dart';
import 'library_defaults_screen.dart';
import 'setup_introduction.dart';
import '../../../app/l10n/app_strings.dart';
import '../../../reader/presentation/reader_settings_sheet.dart';
import '../../connection/application/session_controller.dart';
import '../../library/application/catalogue_providers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/ui_preferences_provider.dart';
import 'settings_screen.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key, this.editing = false});
  final bool editing;
  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  static const _sections = [
    ('language', 'Language'),
    ('introduction', 'Welcome to Inkora'),
    ('appearance', 'Appearance'),
    ('gestures', 'Reading gestures'),
    ('library-defaults', 'Library defaults'),
    ('downloads', 'Downloads'),
    ('accessibility', 'Accessibility'),
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
      setState(() => _libraryId = null);
    } else if (step > 0) {
      _move(step - 1);
    } else if (widget.editing) {
      context.go('/settings');
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
      await _move(
        (step + 1).clamp(0, _sections.length),
        finish: step == _sections.length,
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
      if (mounted && finish) context.go(widget.editing ? '/settings' : '/');
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
      _sections.length,
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back(step);
      },
      child: Scaffold(
        appBar: InkAppBar(
          automaticallyImplyLeading: false,
          title: const LText('Make Inkora yours'),
          actions: [
            if (widget.editing)
              CloseButton(
                onPressed: _saving ? null : () => context.go('/settings'),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(
                  MediaQuery.textScalerOf(context).scale(1) > 1.5 ? 8 : 16,
                ),
                child: Column(
                  children: [
                    LText(
                      'Step {0} of {1}',
                      arguments: [step + 1, _sections.length + 1],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      semanticsLabel: context.tr(
                        step < _sections.length
                            ? _sections[step].$2
                            : 'Ready to read',
                      ),
                      value: (step + 1) / (_sections.length + 1),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: step < _sections.length
                    ? _sections[step].$1 == 'library-defaults'
                          ? LibraryDefaultsScreen(
                              key: ValueKey(_libraryId),
                              embedded: true,
                              libraryId: _libraryId,
                              editorKey: _editorKey,
                              onLibrarySelected: (id) =>
                                  setState(() => _libraryId = id),
                              onSaved: () => setState(() => _libraryId = null),
                            )
                          : _sections[step].$1 == 'introduction'
                          ? const SetupIntroduction()
                          : SettingsScreen(
                              key: ValueKey(step),
                              section: _sections[step].$1,
                              embedded: true,
                            )
                    : Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Icon(
                                  InkIcons.checkCircle,
                                  size: 56,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(height: 20),
                                LText(
                                  'Ready to read',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium,
                                ),
                                const SizedBox(height: 12),
                                const LText(
                                  'Your configuration is saved on this device. You can change every setting later, or reopen Guided setup from Settings.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                InkPanel(
                                  child: Column(
                                    children: [
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(InkIcons.palette),
                                        title: LText(
                                          appearanceLabel(
                                            preferences.appearance,
                                          ),
                                        ),
                                        subtitle: LText(
                                          densityLabel(preferences.density),
                                        ),
                                      ),
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(InkIcons.books),
                                        title: Text(
                                          languageNames[preferences.locale] ??
                                              context.tr('System language'),
                                        ),
                                      ),
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(
                                          InkIcons.personArmsSpread,
                                        ),
                                        title: LText(
                                          gesturePresetLabel(
                                            preferences.gestures.preset,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: LText(_error!),
                ),
              Padding(
                padding: EdgeInsets.all(
                  MediaQuery.textScalerOf(context).scale(1) > 1.5 ? 8 : 16,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: InkSurface(
                      padding: const EdgeInsets.all(8),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                key: const Key('setup-back'),
                                onPressed: _saving || step == 0
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
                                  step == _sections.length
                                      ? 'Start reading'
                                      : 'Next',
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
