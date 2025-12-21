import 'package:flutter/material.dart';

/// Semantic Icon Set for the application
class AppIcons {
  final IconData play;
  final IconData stop;
  final IconData settings;
  final IconData clear;
  final IconData copy;
  final IconData time;
  final IconData calendar;
  final IconData save;
  final IconData lock;
  final IconData unlock;
  final IconData download; // Export
  final IconData upload;   // Import

  const AppIcons({
    required this.play,
    required this.stop,
    required this.settings,
    required this.clear,
    required this.copy,
    required this.time,
    required this.calendar,
    required this.save,
    required this.lock,
    required this.unlock,
    required this.download,
    required this.upload,
  });

  // Standard Material Icons (Default)
  static const standard = AppIcons(
    play: Icons.play_arrow,
    stop: Icons.stop,
    settings: Icons.settings,
    clear: Icons.delete_outline,
    copy: Icons.copy,
    time: Icons.access_time,
    calendar: Icons.calendar_today,
    save: Icons.save,
    lock: Icons.lock_outline,
    unlock: Icons.lock_open,
    download: Icons.download,
    upload: Icons.upload,
  );

  // Rounded Icons (For Cloud/Azure/Soft themes)
  static const rounded = AppIcons(
    play: Icons.play_circle_filled_rounded,
    stop: Icons.stop_circle_outlined,
    settings: Icons.settings_rounded,
    clear: Icons.delete_rounded,
    copy: Icons.content_copy_rounded,
    time: Icons.access_time_filled_rounded,
    calendar: Icons.calendar_month_rounded,
    save: Icons.save_rounded,
    lock: Icons.lock_rounded,
    unlock: Icons.lock_open_rounded,
    download: Icons.download_rounded,
    upload: Icons.upload_rounded,
  );

  // Sharp Icons (For Terminal/Industrial themes)
  static const sharp = AppIcons(
    play: Icons.play_arrow_sharp,
    stop: Icons.stop_sharp,
    settings: Icons.settings_sharp,
    clear: Icons.delete_sharp,
    copy: Icons.copy_sharp,
    time: Icons.access_time_sharp,
    calendar: Icons.calendar_view_day_sharp,
    save: Icons.save_sharp,
    lock: Icons.lock_sharp,
    unlock: Icons.lock_open_sharp,
    download: Icons.download_sharp,
    upload: Icons.upload_sharp,
  );
  
  // Outlined/Tech Icons (For Future/Cyber themes)
  static const tech = AppIcons(
    play: Icons.play_circle_outline,
    stop: Icons.stop_circle_outlined,
    settings: Icons.settings_applications_outlined,
    clear: Icons.delete_sweep_outlined,
    copy: Icons.file_copy_outlined,
    time: Icons.watch_later_outlined,
    calendar: Icons.event_available_outlined,
    save: Icons.save_as_outlined,
    lock: Icons.lock_outline,
    unlock: Icons.lock_open_outlined,
    download: Icons.file_download_outlined,
    upload: Icons.file_upload_outlined,
  );
}

/// Dynamic Theme Extension
class AppThemeEffect extends ThemeExtension<AppThemeEffect> {
  final Curve animationCurve;
  final double layoutDensity; // 1.0 = standard, 0.8 = compact, 1.2 = spacious
  final AppIcons icons;
  final BoxShadow? innerShadow; // Simulate depth if needed

  const AppThemeEffect({
    required this.animationCurve,
    required this.layoutDensity,
    required this.icons,
    this.innerShadow,
  });

  @override
  AppThemeEffect copyWith({
    Curve? animationCurve,
    double? layoutDensity,
    AppIcons? icons,
    BoxShadow? innerShadow,
  }) {
    return AppThemeEffect(
      animationCurve: animationCurve ?? this.animationCurve,
      layoutDensity: layoutDensity ?? this.layoutDensity,
      icons: icons ?? this.icons,
      innerShadow: innerShadow ?? this.innerShadow,
    );
  }

  @override
  AppThemeEffect lerp(ThemeExtension<AppThemeEffect>? other, double t) {
    if (other is! AppThemeEffect) {
      return this;
    }
    return AppThemeEffect(
      // Curves cannot be lerped easily, snap to target at 50%
      animationCurve: t < 0.5 ? animationCurve : other.animationCurve,
      layoutDensity: lerpDouble(layoutDensity, other.layoutDensity, t),
      // Icons cannot be lerped, snap to target
      icons: t < 0.5 ? icons : other.icons,
      innerShadow: BoxShadow.lerp(innerShadow, other.innerShadow, t),
    );
  }
  
  // Helper to easily lerp doubles without importing dart:ui everywhere
  double lerpDouble(double a, double b, double t) {
    return a + (b - a) * t;
  }
}
