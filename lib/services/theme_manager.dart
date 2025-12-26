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
    // 1. 🌲 Forest Mint (保留 - 用户指定)
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

    // 2. 👔 Corporate Slate (商务板岩) - 专业、克制、像 Linear/Vercel 风格
    'corporate-slate': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF0F172A), // Slate 900
      secondary: const Color(0xFF334155), // Slate 700
      background: const Color(0xFFF8FAFC), // Slate 50
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF020617), // Slate 950
      onBackground: const Color(0xFF475569), // Slate 600
      error: const Color(0xFFBE123C), // Rose 700
      borderRadius: 6.0, // Sharp, professional corners
      borderColor: const Color(0xFFE2E8F0), // Slate 200
      primaryContainer: const Color(0xFFF1F5F9), // Slate 100
      onPrimaryContainer: const Color(0xFF0F172A),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeInOut,
        layoutDensity: 0.9, // Denser layout for pro tools
        borderRadius: 6.0,
        icons: AppIcons.sharp,
      ),
    ),

    // 3. 🌌 Cosmic Void (深空虚无) - 极致深黑，点缀紫色星光，适合长时间夜间工作
    'cosmic-void': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFF6366F1), // Indigo 500
      secondary: const Color(0xFF4F46E5),
      background: const Color(0xFF000000), // Pure Black (OLED Friendly)
      surface: const Color(0xFF09090B), // Zinc 950
      onSurface: const Color(0xFFFAFAFA), // Zinc 50
      onBackground: const Color(0xFFA1A1AA), // Zinc 400
      error: const Color(0xFFF87171),
      borderRadius: 12.0,
      borderColor: const Color(0xFF27272A), // Zinc 800
      primaryContainer: const Color(0xFF1E1B4B), // Indigo 950
      onPrimaryContainer: const Color(0xFFC7D2FE), // Indigo 200
      effect: const AppThemeEffect(
        animationCurve: Curves.easeOutExpo,
        layoutDensity: 1.0,
        borderRadius: 12.0,
        icons: AppIcons.tech,
        useGlassEffect: false, // Solid performance
      ),
    ),

    // 4. 🍵 Matcha Mochi (抹茶麻薯) - 治愈系，低饱和度，纸张质感
    'matcha-mochi': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF5D7052), // Muted Green
      secondary: const Color(0xFF8B9D83),
      background: const Color(0xFFF2F0E9), // Warm Beige Paper
      surface: const Color(0xFFFCFAF7), // Off-white
      onSurface: const Color(0xFF44403C), // Warm Grey
      onBackground: const Color(0xFF57534E),
      error: const Color(0xFFB91C1C),
      borderRadius: 24.0, // Very round, soft
      borderColor: const Color(0xFFE7E5E4),
      primaryContainer: const Color(0xFFE4E9E1),
      onPrimaryContainer: const Color(0xFF3F4E38),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeOutBack, // Bouncy
        layoutDensity: 1.1, // Relaxed
        borderRadius: 24.0,
        icons: AppIcons.rounded,
      ),
    ),

    // 5. ⚡ Neon Cyberpunk (霓虹赛博) - 电竞风，高对比度，故障艺术色
    'neon-cyberpunk': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFFF000FF), // Magenta
      secondary: const Color(0xFF00FFFF), // Cyan
      background: const Color(0xFF050510), // Deep Blue Black
      surface: const Color(0xFF13132B),
      onSurface: const Color(0xFFFFFFFF),
      onBackground: const Color(0xFFB8B8FF),
      error: const Color(0xFFFF0055),
      borderRadius: 4.0, // Cyber angular
      borderColor: const Color(0xFF502090),
      primaryContainer: const Color(0xFF35003E),
      onPrimaryContainer: const Color(0xFFFFCCFF),
      effect: const AppThemeEffect(
        animationCurve: Curves.elasticOut,
        layoutDensity: 1.0,
        borderRadius: 4.0,
        icons: AppIcons.tech,
      ),
    ),

    // 6. 🌊 Nordic Frost (北欧霜雪) - 极简主义，冰蓝冷调
    'nordic-frost': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF0EA5E9), // Sky 500
      secondary: const Color(0xFF7DD3FC),
      background: const Color(0xFFF0F9FF), // Sky 50
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF0C4A6E), // Sky 900
      onBackground: const Color(0xFF334155),
      error: const Color(0xFFEF4444),
      borderRadius: 16.0,
      borderColor: const Color(0xFFBAE6FD), // Sky 200
      primaryContainer: const Color(0xFFE0F2FE),
      onPrimaryContainer: const Color(0xFF0369A1),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeOutSine,
        layoutDensity: 1.0,
        borderRadius: 16.0,
        icons: AppIcons.standard,
        useGlassEffect: true, // Icy glass
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
