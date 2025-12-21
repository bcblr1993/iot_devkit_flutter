import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ui/styles/app_theme_effect.dart';

class ThemeManager extends ChangeNotifier {
  static const String _kInfoTheme = 'app-theme';
  
  late ThemeData _currentTheme;
  String _currentThemeName = 'vercel-light';
  
  ThemeData get currentTheme => _currentTheme;
  String get currentThemeName => _currentThemeName;

  ThemeManager() {
    _currentTheme = _themes['vercel-white']!;
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
      
      // 1. 卡片主题
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0, // Flat design trend
        shadowColor: Colors.black.withOpacity(0.1), // Slightly more shadow for Adminix
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: BorderSide(color: borderColor ?? onBackground.withOpacity(0.08)), // Subtle border or custom
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

      // 2. 输入框主题
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.dark 
            ? onBackground.withOpacity(0.05) 
            : onBackground.withOpacity(0.03),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: onBackground.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: error),
        ),
        labelStyle: TextStyle(color: onBackground.withOpacity(0.6)),
        floatingLabelStyle: TextStyle(color: primary, fontWeight: FontWeight.bold),
      ),

      // 3. 按钮主题
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: brightness == Brightness.dark ? Colors.black : Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: brightness == Brightness.dark ? Colors.black : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary.withOpacity(0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),

      // 4. 对话框
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius + 4)),
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: onBackground),
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
        color: surface,
        elevation: 4,
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
      
      // 8. TabBar
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: onBackground.withOpacity(0.6),
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
      ),
    );
  }

  static final Map<String, ThemeData> _themes = {
    // Adminix Emerald (翡翠之都) - Clean SaaS Style
    'adminix-emerald': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF108953), // Adminix Emerald Green
      secondary: const Color(0xFFC5DC6B), // Adminix Lime Green
      background: const Color(0xFFF4F5F2), // Off-white Background
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF1A1A1A),
      onBackground: const Color(0xFF1A1A1A),
      error: const Color(0xFFE11D48),
      borderRadius: 20.0, // High roundness from the Adminix image
      borderColor: const Color(0xFFE5E7EB),
      primaryContainer: const Color(0xFF108953).withOpacity(0.1),
      onPrimaryContainer: const Color(0xFF108953),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeOutQuart,
        layoutDensity: 1.0,
        icons: AppIcons.rounded,
        useGlassEffect: false, // Standard clean UI
      ),
    ),

    // Rivlo Dark (幻夜绿光) - Premium Dark with Neon Accents
    'rivlo-dark': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFFA3FF4D), // Neon Lime
      secondary: const Color(0xFFB1A2FF), // Lavender
      background: const Color(0xFF0F0F0F), // Deep Black
      surface: const Color(0xFF1C1C1E), // Dark Grey Card
      onSurface: const Color(0xFFFFFFFF),
      onBackground: const Color(0xFFECECEC),
      error: const Color(0xFFFF4D4D),
      borderRadius: 24.0, // High roundness from the Rivlo image
      borderColor: const Color(0xFF2C2C2E),
      primaryContainer: const Color(0xFFA3FF4D).withOpacity(0.12),
      onPrimaryContainer: const Color(0xFFA3FF4D),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeInOutExpo,
        layoutDensity: 1.0,
        icons: AppIcons.standard,
        useGlassEffect: false,
      ),
    ),

    // SalesFlow Coral (熔岩珊瑩) - Warm Dark with Coral Accents
    'salesflow-coral': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFFFF6B4A), // Coral Orange
      secondary: const Color(0xFFE8A87C), // Warm Peach
      background: const Color(0xFF121212), // Deep Black
      surface: const Color(0xFF1E1E1E), // Dark Card
      onSurface: const Color(0xFFFFFFFF),
      onBackground: const Color(0xFFE5E5E5),
      error: const Color(0xFFFF5252),
      borderRadius: 16.0, // Modern rounded corners
      borderColor: const Color(0xFF2A2A2A),
      primaryContainer: const Color(0xFFFF6B4A).withOpacity(0.15),
      onPrimaryContainer: const Color(0xFFFF6B4A),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeOutCubic,
        layoutDensity: 1.0,
        icons: AppIcons.standard,
        useGlassEffect: false,
      ),
    ),

    // Rydex Racing (竞速赤焰) - Sport Black with Racing Red
    'rydex-racing': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFFE63946), // Racing Red
      secondary: const Color(0xFFC0C0C0), // Silver Metal
      background: const Color(0xFF0A0A0A), // Pure Black
      surface: const Color(0xFF181818), // Dark Grey Card
      onSurface: const Color(0xFFFFFFFF),
      onBackground: const Color(0xFFF0F0F0),
      error: const Color(0xFFFF3333),
      borderRadius: 8.0, // Sharp, sporty corners
      borderColor: const Color(0xFF2A2A2A),
      primaryContainer: const Color(0xFFE63946).withOpacity(0.12),
      onPrimaryContainer: const Color(0xFFE63946),
      effect: const AppThemeEffect(
        animationCurve: Curves.fastOutSlowIn,
        layoutDensity: 0.95, // Compact sporty feel
        icons: AppIcons.sharp,
        useGlassEffect: false,
      ),
    ),

    // FinFlow Blue (金融蜻篮) - Clean Finance Light Theme
    'finflow-blue': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF2196F3), // Material Blue
      secondary: const Color(0xFF22C55E), // Success Green
      background: const Color(0xFFF8F9FC), // Light Grey Background
      surface: const Color(0xFFFFFFFF), // Pure White Cards
      onSurface: const Color(0xFF1A1A2E),
      onBackground: const Color(0xFF1A1A2E),
      error: const Color(0xFFEF4444),
      borderRadius: 12.0, // Professional rounded corners
      borderColor: const Color(0xFFE5E7EB),
      primaryContainer: const Color(0xFF2196F3).withOpacity(0.08),
      onPrimaryContainer: const Color(0xFF1976D2),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeInOut,
        layoutDensity: 1.0,
        icons: AppIcons.rounded,
        useGlassEffect: false,
      ),
    ),

    // =======================
    // ✨ Minimal / White Themes
    // =======================

    // Vercel White - 极简专业
    'vercel-white': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF000000),
      secondary: const Color(0xFF6B7280),
      background: const Color(0xFFFAFAFA),
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF111827),
      onBackground: const Color(0xFF111827),
      error: const Color(0xFFEF4444),
      borderRadius: 14.0,
      borderColor: const Color(0xFFE5E7EB),
      primaryContainer: const Color(0xFF000000).withOpacity(0.06),
      onPrimaryContainer: const Color(0xFF000000),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeOut,
        layoutDensity: 1.0,
        icons: AppIcons.standard,
        useGlassEffect: false,
      ),
    ),

    // Notion Milk - 柔白文档风
    'notion-milk': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF4F46E5),
      secondary: const Color(0xFF64748B),
      background: const Color(0xFFF7F7F5),
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF1F2937),
      onBackground: const Color(0xFF1F2937),
      error: const Color(0xFFDC2626),
      borderRadius: 12.0,
      borderColor: const Color(0xFFE4E4E7),
      primaryContainer: const Color(0xFF4F46E5).withOpacity(0.08),
      onPrimaryContainer: const Color(0xFF4F46E5),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeInOut,
        layoutDensity: 1.0,
        icons: AppIcons.rounded,
        useGlassEffect: false,
      ),
    ),

    // Apple Frost - 苹果系白
    'apple-frost': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF007AFF),
      secondary: const Color(0xFF34C759),
      background: const Color(0xFFF2F2F7),
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF1C1C1E),
      onBackground: const Color(0xFF1C1C1E),
      error: const Color(0xFFFF3B30),
      borderRadius: 18.0,
      borderColor: const Color(0xFFD1D1D6),
      primaryContainer: const Color(0xFF007AFF).withOpacity(0.1),
      onPrimaryContainer: const Color(0xFF007AFF),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeOutCubic,
        layoutDensity: 1.0,
        icons: AppIcons.rounded,
        useGlassEffect: false,
      ),
    ),

    // =======================
    // 🌙 Dark / Black Themes
    // =======================

    // Carbon Black - 高级暗色
    'carbon-black': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFF38BDF8),
      secondary: const Color(0xFF94A3B8),
      background: const Color(0xFF0B0B0E),
      surface: const Color(0xFF16161A),
      onSurface: const Color(0xFFFFFFFF),
      onBackground: const Color(0xFFE5E7EB),
      error: const Color(0xFFF87171),
      borderRadius: 14.0,
      borderColor: const Color(0xFF262626),
      primaryContainer: const Color(0xFF38BDF8).withOpacity(0.15),
      onPrimaryContainer: const Color(0xFF38BDF8),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeInOut,
        layoutDensity: 1.0,
        icons: AppIcons.standard,
        useGlassEffect: false,
      ),
    ),

    // Midnight Zen - 深蓝护眼
    'midnight-zen': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFF22C55E),
      secondary: const Color(0xFF64748B),
      background: const Color(0xFF0F172A),
      surface: const Color(0xFF1E293B),
      onSurface: const Color(0xFFF8FAFC),
      onBackground: const Color(0xFFE2E8F0),
      error: const Color(0xFFF43F5E),
      borderRadius: 16.0,
      borderColor: const Color(0xFF334155),
      primaryContainer: const Color(0xFF22C55E).withOpacity(0.15),
      onPrimaryContainer: const Color(0xFF22C55E),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeInOut,
        layoutDensity: 1.0,
        icons: AppIcons.standard,
        useGlassEffect: false,
      ),
    ),

    // Obsidian Mono - 极简纯黑
    'obsidian-mono': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFFFFFFFF),
      secondary: const Color(0xFF9CA3AF),
      background: const Color(0xFF000000),
      surface: const Color(0xFF111111),
      onSurface: const Color(0xFFFFFFFF),
      onBackground: const Color(0xFFE5E5E5),
      error: const Color(0xFFEF4444),
      borderRadius: 10.0,
      borderColor: const Color(0xFF222222),
      primaryContainer: const Color(0xFFFFFFFF).withOpacity(0.1),
      onPrimaryContainer: const Color(0xFFFFFFFF),
      effect: const AppThemeEffect(
        animationCurve: Curves.linear,
        layoutDensity: 0.95,
        icons: AppIcons.standard,
        useGlassEffect: false,
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
       // Reset to Vercel White
       _currentTheme = _themes['vercel-white']!;
       _currentThemeName = 'vercel-white';
       notifyListeners();
    }
  }

  Future<void> _savePreference(String themeName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kInfoTheme, themeName);
  }
}
