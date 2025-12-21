import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager extends ChangeNotifier {
  static const String _kInfoTheme = 'app-theme';
  
  late ThemeData _currentTheme;
  String _currentThemeName = 'vercel-light';
  
  ThemeData get currentTheme => _currentTheme;
  String get currentThemeName => _currentThemeName;

  ThemeManager() {
    _currentTheme = _themes['vercel-light']!;
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
          side: BorderSide(color: onBackground.withOpacity(0.08)), // Subtle border
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
    // 1. Vercel Light (极简光)
    // High contrast, clean, professional. Inspired by Vercel/Next.js design.
    'vercel-light': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF000000), // Black primary
      secondary: const Color(0xFF333333),
      background: const Color(0xFFFFFFFF),
      surface: const Color(0xFFF9FAFB), // Gray 50
      onSurface: const Color(0xFF111827), // Gray 900
      onBackground: const Color(0xFF111827),
      error: const Color(0xFFE00000),
      borderRadius: 6.0,
    ),

    // 2. GitHub Dark (GitHub 暗黑)
    // Comfortable, developer-focused.
    'github-dark': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFF58A6FF), // GitHub Blue
      secondary: const Color(0xFF238636), // GitHub Green
      background: const Color(0xFF0D1117), // GitHub Bg
      surface: const Color(0xFF161B22), // GitHub Surface
      onSurface: const Color(0xFFC9D1D9), // GitHub Text
      onBackground: const Color(0xFFC9D1D9),
      error: const Color(0xFFDA3633),
      borderRadius: 6.0,
    ),

    // 3. Dracula (吸血鬼)
    // High contrast, vibrant colors.
    'dracula': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFFBD93F9), // Purple
      secondary: const Color(0xFFFF79C6), // Pink
      background: const Color(0xFF282A36),
      surface: const Color(0xFF44475A),
      onSurface: const Color(0xFFF8F8F2),
      onBackground: const Color(0xFFF8F8F2),
      error: const Color(0xFFFF5555),
      borderRadius: 8.0,
    ),

    // 4. Monokai Pro (莫诺凯)
    // Sharp, professional coding theme.
    'monokai-pro': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFFFFD866), // Yellow
      secondary: const Color(0xFFA9DC76), // Green
      background: const Color(0xFF2D2A2E), // Dark Grey
      surface: const Color(0xFF403E41), 
      onSurface: const Color(0xFFFCFCFA),
      onBackground: const Color(0xFFFCFCFA),
      error: const Color(0xFFFF6188), // Red
      borderRadius: 6.0,
    ),

    // 5. Nordic Snow (北欧雪)
    // Cool, blue-gray palette. Calming.
    'nordic-snow': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF5E81AC), // Blue
      secondary: const Color(0xFF88C0D0), // Cyan
      background: const Color(0xFFECEFF4), // Snow storm
      surface: const Color(0xFFE5E9F0), 
      onSurface: const Color(0xFF2E3440), // Polar Night
      onBackground: const Color(0xFF2E3440),
      error: const Color(0xFFBF616A),
      borderRadius: 12.0,
    ),

    // 6. Solarized Dark (日蚀暗)
    // Distinctive, low contrast, easy on eyes.
    'solarized-dark': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFF268BD2), // Blue
      secondary: const Color(0xFFB58900), // Yellow
      background: const Color(0xFF002B36), // Base03
      surface: const Color(0xFF073642), // Base02
      onSurface: const Color(0xFF839496), // Base0
      onBackground: const Color(0xFF839496),
      error: const Color(0xFFDC322F),
      borderRadius: 4.0,
    ),

    // 7. Deep Ocean (深邃海)
    // Modern Slate/Sky Palette (Tailwind style).
    'deep-ocean': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFF38BDF8), // Sky 400
      secondary: const Color(0xFF0EA5E9), // Sky 500
      background: const Color(0xFF0F172A), // Slate 900
      surface: const Color(0xFF1E293B), // Slate 800
      onSurface: const Color(0xFFF1F5F9), // Slate 100
      onBackground: const Color(0xFFF1F5F9),
      error: const Color(0xFFEF4444),
      borderRadius: 12.0,
    ),

    // 8. Sakura Pink (樱花粉)
    // Soft, welcoming, pastel.
    'sakura-pink': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFFF43F5E), // Rose 500
      secondary: const Color(0xFFFB7185), // Rose 400
      background: const Color(0xFFFFF1F2), // Rose 50
      surface: const Color(0xFFFFFFFF), 
      onSurface: const Color(0xFF881337), // Rose 900
      onBackground: const Color(0xFF881337),
      error: const Color(0xFF9F1239),
      borderRadius: 16.0,
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
       _currentTheme = _themes['vercel-light']!;
       _currentThemeName = 'vercel-light';
       notifyListeners();
    }
  }

  Future<void> _savePreference(String themeName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kInfoTheme, themeName);
  }
}
