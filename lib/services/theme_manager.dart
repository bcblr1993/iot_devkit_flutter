import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ui/styles/app_theme_effect.dart';

class ThemeManager extends ChangeNotifier {
  static const String kThemePreferenceKey = 'app-theme';
  static const String kDefaultTheme = 'polar-blue';

  late ThemeData _currentTheme;
  String _currentThemeName = kDefaultTheme;

  ThemeData get currentTheme => _currentTheme;
  String get currentThemeName => _currentThemeName;

  ThemeManager({String? initialTheme}) {
    if (initialTheme != null && _themes.containsKey(initialTheme)) {
      _currentThemeName = initialTheme;
      _currentTheme = _themes[initialTheme]!;
    } else {
      _currentTheme = _themes[kDefaultTheme]!;
      // Only load preference usage if not provided (though main.dart should ideally always provide it)
      if (initialTheme == null) {
        _loadPreference();
      }
    }
  }

  /// 核心主题构建器，深度定制各个组件
  static ThemeData _buildProTheme({
    required Brightness brightness,
    required Color primary,
    required Color secondary,
    required Color background,
    required Color surface,
    required Color onSurface,
    required Color error,
    required Color onBackground,
    double borderRadius = 8.0,
    String? fontFamily,
    Color? borderColor,
    Color? progressIndicatorColor,
    Color? snackBarBackgroundColor,
    Color? snackBarContentColor,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? secondaryContainer,
    Color? onSecondaryContainer,
    Color? tertiary,
    Color? onTertiary,
    Color? tertiaryContainer,
    Color? onTertiaryContainer,
    Color? surfaceContainerLowest,
    Color? surfaceContainerLow,
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
    Color? surfaceContainerHighest,
    Color? onSurfaceVariant,
    Color? outline,
    Color? outlineVariant,
    AppThemeEffect? effect, // Dynamic extension
  }) {
    // 1. Platform Detection
    final bool isWindows = Platform.isWindows;

    // 2. ColorScheme
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: brightness == Brightness.dark ? Colors.black : Colors.white,
      primaryContainer: primaryContainer ?? primary.withValues(alpha: 0.12),
      onPrimaryContainer: onPrimaryContainer ?? primary,
      secondary: secondary,
      onSecondary: brightness == Brightness.dark ? Colors.black : Colors.white,
      secondaryContainer:
          secondaryContainer ?? secondary.withValues(alpha: 0.16),
      onSecondaryContainer: onSecondaryContainer ?? onSurface,
      tertiary: tertiary ?? secondary,
      onTertiary: onTertiary ??
          (brightness == Brightness.dark ? Colors.black : Colors.white),
      tertiaryContainer:
          tertiaryContainer ?? (tertiary ?? secondary).withValues(alpha: 0.16),
      onTertiaryContainer: onTertiaryContainer ?? onSurface,
      error: error,
      onError: Colors.white,
      errorContainer:
          error.withValues(alpha: brightness == Brightness.dark ? 0.22 : 0.12),
      onErrorContainer: error,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerLowest: surfaceContainerLowest ?? surface,
      surfaceContainerLow: surfaceContainerLow ?? surface,
      surfaceContainer: surfaceContainer ?? surface,
      surfaceContainerHigh: surfaceContainerHigh ?? surface,
      surfaceContainerHighest: surfaceContainerHighest ?? surface,
      onSurfaceVariant: onSurfaceVariant ?? onBackground,
      outline: outline ?? onBackground.withValues(alpha: 0.42),
      outlineVariant: outlineVariant ?? onBackground.withValues(alpha: 0.20),
      inverseSurface: onSurface,
      onInverseSurface: surface,
      inversePrimary: primaryContainer ?? primary,
      surfaceTint: Colors.transparent,
    );

    // 3. Premium Windows Typography
    // Windows fonts render thinner than Mac. We bump weights and force YaHei UI.
    final String effectiveFontFamily =
        fontFamily ?? (isWindows ? 'Microsoft YaHei UI' : null) ?? 'Roboto';
    final List<String> fallbackFonts =
        isWindows ? ['Microsoft YaHei', 'SimHei', 'Segoe UI Emoji'] : [];

