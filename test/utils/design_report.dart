// Prints the measurements the design tokens were derived from.
//
// `test/utils/design_tokens_test.dart` asserts that these stay in band; this
// tool shows the actual numbers, which is what you want when you are
// changing a token and need to see how far it can move before something
// else breaks. Keeping the generator next to the generated values is the
// point: a number whose derivation is not reproducible is a number nobody
// can safely change later.
//
// Not named `_test.dart`, so it stays out of the default suite and only
// runs when asked for:
//
//   flutter test test/utils/design_report.dart

// This file's whole purpose is to print a table for a human to read, so
// the lint against printing does not apply to it.
// ignore_for_file: avoid_print

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixterm/utils/design_tokens.dart';

double luminance(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final hi = math.max(luminance(a), luminance(b));
  final lo = math.min(luminance(a), luminance(b));
  return (hi + 0.05) / (lo + 0.05);
}

String hex(Color c) =>
    '#${((c.r * 255).round() << 16 | (c.g * 255).round() << 8 | (c.b * 255).round()).toRadixString(16).padLeft(6, '0').toUpperCase()}';

void row(String label, Color c, {Color? against}) {
  final hsl = HSLColor.fromColor(c);
  final buf = StringBuffer()
    ..write(label.padRight(18))
    ..write(hex(c).padRight(10))
    ..write('H${hsl.hue.round().toString().padLeft(4)}  ')
    ..write('S${(hsl.saturation * 100).round().toString().padLeft(3)}%  ')
    ..write('L${(hsl.lightness * 100).toStringAsFixed(1).padLeft(5)}%');
  if (against != null) {
    buf.write('   ${contrast(against, c).toStringAsFixed(3)}:1');
  }
  print(buf);
}

void main() {
  test('design measurements', () {
  print('SURFACE LADDER  (target: every step in 1.15-1.40:1, evenly)');
  row('bg', AppColors.bg);
  row('panel', AppColors.panel, against: AppColors.bg);
  row('raised', AppColors.raised, against: AppColors.panel);
  row('hover', AppColors.hover, against: AppColors.raised);
  row('selected', AppColors.selected, against: AppColors.hover);
  row('border', AppColors.border, against: AppColors.raised);
  print('  panel -> selected (greyscale floor 1.5): '
      '${contrast(AppColors.panel, AppColors.selected).toStringAsFixed(3)}:1');

  print('\nTEXT  (verified on `raised`, the lightest surface carrying text)');
  row('textPrimary', AppColors.textPrimary, against: AppColors.raised);
  row('textSecondary', AppColors.textSecondary, against: AppColors.raised);
  row('textTertiary', AppColors.textTertiary, against: AppColors.raised);

  print('\nACCENT  (hue sampled from the app icon; AA on every surface)');
  for (final s in {
    'bg': AppColors.bg,
    'panel': AppColors.panel,
    'raised': AppColors.raised,
    'hover': AppColors.hover,
    'selected': AppColors.selected,
  }.entries) {
    print('  accent on ${s.key.padRight(9)} '
        '${contrast(s.value, AppColors.accent).toStringAsFixed(2)}:1');
  }
  print('  onAccent on accent  '
      '${contrast(AppColors.accent, AppColors.onAccent).toStringAsFixed(2)}:1');

  print('\nSEMANTIC  (must sit >=25 deg off the accent hue)');
  final accentHue = HSLColor.fromColor(AppColors.accent).hue;
  for (final e in {
    'success': AppColors.success,
    'warning': AppColors.warning,
    'danger': AppColors.danger,
  }.entries) {
    var d = (HSLColor.fromColor(e.value).hue - accentHue).abs();
    if (d > 180) d = 360 - d;
    row(e.key, e.value, against: AppColors.raised);
    print('  ${' ' * 16}${d.round()} deg from accent');
  }
  });
}
