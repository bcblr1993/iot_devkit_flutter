import 'package:flutter/material.dart';

import '../styles/app_theme_effect.dart';
import '../widgets/log_console.dart';

class SimulatorLogDock extends StatelessWidget {
  static const double collapsedHeight = 54;

  final List<LogEntry> logs;
  final bool isExpanded;
  final bool isMaximized;
  final VoidCallback onToggle;
  final VoidCallback onClear;
  final VoidCallback onMaximize;
  final Widget? headerContent;
  final AppThemeEffect effect;

  const SimulatorLogDock({
    super.key,
    required this.logs,
    required this.isExpanded,
    required this.isMaximized,
    required this.onToggle,
    required this.onClear,
    required this.onMaximize,
    required this.effect,
    this.headerContent,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final expandedHeight = (screenHeight * 0.42).clamp(300.0, 520.0).toDouble();
    final height = isMaximized
        ? screenHeight
        : (isExpanded ? expandedHeight : collapsedHeight);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: effect.animationCurve,
      left: 0,
      right: 0,
      bottom: 0,
      height: height,
      child: Material(
        type: MaterialType.transparency,
        child: LogConsole(
          logs: logs,
          isExpanded: isExpanded,
          onToggle: onToggle,
          onClear: onClear,
          isMaximized: isMaximized,
          onMaximize: onMaximize,
          headerContent: headerContent,
        ),
      ),
    );
  }
}
