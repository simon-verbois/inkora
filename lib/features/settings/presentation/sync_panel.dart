import '../../../app/l10n/app_strings.dart';
import '../../../app/icons/inkora_icons.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/inkora_widgets.dart';
import '../../../offline/application/offline_coordinator.dart';

class SyncPanel extends ConsumerStatefulWidget {
  const SyncPanel({super.key});
  @override
  ConsumerState<SyncPanel> createState() => _SyncPanelState();
}

class _SyncPanelState extends ConsumerState<SyncPanel> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final events = ref.watch(progressIntentsProvider);
    final pending = events.asData?.value ?? [];
    return InkPanel(
      title: context.tr("Reading progress"),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LText(
            events.hasError
                ? 'Unable to read synchronization status.'
                : events.isLoading
                ? 'Loading saved updates…'
                : pending.isEmpty
                ? 'All saved progress is synchronized.'
                : 'Waiting to sync: {0}.',
            arguments: [
              AppStrings.of(context).quantity(pending.length, 'update'),
            ],
          ),
          const SizedBox(height: 12),
          const LText(
            'Reading positions are saved on your device immediately. Uploads retry automatically.',
          ),
          if (pending.any((event) => event.state == 'conflict'))
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LText(
                'A conflict needs your choice. Open the affected book and select Reading progress.',
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await (await ref.read(offlineCoordinatorProvider.future))
                          ?.sync
                          .replay();
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: LText(
                              'Sync could not finish. Your progress remains saved locally.',
                            ),
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            icon: const Icon(InkIcons.arrowsClockwise),
            label: LText(_busy ? 'Retrying…' : 'Retry synchronization'),
          ),
        ],
      ),
    );
  }
}
