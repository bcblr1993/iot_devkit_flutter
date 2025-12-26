import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ui/styles/app_theme_effect.dart';

class ThemeManager extends ChangeNotifier {
  static const String kThemePreferenceKey = 'app-theme';
  
  late ThemeData _currentTheme;
  String _currentThemeName = 'forest-mint';
  
  ThemeData get currentTheme => _currentTheme;
  String get currentThemeName => _currentThemeName;

  ThemeManager({String? initialTheme}) {
    if (initialTheme != null && _themes.containsKey(initialTheme)) {
      _currentThemeName = initialTheme;
      _currentTheme = _themes[initialTheme]!;
    } else {
      _currentTheme = _themes['forest-mint']!;
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
    AppThemeEffect? effect, // Dynamic extension
  }) {
    // 1. Platform Detection
    final bool isWindows = Platform.isWindows;
    
    // 2. ColorScheme
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: brightness == Brightness.dark ? Colors.black : Colors.white,
      primaryContainer: primaryContainer ?? primary.withOpacity(0.12),
      onPrimaryContainer: onPrimaryContainer ?? primary,
      secondary: secondary,
      onSecondary: brightness == Brightness.dark ? Colors.black : Colors.white,
      error: error,
      onError: Colors.white,
      background: background,
      onBackground: onBackground,
      surface: surface,
      onSurface: onSurface,
    );

    // 3. Premium Windows Typography
    // Windows fonts render thinner than Mac. We bump weights and force YaHei UI.
    final String effectiveFontFamily = fontFamily ?? (isWindows ? 'Microsoft YaHei UI' : null) ?? 'Roboto';
    final List<String> fallbackFonts = isWindows ? ['Microsoft YaHei', 'SimHei', 'Segoe UI Emoji'] : [];

    TextTheme baseTextTheme = Typography.material2021(
      platform: isWindows ? TargetPlatform.windows : TargetPlatform.macOS
    ).englishLike.merge(
      Typography.material2021(platform: isWindows ? TargetPlatform.windows : TargetPlatform.macOS).black
    );

