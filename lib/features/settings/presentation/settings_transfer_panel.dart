import '../../../app/icons/inkora_icons.dart';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/widgets/inkora_widgets.dart';
import '../../connection/application/session_controller.dart';
import '../data/settings_transfer.dart';

class SettingsTransferPanel extends ConsumerStatefulWidget {
  const SettingsTransferPanel({super.key});
  @override
  ConsumerState<SettingsTransferPanel> createState() =>
      _SettingsTransferPanelState();
}

class _SettingsTransferPanelState extends ConsumerState<SettingsTransferPanel> {
  bool _busy = false, _presenting = false;
  String? _message;
  Future<void> _run(
    Future<void> Function(SettingsTransfer, String) action,
  ) async {
    if (_busy) return;
    final account = ref.read(sessionProvider).session?.accountId;
    if (account == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final database = await ref.read(databaseProvider);
      await action(SettingsTransfer(database, account), account);
    } catch (error) {
      if (mounted) {
        setState(
          () => _message =
              error is FormatException &&
                  error.message ==
                      'This backup belongs to another server or account.'
              ? error.message
              : 'Unable to transfer settings. Check the file and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _presenting = false;
        });
      }
    }
  }

  Future<void> _preview(
    SettingsTransfer transfer,
    String account,
    Map<String, dynamic> value,
  ) async {
    if (!mounted || ref.read(sessionProvider).session?.accountId != account) {
      return;
    }
    if (value['portable'] != true && value['account'] != account) {
      throw const FormatException(
        'This backup belongs to another server or account.',
      );
    }
    setState(() => _presenting = true);
    final confirmed = await confirmInk(
      context,
      title: 'Import settings?',
      message: 'Interface preferences and matching reading preferences will be replaced. Bookmarks will be merged. Other saved data will be kept.',
      confirmLabel: 'Import',
      details: LText(
        'Reading preferences: {0} · Bookmarked books: {1}',
        arguments: [
          (value['preferences'] as List).length,
          (value['bookmarks'] as List).length,
        ],
      ),
    );
    if (!confirmed ||
        !mounted ||
        ref.read(sessionProvider).session?.accountId != account) {
      return;
    }
    setState(() => _presenting = false);
    await transfer.apply(value);
    if (mounted) setState(() => _message = 'Settings imported.');
  }

  @override
  Widget build(BuildContext context) => InkPanel(
    framed: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LText(
          'Files contain interface preferences, reading preferences and local bookmarks for the active account. Passwords, API keys, books and reading progress are excluded.',
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(InkIcons.arrowsDownUp),
          onPressed: _busy
              ? null
              : () => _run((transfer, _) async {
                  final bytes = await transfer.export();
                  final file = await FilePicker.saveFile(
                    fileName: 'inkora-settings.json',
                    bytes: bytes,
                    mimeType: 'application/json',
                  );
                  if (file != null && mounted) {
                    setState(() => _message = 'Settings exported.');
                  }
                }),
          label: const LText('Export to file'),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(InkIcons.downloadSimple),
          onPressed: _busy
              ? null
              : () => _run((transfer, account) async {
                  final files = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['json'],
                  );
                  if (files.isEmpty) return;
                  final file = files.single;
                  final bytes = BytesBuilder(copy: false);
                  var size = 0;
                  await for (final chunk in file.readAsByteStream()) {
                    size += chunk.length;
                    if (size > SettingsTransfer.maxBytes) {
                      throw const FormatException('Backup exceeds size limit');
                    }
                    bytes.add(chunk);
                  }
                  await _preview(
                    transfer,
                    account,
                    await transfer.inspect(bytes.takeBytes()),
                  );
                }),
          label: const LText('Import from file'),
        ),
        if (_busy && !_presenting) const LinearProgressIndicator(),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Semantics(liveRegion: true, child: LText(_message!)),
          ),
      ],
    ),
  );
}
