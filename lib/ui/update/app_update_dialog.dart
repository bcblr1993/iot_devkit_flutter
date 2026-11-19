import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/app_release_info.dart';
import '../../services/app_update_service.dart';
import '../../services/mqtt_controller.dart';
import '../../viewmodels/app_update_provider.dart';
import '../lab/lab.dart';

class AppUpdateInstallHelper {
  static Future<void> confirmAndInstall(
    BuildContext context,
    AppUpdateProvider provider,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final mqtt = context.read<MqttController?>();
    final isWindows = provider.currentPlatform == AppUpdatePlatform.windows;

    if (isWindows && mqtt != null && mqtt.isRunning) {
      final confirmed = await showLabConfirm(
        context,
        title: l10n.updateActiveSimulationTitle,
        body: l10n.updateActiveSimulationBody,
        primaryLabel: l10n.updateConfirmStopAndInstall,
        secondaryLabel: l10n.cancel,
        destructive: true,
      );
      if (!confirmed || !context.mounted) return;
    }

    final outcome = await provider.installUpdate(
      onBeforeExitApp: (isWindows && mqtt != null && mqtt.isRunning)
          ? () => mqtt.stop()
          : null,
    );

    if (!context.mounted || outcome == null) return;

    if (outcome == InstallActionOutcome.mountedDiskImage) {
      showLabToast(
        context,
        kind: LabStatus.ok,
        title: l10n.updateDialogTitle,
        message: l10n.updateMountedDmgToast,
      );
    } else if (outcome == InstallActionOutcome.openedArchiveDirectory) {
      showLabToast(
        context,
        kind: LabStatus.ok,
        title: l10n.updateDialogTitle,
        message: l10n.updateOpenedFolderToast,
      );
    }
  }
}

class AppUpdateDialog extends StatefulWidget {
  const AppUpdateDialog({super.key});

  static Future<void> show(
    BuildContext context, {
    bool checkIfIdle = true,
  }) async {
    final provider = context.read<AppUpdateProvider?>();
    if (provider == null) return;

    if (checkIfIdle &&
        (provider.phase == AppUpdatePhase.idle ||
            provider.phase == AppUpdatePhase.upToDate)) {
      // Trigger a fresh manual check without blocking dialog presentation.
      provider.checkForUpdates(manual: true);
    }

    await showDialog<void>(
      context: context,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.42),
      builder: (_) => const AppUpdateDialog(),
    );
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  late final TextEditingController _mirrorController;
  bool _settingsExpanded = false;

