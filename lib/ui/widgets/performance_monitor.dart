import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../utils/statistics_collector.dart';
import '../lab/lab.dart';

/// Live performance dashboard, rebuilt on the Lab design system.
///
/// Reads [StatisticsCollector] only — no business logic lives here. Every
/// number shown is backed by a real field on the collector; metrics without
/// a real data source (e.g. socket queue depth) are intentionally omitted
/// rather than faked.
class PerformanceMonitor extends StatelessWidget {
  const PerformanceMonitor({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = LabTokens.of(context);

    return Consumer<StatisticsCollector>(
      builder: (context, stats, child) {
        final snapshot = stats.getSnapshot();
        final successRate =
            double.tryParse('${snapshot['successRate']}') ?? 0.0;

        return Padding(
          padding: EdgeInsets.all(tokens.sLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // KPI row — five tiles, wraps on narrow widths so it never
              // overflows the collapsible monitor panel.
              Wrap(
                spacing: tokens.sMd,
                runSpacing: tokens.sMd,
                children: [
                  _kpi(context, l10n.dashboardTPS,
                      stats.currentTps.toStringAsFixed(1), '/s'),
                  _kpi(context, l10n.dashboardBandwidth,
                      stats.currentBandwidth.toStringAsFixed(1), 'KB/s'),
                  _kpi(context, l10n.dashboardLatency,
                      stats.currentLatency.toStringAsFixed(0), 'ms'),
                  _kpi(context, l10n.statSuccess, '${stats.successCount}',
                      null, tokens.ok),
                  _kpi(context, l10n.statFailed, '${stats.failureCount}', null,
                      stats.failureCount > 0
                          ? Theme.of(context).colorScheme.error
                          : null),
                ],
              ),
              SizedBox(height: tokens.sLg),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Throughput + latency history as bar series.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: LabSection(
                              title: l10n.chartTitleThroughput,
                              child: _bars(context, stats.tpsHistory,
                                  Theme.of(context).colorScheme.primary),
                            ),
                          ),
                          SizedBox(width: tokens.sLg),
                          Expanded(
                            child: LabSection(
                              title: l10n.chartTitleLatency,
                              child: _bars(
                                  context, stats.latencyHistory, tokens.warn),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: tokens.sLg),
                      // Donuts + resource meters.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: LabSection(
                              title: l10n.statistics,
                              child: Center(
                                child: LabDonut(
                                  pct: successRate,
                                  color: tokens.ok,
                                  label: l10n.perfSuccessRate,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: tokens.sLg),
                          Expanded(
                            child: LabSection(
                              title: l10n.perfResources,
                              child: Column(
                                children: [
                                  LabMeter(
                                    label: l10n.memoryUsage,
                                    value:
                                        '${(stats.memoryUsage / (1024 * 1024)).toStringAsFixed(0)} MB',
                                    // No hard memory ceiling is exposed; show a
                                    // soft 512 MB reference scale for the bar.
                                    fraction:
                                        stats.memoryUsage / (512 * 1024 * 1024),
                                    color: tokens.info,
                                  ),
                                  SizedBox(height: tokens.sMd),
                                  LabMeter(
                                    label: l10n.perfOnline,
                                    value:
                                        '${stats.onlineDevices}/${stats.totalDevices}',
                                    fraction: stats.totalDevices == 0
                                        ? 0
                                        : stats.onlineDevices /
                                            stats.totalDevices,
                                    color: tokens.ok,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _kpi(BuildContext context, String label, String value, String? unit,
      [Color? valueColor]) {
    // Fixed-ish width so five tiles tile neatly and wrap predictably.
    return SizedBox(
      width: 150,
      child: LabStatTile(
        label: label,
        value: value,
        unit: unit,
        valueColor: valueColor,
      ),
    );
  }

  Widget _bars(BuildContext context, List<Map<String, double>> history,
      Color color) {
    final values = history.map((e) => e['value'] ?? 0.0).toList();
    if (values.length < 2) {
      final l10n = AppLocalizations.of(context)!;
      return SizedBox(
        height: 60,
        child: Center(
          child: Text(
            l10n.perfWaitingData,
            style: TextStyle(color: LabTokens.of(context).faint),
          ),
        ),
      );
    }
    var peak = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[peak]) peak = i;
    }
    return LabBars(values: values, color: color, peakIndex: peak, height: 60);
  }
}
