import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ui/styles/app_theme_effect.dart';

class ThemeManager extends ChangeNotifier {
  static const String _kInfoTheme = 'app-theme';
  
  late ThemeData _currentTheme;
  String _currentThemeName = 'forest-mint';
  
  ThemeData get currentTheme => _currentTheme;
  String get currentThemeName => _currentThemeName;

  ThemeManager() {
    _currentTheme = _themes['forest-mint']!;
    _loadPreference();
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

    final TextTheme textTheme = Typography.material2021(platform: TargetPlatform.macOS)
        .englishLike
        .merge(Typography.material2021(platform: TargetPlatform.macOS).black)
        .apply(
          bodyColor: onBackground, 
          displayColor: onBackground,
          fontFamily: fontFamily, 
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
        effect ?? const AppThemeEffect(
          animationCurve: Curves.easeInOut, 
          layoutDensity: 1.0, 
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
    // 🟢 森林薄荷 (Forest Mint) - Modern Clean Green
    'forest-mint': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF047857), // 加深的翡翠绿，对比度更好
      secondary: const Color(0xFFD1FAE5),
      background: const Color(0xFFF8FDF9), // 薄荷白
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF1F2937),
      onBackground: const Color(0xFF475569), // 调深，提高可读性
      error: const Color(0xFFDC2626),
      borderRadius: 20.0,
      borderColor: const Color(0xFFE5E7EB).withOpacity(0.8),
      primaryContainer: const Color(0xFF047857).withOpacity(0.08),
      onPrimaryContainer: const Color(0xFF065F46),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeOutCubic,
        layoutDensity: 1.0,
        icons: AppIcons.rounded,
        useGlassEffect: true,
      ),
    ),

    // 🔵 极地冰蓝 (Arctic Blue) - Modern Professional Blue  
    'arctic-blue': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF0284C7), // 深邃天空蓝
      secondary: const Color(0xFFF0F9FF), // 更淡的蓝色
      background: const Color(0xFFF8FAFC), // 冰晶白
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF1E293B),
      onBackground: const Color(0xFF475569), // 调深，提高可读性
      error: const Color(0xFFDC2626),
      borderRadius: 20.0,
      borderColor: const Color(0xFFE2E8F0).withOpacity(0.9),
      primaryContainer: const Color(0xFF0284C7).withOpacity(0.08),
      onPrimaryContainer: const Color(0xFF0369A1),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeOutCubic,
        layoutDensity: 1.0,
        icons: AppIcons.rounded,
        useGlassEffect: true,
      ),
    ),

    // 🌙 深夜蓝调 (Midnight Blue) - Professional Dark Theme
    'midnight-blue': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFF38BDF8), // 明亮天蓝色
      secondary: const Color(0xFF1E3A8A),
      background: const Color(0xFF0F172A), // 深蓝背景
      surface: const Color(0xFF1E293B), // 卡片背景
      onSurface: const Color(0xFFE2E8F0), // 浅色文字
      onBackground: const Color(0xFFCBD5E1), // 次要文字
      error: const Color(0xFFEF4444),
      borderRadius: 20.0,
      borderColor: const Color(0xFF334155),
      primaryContainer: const Color(0xFF38BDF8).withOpacity(0.15),
      onPrimaryContainer: const Color(0xFF7DD3FC),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeOutCubic,
        layoutDensity: 1.0,
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
    final savedTheme = prefs.getString(_kInfoTheme);
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
    await prefs.setString(_kInfoTheme, themeName);
  }
}
