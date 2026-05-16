// lib/ui/lab/tokens/lab_text_theme.dart
//
// Lab Console TextTheme — 11 type roles mapped onto Material 3 named
// styles. Mono roles use [LabTokens.monoFamily], everything else uses
// [LabTokens.sansFamily].
//
// Design-system reference: §01 Type.

import 'package:flutter/material.dart';
import 'lab_tokens.dart';

TextTheme labTextTheme(ColorScheme scheme, LabTokens tokens) {
  final sans = tokens.sansFamily;
  final mono = tokens.monoFamily;
  final ink = scheme.onSurface;

  TextStyle s({
    required double size,
    required double line,
    required FontWeight weight,
    double ls = 0,
    String family = 'sans',
    Color? color,
  }) {
    return TextStyle(
      fontFamily: family == 'mono' ? mono : sans,
      fontSize: size,
      height: line,
      fontWeight: weight,
      letterSpacing: ls,
      color: color ?? ink,
    );
  }

  return TextTheme(
    // display & headlines
    displayLarge:  s(size: 32, line: 1.10, weight: FontWeight.w700, ls: -0.6),
    headlineLarge: s(size: 22, line: 1.20, weight: FontWeight.w700, ls: -0.2),
    headlineSmall: s(size: 17, line: 1.25, weight: FontWeight.w700, ls: -0.1),

    // section / titles
    titleMedium:   s(size: 13, line: 1.30, weight: FontWeight.w700, ls:  0.4),  // upper-cased at use-site
    titleSmall:    s(size: 12, line: 1.30, weight: FontWeight.w700, ls:  0.4),

    // body
    bodyMedium:    s(size: 13, line: 1.45, weight: FontWeight.w500),
    bodySmall:     s(size: 12, line: 1.40, weight: FontWeight.w500),

    // labels
    labelMedium:   s(size: 11, line: 1.30, weight: FontWeight.w600, ls: 0.2),
    labelSmall:    s(size: 10, line: 1.20, weight: FontWeight.w700, ls: 0.6, family: 'mono'), // overline (mono)

    // mono data
    displaySmall:  s(size: 24, line: 1.05, weight: FontWeight.w700, family: 'mono'), // big numerics
    titleLarge:    s(size: 14, line: 1.20, weight: FontWeight.w600, family: 'mono'), // medium numerics
    labelLarge:    s(size: 12, line: 1.30, weight: FontWeight.w500, family: 'mono'), // small numerics
  );
}
