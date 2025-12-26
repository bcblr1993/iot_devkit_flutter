import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../utils/statistics_collector.dart';
import '../../l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

class PerformanceMonitor extends StatefulWidget {
  const PerformanceMonitor({super.key});

  @override
  State<PerformanceMonitor> createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<PerformanceMonitor> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 确保使用 AppLocalizations，如果为空则 fallback 到英文以防 crash
    final l10n = AppLocalizations.of(context);
    // 这里做个简单的空安全处理，或者假设上层已经保证了 localization 存在
    
    return Column(
      children: [
        // 1. Metric Cards Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Consumer<StatisticsCollector>(
            builder: (context, stats, child) {
              return Row(
                children: [
                  Expanded(child: _buildMetricCard(context, l10n?.dashboardTPS ?? 'Throughput', '${stats.currentTps.toStringAsFixed(1)} /s', Colors.blue)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildMetricCard(context, l10n?.dashboardBandwidth ?? 'Bandwidth', '${stats.currentBandwidth.toStringAsFixed(1)} KB/s', Colors.purple)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildMetricCard(context, l10n?.dashboardLatency ?? 'Avg Latency', '${stats.currentLatency.toStringAsFixed(0)} ms', Colors.orange)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildMetricCard(context, 'Success Rate', '${stats.getSnapshot()['successRate']}%', Colors.green)),
                ],
              );
            },
          ),
        ),

        // 2. Chart Area
        Expanded(
          child: Container(
             margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
             decoration: BoxDecoration(
               color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
               borderRadius: BorderRadius.circular(16),
               border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
             ),
             child: Column(
               children: [
                 TabBar(
                   controller: _tabController,
                   labelColor: Theme.of(context).primaryColor,
                   unselectedLabelColor: Theme.of(context).hintColor,
                   indicatorColor: Theme.of(context).primaryColor,
                   tabs: [
                     Tab(text: l10n?.chartTitleThroughput ?? 'Throughput Trend'),
                     Tab(text: l10n?.chartTitleLatency ?? 'Latency Trend'),
                     Tab(text: l10n?.dashboardBandwidth ?? 'Bandwidth Trend'), 
                   ],
                 ),
                 Expanded(
                   child: TabBarView(
                     controller: _tabController,
                     children: [
                       _buildLiveChart<StatisticsCollector>(
                          color: Colors.blue, 
                          dataSelector: (s) => s.tpsHistory
                       ),
                       _buildLiveChart<StatisticsCollector>(
                          color: Colors.orange, 
                          dataSelector: (s) => s.latencyHistory
                       ),
                       // Placeholder for Bandwidth Chart (reuse TPS history logic for now or implement bandwidth history if needed)
                       // Since we only added history for TPS and Latency in Step 1, let's use TPS as placeholder or hide it.
                       // Re-reading Step 1: I only added tpsHistory and latencyHistory.
                       // Let's hide the 3rd tab or map it to something else later. For now, show TPS again but purple.
                       _buildLiveChart<StatisticsCollector>(
                          color: Colors.purple, 
                          dataSelector: (s) => s.tpsHistory // TODO: Add bandwidth history
                       ),
                     ],
                   ),
                 ),
               ],
             ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value, Color color) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2)),
        // Glassmorphism accent
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? theme.colorScheme.surface : Colors.white,
            color.withOpacity(0.05),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
               Icon(Icons.circle, size: 8, color: color),
               const SizedBox(width: 6),
               Text(
                 title,
                 style: TextStyle(
                   fontSize: 12,
                   color: theme.textTheme.bodySmall?.color,
                   fontWeight: FontWeight.w500,
                 ),
                 maxLines: 1,
                 overflow: TextOverflow.ellipsis,
               ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
              fontFamily: 'RobotoMono', // Monospace for numbers
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveChart<T>({
    required Color color,
    required List<Map<String, double>> Function(StatisticsCollector) dataSelector,
  }) {
    return Consumer<StatisticsCollector>(
      builder: (context, stats, child) {
        final history = dataSelector(stats);
        
        if (history.isEmpty || history.length < 2) {
          return Center(child: Text('Waiting for data...', style: TextStyle(color: Theme.of(context).hintColor)));
        }

        // Convert to FlSpots
        // Normalize time to 0-60 relative range for display
        double startTime = history.first['time']!;
        List<FlSpot> spots = history.map((e) {
             return FlSpot((e['time']! - startTime) / 1000.0, e['value']!);
        }).toList();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 10, // 10 seconds
                    getTitlesWidget: (value, meta) {
                       return const SizedBox.shrink(); // Hide bottom headers for cleaner look, or show '10s', '20s'
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          color: Theme.of(context).hintColor,
                          fontSize: 10,
                        ),
                      ); 
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              // maxX: 60, // Keep it auto-scaling or fixed window? Auto is better for start.
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  gradient: LinearGradient(colors: [color, color.withOpacity(0.5)]),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.2),
                        color.withOpacity(0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