    TextTheme baseTextTheme = Typography.material2021(
            platform: isWindows ? TargetPlatform.windows : TargetPlatform.macOS)
        .englishLike
        .merge(Typography.material2021(
                platform:
                    isWindows ? TargetPlatform.windows : TargetPlatform.macOS)
            .black);

    // Adjust visibility for Windows
    if (isWindows) {
      baseTextTheme = baseTextTheme.copyWith(
        bodyMedium: baseTextTheme.bodyMedium
            ?.copyWith(fontWeight: FontWeight.w500), // Fix "thin" look
        titleMedium:
            baseTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        labelLarge:
            baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      );
    }

    final TextTheme textTheme = baseTextTheme.apply(
      bodyColor: onBackground,
      displayColor: onBackground,
      fontFamily: effectiveFontFamily,
      fontFamilyFallback: fallbackFonts,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      cardColor: surface,
      canvasColor: surface, // Fixes DropdownButton background color
      fontFamily: fontFamily,
      extensions: [
        effect ??
            AppThemeEffect(
              animationCurve: Curves.easeInOut,
              layoutDensity: 1.0,
              borderRadius: borderRadius,
              icons: AppIcons.standard,
            ),
      ],

      // 1. 卡片主题 - 关于对话框风格
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0, // Flat design with custom shadows
        shadowColor: primary.withValues(alpha: 0.1), // 主题色阴影
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: BorderSide(
              color: borderColor ??
                  onBackground.withValues(alpha: 0.06)), // 更细腻的边框
        ),
      ),

      // 2. 进度条主题
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: progressIndicatorColor ?? primary,
      ),

      // 3. SnackBar 主题
      snackBarTheme: SnackBarThemeData(
        backgroundColor: snackBarBackgroundColor ?? primary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: snackBarContentColor ?? colorScheme.onPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius)),
      ),

      // 2. 输入框主题 - 与MQTT区域风格一致
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: onBackground.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: error, width: 2),
        ),
        labelStyle: TextStyle(color: onBackground.withValues(alpha: 0.7)),
        floatingLabelStyle:
            TextStyle(color: primary, fontWeight: FontWeight.bold),
        fillColor: colorScheme.surfaceContainerLowest,
      ),

      // 3. 按钮主题 - 使用合理的圆角
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor:
              brightness == Brightness.dark ? Colors.black : Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10), // 合理的圆角
          ),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor:
              brightness == Brightness.dark ? Colors.black : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: colorScheme.outlineVariant),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: colorScheme.surfaceContainerLowest,
          foregroundColor: colorScheme.onSurfaceVariant,
          selectedBackgroundColor: primary,
          selectedForegroundColor: colorScheme.onPrimary,
          side: BorderSide(color: colorScheme.outlineVariant),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius.clamp(4, 12)),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return colorScheme.surfaceContainerHighest;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withValues(alpha: 0.28);
          }
          return colorScheme.surfaceContainerHigh;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return Colors.transparent;
        }),
        side: BorderSide(color: colorScheme.outline, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        indicatorColor: primaryContainer ?? primary.withValues(alpha: 0.10),
        selectedIconTheme: IconThemeData(color: primary, size: 24),
        unselectedIconTheme:
            IconThemeData(color: colorScheme.onSurfaceVariant, size: 24),
        selectedLabelTextStyle:
            TextStyle(color: primary, fontWeight: FontWeight.w800),
        unselectedLabelTextStyle:
            TextStyle(color: colorScheme.onSurfaceVariant),
      ),

      // 4. 对话框 - 关于对话框风格
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius + 4)),
        titleTextStyle: TextStyle(
            fontSize: 20, fontWeight: FontWeight.bold, color: onBackground),
        elevation: 16,
        shadowColor: primary.withValues(alpha: 0.15),
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius)),
        color: surface,
        elevation: 8,
        shadowColor: primary.withValues(alpha: 0.1),
      ),

      // 5. 分割线与图标
      dividerTheme: DividerThemeData(
        color: onBackground.withValues(alpha: 0.1),
        space: 24,
        thickness: 1,
      ),
      iconTheme:
          IconThemeData(color: onBackground.withValues(alpha: 0.8), size: 22),

      // 6. AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onBackground,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent, // Disable tint
        titleTextStyle: TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: onBackground),
        iconTheme: IconThemeData(color: onBackground),
        shape: Border(
            bottom: BorderSide(color: onBackground.withValues(alpha: 0.05))),
      ),

      // 7. ExpansionTile
      expansionTileTheme: ExpansionTileThemeData(
        shape: Border.all(
            color: Colors.transparent), // Remove borders when expanded
        collapsedShape: Border.all(color: Colors.transparent),
        iconColor: primary,
        textColor: primary,
        collapsedIconColor: onBackground.withValues(alpha: 0.6),
        collapsedTextColor: onBackground.withValues(alpha: 0.9),
        backgroundColor: Colors.transparent,
      ),

      // 8. TabBar - 现代渐变指示器
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: onBackground.withValues(alpha: 0.55),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        indicator: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: primary,
              width: 3,
            ),
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
      ),
    );
  }

  static final Map<String, ThemeData> _themes = {
    // Default: calm operational dashboard style.
    'polar-blue': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF2563EB),
      secondary: const Color(0xFF0F766E),
      tertiary: const Color(0xFFF59E0B),
      background: const Color(0xFFF5F7FB),
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF111827),
      onBackground: const Color(0xFF4B5563),
      error: const Color(0xFFDC2626),
      borderRadius: 8.0,
      borderColor: const Color(0xFFD8DEE8),
      primaryContainer: const Color(0xFFDBEAFE),
      onPrimaryContainer: const Color(0xFF1E3A8A),
      secondaryContainer: const Color(0xFFCCFBF1),
      onSecondaryContainer: const Color(0xFF134E4A),
      tertiaryContainer: const Color(0xFFFEF3C7),
      onTertiaryContainer: const Color(0xFF92400E),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF8FAFC),
      surfaceContainer: const Color(0xFFF1F5F9),
      surfaceContainerHigh: const Color(0xFFEFF4FA),
      surfaceContainerHighest: const Color(0xFFE6EDF6),
      outline: const Color(0xFF94A3B8),
      outlineVariant: const Color(0xFFD6DEE9),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeOutCubic,
        layoutDensity: 0.95,
        borderRadius: 8.0,
        icons: AppIcons.sharp,
      ),
    ),

    // Compact neutral style for dense engineering work.
    'graphite-mono': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF2F343A),
      secondary: const Color(0xFF0F766E),
      tertiary: const Color(0xFFB45309),
      background: const Color(0xFFF7F7F5),
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF111827),
      onBackground: const Color(0xFF4B5563),
      error: const Color(0xFFDC2626),
      borderRadius: 4.0,
      borderColor: const Color(0xFFD9D9D6),
      primaryContainer: const Color(0xFFE5E7EB),
      onPrimaryContainer: const Color(0xFF1F2937),
      secondaryContainer: const Color(0xFFDDF3EF),
      onSecondaryContainer: const Color(0xFF134E4A),
      tertiaryContainer: const Color(0xFFF3E6D3),
      onTertiaryContainer: const Color(0xFF7C2D12),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFFAFAF9),
      surfaceContainer: const Color(0xFFF2F2F0),
      surfaceContainerHigh: const Color(0xFFEAEAE7),
      surfaceContainerHighest: const Color(0xFFE1E1DE),
      outline: const Color(0xFF9CA3AF),
      outlineVariant: const Color(0xFFD1D5DB),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeInOut,
        layoutDensity: 0.84,
        borderRadius: 4.0,
        icons: AppIcons.sharp,
      ),
    ),

    // Gentle green theme for long sessions.
    'forest-mint': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF047857),
      secondary: const Color(0xFF2563EB),
      tertiary: const Color(0xFFD97706),
      background: const Color(0xFFF5FAF7),
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF17201B),
      onBackground: const Color(0xFF51615A),
      error: const Color(0xFFDC2626),
      borderRadius: 10.0,
      borderColor: const Color(0xFFDDE7E1),
      primaryContainer: const Color(0xFFD1FAE5),
      onPrimaryContainer: const Color(0xFF064E3B),
      secondaryContainer: const Color(0xFFDBEAFE),
      onSecondaryContainer: const Color(0xFF1E3A8A),
      tertiaryContainer: const Color(0xFFFDECC8),
      onTertiaryContainer: const Color(0xFF92400E),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF8FCFA),
      surfaceContainer: const Color(0xFFEFF7F3),
      surfaceContainerHigh: const Color(0xFFE4F0EA),
      surfaceContainerHighest: const Color(0xFFD8E7DF),
      outline: const Color(0xFF8FA499),
      outlineVariant: const Color(0xFFD0DED6),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeOutCubic,
        layoutDensity: 0.98,
        borderRadius: 10.0,
        icons: AppIcons.rounded,
      ),
    ),

    // Alert-forward style for QA and failure-focused workflows.
    'porcelain-red': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFFC62828),
      secondary: const Color(0xFF2563EB),
      tertiary: const Color(0xFF0F766E),
      background: const Color(0xFFFFFAFA),
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF1F1F24),
      onBackground: const Color(0xFF5F626B),
      error: const Color(0xFFB91C1C),
      borderRadius: 8.0,
      borderColor: const Color(0xFFE8D6D6),
      primaryContainer: const Color(0xFFFFE1E1),
      onPrimaryContainer: const Color(0xFF7F1D1D),
      secondaryContainer: const Color(0xFFDBEAFE),
      onSecondaryContainer: const Color(0xFF1E3A8A),
      tertiaryContainer: const Color(0xFFDDF3EF),
      onTertiaryContainer: const Color(0xFF134E4A),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFFFF7F7),
      surfaceContainer: const Color(0xFFFDF0F0),
      surfaceContainerHigh: const Color(0xFFF7E7E7),
      surfaceContainerHighest: const Color(0xFFEFDCDC),
      outline: const Color(0xFFA7A1A1),
      outlineVariant: const Color(0xFFE2CCCC),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeOutCubic,
        layoutDensity: 0.96,
        borderRadius: 8.0,
        icons: AppIcons.standard,
      ),
    ),

    // Clear water style for monitoring rooms and bright displays.
    'azure-coast': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF0891B2),
      secondary: const Color(0xFF2563EB),
      tertiary: const Color(0xFFF59E0B),
      background: const Color(0xFFF3FBFC),
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF102027),
      onBackground: const Color(0xFF52656D),
      error: const Color(0xFFDC2626),
      borderRadius: 12.0,
      borderColor: const Color(0xFFCBE5EA),
      primaryContainer: const Color(0xFFCFFAFE),
      onPrimaryContainer: const Color(0xFF164E63),
      secondaryContainer: const Color(0xFFDBEAFE),
      onSecondaryContainer: const Color(0xFF1E3A8A),
      tertiaryContainer: const Color(0xFFFEF3C7),
      onTertiaryContainer: const Color(0xFF92400E),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF7FCFD),
      surfaceContainer: const Color(0xFFEAF8FA),
      surfaceContainerHigh: const Color(0xFFDDF1F5),
      surfaceContainerHighest: const Color(0xFFD0E8EE),
      outline: const Color(0xFF7BA7B2),
      outlineVariant: const Color(0xFFC4DDE3),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeInOutCubic,
        layoutDensity: 1.0,
        borderRadius: 12.0,
        icons: AppIcons.rounded,
      ),
    ),

    // Warm workbench style, restrained enough for forms.
    'amber-glow': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFFB45309),
      secondary: const Color(0xFF0F766E),
      tertiary: const Color(0xFF4F46E5),
      background: const Color(0xFFFBF8F2),
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF211A14),
      onBackground: const Color(0xFF655D54),
      error: const Color(0xFFDC2626),
      borderRadius: 8.0,
      borderColor: const Color(0xFFE8DAC6),
      primaryContainer: const Color(0xFFFDECC8),
      onPrimaryContainer: const Color(0xFF7C2D12),
      secondaryContainer: const Color(0xFFDDF3EF),
      onSecondaryContainer: const Color(0xFF134E4A),
      tertiaryContainer: const Color(0xFFEDE9FE),
      onTertiaryContainer: const Color(0xFF3730A3),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFFCFAF6),
      surfaceContainer: const Color(0xFFF7F0E5),
      surfaceContainerHigh: const Color(0xFFF0E6D6),
      surfaceContainerHighest: const Color(0xFFE8DCC9),
      outline: const Color(0xFFA79782),
      outlineVariant: const Color(0xFFDED0BC),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeOutCubic,
        layoutDensity: 0.98,
        borderRadius: 8.0,
        icons: AppIcons.standard,
      ),
    ),

    // Distinct purple accent without turning the whole app purple.
    'wisteria-white': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF7C3AED),
      secondary: const Color(0xFF0F766E),
      tertiary: const Color(0xFFEAB308),
      background: const Color(0xFFFAFAFC),
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF17151F),
      onBackground: const Color(0xFF625F6D),
      error: const Color(0xFFDC2626),
      borderRadius: 12.0,
      borderColor: const Color(0xFFE0D8EE),
      primaryContainer: const Color(0xFFEDE9FE),
      onPrimaryContainer: const Color(0xFF4C1D95),
      secondaryContainer: const Color(0xFFDDF3EF),
      onSecondaryContainer: const Color(0xFF134E4A),
      tertiaryContainer: const Color(0xFFFEF9C3),
      onTertiaryContainer: const Color(0xFF713F12),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFFCFBFF),
      surfaceContainer: const Color(0xFFF4F1FA),
      surfaceContainerHigh: const Color(0xFFECE7F5),
      surfaceContainerHighest: const Color(0xFFE3DDEC),
      outline: const Color(0xFF9C91AF),
      outlineVariant: const Color(0xFFD7D0E2),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeInOutCubic,
        layoutDensity: 1.0,
        borderRadius: 12.0,
        icons: AppIcons.rounded,
      ),
    ),

    // Low-stimulation green for all-day usage.
    'matcha-mochi': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF4D7C0F),
      secondary: const Color(0xFF0E7490),
      tertiary: const Color(0xFFB45309),
      background: const Color(0xFFF7F8EF),
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF1F2418),
      onBackground: const Color(0xFF5C6653),
      error: const Color(0xFFDC2626),
      borderRadius: 14.0,
      borderColor: const Color(0xFFD8E0C8),
      primaryContainer: const Color(0xFFE4F1C7),
      onPrimaryContainer: const Color(0xFF365314),
      secondaryContainer: const Color(0xFFD4F2F5),
      onSecondaryContainer: const Color(0xFF164E63),
      tertiaryContainer: const Color(0xFFFDECC8),
      onTertiaryContainer: const Color(0xFF7C2D12),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFFCFCF7),
      surfaceContainer: const Color(0xFFF0F4E6),
      surfaceContainerHigh: const Color(0xFFE7EDD8),
      surfaceContainerHighest: const Color(0xFFDDE5CB),
      outline: const Color(0xFF98A584),
      outlineVariant: const Color(0xFFD0D9BC),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeOutCubic,
        layoutDensity: 1.0,
        borderRadius: 14.0,
        icons: AppIcons.rounded,
      ),
    ),

    // Cool neutral Scandinavian style.
    'nordic-frost': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF3B82F6),
      secondary: const Color(0xFF64748B),
      tertiary: const Color(0xFF0F766E),
      background: const Color(0xFFF8FAFC),
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF0F172A),
      onBackground: const Color(0xFF64748B),
      error: const Color(0xFFDC2626),
      borderRadius: 6.0,
      borderColor: const Color(0xFFD7E0EA),
      primaryContainer: const Color(0xFFE0F2FE),
      onPrimaryContainer: const Color(0xFF075985),
      secondaryContainer: const Color(0xFFE2E8F0),
      onSecondaryContainer: const Color(0xFF334155),
      tertiaryContainer: const Color(0xFFDDF3EF),
      onTertiaryContainer: const Color(0xFF134E4A),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFFAFCFE),
      surfaceContainer: const Color(0xFFF1F5F9),
      surfaceContainerHigh: const Color(0xFFE8EEF5),
      surfaceContainerHighest: const Color(0xFFDDE6F0),
      outline: const Color(0xFF94A3B8),
      outlineVariant: const Color(0xFFD4DDE8),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeInOut,
        layoutDensity: 0.92,
        borderRadius: 6.0,
        icons: AppIcons.sharp,
      ),
    ),

    // Dark command-center style.
    'cosmic-void': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFF38BDF8),
      secondary: const Color(0xFFA78BFA),
      tertiary: const Color(0xFFFBBF24),
      background: const Color(0xFF070B14),
      surface: const Color(0xFF0D1320),
      onSurface: const Color(0xFFE5E7EB),
      onBackground: const Color(0xFF9CA3AF),
      error: const Color(0xFFF87171),
      borderRadius: 8.0,
      borderColor: const Color(0xFF253145),
      primaryContainer: const Color(0xFF082F49),
      onPrimaryContainer: const Color(0xFFE0F2FE),
      secondaryContainer: const Color(0xFF312E81),
      onSecondaryContainer: const Color(0xFFEDE9FE),
      tertiaryContainer: const Color(0xFF451A03),
      onTertiaryContainer: const Color(0xFFFEF3C7),
      surfaceContainerLowest: const Color(0xFF090E18),
      surfaceContainerLow: const Color(0xFF111827),
      surfaceContainer: const Color(0xFF162033),
      surfaceContainerHigh: const Color(0xFF1D293D),
      surfaceContainerHighest: const Color(0xFF273449),
      outline: const Color(0xFF536179),
      outlineVariant: const Color(0xFF273449),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeOutExpo,
        layoutDensity: 0.95,
        borderRadius: 8.0,
        icons: AppIcons.tech,
      ),
    ),

    // High-contrast dark theme for demos and monitoring walls.
    'neon-cyberpunk': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFF22D3EE),
      secondary: const Color(0xFFF472B6),
      tertiary: const Color(0xFFA3E635),
      background: const Color(0xFF070A12),
      surface: const Color(0xFF0E1422),
      onSurface: const Color(0xFFF8FAFC),
      onBackground: const Color(0xFFB6C2D6),
      error: const Color(0xFFFB7185),
      borderRadius: 10.0,
      borderColor: const Color(0xFF28415E),
      primaryContainer: const Color(0xFF164E63),
      onPrimaryContainer: const Color(0xFFCFFAFE),
      secondaryContainer: const Color(0xFF831843),
      onSecondaryContainer: const Color(0xFFFCE7F3),
      tertiaryContainer: const Color(0xFF365314),
      onTertiaryContainer: const Color(0xFFECFCCB),
      surfaceContainerLowest: const Color(0xFF080D16),
      surfaceContainerLow: const Color(0xFF111827),
      surfaceContainer: const Color(0xFF172033),
      surfaceContainerHigh: const Color(0xFF202C45),
      surfaceContainerHighest: const Color(0xFF2A3855),
      outline: const Color(0xFF5C789A),
      outlineVariant: const Color(0xFF28415E),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeOutExpo,
        layoutDensity: 1.0,
        borderRadius: 10.0,
        icons: AppIcons.tech,
      ),
    ),
  };

  List<String> get availableThemes => _themes.keys.toList();

  List<Color> previewColors(String themeName) {
    final scheme = _themes[themeName]?.colorScheme ?? currentTheme.colorScheme;
    return [
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.surfaceContainerHighest,
    ];
  }

  void setTheme(String themeName) {
    if (_themes.containsKey(themeName)) {
      _currentTheme = _themes[themeName]!;
      _currentThemeName = themeName;
      _savePreference(themeName);
      notifyListeners();
    }
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(kThemePreferenceKey);
    if (savedTheme != null && _themes.containsKey(savedTheme)) {
      _currentTheme = _themes[savedTheme]!;
      _currentThemeName = savedTheme;
      notifyListeners();
    } else {
      _currentTheme = _themes[kDefaultTheme]!;
      _currentThemeName = kDefaultTheme;
      notifyListeners();
    }
  }

  Future<void> _savePreference(String themeName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kThemePreferenceKey, themeName);
  }
}
