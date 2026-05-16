import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../viewmodels/timesheet_provider.dart';
import 'settings_menu.dart';

class AppNavigationRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback? onTimesheetDisabled;

  const AppNavigationRail({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.onTimesheetDisabled,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isTimesheetVisible = context.watch<TimesheetProvider>().isEnabled;
    final theme = Theme.of(context);

    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      minWidth: 88.0,
      groupAlignment: -0.78,
      labelType: NavigationRailLabelType.all,
      useIndicator: true,
      indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.10),
      indicatorShape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      selectedIconTheme: IconThemeData(
        color: theme.colorScheme.primary,
        size: 24,
      ),
      unselectedIconTheme: IconThemeData(
        color: theme.colorScheme.onSurfaceVariant,
        size: 24,
      ),
      selectedLabelTextStyle: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w800,
      ),
      unselectedLabelTextStyle: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
      destinations: <NavigationRailDestination>[
        NavigationRailDestination(
          icon: const Icon(Icons.settings_input_component),
          selectedIcon: const Icon(Icons.tune),
          label: Text(l10n.navSimulator),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.access_time),
          selectedIcon: const Icon(Icons.access_time_filled),
          label: Text(l10n.navTimestamp),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.code),
          selectedIcon: const Icon(Icons.data_object),
          label: Text(l10n.navJson),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.workspace_premium_outlined),
          selectedIcon: const Icon(Icons.verified_user),
          label: Text(l10n.navCertificates),
        ),
        if (isTimesheetVisible)
          NavigationRailDestination(
            icon: const Icon(Icons.calendar_month),
            selectedIcon: const Icon(Icons.calendar_month),
            label: Text(l10n.toolTimesheet),
          ),
      ],
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: SettingsMenu(onTimesheetDisabled: onTimesheetDisabled),
          ),
        ),
      ),
    );
  }
}
