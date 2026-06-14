import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/mqtt_view_model.dart';
import '../../services/profile_service.dart';
import '../../models/profile_metadata.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../utils/app_dialog_helper.dart';
import '../lab/lab.dart';

/// Profile manager rail — Lab-styled list of saved simulation profiles with
/// switch / duplicate / rename / delete and a name filter.
///
/// All persistence goes through [ProfileService] / [MqttViewModel]; this
/// widget owns presentation only.
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
  final TextEditingController _searchController = TextEditingController();
  List<ProfileMetadata> _profiles = [];
  String _query = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final vm = Provider.of<MqttViewModel>(context, listen: false);
    AppDialogHelper.showTextFieldDialog(
      context: context,
      title: l10n.newProfile,
      hintText: l10n.profileName,
      confirmText: l10n.confirm,
      cancelText: l10n.cancel,
      onConfirm: (name) async {
        if (name.isNotEmpty) {
          await vm.createNewProfile(name);
          _loadProfiles();
        }
      },
    );
  }

  void _handleDelete(String id) {
    final l10n = AppLocalizations.of(context)!;
    final vm = Provider.of<MqttViewModel>(context, listen: false);
    showLabConfirm(
      context,
      title: l10n.deleteProfile,
      body: l10n.deleteConfirm,
      destructive: true,
      primaryLabel: l10n.confirm,
      secondaryLabel: l10n.cancel,
    ).then((confirm) async {
      if (confirm) {
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
    final vm = Provider.of<MqttViewModel>(context, listen: false);
    AppDialogHelper.showTextFieldDialog(
      context: context,
      title: l10n.renameProfile,
      initialValue: profile.name,
      confirmText: l10n.confirm,
      cancelText: l10n.cancel,
      onConfirm: (newName) async {
        if (newName.isNotEmpty) {
          // Persist under the SAME id so it's a rename, not a new profile.
          final config = await _service.loadProfileConfig(profile.id);
          if (config != null) {
            await _service.saveProfile(newName, config, id: profile.id);
            _loadProfiles();
            if (vm.currentProfileId == profile.id) {
              // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
              vm.notifyListeners(); // Refresh the title-bar profile chip.
            }
          }
        }
      },
    );
  }

  /// Clone a profile's config under a new id (and a "(Duplicate)" name).
  Future<void> _handleDuplicate(ProfileMetadata profile) async {
    final l10n = AppLocalizations.of(context)!;
    final config = await _service.loadProfileConfig(profile.id);
    if (config == null) return;
    await _service.saveProfile('${profile.name} (${l10n.duplicate})', config);
    _loadProfiles();
  }

  void _handleSelect(String id) async {
    final vm = Provider.of<MqttViewModel>(context, listen: false);
    await vm.loadProfile(id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tokens = LabTokens.of(context);
    final vm = Provider.of<MqttViewModel>(context);

    final visible = _profiles
        .where((p) =>
            _query.isEmpty || p.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: widget.isVisible ? 240 : 0,
      child: Material(
        color: scheme.surfaceContainerLowest,
        child: !widget.isVisible
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        tokens.sLg, tokens.sLg, tokens.sLg, tokens.sMd),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.profiles.toUpperCase(),
                          style: text.titleSmall?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                        LabIconButton(
                          icon: Icons.add,
                          size: LabButtonSize.sm,
                          tooltip: l10n.newProfile,
                          onPressed: _handleCreate,
                        ),
                      ],
                    ),
                  ),
                  // Search
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: tokens.sLg),
                    child: LabField(
                      controller: _searchController,
                      hintText: l10n.searchProfiles,
                      mono: false,
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  SizedBox(height: tokens.sMd),
                  Divider(height: 1, color: scheme.outlineVariant),
                  // List
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : visible.isEmpty
                            ? Center(
                                child: Text(
                                  l10n.noProfiles,
                                  style: TextStyle(color: tokens.faint),
                                ),
                              )
                            : ListView.separated(
                                padding: EdgeInsets.all(tokens.sMd),
                                itemCount: visible.length,
                                separatorBuilder: (_, __) =>
                                    SizedBox(height: tokens.sSm),
                                itemBuilder: (context, index) {
                                  final p = visible[index];
                                  return _ProfileCard(
                                    profile: p,
                                    active: vm.currentProfileId == p.id,
                                    onSelect: () => _handleSelect(p.id),
                                    onDuplicate: () => _handleDuplicate(p),
                                    onRename: () => _handleRename(p),
                                    onDelete: () => _handleDelete(p.id),
                                  );
                                },
                              ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final ProfileMetadata profile;
  final bool active;
  final VoidCallback onSelect;
  final VoidCallback onDuplicate;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _ProfileCard({
    required this.profile,
    required this.active,
    required this.onSelect,
    required this.onDuplicate,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tokens = LabTokens.of(context);

    final initial = profile.name.trim().isEmpty
        ? '?'
        : profile.name.trim()[0].toUpperCase();

    return Material(
      color: active
          ? Color.alphaBlend(
              scheme.primary.withValues(alpha: 0.08), scheme.surface)
          : scheme.surface,
      borderRadius: BorderRadius.circular(tokens.rLg),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(tokens.rLg),
        child: Container(
          padding: EdgeInsets.all(tokens.sMd),
          decoration: BoxDecoration(
            border: Border.all(
                color: active ? scheme.primary : scheme.outlineVariant),
            borderRadius: BorderRadius.circular(tokens.rLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar square
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                          scheme.primary.withValues(alpha: 0.14),
                          scheme.surface),
                      border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(tokens.rMd),
                    ),
                    child: Text(
                      initial,
                      style: text.labelLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(width: tokens.sMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                            color:
                                active ? scheme.primary : scheme.onSurface,
                          ),
                        ),
                        Text(
                          profile.lastModified.toString().split('.').first,
                          style: text.labelSmall?.copyWith(color: tokens.faint),
                        ),
                      ],
                    ),
                  ),
                  if (active) ...[
                    SizedBox(width: tokens.sXs),
                    LabPill(
                        label: l10n.profileActive,
                        color: tokens.ok,
                        small: true),
                  ],
                ],
              ),
              SizedBox(height: tokens.sSm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  LabIconButton(
                    icon: Icons.copy_outlined,
                    size: LabButtonSize.sm,
                    tooltip: l10n.duplicate,
                    onPressed: onDuplicate,
                  ),
                  SizedBox(width: tokens.sXs),
                  LabIconButton(
                    icon: Icons.edit_outlined,
                    size: LabButtonSize.sm,
                    tooltip: l10n.rename,
                    onPressed: onRename,
                  ),
                  SizedBox(width: tokens.sXs),
                  LabIconButton(
                    icon: Icons.delete_outline,
                    size: LabButtonSize.sm,
                    tooltip: l10n.delete,
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
