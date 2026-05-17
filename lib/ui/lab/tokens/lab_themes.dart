// lib/ui/lab/tokens/lab_themes.dart
//
// Lab Console — 8 themes (5 dark + 3 light). Every theme is built from
// the SAME structural recipe so swapping has no layout cost.
//
//   id         brightness  accent
//   ───────────────────────────────────
//   signal     dark        signal lime  ← default
//   plasma     dark        magenta
//   cobalt     dark        electric blue
//   amber      dark        crt amber
//   mint       dark        mint teal
//   paper      light       leaf green
//   linen      light       terracotta
//   slate      light       cobalt blue

import 'package:flutter/material.dart';
import 'oklch.dart';
import 'lab_tokens.dart';
import 'lab_text_theme.dart';

/// A complete Lab Console theme: id + name + assembled [ThemeData].
@immutable
class LabTheme {
  final String id;
  final String name;
  final String tag;
  final String note;
  final Brightness brightness;
  final ColorScheme colorScheme;
  final LabTokens tokens;

  const LabTheme({
    required this.id,
    required this.name,
    required this.tag,
    required this.note,
    required this.brightness,
    required this.colorScheme,
    required this.tokens,
  });

  /// Build a [ThemeData] ready to hand to MaterialApp.
  /// All component overrides (FilledButton, OutlinedButton, Inputs, Cards…)
  /// pull from this theme so widgets read the right colors automatically.
  ThemeData get themeData {
    final tt = labTextTheme(colorScheme, tokens);

    OutlinedBorder roundedBorder([double r = 5]) => RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r),
        );

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: tt,
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      dividerColor: colorScheme.outlineVariant,
      extensions: <ThemeExtension<dynamic>>[tokens],

      // — Buttons ——————————————————————————————————————————————
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 30),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          textStyle: tt.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          shape: roundedBorder(tokens.rSm + 1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 30),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          side: BorderSide(color: colorScheme.outline),
          foregroundColor: colorScheme.onSurface,
          textStyle: tt.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          shape: roundedBorder(tokens.rSm + 1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 30),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor: tokens.body,
          textStyle: tt.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          shape: roundedBorder(tokens.rSm + 1),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(30, 30),
          foregroundColor: colorScheme.onSurfaceVariant,
        ),
      ),

      // — Inputs ——————————————————————————————————————————————
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: colorScheme.surface,
        hintStyle: tt.bodySmall?.copyWith(color: tokens.faint),
        labelStyle: tt.labelSmall?.copyWith(color: tokens.faint),
        floatingLabelStyle: tt.labelSmall?.copyWith(color: colorScheme.primary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.rSm + 1),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.rSm + 1),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.rSm + 1),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.rSm + 1),
          borderSide: BorderSide(color: colorScheme.error),
        ),
      ),

      // — Cards / Dialogs / Tooltip ————————————————————————————————
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(tokens.rLg),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(tokens.rXl),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          border: Border.all(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(tokens.rSm),
        ),
        textStyle: tt.bodySmall?.copyWith(color: colorScheme.onSurface),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        waitDuration: const Duration(milliseconds: 400),
      ),

      // — Misc ————————————————————————————————————————————————
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        contentTextStyle: tt.bodySmall?.copyWith(color: colorScheme.onSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(tokens.rMd),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.10),
        selectedIconTheme: IconThemeData(color: colorScheme.primary, size: 22),
        unselectedIconTheme:
            IconThemeData(color: colorScheme.onSurfaceVariant, size: 22),
        selectedLabelTextStyle: tt.labelMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: tt.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        useIndicator: true,
      ),
    );
  }
}

// ── builder ──────────────────────────────────────────────────────────
//
// Saves writing the same ColorScheme keys 8 times. The `_T` struct
// mirrors the token shape from the design-system page 1:1.

