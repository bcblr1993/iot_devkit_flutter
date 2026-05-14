import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/language_provider.dart';
import '../../services/log_storage_service.dart';
import '../../services/theme_manager.dart';
import '../../utils/about_dialog_helper.dart';
import '../../utils/app_dialog_helper.dart';
import '../../viewmodels/timesheet_provider.dart';

class SettingsMenu extends StatelessWidget {
  final VoidCallback? onTimesheetDisabled;

  const SettingsMenu({
    super.key,
    this.onTimesheetDisabled,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tsProvider = context.watch<TimesheetProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Tooltip(
      message: l10n.menuSettings,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.24),
        constraints: const BoxConstraints.tightFor(width: 268),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        tooltip: '',
        offset: const Offset(52, -260),
        position: PopupMenuPosition.under,
        onSelected: (String action) {
          switch (action) {
            case 'theme':
              _showThemeDialog(context);
              break;
            case 'language':
              _showLanguageDialog(context);
              break;
            case 'logs':
              LogStorageService.instance.openLogFolder();
              break;
            case 'about':
              AboutDialogHelper.showAboutDialog(context);
              break;
            case 'toggle_timesheet':
              final nextValue = !tsProvider.isEnabled;
              if (!nextValue) {
                onTimesheetDisabled?.call();
              }
              tsProvider.toggleEnabled(nextValue);
              break;
          }
        },
        itemBuilder: (BuildContext context) {
          return [
            PopupMenuItem(
              value: 'theme',
              height: 44,
              padding: EdgeInsets.zero,
              child: _SettingsMenuRow(
                icon: Icons.palette_outlined,
                label: l10n.selectTheme,
              ),
            ),
            PopupMenuItem(
              value: 'language',
              height: 44,
              padding: EdgeInsets.zero,
              child: _SettingsMenuRow(
                icon: Icons.language,
                label: l10n.selectLanguage,
              ),
            ),
            PopupMenuDivider(
              height: 8,
              color: colorScheme.outlineVariant.withValues(alpha: 0.62),
            ),
            PopupMenuItem(
              value: 'toggle_timesheet',
              height: 44,
              padding: EdgeInsets.zero,
              child: _SettingsMenuRow(
                icon: Icons.calendar_month_outlined,
                label: l10n.toolTimesheet,
                iconColor: colorScheme.primary,
                trailing: _MenuStatePill(active: tsProvider.isEnabled),
              ),
            ),
            PopupMenuDivider(
              height: 8,
              color: colorScheme.outlineVariant.withValues(alpha: 0.62),
            ),
            PopupMenuItem(
              value: 'logs',
              height: 44,
              padding: EdgeInsets.zero,
              child: _SettingsMenuRow(
                icon: Icons.folder_open,
                label: l10n.menuOpenLogs,
              ),
            ),
            PopupMenuItem(
              value: 'about',
              height: 44,
              padding: EdgeInsets.zero,
              child: _SettingsMenuRow(
                icon: Icons.info_outline,
                label: l10n.menuAbout,
              ),
            ),
          ];
        },
        child: _SettingsButton(colorScheme: colorScheme),
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    AppDialogHelper.show(
      context: context,
      title: l10n.selectTheme,
      icon: Icons.palette_outlined,
      content: Consumer<ThemeManager>(
        builder: (context, themeManager, child) {
          return _ThemePickerGrid(
            themes: themeManager.availableThemes,
            selectedTheme: themeManager.currentThemeName,
            labelForTheme: (theme) => _themeLabel(l10n, theme),
            colorsForTheme: themeManager.previewColors,
            onSelected: themeManager.setTheme,
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (dialogContext) => Consumer<LanguageProvider>(
        builder: (context, langProvider, child) {
          return _LanguagePickerDialog(
            selectedCode: langProvider.currentLocale.languageCode,
            onSelected: (code) {
              langProvider.setLocale(Locale(code));
              Navigator.pop(dialogContext);
            },
          );
        },
      ),
    );
  }

  String _themeLabel(AppLocalizations l10n, String theme) {
    switch (theme) {
      case 'forest-mint':
        return l10n.themeForestMint;
      case 'cosmic-void':
        return l10n.themeCosmicVoid;
      case 'polar-blue':
        return l10n.themePolarBlue;
      case 'porcelain-red':
        return l10n.themePorcelainRed;
      case 'wisteria-white':
        return l10n.themeWisteriaWhite;
      case 'amber-glow':
        return l10n.themeAmberGlow;
      case 'graphite-mono':
        return l10n.themeGraphiteMono;
      case 'azure-coast':
        return l10n.themeAzureCoast;
      case 'matcha-mochi':
        return l10n.themeMatchaMochi;
      case 'neon-cyberpunk':
        return l10n.themeNeonCyberpunk;
      case 'nordic-frost':
        return l10n.themeNordicFrost;
      default:
        return theme;
    }
  }
}

class _ThemePickerGrid extends StatelessWidget {
  final List<String> themes;
  final String selectedTheme;
  final String Function(String theme) labelForTheme;
  final List<Color> Function(String theme) colorsForTheme;
  final ValueChanged<String> onSelected;

  const _ThemePickerGrid({
    required this.themes,
    required this.selectedTheme,
    required this.labelForTheme,
    required this.colorsForTheme,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 420 ? 2 : 1;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: themes.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: columns == 1 ? 5.8 : 3.15,
            ),
            itemBuilder: (context, index) {
              final themeName = themes[index];
              return _ThemeOptionCard(
                label: labelForTheme(themeName),
                colors: colorsForTheme(themeName),
                isSelected: selectedTheme == themeName,
                onTap: () => onSelected(themeName),
              );
            },
          );
        },
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  final ColorScheme colorScheme;

  const _SettingsButton({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.16),
            ),
          ),
          child: Icon(
            Icons.settings_rounded,
            size: 20,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _SettingsMenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;
  final Widget? trailing;

  const _SettingsMenuRow({
    required this.icon,
    required this.label,
    this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = iconColor ?? colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _MenuStatePill extends StatelessWidget {
  final bool active;

  const _MenuStatePill({required this.active});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = active ? colorScheme.primary : colorScheme.outline;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: 34,
      height: 20,
      decoration: BoxDecoration(
        color: color.withValues(alpha: active ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Align(
        alignment: active ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  final String label;
  final List<Color> colors;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOptionCard({
    required this.label,
    required this.colors,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primary = colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.72)
                : colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? primary : colorScheme.outlineVariant,
              width: isSelected ? 1.4 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.13),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              _ThemeSwatch(colors: colors, isSelected: isSelected),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                child: isSelected
                    ? Icon(
                        Icons.check_circle,
                        key: const ValueKey('selected'),
                        color: primary,
                        size: 20,
                      )
                    : SizedBox(
                        key: const ValueKey('empty'),
                        width: 20,
                        height: 20,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: colorScheme.outline),
                          ),
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

class _LanguagePickerDialog extends StatelessWidget {
  final String selectedCode;
  final ValueChanged<String> onSelected;

  const _LanguagePickerDialog({
    required this.selectedCode,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final languages = [
      _LanguageOptionData(
        code: 'zh',
        badge: '中',
        title: '简体中文',
        subtitle: isZh ? '当前界面语言' : 'Chinese Simplified',
      ),
      _LanguageOptionData(
        code: 'en',
        badge: 'EN',
        title: 'English',
        subtitle: isZh ? '英文界面' : 'Interface language',
      ),
    ];

    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.language, color: colors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.selectLanguage,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 440;
                  if (compact) {
                    return Column(
                      children: [
                        for (final language in languages) ...[
                          _LanguageOptionCard(
                            data: language,
                            selected: selectedCode == language.code,
                            onTap: () => onSelected(language.code),
                          ),
                          if (language != languages.last)
                            const SizedBox(height: 10),
                        ],
                      ],
                    );
                  }

                  return Row(
                    children: [
                      for (final language in languages) ...[
                        Expanded(
                          child: _LanguageOptionCard(
                            data: language,
                            selected: selectedCode == language.code,
                            onTap: () => onSelected(language.code),
                          ),
                        ),
                        if (language != languages.last)
                          const SizedBox(width: 10),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageOptionData {
  final String code;
  final String badge;
  final String title;
  final String subtitle;

  const _LanguageOptionData({
    required this.code,
    required this.badge,
    required this.title,
    required this.subtitle,
  });
}

class _LanguageOptionCard extends StatelessWidget {
  final _LanguageOptionData data;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageOptionCard({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final primary = colors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 104),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? colors.primaryContainer.withValues(alpha: 0.46)
                : colors.surfaceContainerLow.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? primary : colors.outlineVariant,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 32,
                    constraints: const BoxConstraints(minWidth: 40),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? primary.withValues(alpha: 0.14)
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      data.badge,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: selected ? primary : colors.onSurfaceVariant,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: selected
                        ? Icon(
                            Icons.check_circle,
                            key: const ValueKey('selected-language'),
                            color: primary,
                            size: 20,
                          )
                        : Icon(
                            Icons.radio_button_unchecked,
                            key: const ValueKey('unselected-language'),
                            color: colors.outline,
                            size: 20,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: selected ? primary : colors.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  final List<Color> colors;
  final bool isSelected;

  const _ThemeSwatch({
    required this.colors,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 34,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.35)
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Column(
            children: [
              Expanded(
                flex: 2,
                child: Row(
                  children: colors
                      .take(3)
                      .map(
                        (color) => Expanded(
                          child: ColoredBox(color: color),
                        ),
                      )
                      .toList(),
                ),
              ),
              Expanded(
                child: ColoredBox(
                  color: colors.length > 3
                      ? colors[3]
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
