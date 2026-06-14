import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/mqtt_controller.dart';
import '../../services/profile_service.dart';
import '../lab/lab.dart';

/// Map the controller's [SimulationRunState] onto the design-system
/// [LabConnectionState]. The two enums are name-for-name identical, so this
/// is a pure presentation adapter — no business logic lives here.
LabConnectionState _toLabState(SimulationRunState s) => switch (s) {
      SimulationRunState.idle => LabConnectionState.idle,
      SimulationRunState.starting => LabConnectionState.starting,
      SimulationRunState.connecting => LabConnectionState.connecting,
      SimulationRunState.running => LabConnectionState.running,
      SimulationRunState.reconnecting => LabConnectionState.reconnecting,
      SimulationRunState.partialRunning => LabConnectionState.partialRunning,
      SimulationRunState.stopping => LabConnectionState.stopping,
      SimulationRunState.failed => LabConnectionState.failed,
    };

class SimulatorHeader extends StatelessWidget {
  final bool isProfileSidebarVisible;
  final String? currentProfileId;
  final VoidCallback onToggleProfileSidebar;
  final VoidCallback onClearProfile;

  const SimulatorHeader({
    super.key,
    required this.isProfileSidebarVisible,
    required this.currentProfileId,
    required this.onToggleProfileSidebar,
    required this.onClearProfile,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Row(
      children: [
        LabIconButton(
          icon: isProfileSidebarVisible ? Icons.menu_open : Icons.menu,
          tooltip: l10n.profiles,
          active: isProfileSidebarVisible,
          onPressed: onToggleProfileSidebar,
        ),
        const SizedBox(width: 12),
        Icon(Icons.speed_outlined, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n.navSimulator,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Live connection state machine pill (idle → running → failed …).
        // Reads MqttController.runState; only rebuilds when the state flips.
        Builder(
          builder: (context) {
            final state = context.select<MqttController, SimulationRunState>(
              (c) => c.runState,
            );
            return LabStatePill(state: _toLabState(state));
          },
        ),
        if (currentProfileId != null) ...[
          const SizedBox(width: 12),
          Chip(
            label: FutureBuilder<String?>(
              future: _profileName(currentProfileId!),
              builder: (context, snapshot) {
                return Text(snapshot.data ?? l10n.profileName);
              },
            ),
            onDeleted: onClearProfile,
            deleteIcon: const Icon(Icons.close, size: 16),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ],
    );
  }

  Future<String?> _profileName(String profileId) async {
    final profiles = await ProfileService().loadProfiles();
    final index = profiles.indexWhere((profile) => profile.id == profileId);
    return index == -1 ? null : profiles[index].name;
  }
}
