// lib/ui/lab/tokens/lab_tokens.dart
//
// LabTokens — ThemeExtension carrying every design token that doesn't fit
// in Material 3's ColorScheme. Read via `LabTokens.of(context)` anywhere.

import 'package:flutter/material.dart';

@immutable
class LabTokens extends ThemeExtension<LabTokens> {
  // ── status colors (ColorScheme only carries `error`) ──────────
  final Color ok;
  final Color warn;
  final Color info;

  // ── extra neutrals beyond onSurface / onSurfaceVariant ───────
  /// Stronger than [ColorScheme.onSurfaceVariant], softer than onSurface.
  /// Used for normal body copy in data rows.
  final Color body;
  /// Softer than [ColorScheme.onSurfaceVariant] — for tertiary hints,
  /// timestamps, "00 of 142" counters.
  final Color faint;

  // ── primary surface variants ─────────────────────────────────
  /// Same hue as [ColorScheme.primary] but desaturated — for trend chips
  /// and chart fill gradients where full accent would over-shout.
  final Color accentDim;
  /// Ink that reads on top of [ColorScheme.primary]. Identical in role to
  /// [ColorScheme.onPrimary] but kept on the extension for component clarity.
  final Color accentInk;

  // ── font families (must match pubspec.yaml entries) ──────────
  final String sansFamily;
  final String monoFamily;

  // ── spacing scale (px) — see design system §02 ───────────────
  final double sXxs; // 2
  final double sXs;  // 4
  final double sSm;  // 6
  final double sMd;  // 8
  final double sLg;  // 12
  final double sXl;  // 16
  final double s2xl; // 20
  final double s3xl; // 24
  final double s4xl; // 32

  // ── radius scale ─────────────────────────────────────────────
  final double rXs;  // 2
  final double rSm;  // 4
  final double rMd;  // 6
  final double rLg;  // 8
  final double rXl;  // 12

  // ── motion durations ─────────────────────────────────────────
  final Duration dFast;
  final Duration dNormal;
  final Duration dSlow;

  const LabTokens({
    required this.ok,
    required this.warn,
    required this.info,
    required this.body,
    required this.faint,
    required this.accentDim,
    required this.accentInk,
    this.sansFamily = 'Inter',
    this.monoFamily = 'JetBrainsMono',
    this.sXxs = 2.0,
    this.sXs = 4.0,
    this.sSm = 6.0,
    this.sMd = 8.0,
    this.sLg = 12.0,
    this.sXl = 16.0,
    this.s2xl = 20.0,
    this.s3xl = 24.0,
    this.s4xl = 32.0,
    this.rXs = 2.0,
    this.rSm = 4.0,
    this.rMd = 6.0,
    this.rLg = 8.0,
    this.rXl = 12.0,
    this.dFast = const Duration(milliseconds: 120),
    this.dNormal = const Duration(milliseconds: 200),
    this.dSlow = const Duration(milliseconds: 320),
  });

  /// Read tokens off the current theme. Throws if no theme registered
  /// the extension — wire up in [ThemeData.extensions] first.
  static LabTokens of(BuildContext context) {
    final t = Theme.of(context).extension<LabTokens>();
    assert(t != null, 'LabTokens not registered on Theme.extensions');
    return t!;
  }

  @override
  LabTokens copyWith({
    Color? ok,
    Color? warn,
    Color? info,
    Color? body,
    Color? faint,
    Color? accentDim,
    Color? accentInk,
    String? sansFamily,
    String? monoFamily,
  }) {
    return LabTokens(
      ok: ok ?? this.ok,
      warn: warn ?? this.warn,
      info: info ?? this.info,
      body: body ?? this.body,
      faint: faint ?? this.faint,
      accentDim: accentDim ?? this.accentDim,
      accentInk: accentInk ?? this.accentInk,
      sansFamily: sansFamily ?? this.sansFamily,
      monoFamily: monoFamily ?? this.monoFamily,
      sXxs: sXxs, sXs: sXs, sSm: sSm, sMd: sMd, sLg: sLg,
      sXl: sXl, s2xl: s2xl, s3xl: s3xl, s4xl: s4xl,
      rXs: rXs, rSm: rSm, rMd: rMd, rLg: rLg, rXl: rXl,
      dFast: dFast, dNormal: dNormal, dSlow: dSlow,
    );
  }

  @override
  LabTokens lerp(ThemeExtension<LabTokens>? other, double t) {
    if (other is! LabTokens) return this;
    return LabTokens(
      ok:        Color.lerp(ok,        other.ok,        t)!,
      warn:      Color.lerp(warn,      other.warn,      t)!,
      info:      Color.lerp(info,      other.info,      t)!,
      body:      Color.lerp(body,      other.body,      t)!,
      faint:     Color.lerp(faint,     other.faint,     t)!,
      accentDim: Color.lerp(accentDim, other.accentDim, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      sansFamily: other.sansFamily,
      monoFamily: other.monoFamily,
      sXxs: sXxs, sXs: sXs, sSm: sSm, sMd: sMd, sLg: sLg,
      sXl: sXl, s2xl: s2xl, s3xl: s3xl, s4xl: s4xl,
      rXs: rXs, rSm: rSm, rMd: rMd, rLg: rLg, rXl: rXl,
      dFast: dFast, dNormal: dNormal, dSlow: dSlow,
    );
  }
}
