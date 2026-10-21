import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final (high, low) = la > lb ? (la, lb) : (lb, la);
  return (high + .05) / (low + .05);
}

void main() {
  for (final appearance in AppAppearance.values) {
    test('$appearance keeps text and semantic colors legible', () {
      final theme = InkoraTheme.forAppearance(appearance);
      final scheme = theme.colorScheme;
      final colors = theme.extension<InkoraColors>()!;
      for (final (name, surface) in [
        ('panel', colors.panel),
        ('raised', colors.raised),
      ]) {
        for (final (role, foreground) in [
          ('text', scheme.onSurface),
          ('secondary text', scheme.onSurfaceVariant),
          ('accent', scheme.primary),
          ('heading', colors.heading),
          ('success', colors.success),
          ('danger', colors.danger),
        ]) {
          expect(
            _contrast(foreground, surface),
            greaterThanOrEqualTo(4.5),
            reason: '$role on $name',
          );
        }
      }
      expect(_contrast(scheme.onPrimary, scheme.primary), greaterThan(4.5));
      expect(_contrast(scheme.onError, scheme.error), greaterThan(4.5));
      // Badges sit on artwork: check the scrim over the brightest artwork.
      final scrimOverWhite = Color.alphaBlend(colors.scrim, Colors.white);
      expect(_contrast(colors.onScrim, scrimOverWhite), greaterThan(4.5));
      expect(
        _contrast(scheme.surface, colors.success),
        greaterThanOrEqualTo(4.5),
        reason: 'read badge check',
      );
    });
  }

  test('radius scale has exactly four values', () {
    expect({
      InkRadius.s,
      InkRadius.m,
      InkRadius.l,
      InkRadius.pill,
    }, hasLength(4));
    expect(InkoraLayout.radius, InkRadius.l);
    expect(
      [
        InkSpace.xs,
        InkSpace.sm,
        InkSpace.md,
        InkSpace.lg,
        InkSpace.xl,
        InkSpace.xxl,
      ],
      [4, 8, 12, 16, 24, 32],
    );
  });
}
