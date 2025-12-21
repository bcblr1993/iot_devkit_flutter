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
    _currentTheme = _themes['cloud-white']!;
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
        shadowColor: Colors.black.withOpacity(0.05),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    // 1. Terminal Green (终端绿) - Developer Classic
    'terminal-green': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFF00FF41), // Terminal Green
      secondary: const Color(0xFF808080), // Neutral Grey
      background: const Color(0xFF0C0C0C),
      surface: const Color(0xFF1A1A1A),
      onSurface: const Color(0xFFE0E0E0),
      onBackground: const Color(0xFFE0E0E0),
      error: const Color(0xFFFFFF00), // Warning Yellow
      borderRadius: 4.0,
      fontFamily: 'JetBrains Mono',
      borderColor: const Color(0xFF00FF41).withOpacity(0.3),
      primaryContainer: const Color(0xFF00FF41).withOpacity(0.1),
      onPrimaryContainer: const Color(0xFF00FF41),
      effect: const AppThemeEffect(
        animationCurve: Curves.linear, // Instant / Glitchy
        layoutDensity: 0.8, // Compact
        icons: AppIcons.sharp,
      ),
    ),

    // 2. IoT Slate (物联灰) - Industrial Professional
    'iot-slate': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFFFF8C00), // Industrial Orange
      secondary: const Color(0xFF4A90E2), // Cool Blue
      background: const Color(0xFF2B2D30),
      surface: const Color(0xFF3C3F41),
      onSurface: const Color(0xFFD4D4D4),
      onBackground: const Color(0xFFD4D4D4),
      error: const Color(0xFFED4545),
      borderRadius: 6.0,
      borderColor: const Color(0xFFFF8C00).withOpacity(0.5),
      primaryContainer: const Color(0xFFFF8C00).withOpacity(0.1),
      onPrimaryContainer: const Color(0xFFFF8C00),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeOutQuart, // Heavy mechanical
        layoutDensity: 0.9,
        icons: AppIcons.standard, // Standard filled
      ),
    ),

    // 3. Cloud White (云境白) - Modern Clean
    'cloud-white': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF0969DA), // GitHub Blue
      secondary: const Color(0xFF2DA44E), // Success Green
      background: const Color(0xFFFAFBFC),
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF24292F),
      onBackground: const Color(0xFF24292F),
      error: const Color(0xFFCF222E),
      borderRadius: 8.0,
      borderColor: const Color(0xFFD0D7DE),
      primaryContainer: const Color(0xFFF6F8FA),
      onPrimaryContainer: const Color(0xFF0969DA),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeInOutCubic, // Soft floating
        layoutDensity: 1.1, // Spacious
        icons: AppIcons.rounded,
      ),
    ),

    // 4. Midnight Purple (深夜紫) - Eye Comfort
    'midnight-purple': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFFBD93F9), // Lavender
      secondary: const Color(0xFF50FA7B), // Soft Green
      background: const Color(0xFF1E1E2E),
      surface: const Color(0xFF2A2A3E),
      onSurface: const Color(0xFFF8F8F2),
      onBackground: const Color(0xFFF8F8F2),
      error: const Color(0xFFFF79C6),
      borderRadius: 10.0,
      borderColor: const Color(0xFFBD93F9).withOpacity(0.2),
      primaryContainer: const Color(0xFFBD93F9).withOpacity(0.1),
      onPrimaryContainer: const Color(0xFFBD93F9),
      effect: const AppThemeEffect(
        animationCurve: Curves.easeOut,
        layoutDensity: 1.0,
        icons: AppIcons.rounded,
      ),
    ),

    // 5. Arctic Teal (极地青) - Tech Future
    'arctic-teal': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFF00D9FF), // Cyan
      secondary: const Color(0xFF7B61FF), // Tech Purple
      background: const Color(0xFF0A0E27),
      surface: const Color(0xFF131D3A),
      onSurface: const Color(0xFFE6F1FF),
      onBackground: const Color(0xFFE6F1FF),
      error: const Color(0xFFFF4081),
      borderRadius: 12.0,
      borderColor: const Color(0xFF00D9FF).withOpacity(0.2),
      primaryContainer: const Color(0xFF00D9FF).withOpacity(0.1),
      onPrimaryContainer: const Color(0xFF00D9FF),
      effect: const AppThemeEffect(
        animationCurve: Curves.elasticOut, // Springy tech
        layoutDensity: 1.0,
        icons: AppIcons.tech, // Outlined
      ),
    ),

    // 6. Azure Mist (蔚蓝迷雾) - Light Gradient Blue
    'azure-mist': _buildProTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF4FC3F7), // Light Blue 300
      secondary: const Color(0xFF81D4FA), // Light Blue 200
      background: const Color(0xFFF0F7FF), // Very Pale Blue
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF0277BD), // Light Blue 800
      onBackground: const Color(0xFF0277BD),
      error: const Color(0xFFD32F2F),
      borderRadius: 16.0,
      borderColor: const Color(0xFF4FC3F7).withOpacity(0.2),
      primaryContainer: const Color(0xFFE1F5FE), // Light Blue 50
      onPrimaryContainer: const Color(0xFF01579B), // Dark Blue text
      effect: const AppThemeEffect(
        animationCurve: Curves.easeInOutSine, // Very smooth
        layoutDensity: 1.2, // Very Spacious
        icons: AppIcons.rounded,
      ),
    ),

    // 7. Amber Retro (复古琥珀) - 80s CRT Style
    'amber-retro': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFFFFC107), // Amber
      secondary: const Color(0xFFFFD54F), // Light Amber
      background: const Color(0xFF101010), // Near Black
      surface: const Color(0xFF1E1E1E),
      onSurface: const Color(0xFFFFC107), // Amber Text
      onBackground: const Color(0xFFFFC107),
      error: const Color(0xFFD32F2F),
      borderRadius: 4.0, // Terminal style
      borderColor: const Color(0xFFFFC107).withOpacity(0.3),
      primaryContainer: const Color(0xFFFFC107).withOpacity(0.1),
      onPrimaryContainer: const Color(0xFFFFC107),
      effect: const AppThemeEffect(
        animationCurve: Curves.linear, // Instant
        layoutDensity: 0.8, // Compact
        icons: AppIcons.sharp,
      ),
    ),

    // 8. Crimson Ops (赤色警戒) - Mission Critical
    'crimson-ops': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFFFF3D00), // Deep Orange/Red
      secondary: const Color(0xFFFF6E40),
      background: const Color(0xFF050505), // Deep Black
      surface: const Color(0xFF150505), // Dark Red tint
      onSurface: const Color(0xFFFF3D00),
      onBackground: const Color(0xFFFF3D00),
      error: const Color(0xFFB71C1C),
      borderRadius: 4.0,
      borderColor: const Color(0xFFFF3D00).withOpacity(0.3),
      primaryContainer: const Color(0xFFFF3D00).withOpacity(0.1),
      onPrimaryContainer: const Color(0xFFFF3D00),
      effect: const AppThemeEffect(
        animationCurve: Curves.linear, // Instant
        layoutDensity: 0.8, // Compact
        icons: AppIcons.sharp,
      ),
    ),

    // 9. Neon Synth (霓虹合成) - Cyberpunk
    'neon-synth': _buildProTheme(
      brightness: Brightness.dark,
      primary: const Color(0xFFD500F9), // Neon Purple
      secondary: const Color(0xFF00E5FF), // Cyan
      background: const Color(0xFF0F0518), // Deep  Purple Black
      surface: const Color(0xFF1A0A2A),
      onSurface: const Color(0xFFE1BEE7), // Light Purple Text
      onBackground: const Color(0xFFE1BEE7),
      error: const Color(0xFFFF4081),
      borderRadius: 4.0,
      borderColor: const Color(0xFFD500F9).withOpacity(0.3),
      primaryContainer: const Color(0xFFD500F9).withOpacity(0.1),
      onPrimaryContainer: const Color(0xFFD500F9),
      effect: const AppThemeEffect(
        animationCurve: Curves.linear, // Instant
        layoutDensity: 0.8, // Compact
        icons: AppIcons.sharp,
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
    // Fallback to vercel-light if saved theme is invalid (from old version)
    if (savedTheme != null && _themes.containsKey(savedTheme)) {
      _currentTheme = _themes[savedTheme]!;
      _currentThemeName = savedTheme;
      notifyListeners();
    } else {
       // Force default if legacy theme found
       _currentTheme = _themes['cloud-white']!;
       _currentThemeName = 'cloud-white';
       notifyListeners();
    }
  }

  Future<void> _savePreference(String themeName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kInfoTheme, themeName);
  }
}