class _T {
  final String id, name, tag, note;
  final Brightness b;
  // OKLCH triples → resolved at build time
  final List<double> bg, surface, surface2, border, borderSoft;
  final List<double> text, body, muted, faint;
  final List<double> accent, accentDim, accentInk;
  final List<double> ok, warn, err, info;
  const _T({
    required this.id,
    required this.name,
    required this.tag,
    required this.note,
    required this.b,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.borderSoft,
    required this.text,
    required this.body,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.accentDim,
    required this.accentInk,
    required this.ok,
    required this.warn,
    required this.err,
    required this.info,
  });
}

Color _c(List<double> v) => oklch(v[0], v[1], v[2]);

LabTheme _build(_T t) {
  final scheme = ColorScheme(
    brightness: t.b,
    primary: _c(t.accent),
    onPrimary: _c(t.accentInk),
    primaryContainer:
        Color.alphaBlend(_c(t.accent).withValues(alpha: .18), _c(t.surface)),
    onPrimaryContainer: _c(t.accent),
    secondary: _c(t.info),
    onSecondary:
        t.b == Brightness.dark ? const Color(0xff0a0e16) : Colors.white,
    secondaryContainer:
        Color.alphaBlend(_c(t.info).withValues(alpha: .16), _c(t.surface)),
    onSecondaryContainer: _c(t.info),
    tertiary: _c(t.warn),
    onTertiary: t.b == Brightness.dark ? const Color(0xff14100a) : Colors.white,
    tertiaryContainer:
        Color.alphaBlend(_c(t.warn).withValues(alpha: .16), _c(t.surface)),
    onTertiaryContainer: _c(t.warn),
    error: _c(t.err),
    onError: t.b == Brightness.dark ? const Color(0xff14070a) : Colors.white,
    errorContainer:
        Color.alphaBlend(_c(t.err).withValues(alpha: .16), _c(t.surface)),
    onErrorContainer: _c(t.err),
    surface: _c(t.bg),
    onSurface: _c(t.text),
    surfaceContainerLowest: _c(t.surface),
    surfaceContainerLow: _c(t.surface2),
    surfaceContainer: _c(t.surface2),
    surfaceContainerHigh: _c(t.surface2),
    surfaceContainerHighest: _c(t.surface2),
    onSurfaceVariant: _c(t.muted),
    outline: _c(t.border),
    outlineVariant: _c(t.borderSoft),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: _c(t.text),
    onInverseSurface: _c(t.bg),
    inversePrimary: _c(t.accentDim),
  );

  final tokens = LabTokens(
    ok: _c(t.ok),
    warn: _c(t.warn),
    info: _c(t.info),
    body: _c(t.body),
    faint: _c(t.faint),
    accentDim: _c(t.accentDim),
    accentInk: _c(t.accentInk),
  );

  return LabTheme(
    id: t.id,
    name: t.name,
    tag: t.tag,
    note: t.note,
    brightness: t.b,
    colorScheme: scheme,
    tokens: tokens,
  );
}

// ── 8 themes — values match design-system tokens.jsx ─────────────────

final LabTheme labThemeSignal = _build(const _T(
  id: 'signal',
  name: 'Signal',
  tag: 'default · lime',
  note: '冷灰底 · 信号绿口音 · 实验室仪表盘默认主题',
  b: Brightness.dark,
  bg: [0.18, 0.008, 240],
  surface: [0.215, 0.008, 240],
  surface2: [0.245, 0.008, 240],
  border: [0.32, 0.008, 240],
  borderSoft: [0.26, 0.008, 240],
  text: [0.94, 0.005, 240],
  body: [0.86, 0.005, 240],
  muted: [0.62, 0.008, 240],
  faint: [0.45, 0.008, 240],
  accent: [0.82, 0.17, 145],
  accentDim: [0.55, 0.13, 145],
  accentInk: [0.18, 0.04, 145],
  ok: [0.82, 0.17, 145],
  warn: [0.80, 0.16, 75],
  err: [0.70, 0.19, 25],
  info: [0.75, 0.12, 230],
));

