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
    // 🟢 GREEN THEMES
    
    // Matrix Emerald (矩阵翡翠) - Dark Green Mech Style
    'matrix-emerald': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFF00FF41), // Matrix Neon Green
      secondary: const Color(0xFF0D0208), 
      background: const Color(0xFF0D0208), // Pitch Black
      surface: const Color(0xFF1A1A1D), // Dark Grey Card
      onSurface: const Color(0xFF00FF41),
      onBackground: const Color(0xFF00FF41),
      error: const Color(0xFFFF3131),
      borderRadius: 12.0,
      borderColor: const Color(0xFF00FF41).withOpacity(0.3),
      primaryContainer: const Color(0xFF00FF41).withOpacity(0.1),
      onPrimaryContainer: const Color(0xFF00FF41),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeInCirc,
        layoutDensity: 1.0,
        icons: AppIcons.sharp,
        useGlassEffect: false,
      ),
    ),

    // Forest Mint (森林薄荷) - Clean White Green
    'forest-mint': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF10B981), // Emerald Green
      secondary: const Color(0xFFD1FAE5),
      background: const Color(0xFFF0FDF4), // Mint White
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF065F46),
      onBackground: const Color(0xFF064E3B),
      error: const Color(0xFFEF4444),
      borderRadius: 16.0,
      borderColor: const Color(0xFFD1FAE5),
      primaryContainer: const Color(0xFF10B981).withOpacity(0.1),
      onPrimaryContainer: const Color(0xFF047857),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeInOut,
        layoutDensity: 1.0,
        icons: AppIcons.rounded,
        useGlassEffect: false,
      ),
    ),

    // 🔵 BLUE THEMES

    // Arctic Blue (极地冰蓝) - Clean Professional Blue
    'arctic-blue': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF0EA5E9), // Sky Blue
      secondary: const Color(0xFFE0F2FE),
      background: const Color(0xFFF8FAFC), // Ice White
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF0F172A),
      onBackground: const Color(0xFF1E293B),
      error: const Color(0xFFEF4444),
      borderRadius: 14.0,
      borderColor: const Color(0xFFE2E8F0),
      primaryContainer: const Color(0xFF0EA5E9).withOpacity(0.1),
      onPrimaryContainer: const Color(0xFF0369A1),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeOut,
        layoutDensity: 1.0,
        icons: AppIcons.rounded,
        useGlassEffect: false,
      ),
    ),

    // Deep Ocean (深海蔚蓝) - Tech Dark Blue
    'deep-ocean': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFF3B82F6), // Royal Blue
      secondary: const Color(0xFF1E3A8A),
      background: const Color(0xFF0C1222), // Deep Ocean Black
      surface: const Color(0xFF1E293B), // Navy Card
      onSurface: const Color(0xFFF1F5F9),
      onBackground: const Color(0xFFE2E8F0),
      error: const Color(0xFFF87171),
      borderRadius: 16.0,
      borderColor: const Color(0xFF334155),
      primaryContainer: const Color(0xFF3B82F6).withOpacity(0.15),
      onPrimaryContainer: const Color(0xFF3B82F6),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeInOutCubic,
        layoutDensity: 1.0,
        icons: AppIcons.standard,
        useGlassEffect: false,
      ),
    ),

    // 🔴 RED THEMES

    // Crimson Night (深红暗夜) - Gaming Dark Red
    'crimson-night': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFFDC2626), // Deep Red
      secondary: const Color(0xFF7F1D1D),
      background: const Color(0xFF0A0A0A), // Pure Black
      surface: const Color(0xFF1C1C1C), // Carbon Card
      onSurface: const Color(0xFFFEE2E2),
      onBackground: const Color(0xFFF9FAFB),
      error: const Color(0xFFFF4D4D),
      borderRadius: 8.0, // Sharp corners for gaming feel
      borderColor: const Color(0xFF262626),
      primaryContainer: const Color(0xFFDC2626).withOpacity(0.12),
      onPrimaryContainer: const Color(0xFFDC2626),
      effect: const AppThemeEffect(
        animationCurve: Curves.fastOutSlowIn,
        layoutDensity: 0.95,
        icons: AppIcons.sharp,
        useGlassEffect: false,
      ),
    ),

    // Ruby Elegance (红宝石雅致) - Luxury Dark Red
    'ruby-elegance': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFFE11D48), // Rose Red
      secondary: const Color(0xFF881337),
      background: const Color(0xFF18181B), // Graphite Background
      surface: const Color(0xFF27272A), // Concrete Card
      onSurface: const Color(0xFFFFF1F2),
      onBackground: const Color(0xFFF4F4F5),
      error: const Color(0xFFFB7185),
      borderRadius: 20.0, // Smooth luxury corners
      borderColor: const Color(0xFF3F3F46),
      primaryContainer: const Color(0xFFE11D48).withOpacity(0.1),
      onPrimaryContainer: const Color(0xFFE11D48),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeOutQuart,
        layoutDensity: 1.0,
        icons: AppIcons.rounded,
        useGlassEffect: false,
      ),
    ),

    // ⚫ BLACK THEMES

    // Void Black (虚空纯黑) - OLED Minimalist
    'void-black': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFFFFFFFF), // Pure White
      secondary: const Color(0xFF404040),
      background: const Color(0xFF000000), // OLED Black
      surface: const Color(0xFF0A0A0A), // Near Black Card
      onSurface: const Color(0xFFFFFFFF),
      onBackground: const Color(0xFFE5E5E5),
      error: const Color(0xFFEF4444),
      borderRadius: 10.0,
      borderColor: const Color(0xFF262626),
      primaryContainer: const Color(0xFFFFFFFF).withOpacity(0.08),
      onPrimaryContainer: const Color(0xFFFFFFFF),
      effect: const AppThemeEffect(
        animationCurve: Curves.linear,
        layoutDensity: 1.0,
        icons: AppIcons.standard,
        useGlassEffect: false,
      ),
    ),

    // Graphite Pro (石墨专业版) - Developer Grey
    'graphite-pro': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFF06B6D4), // Cyan Accent
      secondary: const Color(0xFF3F3F46),
      background: const Color(0xFF18181B), // Zinc Black
      surface: const Color(0xFF27272A), // Zinc Gray Card
      onSurface: const Color(0xFFF4F4F5),
      onBackground: const Color(0xFFD1D1D6),
      error: const Color(0xFFEF4444),
      borderRadius: 12.0,
      borderColor: const Color(0xFF3F3F46),
      primaryContainer: const Color(0xFF06B6D4).withOpacity(0.12),
      onPrimaryContainer: const Color(0xFF22D3EE),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeInOut,
        layoutDensity: 1.0,
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
