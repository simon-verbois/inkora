import 'preference_labels.dart';
import 'library_defaults_screen.dart';
import 'setup_introduction.dart';
import '../../../app/l10n/app_strings.dart';
import '../../../reader/presentation/reader_settings_sheet.dart';
import '../../connection/application/session_controller.dart';

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
    'language',
    'introduction',
    'appearance',
    'gestures',
    'library-defaults',
    'downloads',
    'accessibility',
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
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const LText('Make Inkora yours'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    LText(
                      'Step {0} of {1}',
                      arguments: [step + 1, _sections.length + 1],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (step + 1) / (_sections.length + 1),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: step < _sections.length
                    ? _sections[step] == 'library-defaults'
                          ? LibraryDefaultsScreen(
                              key: ValueKey(_libraryId),
                              embedded: true,
                              libraryId: _libraryId,
                              editorKey: _editorKey,
                              onLibrarySelected: (id) =>
                                  setState(() => _libraryId = id),
                              onSaved: () => setState(() => _libraryId = null),
                            )
                          : _sections[step] == 'introduction'
                          ? const SetupIntroduction()
                          : SettingsScreen(
                              key: ValueKey(step),
                              section: _sections[step],
                              embedded: true,
                            )
                    : ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          const LText(
                            'Ready to read',
                            style: TextStyle(fontSize: 26),
                          ),
                          const SizedBox(height: 16),
                          const LText(
                            'Your configuration is saved on this device. You can change every setting later, or reopen Guided setup from Settings.',
                          ),
                          const SizedBox(height: 16),
                          LText(
                            "{0} · {1}",
                            arguments: [
                              context.tr(
                                appearanceLabel(preferences.appearance),
                              ),
                              context.tr(densityLabel(preferences.density)),
                            ],
                          ),
                          LText(
                            "{0} · {1}",
                            arguments: [
                              context.tr(
                                gesturePresetLabel(preferences.gestures.preset),
                              ),
                              languageNames[preferences.locale] ??
                                  context.tr('System language'),
                            ],
                          ),
                        ],
                      ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: LText(_error!),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: FilledButton(
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
                              child: const LText(
                                'Next',
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
            ],
          ),
        ),
      ),
    );
  }
}
