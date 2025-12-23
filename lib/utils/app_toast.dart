import 'dart:async';
import 'package:flutter/material.dart';

/// Toast通知类型
enum ToastType {
  success,
  error,
  warning,
  info,
}

/// 统一的Toast通知组件
/// 在屏幕右上角显示浮动通知,采用与对话框一致的现代设计风格
/// 单实例模式:同一时间只显示一个通知,新通知会替换旧通知
class AppToast {
  static OverlayEntry? _currentToast;
  static Timer? _dismissTimer;
  static int _toastId = 0;
  
  /// 显示Toast通知 (单实例模式,新通知替换旧通知)
  static void show({
    required BuildContext context,
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 2),
    IconData? icon,
  }) {
    // 取消之前的定时器
    _dismissTimer?.cancel();
    _dismissTimer = null;
    
    // 移除当前的Toast
    _currentToast?.remove();
    _currentToast = null;
    
    // 增加ID防止旧回调影响新Toast
    _toastId++;
    final currentId = _toastId;
    
    final overlay = Overlay.of(context);
    
    final entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        key: ValueKey(currentId),
        message: message,
        type: type,
        icon: icon,
        onDismiss: () => _dismiss(currentId),
      ),
    );
    
    _currentToast = entry;
    overlay.insert(entry);
    
    // 设置自动消失定时器
    _dismissTimer = Timer(duration, () {
      _dismiss(currentId);
    });
  }
  
  /// 内部dismiss方法,检查ID
  static void _dismiss(int id) {
    if (id == _toastId && _currentToast != null) {
      _dismissTimer?.cancel();
      _dismissTimer = null;
      _currentToast?.remove();
      _currentToast = null;
    }
  }
  
  /// 显示成功通知
  static void success(BuildContext context, String message, {Duration? duration}) {
    show(
      context: context,
      message: message,
      type: ToastType.success,
      duration: duration ?? const Duration(seconds: 2),
    );
  }
  
  /// 显示错误通知
  static void error(BuildContext context, String message, {Duration? duration}) {
    show(
      context: context,
      message: message,
      type: ToastType.error,
      duration: duration ?? const Duration(seconds: 3),
    );
  }
  
  /// 显示警告通知
  static void warning(BuildContext context, String message, {Duration? duration}) {
    show(
      context: context,
      message: message,
      type: ToastType.warning,
      duration: duration ?? const Duration(seconds: 2),
    );
  }
  
  /// 显示信息通知
  static void info(BuildContext context, String message, {Duration? duration}) {
    show(
      context: context,
      message: message,
      type: ToastType.info,
      duration: duration ?? const Duration(seconds: 2),
    );
  }
  
  /// 清除当前Toast
  static void clear() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentToast?.remove();
    _currentToast = null;
    _toastId++;
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final IconData? icon;
  final VoidCallback onDismiss;
  
  const _ToastWidget({
    super.key,
    required this.message,
    required this.type,
    this.icon,
    required this.onDismiss,
  });
  
  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    
    _controller.forward();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  Color _getTypeColor(ToastType type, ThemeData theme) {
    final primary = theme.colorScheme.primary;
    switch (type) {
      case ToastType.success:
        return Color.lerp(primary, const Color(0xFF10B981), 0.7)!;
      case ToastType.error:
        return theme.colorScheme.error;
      case ToastType.warning:
        return Color.lerp(primary, const Color(0xFFF59E0B), 0.6)!;
      case ToastType.info:
        return primary;
    }
  }
  
  IconData _getTypeIcon(ToastType type) {
    switch (type) {
      case ToastType.success:
        return Icons.check_circle_rounded;
      case ToastType.error:
        return Icons.error_rounded;
      case ToastType.warning:
        return Icons.warning_rounded;
      case ToastType.info:
        return Icons.info_rounded;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final typeColor = _getTypeColor(widget.type, theme);
    final icon = widget.icon ?? _getTypeIcon(widget.type);
    
    return Positioned(
      top: 20,
      right: 20,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: widget.onDismiss,
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 300,
                  minWidth: 180,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark 
                      ? theme.colorScheme.surface 
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: typeColor.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: Border.all(
                    color: typeColor.withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: typeColor, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
