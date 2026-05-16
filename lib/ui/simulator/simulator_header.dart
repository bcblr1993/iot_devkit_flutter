import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/profile_service.dart';
import '../lab/lab.dart';

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
        if (currentProfileId != null)
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
    );
  }

  Future<String?> _profileName(String profileId) async {
    final profiles = await ProfileService().loadProfiles();
    final index = profiles.indexWhere((profile) => profile.id == profileId);
    return index == -1 ? null : profiles[index].name;
  }
}
