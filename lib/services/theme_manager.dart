import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager extends ChangeNotifier {
  static const String _kInfoTheme = 'app-theme';
  
  late ThemeData _currentTheme;
  String _currentThemeName = 'vercel-light';
  
  ThemeData get currentTheme => _currentTheme;
  String get currentThemeName => _currentThemeName;

  ThemeManager() {
    _currentTheme = _themes['neon-core']!;
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
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: brightness == Brightness.dark ? Colors.black : Colors.white,
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
      fontFamily: fontFamily,
      
      // 1. 卡片主题
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0, // Flat design trend
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: BorderSide(color: borderColor ?? onBackground.withOpacity(0.08)), // Subtle border or custom
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
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

      // 4. 对话框与 SnackBar
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius + 4)),
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: onBackground),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: secondary,
        contentTextStyle: TextStyle(color: brightness == Brightness.dark ? Colors.black : Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
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
        backgroundColor: surface,
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
        shape: const Border(), // Remove borders when expanded
        collapsedShape: const Border(),
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
    // 1. Neon Core (霓虹核心) - Cyberpunk/Industrial (Default)
    'neon-core': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFF00F0FF), // Cyber Neon (Cyan)
      secondary: const Color(0xFF7000FF), // Electric Purple
      background: const Color(0xFF0B0E14), // Void Blue
      surface: const Color(0xFF1A1F29), // Lighter Gunmetal for separation
      onSurface: const Color(0xFFE2E8F0), 
      onBackground: const Color(0xFFE2E8F0),
      error: const Color(0xFFFF2E54), 
      borderRadius: 12.0,
      fontFamily: 'JetBrains Mono',
    ),

    // 2. Phantom Violet (幽灵紫) - CoinCore/Webwallet Inspired
    'phantom-violet': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFFD946EF), // Fuchsia Pink
      secondary: const Color(0xFF8B5CF6), // Violet
      background: const Color(0xFF0F0518), // Deepest Purple Black
      surface: const Color(0xFF251842), // Dark Violet Surface
      onSurface: const Color(0xFFF3E8FF), // Pale Purple
      onBackground: const Color(0xFFF3E8FF),
      error: const Color(0xFFFF3366),
      borderRadius: 16.0,
    ),

    // 3. Aerix Amber (琥珀工控) - Aerix Inspired
    'aerix-amber': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFFFF9F1C), // Safety Orange/Amber
      secondary: const Color(0xFF2EC4B6), // Teal
      background: const Color(0xFF011627), // Deep Navy
      surface: const Color(0xFF0B253A), // Lighter Navy
      onSurface: const Color(0xFFFDFFFC), 
      onBackground: const Color(0xFFE2E8F0),
      error: const Color(0xFFE71D36),
      borderRadius: 4.0, // Sharper, industrial look
    ),

    // 4. Vitality Lime (活力青柠) - Swirly Inspired
    'vitality-lime': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF84CC16), // Lime 500
      secondary: const Color(0xFF10B981), // Emerald
      background: const Color(0xFFF7FEE7), // Lime 50
      surface: const Color(0xFFFFFFFF), 
      onSurface: const Color(0xFF3F6212), // Dark Forest Green for readability
      onBackground: const Color(0xFF3F6212),
      error: const Color(0xFFEF4444),
      borderRadius: 20.0, // Very round, organic
    ),

    // 5. Azure Radiance (蔚蓝光辉) - Sooni Inspired
    'azure-radiance': _buildProTheme(
      brightness: Brightness.light, // Can be light or dark, Sooni is bright blue
      primary: const Color(0xFF2563EB), // Royal Blue
      secondary: const Color(0xFF00C4B4), // Electric Teal accent
      background: const Color(0xFFF8FAFC), // Very pale blue-grey
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF1E3A8A), // Blue 900
      onBackground: const Color(0xFF1E3A8A),
      error: const Color(0xFFDC2626),
      borderRadius: 4.0, // Sharp, modern
    ),

    // 6. Glassy Ice (冰川玻璃) - One Click Apps Inspired
    'glassy-ice': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF6366F1), // Indigo
      secondary: const Color(0xFFA5B4FC), // Indigo 200
      background: const Color(0xFFF3F4F6), // Cool Grey
      surface: const Color(0xFFFFFFFF), // Pure white for glass effect
      onSurface: const Color(0xFF374151), // Grey 700
      onBackground: const Color(0xFF374151),
      error: const Color(0xFFF87171),
      borderRadius: 12.0,
    ),

    // 7. Minimal White (极简白) - Vercel Light
    'minimal-white': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF000000), 
      secondary: const Color(0xFF666666),
      background: const Color(0xFFFFFFFF),
      surface: const Color(0xFFFAFAFA), 
      onSurface: const Color(0xFF000000),
      onBackground: const Color(0xFF000000),
      error: const Color(0xFFE00000),
      borderRadius: 6.0,
    ),

    // 8. Classic Dark (经典黑) - GitHub Dark
    'classic-dark': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFF58A6FF), 
      secondary: const Color(0xFF238636),
      background: const Color(0xFF0D1117),
      surface: const Color(0xFF161B22),
      onSurface: const Color(0xFFC9D1D9),
      onBackground: const Color(0xFFC9D1D9),
      error: const Color(0xFFDA3633),
      borderRadius: 6.0,
    ),
    // 10. Deep Glass (磨砂黑) - Textured, Blurred
    'deep-glass': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFF00F0FF), // Cyber Cyan accents
      secondary: const Color(0xFFBD93F9), // Purple accents
      background: const Color(0xFF000000), // Pure black background
      surface: const Color(0xFFFFFFFF).withOpacity(0.08), // Very transparent white
      onSurface: const Color(0xFFFFFFFF),
      onBackground: const Color(0xFFFFFFFF), 
      error: const Color(0xFFFF5555),
      borderRadius: 16.0,
      borderColor: const Color(0xFFFFFFFF).withOpacity(0.1),
    ),

    // 11. Clear Glass (磨砂白) - Icy, Blurred
    'clear-glass': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF2563EB), // Royal Blue
      secondary: const Color(0xFF3B82F6), // Sky Blue
      background: const Color(0xFFE2E8F0), // Slate 200 background
      surface: const Color(0xFFFFFFFF).withOpacity(0.5), // Semi-transparent white
      onSurface: const Color(0xFF1E293B), // Slate 800
      onBackground: const Color(0xFF1E293B),
      error: const Color(0xFFEF4444),
      borderRadius: 16.0,
      borderColor: const Color(0xFFFFFFFF).withOpacity(0.4),
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
    // Fallback to vercel-light if saved theme is invalid (from old version)
    if (savedTheme != null && _themes.containsKey(savedTheme)) {
      _currentTheme = _themes[savedTheme]!;
      _currentThemeName = savedTheme;
      notifyListeners();
    } else {
       // Force default if legacy theme found
       _currentTheme = _themes['neon-core']!;
       _currentThemeName = 'neon-core';
       notifyListeners();
    }
  }

  Future<void> _savePreference(String themeName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kInfoTheme, themeName);
  }
}