    // Adjust visibility for Windows
    if (isWindows) {
       baseTextTheme = baseTextTheme.copyWith(
         bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500), // Fix "thin" look
         titleMedium: baseTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
         labelLarge: baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
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
        effect ?? AppThemeEffect(
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
        shadowColor: primary.withOpacity(0.1), // 主题色阴影
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: BorderSide(color: borderColor ?? onBackground.withOpacity(0.06)), // 更细腻的边框
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
      ),

      // 2. 输入框主题 - 与MQTT区域风格一致
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: onBackground.withOpacity(0.3)),
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
        labelStyle: TextStyle(color: onBackground.withOpacity(0.7)),
        floatingLabelStyle: TextStyle(color: primary, fontWeight: FontWeight.bold),
      ),

      // 3. 按钮主题 - 使用合理的圆角
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: brightness == Brightness.dark ? Colors.black : Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10), // 合理的圆角
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: brightness == Brightness.dark ? Colors.black : Colors.white,
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
          side: BorderSide(color: primary.withOpacity(0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),

      // 4. 对话框 - 关于对话框风格
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius + 4)),
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: onBackground),
        elevation: 16,
        shadowColor: primary.withOpacity(0.15),
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
        color: surface,
        elevation: 8,
        shadowColor: primary.withOpacity(0.1),
      ),

      // 5. 分割线与图标
      dividerTheme: DividerThemeData(
        color: onBackground.withOpacity(0.1), 
        space: 24,
        thickness: 1,
      ),
      iconTheme: IconThemeData(color: onBackground.withOpacity(0.8), size: 22),
      
      // 6. AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onBackground,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent, // Disable tint
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: onBackground),
        iconTheme: IconThemeData(color: onBackground),
        shape: Border(bottom: BorderSide(color: onBackground.withOpacity(0.05))),
      ),

      // 7. ExpansionTile
      expansionTileTheme: ExpansionTileThemeData(
        shape: Border.all(color: Colors.transparent), // Remove borders when expanded
        collapsedShape: Border.all(color: Colors.transparent),
        iconColor: primary,
        textColor: primary,
        collapsedIconColor: onBackground.withOpacity(0.6),
        collapsedTextColor: onBackground.withOpacity(0.9),
        backgroundColor: Colors.transparent, 
      ),
      
      // 8. TabBar - 现代渐变指示器
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: onBackground.withOpacity(0.55),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
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
    // 1. 🌲 Forest Mint (保留 - 经典绿)
    'forest-mint': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF047857),
      secondary: const Color(0xFFD1FAE5),
      background: const Color(0xFFF8FDF9),
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF1F2937),
      onBackground: const Color(0xFF475569),
      error: const Color(0xFFDC2626),
      borderRadius: 20.0,
      borderColor: const Color(0xFFE5E7EB).withOpacity(0.8),
      primaryContainer: const Color(0xFF047857).withOpacity(0.08),
      onPrimaryContainer: const Color(0xFF065F46),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeOutCubic,
        layoutDensity: 1.0,
        borderRadius: 20.0,
        icons: AppIcons.rounded,
        useGlassEffect: true,
      ),
    ),

    // 2. 🌌 Cosmic Void (保留 - 唯一暗色)
    'cosmic-void': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFF818CF8), // Indigo 400
      secondary: const Color(0xFF4F46E5),
      background: const Color(0xFF000000), // Pure Black Oled
      surface: const Color(0xFF09090B), // Zinc 950
      onSurface: const Color(0xFFFAFAFA),
      onBackground: const Color(0xFFA1A1AA),
      error: const Color(0xFFF87171),
      borderRadius: 12.0,
      borderColor: const Color(0xFF27272A),
      primaryContainer: const Color(0xFF1E1B4B),
      onPrimaryContainer: const Color(0xFFC7D2FE),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeOutExpo,
        layoutDensity: 1.0,
        borderRadius: 12.0,
        icons: AppIcons.tech,
        useGlassEffect: false,
      ),
    ),

    // 3. 🧊 Polar Blue (极地冰蓝) - White + Blue
    'polar-blue': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF0066CC), // Swiss Blue
      secondary: const Color(0xFFE6F2FF),
      background: const Color(0xFFF8FAFC), // Cool White
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF333333), // Dark Grey Text
      onBackground: const Color(0xFF64748B),
      error: const Color(0xFFEF4444),
      borderRadius: 8.0,
      borderColor: const Color(0xFFE2E8F0),
      primaryContainer: const Color(0xFFF1F5F9), // Slate 100
      onPrimaryContainer: const Color(0xFF0F172A),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeInOut,
        layoutDensity: 0.95,
        borderRadius: 8.0,
        icons: AppIcons.sharp,
        useGlassEffect: false,
      ),
    ),

    // 4. 🌹 Porcelain Red (绯红白瓷) - White + Red
    'porcelain-red': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFFD32F2F), // Carmine
      secondary: const Color(0xFFFFEBEE),
      background: const Color(0xFFFFFAFA), // Snow
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF333333),
      onBackground: const Color(0xFF757575),
      error: const Color(0xFFB71C1C),
      borderRadius: 12.0,
      borderColor: const Color(0xFFF5F5F5),
      primaryContainer: const Color(0xFFFFEBEE),
      onPrimaryContainer: const Color(0xFFB71C1C),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeOutQuart,
        layoutDensity: 1.0,
        borderRadius: 12.0,
        icons: AppIcons.standard,
        useGlassEffect: true,
      ),
    ),

    // 5. 🔮 Wisteria White (紫藤云烟) - White + Purple
    'wisteria-white': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF8B5CF6), // Violet 500
      secondary: const Color(0xFFF3E8FF),
      background: const Color(0xFFFAF5FF), // Purple 50
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF333333),
      onBackground: const Color(0xFF6B7280),
      error: const Color(0xFFEF4444),
      borderRadius: 16.0,
      borderColor: const Color(0xFFF3E8FF),
      primaryContainer: const Color(0xFFF3E8FF),
      onPrimaryContainer: const Color(0xFF5B21B6),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeInOutCubic,
        layoutDensity: 1.0,
        borderRadius: 16.0,
        icons: AppIcons.rounded,
        useGlassEffect: true,
      ),
    ),

    // 6. 🍊 Amber Glow (晨曦琥珀) - White + Orange
    'amber-glow': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFFF97316), // Orange 500
      secondary: const Color(0xFFFFEDD5),
      background: const Color(0xFFFFF7ED), // Orange 50
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF333333),
      onBackground: const Color(0xFF78716C),
      error: const Color(0xFFEF4444),
      borderRadius: 10.0,
      borderColor: const Color(0xFFFED7AA),
      primaryContainer: const Color(0xFFFFEDD5),
      onPrimaryContainer: const Color(0xFF9A3412),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeOutBack,
        layoutDensity: 1.0,
        borderRadius: 10.0,
        icons: AppIcons.standard,
        useGlassEffect: false,
      ),
    ),

    // 7. 🦢 Graphite Mono (极简石墨) - White + Gray
    'graphite-mono': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF374151), // Gray 700
      secondary: const Color(0xFFF3F4F6),
      background: const Color(0xFFFFFFFF), // Pure White
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF111827), // Gray 900
      onBackground: const Color(0xFF4B5563),
      error: const Color(0xFFEF4444), // Only color allowed is error
      borderRadius: 0.0, // Bauhaus sharp
      borderColor: const Color(0xFFE5E7EB),
      primaryContainer: const Color(0xFFF3F4F6),
      onPrimaryContainer: const Color(0xFF1F2937),
      effect: const AppThemeEffect(
        animationCurve: Curves.linear,
        layoutDensity: 0.85, // Compact
        borderRadius: 0.0,
        icons: AppIcons.sharp,
        useGlassEffect: false,
      ),
    ),

    // 8. 🏖️ Azure Coast (蔚蓝海岸) - White + Cyan
    'azure-coast': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF06B6D4), // Cyan 500
      secondary: const Color(0xFFCFFAFE),
      background: const Color(0xFFECFEFF), // Cyan 50
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF333333),
      onBackground: const Color(0xFF64748B),
      error: const Color(0xFFEF4444),
      borderRadius: 14.0,
      borderColor: const Color(0xFFCFFAFE),
      primaryContainer: const Color(0xFFE0F2FE), // Light Blue 100 mixed
      onPrimaryContainer: const Color(0xFF0E7490),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeInOutSine,
        layoutDensity: 1.0,
        borderRadius: 14.0,
        icons: AppIcons.rounded,
        useGlassEffect: true,
      ),
    ),
  };

  List<String> get availableThemes => _themes.keys.toList();

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
    final  savedTheme = prefs.getString(kThemePreferenceKey);
    if (savedTheme != null && _themes.containsKey(savedTheme)) {
      _currentTheme = _themes[savedTheme]!;
      _currentThemeName = savedTheme;
      notifyListeners();
    } else {
       // Reset to Forest Mint
       _currentTheme = _themes['forest-mint']!;
       _currentThemeName = 'forest-mint';
       notifyListeners();
    }
  }

  Future<void> _savePreference(String themeName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kThemePreferenceKey, themeName);
  }
}