final LabTheme labThemePlasma = _build(const _T(
  id: 'plasma',
  name: 'Plasma',
  tag: 'cyberpunk · magenta',
  note: '紫黑底 · 品红口音 · 偏赛博朋克氛围',
  b: Brightness.dark,
  bg: [0.175, 0.015, 305],
  surface: [0.215, 0.015, 305],
  surface2: [0.250, 0.018, 305],
  border: [0.34, 0.022, 305],
  borderSoft: [0.28, 0.018, 305],
  text: [0.94, 0.008, 305],
  body: [0.86, 0.008, 305],
  muted: [0.62, 0.012, 305],
  faint: [0.45, 0.012, 305],
  accent: [0.74, 0.20, 340],
  accentDim: [0.52, 0.17, 340],
  accentInk: [0.16, 0.05, 340],
  ok: [0.78, 0.18, 165],
  warn: [0.80, 0.16, 75],
  err: [0.72, 0.21, 18],
  info: [0.78, 0.16, 260],
));

final LabTheme labThemeCobalt = _build(const _T(
  id: 'cobalt',
  name: 'Cobalt',
  tag: 'tech blue',
  note: '深海军蓝底 · 电光蓝口音 · 接近原项目科技蓝',
  b: Brightness.dark,
  bg: [0.18, 0.022, 255],
  surface: [0.215, 0.024, 255],
  surface2: [0.250, 0.026, 255],
  border: [0.34, 0.028, 255],
  borderSoft: [0.28, 0.026, 255],
  text: [0.95, 0.008, 255],
  body: [0.86, 0.008, 255],
  muted: [0.62, 0.012, 255],
  faint: [0.46, 0.012, 255],
  accent: [0.74, 0.16, 245],
  accentDim: [0.52, 0.14, 245],
  accentInk: [0.16, 0.04, 245],
  ok: [0.80, 0.16, 155],
  warn: [0.80, 0.16, 75],
  err: [0.70, 0.19, 25],
  info: [0.78, 0.13, 230],
));

final LabTheme labThemeAmber = _build(const _T(
  id: 'amber',
  name: 'Amber',
  tag: 'crt · warm',
  note: '暖黑底 · 琥珀色口音 · 致敬老式 CRT 监视器',
  b: Brightness.dark,
  bg: [0.18, 0.012, 60],
  surface: [0.215, 0.014, 60],
  surface2: [0.250, 0.016, 60],
  border: [0.34, 0.020, 60],
  borderSoft: [0.28, 0.018, 60],
  text: [0.95, 0.010, 60],
  body: [0.87, 0.012, 60],
  muted: [0.62, 0.014, 60],
  faint: [0.46, 0.012, 60],
  accent: [0.83, 0.17, 75],
  accentDim: [0.58, 0.14, 75],
  accentInk: [0.18, 0.05, 60],
  ok: [0.80, 0.15, 145],
  warn: [0.83, 0.17, 75],
  err: [0.70, 0.19, 25],
  info: [0.78, 0.12, 230],
));

final LabTheme labThemeMint = _build(const _T(
  id: 'mint',
  name: 'Mint',
  tag: 'nature · teal',
  note: '冷绿底 · 薄荷青口音 · 接近原项目自然绿',
  b: Brightness.dark,
  bg: [0.18, 0.014, 175],
  surface: [0.215, 0.016, 175],
  surface2: [0.250, 0.018, 175],
  border: [0.34, 0.020, 175],
  borderSoft: [0.28, 0.018, 175],
  text: [0.95, 0.008, 175],
  body: [0.87, 0.010, 175],
  muted: [0.62, 0.012, 175],
  faint: [0.46, 0.012, 175],
  accent: [0.80, 0.13, 170],
  accentDim: [0.56, 0.11, 170],
  accentInk: [0.16, 0.04, 170],
  ok: [0.80, 0.13, 170],
  warn: [0.80, 0.16, 75],
  err: [0.70, 0.19, 25],
  info: [0.78, 0.12, 230],
));

