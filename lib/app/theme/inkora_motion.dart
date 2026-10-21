import 'package:flutter/material.dart';

/// Header destinations fade horizontally, deeper pages slide, sheets rise.
abstract final class InkoraMotion {
  static const tab = Duration(milliseconds: 160);
  static const forward = Duration(milliseconds: 240);
  static const reverse = Duration(milliseconds: 200);
  static const sheet = Duration(milliseconds: 240);
  static const sheetReverse = Duration(milliseconds: 180);

  static AnimationStyle sheetStyle(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : const AnimationStyle(duration: sheet, reverseDuration: sheetReverse);
}
