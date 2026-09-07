import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixterm/utils/design_tokens.dart';

/// WCAG 2.1 relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

/// WCAG 2.1 contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

double _hue(Color c) => HSLColor.fromColor(c).hue;

void main() {
  // These are the thresholds the palette was derived to satisfy. They are
  // gates rather than diagnostics: each one comes from a rule this project
  // chose, so a failure means a token drifted, not that the rule needs
  // relaxing. If a value here has to change, change the derivation and the
  // documented reason with it.
  group('surface ladder', () {
    const ladder = <String, List<Color>>{
      'bg -> panel': [AppColors.bg, AppColors.panel],
      'panel -> raised': [AppColors.panel, AppColors.raised],
      'raised -> hover': [AppColors.raised, AppColors.hover],
      'hover -> selected': [AppColors.hover, AppColors.selected],
    };

    test('every step sits in the 1.15-1.40:1 band', () {
      // Below 1.15 the layers stop reading as separate; above 1.40 a dark
      // interface turns into a stack of visibly different greys. The palette
      // this replaced measured 1.094, 1.137 and 1.247 — the problem was not
      // that the steps were small but that they were uneven.
      ladder.forEach((name, pair) {
        final ratio = _contrast(pair[0], pair[1]);
        expect(
          ratio,
          inInclusiveRange(1.15, 1.40),
          reason: '$name is ${ratio.toStringAsFixed(3)}:1',
        );
      });
    });

    test('steps are even, so no layer reads as the odd one out', () {
      final ratios = ladder.values.map((p) => _contrast(p[0], p[1])).toList();
      final spread = ratios.reduce(math.max) - ratios.reduce(math.min);
      expect(
        spread,
        lessThan(0.06),
        reason: 'ladder steps: '
            '${ratios.map((r) => r.toStringAsFixed(3)).join(", ")}',
      );
    });

    test('selection survives with hue stripped out', () {
      // Selection must not depend on the accent alone: a colour-blind user,
      // a monochrome display, or a greyscale screenshot has to still show
      // which row is current.
      expect(_contrast(AppColors.panel, AppColors.selected),
          greaterThanOrEqualTo(1.5));
    });

    test('neutrals stay in one hue family', () {
      // A dark interface whose greys disagree about their hue reads as
      // dirty rather than as deliberate. +-30 degrees of the 214 the ramp
      // was derived at.
      for (final c in [
        AppColors.bg,
        AppColors.panel,
        AppColors.raised,
        AppColors.hover,
        AppColors.selected,
        AppColors.border,
        AppColors.borderStrong,
      ]) {
        expect((_hue(c) - 214).abs(), lessThanOrEqualTo(30));
      }
    });
  });

  group('text contrast', () {
    // Verified against the lightest surface that carries text, so every
    // pairing is at least this legible everywhere else it appears.
    test('primary and secondary text meet WCAG AA on the lightest surface',
        () {
      expect(_contrast(AppColors.raised, AppColors.textPrimary),
          greaterThanOrEqualTo(4.5));
      expect(_contrast(AppColors.raised, AppColors.textSecondary),
          greaterThanOrEqualTo(4.5));
    });

    test('tertiary text clears the large-text and glyph floor', () {
      // Placeholders and disabled labels only; never body copy.
      expect(_contrast(AppColors.raised, AppColors.textTertiary),
          greaterThanOrEqualTo(3.0));
    });

    test('no pure black or pure white', () {
      // Both read as harsh on a dark ground and are a reliable tell of a
      // palette that was typed rather than derived.
      for (final c in [
        AppColors.bg,
        AppColors.panel,
        AppColors.raised,
        AppColors.textPrimary,
        AppColors.textSecondary,
      ]) {
        expect(c, isNot(const Color(0xFF000000)));
        expect(c, isNot(const Color(0xFFFFFFFF)));
      }
    });
  });

  group('accent', () {
    test('is legible on every surface it can appear on', () {
      for (final surface in [
        AppColors.bg,
        AppColors.panel,
        AppColors.raised,
        AppColors.hover,
        AppColors.selected,
      ]) {
        expect(_contrast(surface, AppColors.accent),
            greaterThanOrEqualTo(4.5),
            reason: 'accent on ${surface.toString()}');
      }
    });

    test('text on an accent fill is legible', () {
      expect(_contrast(AppColors.accent, AppColors.onAccent),
          greaterThanOrEqualTo(4.5));
    });

    test('matches the hue of the application icon', () {
      // The accent is sampled from the icon's own dominant colour (hue 170)
      // so the mark and the interface agree. Drifting off it means the app
      // no longer looks like its own icon.
      expect((_hue(AppColors.accent) - 170).abs(), lessThanOrEqualTo(10));
    });

    test('is not fully saturated', () {
      // The palette this replaced ran the accent at 100% saturation, which
      // made the interface louder than the icon it was matching while
      // buying almost no contrast.
      expect(HSLColor.fromColor(AppColors.accent).saturation, lessThan(0.85));
    });

    test('semantic colours stay clear of the accent hue', () {
      // Otherwise "connected" and "this is the button" say the same thing.
      for (final c in [AppColors.success, AppColors.warning, AppColors.danger]) {
        var delta = (_hue(c) - _hue(AppColors.accent)).abs();
        if (delta > 180) delta = 360 - delta;
        expect(delta, greaterThanOrEqualTo(25));
      }
    });

    test('semantic colours meet WCAG AA on the lightest surface', () {
      for (final c in [AppColors.success, AppColors.warning, AppColors.danger]) {
        expect(_contrast(AppColors.raised, c), greaterThanOrEqualTo(4.5));
      }
    });
  });

  group('scales', () {
    test('spacing is a multiple of 4', () {
      // The single rule that most reliably separates a layout that was
      // measured from one that was nudged until it looked about right.
      for (final v in [
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xxxl,
      ]) {
        expect(v % 4, 0, reason: '$v is not a multiple of 4');
      }
    });

    test('type sizes are far enough apart to read as a hierarchy', () {
      // Two steps a single pixel apart are invisible alone and dissolve the
      // hierarchy wherever they appear together.
      final sizes = <double>{
        AppTypography.caption.fontSize!,
        AppTypography.label.fontSize!,
        AppTypography.secondary.fontSize!,
        AppTypography.body.fontSize!,
        AppTypography.title.fontSize!,
        AppTypography.display.fontSize!,
      }.toList()
        ..sort();

      for (var i = 1; i < sizes.length; i++) {
        final gap = sizes[i] - sizes[i - 1];
        // 11 -> 12 is the one deliberate exception: both are too small for
        // a 2px step, and weight (600 vs 500/400) separates them instead.
        final isSmallPair = sizes[i] <= 12;
        expect(gap, greaterThanOrEqualTo(isSmallPair ? 1 : 2),
            reason: 'sizes: $sizes');
      }
    });

    test('type uses at most three weights', () {
      final weights = <FontWeight>{
        AppTypography.display.fontWeight!,
        AppTypography.title.fontWeight!,
        AppTypography.bodyStrong.fontWeight!,
        AppTypography.body.fontWeight!,
        AppTypography.secondary.fontWeight!,
        AppTypography.label.fontWeight!,
        AppTypography.caption.fontWeight!,
      };
      expect(weights.length, lessThanOrEqualTo(3), reason: '$weights');
    });

    test('radii are three steps that do not collide', () {
      expect(AppRadius.sm, lessThan(AppRadius.md));
      expect(AppRadius.md, lessThan(AppRadius.lg));
      expect(AppRadius.md - AppRadius.sm, greaterThanOrEqualTo(2));
      expect(AppRadius.lg - AppRadius.md, greaterThanOrEqualTo(2));
    });

    test('shadows are shadows, not glows', () {
      // A glow is wide and bright and reads as emission; a shadow is offset
      // downward and dark and reads as a surface lifting. Only genuinely
      // floating surfaces get one at all.
      for (final shadow in [
        ...AppElevation.popover,
        ...AppElevation.dialog,
      ]) {
        expect(shadow.offset.dy, greaterThan(0));
        expect(_luminance(shadow.color.withValues(alpha: 1.0)), lessThan(0.05));
      }
    });
  });

  group('token discipline in widget code', () {
    // A ratchet: the count of raw values in the UI may fall but never rise.
    // Without this the tokens quietly become one more option alongside the
    // hardcoded numbers they were meant to replace.
    late List<String> uiSources;

    setUpAll(() {
      uiSources = [
        ...Directory('lib/widgets').listSync(recursive: true),
        ...Directory('lib/screens').listSync(recursive: true),
      ]
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.readAsStringSync())
          .toList();
    });

    test('no widget hardcodes a hex colour', () {
      final hex = RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)');
      final hits = <String>[];
      for (final src in uiSources) {
        hits.addAll(hex.allMatches(src).map((m) => m.group(0)!));
      }
      expect(hits, isEmpty,
          reason: 'colours belong in AppColors, not in widgets: $hits');
    });

    test('raw fontSize use does not grow', () {
      // Every one of these is a place the type scale was bypassed.
      final hits = uiSources
          .expand((s) => RegExp(r'fontSize:\s*\d').allMatches(s))
          .length;
      expect(hits, lessThanOrEqualTo(24),
          reason: 'use AppTypography instead of a raw fontSize');
    });

    test('raw border radius use does not grow', () {
      final hits = uiSources
          .expand((s) => RegExp(r'circular\(\s*\d').allMatches(s))
          .length;
      expect(hits, lessThanOrEqualTo(20),
          reason: 'use AppRadius instead of a raw circular()');
    });
  });
}
