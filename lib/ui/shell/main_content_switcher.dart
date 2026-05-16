import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/timesheet_provider.dart';
import '../screens/timesheet_screen.dart';
import '../tools/certificate_generator_tool.dart';
import '../tools/json_formatter_tool.dart';
import '../tools/timestamp_tool.dart';
import '../widgets/log_console.dart';
import '../widgets/simulator_panel.dart';
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
    final isTimesheetVisible = context.watch<TimesheetProvider>().isEnabled;
    final children = <Widget>[
      Column(
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
      const TimestampTool(),
      const JsonFormatterTool(),
      const CertificateGeneratorTool(),
      if (isTimesheetVisible) const TimesheetScreen(),
    ];

    final safeIndex = selectedIndex < children.length ? selectedIndex : 0;

    return IndexedStack(
      index: safeIndex,
      children: children,
    );
  }
}
