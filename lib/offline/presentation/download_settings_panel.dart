import '../../app/widgets/ink_slider.dart';
import '../../app/l10n/app_strings.dart';
import '../../app/icons/inkora_icons.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/widgets/inkora_widgets.dart';
import '../application/offline_coordinator.dart';
import '../data/download_store.dart';
import '../../features/settings/presentation/settings_reset_button.dart';

class DownloadSettingsPanel extends ConsumerStatefulWidget {
  const DownloadSettingsPanel({super.key});
  @override
  ConsumerState<DownloadSettingsPanel> createState() =>
      _DownloadSettingsPanelState();
}

class _DownloadSettingsPanelState extends ConsumerState<DownloadSettingsPanel> {
  bool _busy = false;

  Future<void> _run(Future<void> Function(OfflineCoordinator) action) async {
    setState(() => _busy = true);
    try {
      final coordinator = await ref.read(offlineCoordinatorProvider.future);
      if (coordinator != null) await action(coordinator);
      // The Downloads storage card shows the quota too.
      ref.invalidate(downloadStorageProvider);
    } catch (_) {
      if (mounted) {
        notifyInk(
          context,
          'Unable to update downloads. Check free space and the selected quota.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = ref.watch(offlineCoordinatorProvider);
    // Shared memoized summary: recomputed on job state changes only.
    final storage = ref.watch(downloadStorageProvider).asData?.value;
    final occupied = storage == null
        ? 0
        : storage.downloaded + storage.reserved;
    return InkContent(
      child: coordinator.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => InkEmptyState(
          icon: InkIcons.warningCircle,
          title: "Offline storage unavailable",
          message: "Unable to open offline storage.",
          label: "Retry",
          action: () => ref.invalidate(offlineCoordinatorProvider),
        ),
        data: (service) => service == null
            ? InkEmptyState(
                icon: InkIcons.checkCircle,
                title: "Preparing your offline shelf",
                message: "Offline storage becomes available with your active account.",
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsResetButton(
                    enabled: !_busy,
                    onReset: () => _run((s) async {
                      final used = await s.store.occupied();
                      await s.configure(
                        quota: used > defaultDownloadQuota
                            ? used
                            : defaultDownloadQuota,
                        wifiOnly: true,
                      );
                    }),
                  ),
                  InkPanel(
                    framed: false,
                    title: "Storage and network",
                    icon: InkIcons.hardDrives,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LText(
                          "{0} MiB downloaded or reserved",
                          arguments: [occupied ~/ (1024 * 1024)],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: (occupied / service.store.quota).clamp(0, 1),
                        ),
                        const SizedBox(height: 8),
                        const LText(
                          'Space includes downloads and temporary transfer reservations. Cover and page caches are separate.',
                        ),
                        const SizedBox(height: 12),
                        InkSlider(
                          sliderKey: const Key('download-quota'),
                          label: context.tr('Download storage quota'),
                          value: service.store.quota / (1024 * 1024),
                          min: 256,
                          max: (service.store.quota / (1024 * 1024)).clamp(
                            32768,
                            double.infinity,
                          ),
                          divisions:
                              ((service.store.quota / (1024 * 1024)).clamp(
                                            32768,
                                            double.infinity,
                                          ) /
                                          256 -
                                      1)
                                  .round(),
                          enabled: !_busy,
                          formatValue: (value) => value < 1024
                              ? context.tr('{0} MiB', [value.round()])
                              : context.tr('{0} GiB', [
                                  double.parse(
                                    (value / 1024).toStringAsFixed(2),
                                  ),
                                ]),
                          onCommitted: (value) => _run(
                            (s) => s.configure(
                              quota: value.round() * 1024 * 1024,
                              wifiOnly: s.store.wifiOnly,
                            ),
                          ),
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
