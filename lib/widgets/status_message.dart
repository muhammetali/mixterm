import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';

/// What a status message is telling the user.
enum StatusKind { success, error, warning, info }

extension _StatusStyle on StatusKind {
  Color get color => switch (this) {
    StatusKind.success => AppColors.success,
    StatusKind.error => AppColors.danger,
    StatusKind.warning => AppColors.warning,
    StatusKind.info => AppColors.accent,
  };

  IconData get icon => switch (this) {
    StatusKind.success => Icons.check_circle_outline,
    StatusKind.error => Icons.error_outline,
    StatusKind.warning => Icons.warning_amber_outlined,
    StatusKind.info => Icons.info_outline,
  };

  /// Failures need long enough to actually be read, and often carry a server
  /// error verbatim. Confirmations do not — the thing the user asked for
  /// visibly happened, so the message is a receipt rather than information.
  Duration get duration => switch (this) {
    StatusKind.success => const Duration(seconds: 2),
    StatusKind.info => const Duration(seconds: 3),
    StatusKind.warning => const Duration(seconds: 4),
    StatusKind.error => const Duration(seconds: 6),
  };
}

/// The widest a message is allowed to get. A message is as long as its text,
/// not as wide as the window.
const double _maxWidth = 460;

/// Builds the message itself.
///
/// Every one of these used to be constructed at its call site, each passing
/// its own `backgroundColor`, which overrode the theme and filled the bar
/// edge to edge with a fully saturated semantic colour. On a wide window
/// that made a two-word confirmation the single loudest object on screen —
/// louder than the primary action, and covering the content the user had
/// just asked to see.
///
/// So the fill is gone. The surface is the same one every other raised
/// object uses, and the meaning is carried by a leading bar and an icon:
/// two channels that survive with hue stripped out, where a coloured
/// background was only one.
SnackBar _buildStatusSnackBar(String message, StatusKind kind, double width) {
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    elevation: 0,
    padding: EdgeInsets.zero,
    duration: kind.duration,
    width: width,
    content: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.raised,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.popover,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.mdAll,
        child: IntrinsicHeight(
          child: Row(
            children: [
              // The semantic colour appears here, as an edge, rather than as
              // the whole surface.
              Container(width: 3, color: kind.color),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                ),
                child: Icon(kind.icon, size: AppIconSize.md, color: kind.color),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: AppSpacing.md,
                    top: AppSpacing.md,
                    bottom: AppSpacing.md,
                  ),
                  child: Text(message, style: AppTypography.body),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Shows a transient status message.
void showStatusMessage(
  BuildContext context,
  String message, {
  StatusKind kind = StatusKind.info,
}) {
  // Never wider than the window, which matters when the sidebar is expanded
  // on a small display.
  final width = math.min(
    _maxWidth,
    MediaQuery.sizeOf(context).width - AppSpacing.xxl * 2,
  );
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(_buildStatusSnackBar(message, kind, width));
}

/// [showStatusMessage] for callers that captured a [ScaffoldMessengerState]
/// before an `await` — the correct pattern when the widget may be gone by
/// the time there is something to report.
void showStatusMessageOn(
  ScaffoldMessengerState messenger,
  String message, {
  StatusKind kind = StatusKind.info,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(_buildStatusSnackBar(message, kind, _maxWidth));
}
