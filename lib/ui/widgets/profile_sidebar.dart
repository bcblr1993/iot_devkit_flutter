import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/mqtt_view_model.dart';
import '../../services/profile_service.dart';
import '../../models/profile_metadata.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../utils/app_dialog_helper.dart';

class ProfileSidebar extends StatefulWidget {
  final bool isVisible;
  final VoidCallback onClose;

  const ProfileSidebar({
    super.key,
    required this.isVisible,
    required this.onClose,
  });

  @override
  State<ProfileSidebar> createState() => _ProfileSidebarState();
}

class _ProfileSidebarState extends State<ProfileSidebar> {
  final ProfileService _service = ProfileService();
  List<ProfileMetadata> _profiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() => _isLoading = true);
    final list = await _service.loadProfiles();
    // Sort by last modified desc
    list.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    if (mounted) {
      setState(() {
        _profiles = list;
        _isLoading = false;
      });
    }
  }

  void _handleCreate() {
    final l10n = AppLocalizations.of(context)!;
    AppDialogHelper.showTextFieldDialog(
      context: context,
      title: l10n.newProfile ?? 'New Profile',
      hintText: l10n.profileName ?? 'Profile Name',
      confirmText: l10n.confirm,
      cancelText: l10n.cancel,
      onConfirm: (name) async {
        if (name.isNotEmpty) {
          final vm = Provider.of<MqttViewModel>(context, listen: false);
          await vm.createNewProfile(name);
          _loadProfiles();
        }
      },
    );
  }

  void _handleDelete(String id) {
    final l10n = AppLocalizations.of(context)!;
    AppDialogHelper.showConfirm(
      context: context,
      title: l10n.deleteProfile ?? 'Delete Profile',
      message: l10n.deleteConfirm ?? 'Are you sure?',
      isDangerous: true,
    ).then((confirm) async {
       if (confirm == true) {
        final vm = Provider.of<MqttViewModel>(context, listen: false);
        // If deleting current, clear it
        if (vm.currentProfileId == id) {
          vm.clearCurrentProfile();
        }
        await _service.deleteProfile(id);
        _loadProfiles();
       }
    });
  }

  void _handleRename(ProfileMetadata profile) {
    final l10n = AppLocalizations.of(context)!;
    AppDialogHelper.showTextFieldDialog(
      context: context,
      title: l10n.renameProfile ?? 'Rename Profile',
      initialValue: profile.name,
      confirmText: l10n.confirm,
      cancelText: l10n.cancel,
      onConfirm: (newName) async {
        if (newName.isNotEmpty) {
           // We have to load config, verify it exists, and save as new name with SAME ID
           final config = await _service.loadProfileConfig(profile.id);
           if (config != null) {
             await _service.saveProfile(newName, config, id: profile.id);
             _loadProfiles();
             
             // If active, update view model might be needed if it cached name? 
             // Currently ViewModel loads by ID, so name is just metadata. 
             // But if we show name in title bar, we might need to refresh VM.
             final vm = Provider.of<MqttViewModel>(context, listen: false);
             if (vm.currentProfileId == profile.id) {
               vm.notifyListeners(); // Trigger rebuild
             }
           }
        }
      },
    );
  }

  void _handleSelect(String id) async {
    final vm = Provider.of<MqttViewModel>(context, listen: false);
    // Add loading indicator?
    await vm.loadProfile(id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final vm = Provider.of<MqttViewModel>(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: widget.isVisible ? 240 : 0,
      child: Material(
        color: theme.colorScheme.surface, // Or transparent if glass
        elevation: 1, // Slight separator
        child: widget.isVisible ? Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.profiles ?? 'Profiles', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: l10n.newProfile ?? 'New Profile',
                    onPressed: _handleCreate,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            // List
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _profiles.isEmpty
                  ? Center(child: Text(l10n.noProfiles ?? 'No Profiles', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)))
                  : ListView.builder(
                      itemCount: _profiles.length,
                      itemBuilder: (context, index) {
                        final p = _profiles[index];
                        final isActive = vm.currentProfileId == p.id;
                        
                        return ListTile(
                          title: Text(p.name, style: TextStyle(
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            color: isActive ? theme.colorScheme.primary : null,
                          )),
                          subtitle: Text(
                             p.lastModified.toString().split('.')[0], // Simple date trim
                             style: TextStyle(fontSize: 10, color: theme.colorScheme.outline),
                          ),
                          selected: isActive,
                          selectedTileColor: theme.colorScheme.primaryContainer.withOpacity(0.2),
                          onTap: () => _handleSelect(p.id),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 16),
                            onSelected: (action) {
                              if (action == 'rename') _handleRename(p);
                              if (action == 'delete') _handleDelete(p.id);
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(value: 'rename', child: Text(l10n.rename ?? 'Rename')),
                              PopupMenuItem(value: 'delete', child: Text(l10n.delete ?? 'Delete', style: const TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ) : null,
      ),
    );
  }
}
