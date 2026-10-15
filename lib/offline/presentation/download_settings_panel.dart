import '../../app/l10n/app_strings.dart';
import '../../app/icons/inkora_icons.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/widgets/inkora_widgets.dart';
import '../application/offline_coordinator.dart';
import '../data/download_store.dart';

class DownloadSettingsPanel extends ConsumerStatefulWidget {
  const DownloadSettingsPanel({super.key});
  @override
  ConsumerState<DownloadSettingsPanel> createState() =>
      _DownloadSettingsPanelState();
}

class _DownloadSettingsPanelState extends ConsumerState<DownloadSettingsPanel> {
  bool _busy = false;
  Future<int>? _occupied;
  Object? _occupiedFor;

  /// Recompute occupied bytes only when the watched job list changes, not on
  /// every rebuild (busy toggles, theme changes).
  Future<int> _occupiedBytes(OfflineCoordinator service, Object? jobs) {
    if (_occupied == null || !identical(jobs, _occupiedFor)) {
      _occupiedFor = jobs;
      _occupied = service.store.occupied();
    }
    return _occupied!;
  }

  Future<void> _run(Future<void> Function(OfflineCoordinator) action) async {
    setState(() => _busy = true);
    try {
      final coordinator = await ref.read(offlineCoordinatorProvider.future);
      if (coordinator != null) await action(coordinator);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LText(
              'Unable to update downloads. Check free space and the selected quota.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = ref.watch(offlineCoordinatorProvider);
    final jobs = ref.watch(downloadsProvider);
    return InkContent(
      child: coordinator.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => InkEmptyState(
          icon: InkIcons.warningCircle,
          title: context.tr("Offline storage unavailable"),
          message: context.tr("Unable to open offline storage."),
          label: context.tr("Retry"),
          action: () => ref.invalidate(offlineCoordinatorProvider),
        ),
        data: (service) => service == null
            ? InkEmptyState(
                icon: InkIcons.checkCircle,
                title: context.tr("Preparing your offline shelf"),
                message: context.tr(
                  "Offline storage becomes available with your active account.",
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkPanel(
                    title: context.tr("Storage and network"),
                    icon: InkIcons.hardDrives,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FutureBuilder<int>(
                          future: _occupiedBytes(service, jobs.asData?.value),
                          builder: (_, bytes) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              LText(
                                "{0} MiB downloaded or reserved",
                                arguments: [(bytes.data ?? 0) ~/ (1024 * 1024)],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: ((bytes.data ?? 0) / service.store.quota)
                                    .clamp(0, 1),
                              ),
                              const SizedBox(height: 8),
                              const LText(
                                'Space includes downloads and temporary transfer reservations. Cover and page caches are separate.',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const LText('Download storage quota'),
                        DropdownButton<int>(
                          icon: const Icon(InkIcons.caretDown, size: 20),
                          isExpanded: true,
                          value: service.store.quota,
                          items:
                              [
                                    512 * 1024 * 1024,
                                    defaultDownloadQuota,
                                    4 * 1024 * 1024 * 1024,
                                  ]
                                  .map(
                                    (bytes) => DropdownMenuItem(
                                      value: bytes,
                                      child: LText(
                                        "{0} MiB",
                                        arguments: [bytes ~/ (1024 * 1024)],
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: _busy
                              ? null
                              : (value) {
                                  if (value != null) {
                                    _run(
                                      (s) => s.configure(
                                        quota: value,
                                        wifiOnly: s.store.wifiOnly,
                                      ),
                                    );
                                  }
                                },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const LText('Download on Wi-Fi only'),
                          value: service.store.wifiOnly,
                          onChanged: _busy
                              ? null
                              : (value) => _run(
                                  (s) => s.configure(
                                    quota: s.store.quota,
                                    wifiOnly: value,
                                  ),
                                ),
                        ),
                        const LText(
                          'Background downloads follow your device’s scheduling and battery policies.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
