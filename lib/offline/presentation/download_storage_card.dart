import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/icons/inkora_icons.dart';
import '../../app/l10n/app_strings.dart';
import '../../app/theme/inkora_theme.dart';
import '../../app/widgets/inkora_widgets.dart';
import '../application/offline_coordinator.dart';
import 'download_status.dart';

/// Storage summary at the top of Downloads: used of quota, a stacked bar
/// (downloads, temporary transfer reservations) and the reader page cache,
/// which is not counted in the quota. One memoized aggregate query feeds it
/// ([downloadStorageProvider]); nothing is computed per frame.
class DownloadStorageCard extends ConsumerWidget {
  const DownloadStorageCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(downloadStorageProvider).asData?.value;
    if (storage == null) return const SizedBox.shrink();
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final used = storage.downloaded + storage.reserved;
    final quota = storage.quota < 1 ? 1 : storage.quota;
    final reservedColor = theme.colorScheme.primary.withValues(alpha: .45);
    String part(String label, int bytes) => strings.text('{0} · {1}', [
      strings.text(label),
      formatBytes(strings, bytes),
    ]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        InkSpace.lg,
        InkSpace.sm,
        InkSpace.lg,
        0,
      ),
      child: InkPanel(
        key: const Key('download-storage'),
        title: 'Storage',
        icon: InkIcons.hardDrives,
        action: IconButton(
          key: const Key('download-storage-settings'),
          tooltip: context.tr('Download settings'),
          onPressed: () => context.go('/settings/downloads'),
          icon: const Icon(InkIcons.gearSix),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LText(
              '{0} of {1} used',
              arguments: [
                formatBytes(strings, used),
                formatBytes(strings, storage.quota),
              ],
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: InkSpace.sm),
            ExcludeSemantics(
              child: ClipRRect(
                borderRadius: InkRadius.round,
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      for (final (bytes, color) in [
                        (storage.downloaded, theme.colorScheme.primary),
                        (storage.reserved, reservedColor),
                        (
                          (quota - used).clamp(0, quota),
                          theme.colorScheme.outlineVariant,
                        ),
                      ])
                        if (bytes > 0)
                          Expanded(
                            flex: (bytes * 1000 / quota).ceil().clamp(1, 1000),
                            child: ColoredBox(color: color),
                          ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: InkSpace.sm),
            Wrap(
              spacing: InkSpace.lg,
              runSpacing: InkSpace.xs,
              children: [
                _Legend(
                  color: theme.colorScheme.primary,
                  label: part('Downloads', storage.downloaded),
                ),
                if (storage.reserved > 0)
                  _Legend(
                    color: reservedColor,
                    label: part('Reserved', storage.reserved),
                  ),
                _Legend(
                  label: part('Page cache', storage.cached),
                  outlined: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, this.color, this.outlined = false});
  final String label;
  final Color? color;
  final bool outlined;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: outlined ? null : color,
            shape: BoxShape.circle,
            border: outlined
                ? Border.all(color: theme.colorScheme.outline)
                : null,
          ),
          child: const SizedBox.square(dimension: 10),
        ),
        const SizedBox(width: InkSpace.xs),
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.meta?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
