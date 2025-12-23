/// 应用间距常量
/// 统一的间距系统,保证UI一致性
class AppSpacing {
  AppSpacing._();
  
  /// 微小间距 - 4px
  static const double xs = 4.0;
  
  /// 小间距 - 8px
  static const double sm = 8.0;
  
  /// 标准间距 - 12px
  static const double md = 12.0;
  
  /// 大间距 - 16px
  static const double lg = 16.0;
  
  /// 超大间距 - 24px
  static const double xl = 24.0;
  
  /// 极大间距 - 32px
  static const double xxl = 32.0;
}

/// 应用图标尺寸常量
class AppIconSize {
  AppIconSize._();
  
  /// 小图标 - 14px (指示器、装饰)
  static const double xs = 14.0;
  
  /// 标准小图标 - 16px (列表项、次要按钮)
  static const double sm = 16.0;
  
  /// 标准图标 - 18px (主要按钮)
  static const double md = 18.0;
  
  /// 大图标 - 20px (标题、重要按钮)
  static const double lg = 20.0;
  
  /// 超大图标 - 24px (主操作)
  static const double xl = 24.0;
}

/// 应用动画时长常量
class AppDuration {
  AppDuration._();
  
  /// 快速动画 - 150ms
  static const Duration fast = Duration(milliseconds: 150);
  
  /// 标准动画 - 250ms
  static const Duration normal = Duration(milliseconds: 250);
  
  /// 慢速动画 - 300ms
  static const Duration slow = Duration(milliseconds: 300);
  
  /// Toast显示时长 - 2秒
  static const Duration toastShort = Duration(seconds: 2);
  
  /// Toast显示时长(长) - 3秒
  static const Duration toastLong = Duration(seconds: 3);
}

/// 应用圆角常量
class AppRadius {
  AppRadius._();
  
  /// 小圆角 - 4px
  static const double xs = 4.0;
  
  /// 标准小圆角 - 8px
  static const double sm = 8.0;
  
  /// 标准圆角 - 12px
  static const double md = 12.0;
  
  /// 大圆角 - 16px
  static const double lg = 16.0;
  
  /// 超大圆角 - 20px
  static const double xl = 20.0;
}
