import 'package:flutter/material.dart';
import '../utils/theme.dart';

class SplitPane extends StatefulWidget {
  final Widget leftPane;
  final Widget rightPane;
  final double initialPosition;
  final ValueChanged<double>? onPositionChanged;
  final double minPaneWidth;

  const SplitPane({
    super.key,
    required this.leftPane,
    required this.rightPane,
    this.initialPosition = 0.5,
    this.onPositionChanged,
    this.minPaneWidth = 200,
  });

  @override
  State<SplitPane> createState() => _SplitPaneState();
}

class _SplitPaneState extends State<SplitPane> {
  late double _position;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
  }

  @override
  void didUpdateWidget(SplitPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPosition != widget.initialPosition) {
      _position = widget.initialPosition;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final dividerWidth = 8.0;
        final availableWidth = totalWidth - dividerWidth;

        final leftWidth = (availableWidth * _position)
            .clamp(widget.minPaneWidth, availableWidth - widget.minPaneWidth);
        final rightWidth = availableWidth - leftWidth;

        return Row(
          children: [
            SizedBox(
              width: leftWidth,
              child: widget.leftPane,
            ),
            _buildDivider(totalWidth),
            SizedBox(
              width: rightWidth,
              child: widget.rightPane,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDivider(double totalWidth) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onHorizontalDragStart: (_) {
          setState(() => _isDragging = true);
        },
        onHorizontalDragUpdate: (details) {
          setState(() {
            final delta = details.delta.dx / totalWidth;
            _position = (_position + delta).clamp(0.2, 0.8);
            widget.onPositionChanged?.call(_position);
          });
        },
        onHorizontalDragEnd: (_) {
          setState(() => _isDragging = false);
        },
        onDoubleTap: () {
          setState(() {
            _position = 0.5;
            widget.onPositionChanged?.call(_position);
          });
        },
        child: Container(
          width: 8,
          decoration: BoxDecoration(
            color: _isDragging
                ? AppTheme.primaryColor.withValues(alpha: 0.3)
                : AppTheme.borderColor,
          ),
          child: Center(
            child: Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: _isDragging
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
