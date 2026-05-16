// lib/ui/lab/tokens/oklch.dart
//
// OKLCH → sRGB color helper. The design tokens (lab_themes.dart) speak in
// OKLCH so the Dart values match the design-system page byte-for-byte.
//
// Reference: https://bottosson.github.io/posts/oklab/

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Build a [Color] from an OKLCH (L, C, h) triple.
///   L : lightness  0..1   (e.g. 0.82)
///   C : chroma     0..~.4 (e.g. 0.17)
///   h : hue        degrees (0..360, e.g. 145)
///   a : alpha      0..1   (default 1)
Color oklch(double L, double C, double h, [double a = 1.0]) {
  final hr = h * math.pi / 180.0;
  final aOk = C * math.cos(hr);
  final bOk = C * math.sin(hr);

  // OKLab → LMS prime
  final lPrime = L + 0.3963377774 * aOk + 0.2158037573 * bOk;
  final mPrime = L - 0.1055613458 * aOk - 0.0638541728 * bOk;
  final sPrime = L - 0.0894841775 * aOk - 1.2914855480 * bOk;

  // LMS prime → linear LMS
  final lLin = lPrime * lPrime * lPrime;
  final mLin = mPrime * mPrime * mPrime;
  final sLin = sPrime * sPrime * sPrime;

  // LMS → linear sRGB
  final r = 4.0767416621 * lLin - 3.3077115913 * mLin + 0.2309699292 * sLin;
  final g = -1.2684380046 * lLin + 2.6097574011 * mLin - 0.3413193965 * sLin;
  final b = -0.0041960863 * lLin - 0.7034186147 * mLin + 1.7076147010 * sLin;

  int toByte(double v) {
    final clamped = v.clamp(0.0, 1.0).toDouble();
    final encoded = clamped <= 0.0031308
        ? 12.92 * clamped
        : 1.055 * math.pow(clamped, 1.0 / 2.4) - 0.055;
    return (encoded.clamp(0.0, 1.0) * 255.0).round();
  }

  return Color.fromARGB(
    (a.clamp(0.0, 1.0) * 255.0).round(),
    toByte(r),
    toByte(g),
    toByte(b),
  );
}

/// Mix two colors in oklab-ish blend (simple alpha over).
/// Used for tinted backgrounds (`primary.tinted(.18)` style).
extension LabColorMix on Color {
  /// Return this color rendered over [base] at the given [pct] (0..100).
  Color tinted(int pct, {Color base = Colors.transparent}) {
    final a = (pct.clamp(0, 100)) / 100.0;
    return Color.alphaBlend(withOpacity(a), base);
  }

  /// Alpha-only version (no base) — common token usage for borders/fills.
  Color alpha(int pct) => withOpacity((pct.clamp(0, 100)) / 100.0);
}
