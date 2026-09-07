import 'package:flutter/material.dart';

/// Design tokens — the single source of truth for every visual constant.
///
/// Nothing here was picked by eye. Each value was derived from a stated rule
/// and verified by measurement (`tool/measure_design.dart` re-runs the
/// checks, and `test/utils/design_tokens_test.dart` fails the build if a
/// value drifts out of its band).
///
/// The rules, and why each exists:
///
/// * **Value carries the hierarchy, not hue.** Surfaces are separated by
///   luminance, so the interface still reads when hue is unavailable —
///   colour-blind users, a monochrome display, a screenshot in a bug report.
/// * **One step size for the whole ladder.** The previous palette's steps
///   were 1.094:1 then 1.137:1 then 1.247:1, which is why the interface read
///   as flat: not because the steps were small, but because they were
///   uneven, so nothing announced itself as a distinct layer.
/// * **Accent is spent, not sprinkled.** It marks what is active or what the
///   user should press next, and nothing else.
/// * **Every spacing, radius, size and duration comes from a scale.** A value
///   1px away from its neighbour is invisible on its own and dissolves the
///   hierarchy when both appear on the same screen.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------
  // Surfaces
  //
  // Hue 214 was measured from the palette this replaces (its neutrals ran
  // 208–216°, already disciplined — only the steps between them were not).
  // Saturation falls as lightness rises (26 → 13%) so the dark end stays
  // tinted rather than grey while the light end doesn't turn blue.
  //
  // Each step is a 1.20:1 luminance ratio against the one below it — the
  // middle of the 1.15–1.40:1 band where a layer reads as separate without
  // the interface turning into a stack of visibly different greys.
  // ---------------------------------------------------------------------

  /// Deepest layer: terminal canvas and the window's own ground. L 6.5%.
  static const Color bg = Color(0xFF0C1015);

  /// Chrome that frames content: sidebar, dialogs, title bars. L 13.95%.
  static const Color panel = Color(0xFF1C232B);

  /// Discrete objects on top of chrome: cards, inputs, icon wells. L 19.55%.
  static const Color raised = Color(0xFF28313B);

  /// Pointer-over state for anything interactive. L 24.55%.
  static const Color hover = Color(0xFF353D49);

  /// Current selection — the row you are on, the active tab. L 29%.
  ///
  /// 1.74:1 against [panel], which clears the 1.5:1 floor for "still
  /// distinguishable with hue stripped out", so selection never depends on
  /// the accent bar alone.
  static const Color selected = Color(0xFF404954);

  /// Divider and outline colour. L 33.75%.
  static const Color border = Color(0xFF4B5561);

  /// Outlines that need to read as an edge rather than a hint — focused
  /// inputs, popover perimeters.
  static const Color borderStrong = Color(0xFF5C6673);

  // ---------------------------------------------------------------------
  // Text
  //
  // Verified against [raised], the lightest surface that carries body text;
  // every pairing is therefore at least as legible everywhere else.
  // ---------------------------------------------------------------------

  /// Primary reading colour. 11.03:1 on [raised], 15.96:1 on [bg].
  ///
  /// Deliberately not #FFFFFF: pure white on a dark ground reads harsh and
  /// is one of the more reliable tells of an unconsidered dark theme.
  static const Color textPrimary = Color(0xFFE8EBEF);

  /// Supporting text — host addresses, captions, field hints. 4.50:1 on
  /// [raised], which is the WCAG AA floor for body text, not merely for
  /// large text.
  static const Color textSecondary = Color(0xFF8D98A5);

  /// Text that must recede but stay readable: placeholders, disabled
  /// labels, inactive icons. 3.02:1 on [raised] — AA for large text and for
  /// interface glyphs, and never used for body copy.
  static const Color textTertiary = Color(0xFF6F7A87);

  // ---------------------------------------------------------------------
  // Accent
  //
  // Hue 170 at S 62% / L 50% is sampled from the application icon's own
  // dominant accent, so the mark and the interface agree. The palette this
  // replaces used S 100%, which made the interface louder than the brand
  // asset it was supposed to match, while buying only 0.26 of contrast
  // (9.99:1 against 9.73:1 on [bg]).
  // ---------------------------------------------------------------------

  /// Active state, focus, primary action. 9.73:1 on [bg], 6.72:1 on
  /// [raised]; dark text on top of it reads at 9.73:1.
  static const Color accent = Color(0xFF30CFB4);

  /// Pressed state for accent-filled controls.
  static const Color accentPressed = Color(0xFF2AB79F);

  /// Accent as a ground rather than a mark — selected-row tint, badge
  /// backgrounds. Low enough not to compete with a filled action.
  static const Color accentSubtle = Color(0x2630CFB4);

  /// Accent as an outline.
  static const Color accentBorder = Color(0x6630CFB4);

  /// Text and glyphs placed on top of an accent fill.
  static const Color onAccent = Color(0xFF07100E);

  // ---------------------------------------------------------------------
  // Semantic
  //
  // These keep their own hues: a status colour's meaning *is* its hue, so
  // unlike chrome they cannot be derived from the identity. Their lightness
  // and saturation are normalised to the ramp (S 62%, AA on [raised]) so
  // they sit in the interface rather than on top of it.
  // ---------------------------------------------------------------------

  /// Connected, succeeded, online. 4.51:1 on [raised].
  ///
  /// Hue 136 rather than the 150 it was first derived at: 150 sat 19.8°
  /// from the accent, close enough that "this connection is live" and "this
  /// is the button to press" would have read as the same signal. 34° apart
  /// is far enough that the two are never confused.
  static const Color success = Color(0xFF29AD4C);

  /// Needs attention but not broken. 4.53:1 on [raised].
  static const Color warning = Color(0xFFC08F2D);

  /// Failed, disconnected, destructive. 4.51:1 on [raised].
  static const Color danger = Color(0xFFDF7A76);

  /// Tinted grounds for the semantic colours, at the same alpha as
  /// [accentSubtle] so a row of mixed badges reads as one family.
  static const Color successSubtle = Color(0x2629AD4C);
  static const Color warningSubtle = Color(0x26C08F2D);
  static const Color dangerSubtle = Color(0x26DF7A76);

  // ---------------------------------------------------------------------
  // Terminal
  // ---------------------------------------------------------------------

  static const Color terminalBackground = bg;
  static const Color terminalForeground = textPrimary;

  /// The icon's secondary cyan (hue 185). It exists to make the caret the
  /// one thing on screen that is brighter than the accent, and is used
  /// nowhere else.
  static const Color terminalCursor = Color(0xFF51DFEC);

  /// Selection is a wash rather than a fill so the glyphs under it keep
  /// their own colours.
  static const Color terminalSelection = Color(0x4630CFB4);
}

