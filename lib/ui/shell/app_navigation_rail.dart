import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../viewmodels/timesheet_provider.dart';
import '../lab/lab.dart';
import 'settings_menu.dart';

/// Lab Console left rail (design system · simulator.jsx).
///
/// Fixed 80px column: stacked icon-box + label + mono F-key hint, with an
/// accent left-border + tint on the active item. Settings sits pinned at the
/// bottom. Public API is unchanged so HomeScreen wiring stays the same.
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
    final scheme = Theme.of(context).colorScheme;

    final items = <_RailEntry>[
      _RailEntry(Icons.settings_input_component, l10n.navSimulator, 'F1'),
      _RailEntry(Icons.access_time, l10n.navTimestamp, 'F2'),
      _RailEntry(Icons.code, l10n.navJson, 'F3'),
      _RailEntry(Icons.workspace_premium_outlined, l10n.navCertificates, 'F4'),
      if (isTimesheetVisible)
        _RailEntry(Icons.calendar_month, l10n.toolTimesheet, 'F5'),
    ];

    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++)
            _RailItem(
              key: ValueKey('rail_item_$i'),
              entry: items[i],
              active: i == selectedIndex,
              onTap: () => onDestinationSelected(i),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SettingsMenu(onTimesheetDisabled: onTimesheetDisabled),
          ),
        ],
      ),
    );
  }
}

class _RailEntry {
  final IconData icon;
  final String label;
  final String hint;
  const _RailEntry(this.icon, this.label, this.hint);
}

class _RailItem extends StatelessWidget {
  final _RailEntry entry;
  final bool active;
  final VoidCallback onTap;

  const _RailItem({
    super.key,
    required this.entry,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);
    final text = Theme.of(context).textTheme;

    final accent = scheme.primary;
    final boxBorder = active ? accent : scheme.outlineVariant;
    final boxBg = active
        ? Color.alphaBlend(accent.withValues(alpha: 0.12), scheme.surface)
        : scheme.surface;
    final iconColor = active ? accent : scheme.onSurfaceVariant;
    final labelColor = active ? scheme.onSurface : tokens.faint;

    return InkWell(
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        decoration: BoxDecoration(
          color: active
              ? Color.alphaBlend(accent.withValues(alpha: 0.08), scheme.surface)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: active ? accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: boxBg,
                border: Border.all(color: boxBorder),
                borderRadius: BorderRadius.circular(tokens.rMd),
              ),
              alignment: Alignment.center,
              child: Icon(entry.icon, size: 17, color: iconColor),
            ),
            const SizedBox(height: 4),
            Text(
              entry.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelMedium?.copyWith(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: labelColor,
              ),
            ),
            Text(
              entry.hint,
              style: TextStyle(
                fontFamily: tokens.monoFamily,
                fontSize: 9,
                color: tokens.faint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
