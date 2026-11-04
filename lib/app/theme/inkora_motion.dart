import 'package:flutter/material.dart';

/// Shared control, scroll and sheet timings; page routes use platform defaults.
abstract final class InkoraMotion {
  static const tab = Duration(milliseconds: 160);
  static const scroll = Duration(milliseconds: 240);
  static const sheet = Duration(milliseconds: 240);
  static const sheetReverse = Duration(milliseconds: 180);

  static AnimationStyle sheetStyle(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : const AnimationStyle(duration: sheet, reverseDuration: sheetReverse);
}
