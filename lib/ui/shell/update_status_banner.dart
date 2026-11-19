import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/app_release_info.dart';
import '../../viewmodels/app_update_provider.dart';
import '../lab/lab.dart';
import '../update/app_update_dialog.dart';

/// Compact bottom status bar strip shown when a new version is available,
/// downloading in background, or verified & ready to install.
class UpdateStatusBanner extends StatelessWidget {
  const UpdateStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppUpdateProvider?>();
    if (provider == null || !provider.shouldShowBottomBanner) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);
    final text = Theme.of(context).textTheme;

    final phase = provider.phase;
    final isReady = phase == AppUpdatePhase.readyToInstall;
    final isDownloading = phase == AppUpdatePhase.downloading;
    final accent = isReady ? tokens.ok : scheme.primary;
    final dotKind = isReady
        ? LabStatus.ok
        : (isDownloading ? LabStatus.info : LabStatus.warn);

    final latestVersion = provider.latestRelease?.version ?? '';
    final summaryText = switch (phase) {
      AppUpdatePhase.downloading => l10n.updateBannerDownloading(
          latestVersion,
          ((provider.downloadProgress ?? 0) * 100).round(),
        ),
      AppUpdatePhase.readyToInstall => l10n.updateBannerReady(latestVersion),
      _ => l10n.updateBannerAvailable(
          latestVersion,
          provider.normalizedCurrentVersion.isEmpty
              ? '-'
              : provider.normalizedCurrentVersion,
        ),
    };

    return Container(
      key: const ValueKey('update_status_banner'),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.sLg,
        vertical: tokens.sSm,
      ),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: 0.08),
          scheme.surfaceContainerLowest,
        ),
        border: Border(top: BorderSide(color: accent.withValues(alpha: 0.35))),
      ),
      child: Row(
        children: [
          LabStatusDot(kind: dotKind, glow: true),
          SizedBox(width: tokens.sMd),
          LabPill(label: 'UPDATE', color: accent, small: true),
          SizedBox(width: tokens.sMd),
          Expanded(
            child: Text(
              summaryText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isDownloading) ...[
            SizedBox(width: tokens.sMd),
            SizedBox(
              width: 96,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(tokens.rXs),
                child: LinearProgressIndicator(
                  value: provider.downloadProgress,
                  minHeight: 5,
                  backgroundColor: scheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(tokens.info),
                ),
              ),
            ),
            SizedBox(width: tokens.sMd),
            LabButton(
              label: l10n.updateViewDetails,
              size: LabButtonSize.sm,
              variant: LabButtonVariant.secondary,
              onPressed: () =>
                  AppUpdateDialog.show(context, checkIfIdle: false),
            ),
          ] else if (isReady) ...[
            SizedBox(width: tokens.sMd),
            LabButton(
              label: _installLabelFor(provider.currentPlatform, l10n),
              size: LabButtonSize.sm,
              variant: LabButtonVariant.primary,
              icon: Icons.install_desktop_rounded,
              onPressed: () =>
                  AppUpdateInstallHelper.confirmAndInstall(context, provider),
            ),
            SizedBox(width: tokens.sSm),
            LabButton(
              label: l10n.updateViewDetails,
              size: LabButtonSize.sm,
              variant: LabButtonVariant.ghost,
              onPressed: () =>
                  AppUpdateDialog.show(context, checkIfIdle: false),
            ),
          ] else ...[
            SizedBox(width: tokens.sMd),
            LabButton(
              label: l10n.updateViewDetails,
              size: LabButtonSize.sm,
              variant: LabButtonVariant.primary,
              onPressed: () =>
                  AppUpdateDialog.show(context, checkIfIdle: false),
            ),
            SizedBox(width: tokens.sXs),
            LabButton(
              label: l10n.updateSkipVersion,
              size: LabButtonSize.sm,
              variant: LabButtonVariant.ghost,
              onPressed: provider.skipAvailableVersion,
            ),
            SizedBox(width: tokens.sXs),
            LabIconButton(
              icon: Icons.close,
              size: LabButtonSize.sm,
              tooltip: l10n.updateLater,
              onPressed: provider.dismissBannerForSession,
            ),
          ],
        ],
      ),
    );
  }

  String _installLabelFor(
    AppUpdatePlatform? platform,
    AppLocalizations l10n,
  ) {
    return switch (platform) {
      AppUpdatePlatform.windows => l10n.updateInstallNowWindows,
      AppUpdatePlatform.macos => l10n.updateOpenInstallerMacos,
      AppUpdatePlatform.linux || null => l10n.updateOpenFolderLinux,
    };
  }
}