  @override
  void initState() {
    super.initState();
    final initialMirror = context.read<AppUpdateProvider?>()?.mirrorUrl ?? '';
    _mirrorController = TextEditingController(text: initialMirror);
    _settingsExpanded = initialMirror.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _mirrorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppUpdateProvider>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = LabTokens.of(context);

    final showSettings =
        _settingsExpanded || provider.phase == AppUpdatePhase.error;

    return Dialog(
      key: const ValueKey('app_update_dialog'),
      elevation: 0,
      backgroundColor: scheme.surface.withValues(alpha: 0),
      insetPadding: EdgeInsets.all(tokens.s2xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(tokens.rXl),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.22),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, provider, l10n, scheme, tokens),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(tokens.sXl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildVersionSummaryStrip(
                        context,
                        provider,
                        l10n,
                        scheme,
                        tokens,
                      ),
                      SizedBox(height: tokens.sLg),
                      _buildPhaseBody(context, provider, l10n, scheme, tokens),
                      SizedBox(height: tokens.sLg),
                      _buildSettingsSection(
                        context,
                        provider,
                        l10n,
                        scheme,
                        tokens,
                        showSettings,
                      ),
                    ],
                  ),
                ),
              ),
              _buildFooter(context, provider, l10n, scheme, tokens),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AppUpdateProvider provider,
    AppLocalizations l10n,
    ColorScheme scheme,
    LabTokens tokens,
  ) {
    final text = Theme.of(context).textTheme;
    final (pillLabel, pillColor) = _statusPillFor(provider, scheme, tokens);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.sXl,
        vertical: tokens.sLg,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(tokens.rMd),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.32)),
            ),
            child: Icon(
              Icons.system_update_alt_rounded,
              size: 16,
              color: scheme.primary,
            ),
          ),
          SizedBox(width: tokens.sLg),
          Expanded(
            child: Text(
              l10n.updateDialogTitle,
              style: text.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
          ),
          LabPill(label: pillLabel, color: pillColor, small: true),
          SizedBox(width: tokens.sMd),
          LabIconButton(
            icon: Icons.close,
            size: LabButtonSize.sm,
            tooltip: l10n.close,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  (String, Color) _statusPillFor(
    AppUpdateProvider provider,
    ColorScheme scheme,
    LabTokens tokens,
  ) {
    return switch (provider.phase) {
      AppUpdatePhase.checking => ('CHECKING', tokens.info),
      AppUpdatePhase.upToDate => ('LATEST', tokens.ok),
      AppUpdatePhase.available => (
          'NEW · v${provider.latestRelease?.version ?? ''}',
          scheme.primary,
        ),
      AppUpdatePhase.downloading => ('DOWNLOADING', tokens.info),
      AppUpdatePhase.readyToInstall ||
      AppUpdatePhase.installing =>
        ('READY', tokens.ok),
      AppUpdatePhase.error => ('ERROR', scheme.error),
      AppUpdatePhase.idle => ('IDLE', scheme.onSurfaceVariant),
    };
  }

  Widget _buildVersionSummaryStrip(
    BuildContext context,
    AppUpdateProvider provider,
    AppLocalizations l10n,
    ColorScheme scheme,
    LabTokens tokens,
  ) {
    final text = Theme.of(context).textTheme;
    final currentDisplay = provider.normalizedCurrentVersion.isEmpty
        ? '-'
        : 'v${provider.normalizedCurrentVersion}';
    final latest = provider.latestRelease;
    final latestDisplay = latest == null
        ? '-'
        : (latest.publishedAt != null
            ? 'v${latest.version} · ${latest.publishedAt}'
            : 'v${latest.version}');

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.sLg,
        vertical: tokens.sMd,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(tokens.rLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: _VersionColumn(
              label: l10n.updateCurrentVersionLabel,
              value: currentDisplay,
              valueColor: scheme.onSurface,
              monoFamily: tokens.monoFamily,
              textTheme: text,
              labelColor: scheme.onSurfaceVariant,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.sMd),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: provider.hasUpdate ? scheme.primary : tokens.faint,
            ),
          ),
          Expanded(
            child: _VersionColumn(
              label: l10n.updateLatestVersionLabel,
              value: latestDisplay,
              valueColor:
                  provider.hasUpdate ? scheme.primary : scheme.onSurface,
              monoFamily: tokens.monoFamily,
              textTheme: text,
              labelColor: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseBody(
    BuildContext context,
    AppUpdateProvider provider,
    AppLocalizations l10n,
    ColorScheme scheme,
    LabTokens tokens,
  ) {
    final text = Theme.of(context).textTheme;

    switch (provider.phase) {
      case AppUpdatePhase.idle:
      case AppUpdatePhase.checking:
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.sLg,
            vertical: tokens.sXl,
          ),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(tokens.rLg),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.primary,
                ),
              ),
              SizedBox(width: tokens.sLg),
              Expanded(
                child: Text(
                  l10n.updateChecking,
                  style: text.bodySmall?.copyWith(color: tokens.body),
                ),
              ),
            ],
          ),
        );

      case AppUpdatePhase.upToDate:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabInlineAlert(
              kind: LabStatus.ok,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.updateUpToDateTitle,
                    style: text.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  SizedBox(height: tokens.sXxs),
                  Text(
                    l10n.updateUpToDateSubtitle(
                      provider.normalizedCurrentVersion.isEmpty
                          ? '-'
                          : provider.normalizedCurrentVersion,
                    ),
                  ),
                ],
              ),
            ),
            if (provider.lastCheckedAt != null) ...[
              SizedBox(height: tokens.sSm),
              Text(
                l10n.updateLastChecked(
                  DateFormat('yyyy-MM-dd HH:mm').format(provider.lastCheckedAt!),
                ),
                style: text.labelSmall?.copyWith(
                  fontFamily: tokens.monoFamily,
                  color: tokens.faint,
                ),
              ),
            ],
          ],
        );

      case AppUpdatePhase.available:
      case AppUpdatePhase.downloading:
      case AppUpdatePhase.readyToInstall:
      case AppUpdatePhase.installing:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildReleaseNotesSection(context, provider, l10n, scheme, tokens),
            if (provider.phase == AppUpdatePhase.downloading) ...[
              SizedBox(height: tokens.sLg),
              _buildDownloadProgressBox(context, provider, l10n, scheme, tokens),
            ],
            if (provider.phase == AppUpdatePhase.readyToInstall ||
                provider.phase == AppUpdatePhase.installing) ...[
              SizedBox(height: tokens.sLg),
              LabInlineAlert(
                kind: LabStatus.ok,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.updateReadyTitle,
                      style: text.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    SizedBox(height: tokens.sXxs),
                    Text(_platformReadyHint(provider.currentPlatform, l10n)),
                  ],
                ),
              ),
            ],
          ],
        );

      case AppUpdatePhase.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (provider.latestRelease != null && provider.hasUpdate) ...[
              _buildReleaseNotesSection(context, provider, l10n, scheme, tokens),
              SizedBox(height: tokens.sLg),
            ],
            LabInlineAlert(
              kind: LabStatus.error,
              child: Text(_localizedError(provider.errorKind, l10n)),
            ),
          ],
        );
    }
  }

  Widget _buildReleaseNotesSection(
    BuildContext context,
    AppUpdateProvider provider,
    AppLocalizations l10n,
    ColorScheme scheme,
    LabTokens tokens,
  ) {
    final text = Theme.of(context).textTheme;
    final release = provider.latestRelease;
    final asset = provider.currentPlatformAsset;
    final rawNotes = release?.releaseNotes.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.updateReleaseNotesTitle.toUpperCase(),
                style: text.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (asset?.hasChecksum == true)
              LabPill(
                label: l10n.updateSha256Verified,
                color: tokens.ok,
                small: true,
              ),
          ],
        ),
        SizedBox(height: tokens.sSm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 196),
          child: Container(
            padding: EdgeInsets.all(tokens.sLg),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(tokens.rLg),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: SingleChildScrollView(
              child: rawNotes.isEmpty
                  ? Text(
                      l10n.updateNoReleaseNotes,
                      style: text.bodySmall?.copyWith(color: tokens.faint),
                    )
                  : _ReleaseNotesBody(rawNotes: rawNotes),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadProgressBox(
    BuildContext context,
    AppUpdateProvider provider,
    AppLocalizations l10n,
    ColorScheme scheme,
    LabTokens tokens,
  ) {
    final text = Theme.of(context).textTheme;
    final progress = provider.downloadProgress;
    final downloadedLabel =
        ReleaseAssetInfo.formatByteCount(provider.downloadedBytes);
    final totalLabel = provider.totalBytes != null
        ? ReleaseAssetInfo.formatByteCount(provider.totalBytes!)
        : null;
    final percentText =
        progress != null ? '${(progress * 100).round()}%' : '...';

    return Container(
      padding: EdgeInsets.all(tokens.sLg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(tokens.rLg),
        border: Border.all(color: tokens.info.withValues(alpha: 0.38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.updateDownloadingTitle(
                    provider.latestRelease?.version ?? '',
                  ),
                  style: text.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Text(
                totalLabel != null
                    ? '$downloadedLabel / $totalLabel · $percentText'
                    : '$downloadedLabel · $percentText',
                style: text.labelSmall?.copyWith(
                  fontFamily: tokens.monoFamily,
                  color: tokens.info,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.sMd),
          ClipRRect(
            borderRadius: BorderRadius.circular(tokens.rXs),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(tokens.info),
            ),
          ),
          SizedBox(height: tokens.sMd),
          Align(
            alignment: Alignment.centerRight,
            child: LabButton(
              label: l10n.updateCancelDownload,
              size: LabButtonSize.sm,
              variant: LabButtonVariant.ghost,
              onPressed: provider.cancelDownload,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(
    BuildContext context,
    AppUpdateProvider provider,
    AppLocalizations l10n,
    ColorScheme scheme,
    LabTokens tokens,
    bool expanded,
  ) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(tokens.rMd),
          onTap: () => setState(() => _settingsExpanded = !_settingsExpanded),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.sXs),
            child: Row(
              children: [
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_right_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                SizedBox(width: tokens.sXs),
                Text(
                  l10n.updateSettingsTitle,
                  style: text.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          SizedBox(height: tokens.sSm),
          Container(
            padding: EdgeInsets.all(tokens.sLg),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(tokens.rLg),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.updateAutoCheckLabel,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    LabToggle(
                      value: provider.autoCheckEnabled,
                      onChanged: provider.setAutoCheckEnabled,
                    ),
                  ],
                ),
                SizedBox(height: tokens.sLg),
                LabField(
                  label: l10n.updateMirrorLabel,
                  controller: _mirrorController,
                  hintText: l10n.updateMirrorHint,
                  helperText: l10n.updateMirrorHelper,
                  mono: true,
                  onChanged: provider.setMirrorUrl,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter(
    BuildContext context,
    AppUpdateProvider provider,
    AppLocalizations l10n,
    ColorScheme scheme,
    LabTokens tokens,
  ) {
    final canSkip = provider.phase == AppUpdatePhase.available &&
        provider.hasBadgeUpdate;
    final canReveal = provider.phase == AppUpdatePhase.readyToInstall &&
        provider.downloadedFilePath != null;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.sXl,
        vertical: tokens.sLg,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          if (canSkip)
            LabButton(
              label: l10n.updateSkipVersion,
              variant: LabButtonVariant.ghost,
              size: LabButtonSize.md,
              onPressed: () async {
                await provider.skipAvailableVersion();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            )
          else if (canReveal)
            LabButton(
              label: l10n.updateRevealFile,
              icon: Icons.folder_open_outlined,
              variant: LabButtonVariant.ghost,
              size: LabButtonSize.md,
              onPressed: provider.revealDownloadedPackage,
            ),
          const Spacer(),
          LabButton(
            label: l10n.updateOpenReleasePage,
            icon: Icons.open_in_new_rounded,
            variant: LabButtonVariant.secondary,
            size: LabButtonSize.md,
            onPressed: provider.openReleasePageInBrowser,
          ),
          SizedBox(width: tokens.sMd),
          _buildPrimaryActionButton(context, provider, l10n),
        ],
      ),
    );
  }

  Widget _buildPrimaryActionButton(
    BuildContext context,
    AppUpdateProvider provider,
    AppLocalizations l10n,
  ) {
    switch (provider.phase) {
      case AppUpdatePhase.checking:
        return LabButton(
          label: l10n.menuCheckUpdate,
          variant: LabButtonVariant.primary,
          loading: true,
        );

      case AppUpdatePhase.available:
        final asset = provider.currentPlatformAsset;
        if (asset == null) {
          return LabButton(
            label: l10n.updateRecheckButton,
            icon: Icons.refresh_rounded,
            variant: LabButtonVariant.primary,
            onPressed: () => provider.checkForUpdates(manual: true),
          );
        }
        final sizeText = asset.formattedSize;
        return LabButton(
          label: sizeText != null
              ? l10n.updateDownloadWithSize(sizeText)
              : l10n.updateDownloadButton,
          icon: Icons.download_rounded,
          variant: LabButtonVariant.primary,
          onPressed: provider.startDownload,
        );

      case AppUpdatePhase.downloading:
        return LabButton(
          label: l10n.updateDownloadButton,
          variant: LabButtonVariant.primary,
          loading: true,
        );

      case AppUpdatePhase.readyToInstall:
      case AppUpdatePhase.installing:
        return LabButton(
          label: _platformInstallLabel(provider.currentPlatform, l10n),
          icon: Icons.install_desktop_rounded,
          variant: LabButtonVariant.primary,
          loading: provider.phase == AppUpdatePhase.installing,
          onPressed: () =>
              AppUpdateInstallHelper.confirmAndInstall(context, provider),
        );

      case AppUpdatePhase.idle:
      case AppUpdatePhase.upToDate:
      case AppUpdatePhase.error:
        final canRetryDownload = provider.hasUpdate &&
            provider.currentPlatformAsset != null &&
            (provider.errorKind == AppUpdateErrorKind.checksumMismatch ||
                provider.errorKind == AppUpdateErrorKind.installerLaunchFailed);
        if (canRetryDownload) {
          return LabButton(
            label: l10n.updateDownloadButton,
            icon: Icons.refresh_rounded,
            variant: LabButtonVariant.primary,
            onPressed: provider.startDownload,
          );
        }
        return LabButton(
          label: l10n.updateRecheckButton,
          icon: Icons.refresh_rounded,
          variant: LabButtonVariant.primary,
          onPressed: () => provider.checkForUpdates(manual: true),
        );
    }
  }

  String _platformReadyHint(
    AppUpdatePlatform? platform,
    AppLocalizations l10n,
  ) {
    return switch (platform) {
      AppUpdatePlatform.windows => l10n.updateReadyHintWindows,
      AppUpdatePlatform.macos => l10n.updateReadyHintMacos,
      AppUpdatePlatform.linux || null => l10n.updateReadyHintLinux,
    };
  }

  String _platformInstallLabel(
    AppUpdatePlatform? platform,
    AppLocalizations l10n,
  ) {
    return switch (platform) {
      AppUpdatePlatform.windows => l10n.updateInstallNowWindows,
      AppUpdatePlatform.macos => l10n.updateOpenInstallerMacos,
      AppUpdatePlatform.linux || null => l10n.updateOpenFolderLinux,
    };
  }

  String _localizedError(
    AppUpdateErrorKind? kind,
    AppLocalizations l10n,
  ) {
    return switch (kind) {
      AppUpdateErrorKind.invalidMirrorUrl => l10n.updateErrorInvalidMirror,
      AppUpdateErrorKind.assetUnavailable => l10n.updateErrorAssetUnavailable,
      AppUpdateErrorKind.checksumMismatch => l10n.updateErrorChecksum,
      AppUpdateErrorKind.installerLaunchFailed => l10n.updateErrorInstaller,
      AppUpdateErrorKind.network ||
      AppUpdateErrorKind.invalidResponse ||
      AppUpdateErrorKind.cancelled ||
      null =>
        l10n.updateErrorNetwork,
    };
  }
}

class _VersionColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final Color labelColor;
  final String monoFamily;
  final TextTheme textTheme;

  const _VersionColumn({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.labelColor,
    required this.monoFamily,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = LabTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelSmall?.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: tokens.sXxs),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(
            fontFamily: monoFamily,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _ReleaseNotesBody extends StatelessWidget {
  final String rawNotes;

  const _ReleaseNotesBody({required this.rawNotes});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);
    final text = Theme.of(context).textTheme;
    final lines = rawNotes.split('\n');

    final widgets = <Widget>[];
    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) {
        if (widgets.isNotEmpty) {
          widgets.add(SizedBox(height: tokens.sSm));
        }
        continue;
      }

      if (line.startsWith('## ') || line.startsWith('### ')) {
        final heading = line.replaceFirst(RegExp(r'^#{2,3}\s+'), '').trim();
        widgets.add(
          Padding(
            padding: EdgeInsets.only(
              top: widgets.isEmpty ? 0 : tokens.sXs,
              bottom: tokens.sXs,
            ),
            child: Text(
              heading,
              style: text.labelLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
        continue;
      }

      final trimmedLeft = line.trimLeft();
      if (trimmedLeft.startsWith('- ') || trimmedLeft.startsWith('* ')) {
        final itemText = _stripInlineMarkdown(trimmedLeft.substring(2));
        final isSubItem = line.startsWith('  ');
        widgets.add(
          Padding(
            padding: EdgeInsets.only(
              left: isSubItem ? tokens.sLg : 0,
              bottom: tokens.sXs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: text.bodySmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    itemText,
                    style: text.bodySmall?.copyWith(
                      color: tokens.body,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      widgets.add(
        Padding(
          padding: EdgeInsets.only(bottom: tokens.sXs),
          child: SelectableText(
            _stripInlineMarkdown(line),
            style: text.bodySmall?.copyWith(
              color: tokens.faint,
              height: 1.45,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  static String _stripInlineMarkdown(String input) {
    return input
        .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1)!)
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\([^)]+\)'),
          (m) => m.group(1)!,
        );
  }
}