/// Spacing scale. Every gap and inset in the interface is one of these.
///
/// Multiples of 4 only. This single constraint is what separates a layout
/// that was measured from one that was nudged until it looked about right —
/// the palette this replaces mixed 2, 4, 8, 12, 16, 24 and 32 with no rule
/// about which applied where.
class AppSpacing {
  AppSpacing._();

  /// Between a glyph and its label.
  static const double xs = 4;

  /// Between tightly related items inside one control.
  static const double sm = 8;

  /// Default padding inside a control or list row.
  static const double md = 12;

  /// Between distinct controls; padding of a panel.
  static const double lg = 16;

  /// Between groups of controls.
  static const double xl = 20;

  /// Between sections.
  static const double xxl = 24;

  /// Around an empty state or a dialog's content.
  static const double xxxl = 32;
}

/// Corner radii. Three steps, each with one job, replacing the five
/// unrelated values (4, 6, 8, 10, 12) that were in use.
class AppRadius {
  AppRadius._();

  /// Badges, chips, and anything small enough that a larger radius would
  /// eat the shape.
  static const double sm = 4;

  /// The default: buttons, inputs, list rows, cards, icon wells.
  static const double md = 8;

  /// Surfaces that float above the window: dialogs, popovers, menus.
  static const double lg = 12;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
}