final LabTheme labThemePaper = _build(const _T(
  id: 'paper',
  name: 'Paper',
  tag: 'light · for daylight',
  note: '浅纸底 · 同款密度 · 适合白天 / 拍演示视频',
  b: Brightness.light,
  bg: [0.985, 0.003, 250],
  surface: [0.965, 0.004, 250],
  surface2: [0.945, 0.005, 250],
  border: [0.86, 0.006, 250],
  borderSoft: [0.91, 0.005, 250],
  text: [0.20, 0.012, 250],
  body: [0.30, 0.012, 250],
  muted: [0.48, 0.012, 250],
  faint: [0.62, 0.010, 250],
  accent: [0.55, 0.18, 145],
  accentDim: [0.40, 0.14, 145],
  accentInk: [0.99, 0.01, 145],
  ok: [0.55, 0.18, 145],
  warn: [0.62, 0.17, 65],
  err: [0.55, 0.21, 25],
  info: [0.55, 0.15, 240],
));

final LabTheme labThemeLinen = _build(const _T(
  id: 'linen',
  name: 'Linen',
  tag: 'light · warm clay',
  note: '暖纸底 · 陶土色口音 · 偏纸质 / 设计文档氛围',
  b: Brightness.light,
  bg: [0.975, 0.010, 70],
  surface: [0.955, 0.012, 70],
  surface2: [0.930, 0.014, 70],
  border: [0.85, 0.014, 60],
  borderSoft: [0.90, 0.012, 65],
  text: [0.22, 0.014, 50],
  body: [0.32, 0.013, 55],
  muted: [0.50, 0.014, 60],
  faint: [0.65, 0.013, 65],
  accent: [0.58, 0.16, 35],
  accentDim: [0.42, 0.13, 35],
  accentInk: [0.99, 0.01, 35],
  ok: [0.55, 0.15, 145],
  warn: [0.62, 0.17, 65],
  err: [0.55, 0.21, 25],
  info: [0.55, 0.14, 240],
));

final LabTheme labThemeSlate = _build(const _T(
  id: 'slate',
  name: 'Slate',
  tag: 'light · cool cobalt',
  note: '冷灰白底 · 钴蓝口音 · 偏 IDE / 技术文档质感',
  b: Brightness.light,
  bg: [0.99, 0.004, 250],
  surface: [0.97, 0.005, 250],
  surface2: [0.945, 0.006, 250],
  border: [0.86, 0.010, 250],
  borderSoft: [0.91, 0.008, 250],
  text: [0.18, 0.022, 255],
  body: [0.28, 0.020, 255],
  muted: [0.48, 0.018, 255],
  faint: [0.62, 0.014, 255],
  accent: [0.50, 0.18, 250],
  accentDim: [0.38, 0.14, 250],
  accentInk: [0.99, 0.01, 250],
  ok: [0.50, 0.15, 155],
  warn: [0.58, 0.17, 65],
  err: [0.52, 0.21, 25],
  info: [0.50, 0.18, 250],
));

// ── catalogue ────────────────────────────────────────────────────────

class LabThemes {
  LabThemes._();

  static final List<LabTheme> all = [
    labThemeSignal,
    labThemePlasma,
    labThemeCobalt,
    labThemeAmber,
    labThemeMint,
    labThemePaper,
    labThemeLinen,
    labThemeSlate,
  ];

  static final List<LabTheme> dark =
      all.where((t) => t.brightness == Brightness.dark).toList();
  static final List<LabTheme> light =
      all.where((t) => t.brightness == Brightness.light).toList();

  /// Find by id with a safe fallback to [labThemeSignal].
  static LabTheme byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => labThemeSignal);
}
