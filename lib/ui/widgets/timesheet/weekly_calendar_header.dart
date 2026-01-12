import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/timesheet_provider.dart';

class WeeklyCalendarHeader extends StatelessWidget {
  const WeeklyCalendarHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TimesheetProvider>(context);
    final selectedDate = provider.selectedDate;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();

    // Calculate Range (Fixed past 10 days from today)
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final startDate = todayMidnight.subtract(const Duration(days: 9));
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(10, (index) {
            final day = startDate.add(Duration(days: index));
            final isSelected = isSameDay(day, selectedDate);
            final isToday = isSameDay(day, now);
            
            final key = DateTime(day.year, day.month, day.day);
            final hours = provider.weekDailyTotals[key] ?? 0.0;
            final hasLogs = hours > 0;
  
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => provider.selectDate(day),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 50,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? theme.colorScheme.primaryContainer : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday && !isSelected 
                      ? Border.all(color: theme.colorScheme.primary) 
                      : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat.E(locale).format(day),
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected 
                            ? theme.colorScheme.onPrimaryContainer 
                            : theme.colorScheme.onSurfaceVariant,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        day.day.toString(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected 
                            ? theme.colorScheme.onPrimaryContainer 
                            : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (hasLogs)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected 
                               ? theme.colorScheme.primary 
                               : theme.colorScheme.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${hours == hours.toInt() ? hours.toInt() : hours.toStringAsFixed(1)}h',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isSelected 
                                    ? theme.colorScheme.onPrimary 
                                    : theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (hours > 8)
                                Padding(
                                  padding: const EdgeInsets.only(left: 2),
                                  child: Text(
                                    "+",
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: isSelected 
                                        ? theme.colorScheme.onPrimary 
                                        : Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )
                      else
                        const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
