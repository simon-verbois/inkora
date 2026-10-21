import 'package:flutter/widgets.dart';

import '../../app/icons/inkora_icons.dart';
import '../../app/l10n/app_strings.dart';
import '../../features/library/presentation/progress_format.dart';
import '../data/download_store.dart';

/// Source key of the single label of each download state (queue rows, volume
/// actions and status lines use the same words).
String downloadStateLabel(DownloadState state) => switch (state) {
  DownloadState.queued => 'Queued',
  DownloadState.running => 'Downloading',
  DownloadState.verifying => 'Checking downloaded pages',
  DownloadState.paused => 'Paused',
  DownloadState.failed => 'Download failed',
  DownloadState.complete => 'Ready offline',
  DownloadState.cancelled => 'Cancelled',
};

/// "Downloading · 40 %" for a running transfer with a known [ratio], the
/// plain state label otherwise. The percent uses the shared formatter.
String downloadStatusLabel(
  AppStrings strings,
  DownloadState state, {
  double? ratio,
}) {
  final label = strings.text(downloadStateLabel(state));
  if (state != DownloadState.running || ratio == null) return label;
  return strings.text('{0} · {1}', [
    label,
    percentLabel(strings, ratio, finished: true),
  ]);
}

/// Center icon of the progress ring: pending (hourglass, distinct from the
/// reading-history clock), paused or failed. Running transfers show none.
IconData? downloadStateIcon(DownloadState state) => switch (state) {
  DownloadState.queued => InkIcons.hourglassMedium,
  DownloadState.paused => InkIcons.pause,
  DownloadState.failed => InkIcons.warningCircle,
  _ => null,
};

/// Binary sizes with the existing MiB/GiB messages: "412 MiB", "1.4 MiB"
/// (one decimal under 10 MiB) and "1.2 GiB" (one decimal from 1 GiB).
String formatBytes(AppStrings strings, int bytes) {
  const mebibyte = 1024 * 1024;
  const gibibyte = 1024 * mebibyte;
  if (bytes >= gibibyte) {
    return strings.text('{0} GiB', [(bytes / gibibyte * 10).round() / 10]);
  }
  final mebibytes = bytes / mebibyte;
  if (bytes > 0 && mebibytes < 10) {
    return strings.text('{0} MiB', [
      ((mebibytes * 10).round() / 10).clamp(.1, 10),
    ]);
  }
  return strings.text('{0} MiB', [mebibytes.round()]);
}
