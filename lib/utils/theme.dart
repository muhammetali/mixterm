import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Flutter theme assembled from [AppColors] and its sibling token classes.
///
/// Every constant here forwards to a token — see `design_tokens.dart` for
/// where each value comes from and why. Nothing in this file should invent
/// a number.
class AppTheme {
  AppTheme._();

  // Names kept from the previous theme so widgets that have not been
  // migrated to the token classes still pick up the corrected ramp.
  static const Color primaryColor = AppColors.accent;
  static const Color backgroundColor = AppColors.bg;
  static const Color surfaceColor = AppColors.panel;
  static const Color cardColor = AppColors.raised;
  static const Color borderColor = AppColors.border;
  static const Color textColor = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color errorColor = AppColors.danger;
  static const Color successColor = AppColors.success;
  static const Color warningColor = AppColors.warning;

  static const Color terminalBackground = AppColors.terminalBackground;
  static const Color terminalForeground = AppColors.terminalForeground;
  static const Color terminalCursor = AppColors.terminalCursor;
  static const Color terminalSelection = AppColors.terminalSelection;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Bundled rather than inherited from the platform. The type scale's
      // sizes and tracking were measured against one rendering, and the
      // system default is SF Pro on macOS but anything at all on Linux —
      // so leaving it to the platform means the interface is only actually
      // designed on one of the two it ships to.
      fontFamily: 'Inter',
      primaryColor: AppColors.accent,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        // The palette this replaces carried a purple secondary 94° away
        // from the accent, which gave the interface two competing brand
        // hues and no rule for when to use which. Secondary now resolves to
        // the accent, so a component that reaches for it stays on-brand.
        secondary: AppColors.accent,
        surface: AppColors.panel,
        surfaceContainerHighest: AppColors.raised,
        outline: AppColors.border,
        error: AppColors.danger,
        onPrimary: AppColors.onAccent,
        onSecondary: AppColors.onAccent,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
        onError: AppColors.onAccent,
      ),

      // Material's ripple is an Android idiom. On desktop the expected
      // feedback is a pointer-over tint, which the widgets provide
      // themselves, so the ripple is removed rather than left to fight it.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: AppColors.hover,

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.panel,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.title,
      ),

      cardTheme: CardThemeData(
        color: AppColors.raised,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AppColors.accentPressed;
            }
            return AppColors.accent;
          }),
          foregroundColor: const WidgetStatePropertyAll(AppColors.onAccent),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          textStyle: const WidgetStatePropertyAll(AppTypography.bodyStrong),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          ),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(AppColors.textPrimary),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return AppColors.selected;
            if (states.contains(WidgetState.hovered)) return AppColors.hover;
            return Colors.transparent;
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return const BorderSide(color: AppColors.borderStrong);
            }
            return const BorderSide(color: AppColors.border);
          }),
          textStyle: const WidgetStatePropertyAll(AppTypography.bodyStrong),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          ),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(AppColors.accent),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return AppColors.accentSubtle;
            }
            return Colors.transparent;
          }),
          textStyle: const WidgetStatePropertyAll(AppTypography.bodyStrong),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.raised,
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        // A focused field is the one place the accent appears as an outline;
        // 1.5px rather than 1px so focus survives with hue stripped out.
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: AppTypography.body.copyWith(color: AppColors.textTertiary),
        labelStyle: AppTypography.label,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      iconTheme: const IconThemeData(
        color: AppColors.textSecondary,
        size: AppIconSize.md,
      ),

      listTileTheme: const ListTileThemeData(
        textColor: AppColors.textPrimary,
        iconColor: AppColors.textSecondary,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.panel,
        elevation: 0,
        titleTextStyle: AppTypography.title,
        contentTextStyle: AppTypography.body,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.raised,
        contentTextStyle: AppTypography.body,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: const BorderSide(color: AppColors.border),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.panel,
        elevation: 0,
        textStyle: AppTypography.body,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          color: AppColors.raised,
          borderRadius: AppRadius.smAll,
          border: Border.all(color: AppColors.border),
        ),
        textStyle: AppTypography.label.copyWith(color: AppColors.textPrimary),
      ),

      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(8),
        radius: const Radius.circular(AppRadius.sm),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return AppColors.borderStrong;
          }
          return AppColors.border;
        }),
      ),

      textTheme: const TextTheme(
        titleLarge: AppTypography.display,
        titleMedium: AppTypography.title,
        bodyLarge: AppTypography.body,
        bodyMedium: AppTypography.body,
        bodySmall: AppTypography.secondary,
        labelLarge: AppTypography.bodyStrong,
        labelMedium: AppTypography.label,
        labelSmall: AppTypography.caption,
      ),
    );
  }
}