/// Type scale.
///
/// Five sizes — 11, 12, 14, 16, 20 — replacing eight ad-hoc ones that ran
/// 10 through 20. Where a size had to move it rounded *down*: text that
/// shrinks cannot overflow its container, text that grows can. The two
/// small sizes sit one pixel apart but never carry the same kind of
/// content, and weight separates them (600 for badges, 500/400 for labels).
///
/// Weight is limited to three: anything finer is invisible in isolation and
/// muddies the hierarchy when two of them share a screen. Tracking opens up
/// as size falls, which is what keeps small interface labels legible without
/// making them larger.
class AppTypography {
  AppTypography._();

  /// Window and screen titles.
  static const TextStyle display = TextStyle(
    fontSize: 20,
    height: 1.25,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );

  /// Section headings, dialog titles.
  static const TextStyle title = TextStyle(
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15,
    color: AppColors.textPrimary,
  );

  /// The name of a row — a server, a file, a tab.
  static const TextStyle bodyStrong = TextStyle(
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  /// Default reading size.
  static const TextStyle body = TextStyle(
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  /// Supporting line under a body row — a host address, a file size.
  ///
  /// 12 rather than 13: at 13 it sat one pixel from [body], which is
  /// invisible on its own but dissolves the hierarchy wherever the two
  /// appear together, as they do in every list row.
  static const TextStyle secondary = TextStyle(
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Field labels and column headers.
  static const TextStyle label = TextStyle(
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: AppColors.textSecondary,
  );

  /// Badges, counters, timestamps — the smallest text that ships.
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: AppColors.textSecondary,
  );
}

/// Icon sizes. Four steps replacing seven, so two icons sitting next to each
/// other are either deliberately different or identical, never accidentally
/// 2px apart.
///
/// **Icons are outlined, not filled.** The interface's job is to frame
/// content, so its glyphs stay light; filled shapes pull weight toward the
/// chrome and away from the terminal, which is the thing the user is
/// actually looking at. This matters most where both styles of the same
/// glyph exist — `Icons.folder` and `Icons.folder_outlined` in the same
/// window read as two different kinds of folder, which is a distinction the
/// app does not mean to draw. Prefer the `_outlined` variant, and where
/// Material only ships the filled one, keep it consistent within its group.
class AppIconSize {
  AppIconSize._();

  /// Inline with small text: badge glyphs, chevrons.
  static const double sm = 14;

  /// The default for anything alongside body text.
  static const double md = 16;

  /// Toolbar and header actions.
  static const double lg = 20;

  /// The illustration in an empty state — the one place an icon is the
  /// subject rather than a label.
  static const double display = 40;
}

/// Motion.
///
/// Durations are tied to how far the thing being animated has to travel.
/// A colour change that takes as long as a panel sliding open feels
/// sluggish; a panel that opens as fast as a hover feels abrupt.
class AppMotion {
  AppMotion._();

  /// Hover and pressed feedback — fast enough to feel like a response
  /// rather than an animation.
  static const Duration fast = Duration(milliseconds: 120);

  /// The default: things appearing, disappearing, or changing size.
  static const Duration base = Duration(milliseconds: 180);

  /// Layout-level movement, such as the sidebar collapsing.
  static const Duration slow = Duration(milliseconds: 240);

  /// For things entering or settling: decelerates into place.
  static const Curve enter = Curves.easeOutCubic;

  /// For things that move and stop under their own steam.
  static const Curve standard = Curves.easeInOutCubic;
}

/// Elevation.
///
/// Shadows here are shadows, not glows: wide, low-opacity, and vertically
/// offset, so they read as a surface lifting rather than emitting. Only
/// surfaces that genuinely float — menus, dialogs, drag previews — get one;
/// a card that is merely a lighter rectangle uses [AppColors.raised] and no
/// shadow at all.
class AppElevation {
  AppElevation._();

  /// Popovers, dropdowns, context menus.
  static const List<BoxShadow> popover = [
    BoxShadow(color: Color(0x59000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  /// Modal dialogs.
  static const List<BoxShadow> dialog = [
    BoxShadow(color: Color(0x73000000), blurRadius: 32, offset: Offset(0, 12)),
  ];
}
