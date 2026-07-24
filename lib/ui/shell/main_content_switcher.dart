import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/feature_visibility_provider.dart';
import '../screens/timesheet_screen.dart';
import '../tools/certificate_generator_tool.dart';
import '../tools/json_formatter_tool.dart';
import '../tools/text_diff_tool.dart';
import '../tools/timestamp_tool.dart';
import '../widgets/log_console.dart';
import '../widgets/simulator_panel.dart';
import 'app_destination.dart';
import 'status_banner.dart';

class MainContentSwitcher extends StatelessWidget {
  final int selectedIndex;
  final List<LogEntry> logs;
  final bool isLogExpanded;
  final VoidCallback onToggleLog;
  final VoidCallback onClearLog;

  const MainContentSwitcher({
    super.key,
    required this.selectedIndex,
    required this.logs,
    required this.isLogExpanded,
    required this.onToggleLog,
    required this.onClearLog,
  });

  @override
  Widget build(BuildContext context) {
    final features = context.watch<FeatureVisibilityProvider>();
    final destinations = visibleAppDestinations(features);
    final children = destinations.map((destination) {
      return switch (destination) {
        AppDestination.simulator => Column(
            children: [
              Expanded(
                child: SimulatorPanel(
                  logs: logs,
                  isLogExpanded: isLogExpanded,
                  onToggleLog: onToggleLog,
                  onClearLog: onClearLog,
                ),
              ),
              const StatusBanner(),
            ],
          ),
        AppDestination.timestamp => const TimestampTool(),
        AppDestination.json => const JsonFormatterTool(),
        AppDestination.certificates => const CertificateGeneratorTool(),
        AppDestination.textDiff => const TextDiffTool(),
        AppDestination.timesheet => const TimesheetScreen(),
      };
    }).toList(growable: false);

    final safeIndex = selectedIndex < children.length ? selectedIndex : 0;

    return IndexedStack(
      index: safeIndex,
      children: children,
    );
  }
}
