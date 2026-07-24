import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../services/mqtt_controller.dart';
import '../../services/status_registry.dart';
import '../../services/feature_visibility_provider.dart';
import '../widgets/log_console.dart';
import '../shell/app_navigation_rail.dart';
import '../shell/app_destination.dart';
import '../shell/main_content_switcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppDestination _selectedDestination = AppDestination.simulator;
  final List<LogEntry> _logs = [];
  bool _isLogExpanded = false;

  // Performance Optimization: Log Throttling
  final List<LogEntry> _logBuffer = [];
  Timer? _logThrottleTimer;

  @override
  void initState() {
    super.initState();
    // Hook up logging
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = Provider.of<MqttController>(context, listen: false);
      controller.onLog = (String message, String type, {String? tag}) {
        if (!mounted) return;

        // Check for critical errors to show in Status Banner
        if (type == 'error' && message.contains('Max reconnect attempts')) {
          Provider.of<StatusRegistry>(context, listen: false)
              .setStatus(message, Theme.of(context).colorScheme.error);
        }

        final now = DateTime.now();
        final timestamp =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

        // Add to buffer (Background operation, no setState)
        _logBuffer.add(LogEntry(message, type, timestamp, tag: tag));

        // Schedule batch update if not already running
        if (_logThrottleTimer == null || !_logThrottleTimer!.isActive) {
          _logThrottleTimer =
              Timer(const Duration(milliseconds: 300), _flushLogs);
        }
      };
    });
  }

  void _flushLogs() {
    if (!mounted || _logBuffer.isEmpty) return;

    setState(() {
      _logs.addAll(_logBuffer);
      _logBuffer.clear();

      // Limit logs to prevent memory issues
      if (_logs.length > 2000) {
        _logs.removeRange(0, _logs.length - 1500); // Keep last 1500
      }
    });
  }

  @override
  void dispose() {
    _logThrottleTimer?.cancel();
    super.dispose();
  }

  void _select(AppDestination destination) {
    final feature = destination.feature;
    if (feature != null &&
        !context.read<FeatureVisibilityProvider>().isEnabled(feature)) {
      return;
    }
    setState(() => _selectedDestination = destination);
  }

  @override
  Widget build(BuildContext context) {
    final features = context.watch<FeatureVisibilityProvider>();
    final destinations = visibleAppDestinations(features);
    final selectedIndex = destinations.indexOf(_selectedDestination);
    final safeSelectedIndex = selectedIndex < 0 ? 0 : selectedIndex;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.f1): () =>
            _select(AppDestination.simulator),
        const SingleActivator(LogicalKeyboardKey.f2): () =>
            _select(AppDestination.timestamp),
        const SingleActivator(LogicalKeyboardKey.f3): () =>
            _select(AppDestination.json),
        const SingleActivator(LogicalKeyboardKey.f4): () =>
            _select(AppDestination.certificates),
        const SingleActivator(LogicalKeyboardKey.f5): () =>
            _select(AppDestination.textDiff),
        const SingleActivator(LogicalKeyboardKey.f6): () =>
            _select(AppDestination.timesheet),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Row(
            children: [
              RepaintBoundary(
                child: AppNavigationRail(
                  selectedIndex: safeSelectedIndex,
                  onDestinationSelected: (int index) {
                    if (index < destinations.length) {
                      _select(destinations[index]);
                    }
                  },
                  onDestinationDisabled: (destination) {
                    if (_selectedDestination == destination) {
                      _select(AppDestination.simulator);
                    }
                  },
                ),
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(
                child: RepaintBoundary(
                  child: MainContentSwitcher(
                    selectedIndex: safeSelectedIndex,
                    logs: _logs,
                    isLogExpanded: _isLogExpanded,
                    onToggleLog: () {
                      setState(() {
                        _isLogExpanded = !_isLogExpanded;
                      });
                    },
                    onClearLog: () {
                      setState(() {
                        _logs.clear();
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
