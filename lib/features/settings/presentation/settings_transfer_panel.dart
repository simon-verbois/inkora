import '../../../app/widgets/ink_surface.dart';
import '../../../app/icons/inkora_icons.dart';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
              : 'Unable to transfer settings. Check the file or QR code and try again.',
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const LText('Import settings?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LText(
                'Interface preferences and matching reading preferences will be replaced. Bookmarks will be merged. Other saved data will be kept.',
              ),
              const SizedBox(height: 12),
              LText(
                'Reading preferences: {0} · Bookmarked books: {1}',
                arguments: [
                  (value['preferences'] as List).length,
                  (value['bookmarks'] as List).length,
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const LText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const LText('Import'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
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
    title: context.tr('Import / export'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LText(
          'Files contain interface preferences, reading preferences and local bookmarks for the active account. Passwords, API keys, books and reading progress are excluded.',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(InkIcons.arrowsLeftRight),
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
        const SizedBox(height: 24),
        const LText(
          'QR codes transfer interface preferences and global reading preferences only. Use a file to transfer bookmarks and library or book settings.',
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(InkIcons.magnifyingGlass),
          onPressed: _busy
              ? null
              : () => _run((transfer, account) async {
                  final text = await Navigator.of(context, rootNavigator: true)
                      .push<String>(
                        MaterialPageRoute(
                          builder: (_) => const SettingsQrScanner(),
                        ),
                      );
                  if (text != null) {
                    await _preview(
                      transfer,
                      account,
                      await transfer.inspectQr(text),
                    );
                  }
                }),
          label: const LText('Scan QR code'),
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

class SettingsQrScanner extends StatefulWidget {
  const SettingsQrScanner({super.key});
  @override
  State<SettingsQrScanner> createState() => _SettingsQrScannerState();
}

class _SettingsQrScannerState extends State<SettingsQrScanner> {
  final _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool _returned = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: InkAppBar(title: const LText('Scan QR code')),
    body: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: LText('Point the camera at an Inkora settings QR code.'),
          ),
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                if (_returned) return;
                final text = capture.barcodes
                    .map((b) => b.rawValue)
                    .whereType<String>()
                    .where((v) => v.startsWith(SettingsTransfer.qrPrefix))
                    .firstOrNull;
                if (text == null) return;
                _returned = true;
                Navigator.pop(context, text);
              },
              errorBuilder: (context, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const LText(
                        'Camera unavailable. Allow camera access in your device settings, or import a file.',
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const LText('Close'),
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
  );
}
