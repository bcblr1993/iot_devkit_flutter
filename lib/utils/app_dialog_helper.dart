import 'package:flutter/material.dart';

/// 统一对话框样式工具类
/// 采用与关于对话框一致的现代设计风格
class AppDialogHelper {
  /// 显示统一样式的对话框
  /// 
  /// [title] - 对话框标题
  /// [icon] - 标题图标
  /// [content] - 对话框内容Widget
  /// [actions] - 底部操作按钮列表
  /// [barrierDismissible] - 是否可以点击外部关闭
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    IconData? icon,
    required Widget content,
    List<Widget>? actions,
    bool barrierDismissible = true,
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark 
                ? [
                    theme.colorScheme.surface,
                    theme.colorScheme.surface.withOpacity(0.95),
                  ]
                : [
                    Colors.white,
                    primaryColor.withOpacity(0.02),
                  ],
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题区域
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.onSurface.withOpacity(0.08),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          icon,
                          color: primaryColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 内容区域
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: content,
                ),
              ),
              
              // 操作按钮区域
              if (actions != null && actions.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: theme.colorScheme.onSurface.withOpacity(0.08),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions.map((action) {
                      final index = actions.indexOf(action);
                      return Padding(
                        padding: EdgeInsets.only(left: index > 0 ? 12 : 0),
                        child: action,
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 显示确认对话框
  static Future<bool?> showConfirm({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    IconData icon = Icons.help_outline_rounded,
    bool isDangerous = false,
  }) {
    final theme = Theme.of(context);
    final l10n = Localizations.localeOf(context).languageCode == 'zh';
    
    return show<bool>(
      context: context,
      title: title,
      icon: icon,
      barrierDismissible: false,
      content: Text(
        message,
        style: TextStyle(
          fontSize: 14,
          height: 1.6,
          color: theme.colorScheme.onSurface.withOpacity(0.8),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText ?? (l10n ? '取消' : 'Cancel')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDangerous 
              ? theme.colorScheme.error 
              : theme.colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(confirmText ?? (l10n ? '确定' : 'Confirm')),
        ),
      ],
    );
  }
  
  /// 显示错误对话框
  static Future<void> showError({
    required BuildContext context,
    required String title,
    required String message,
    String? buttonText,
  }) {
    final theme = Theme.of(context);
    final l10n = Localizations.localeOf(context).languageCode == 'zh';
    
    return show(
      context: context,
      title: title,
      icon: Icons.error_outline_rounded,
      content: Text(
        message,
        style: TextStyle(
          fontSize: 14,
          height: 1.6,
          color: theme.colorScheme.onSurface.withOpacity(0.8),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(buttonText ?? (l10n ? '确定' : 'OK')),
        ),
      ],
    );
  }
  
  /// 显示代码预览对话框
  static Future<bool?> showCodePreview({
    required BuildContext context,
    required String title,
    required String code,
    IconData icon = Icons.code_rounded,
    VoidCallback? onCopy,
    String? confirmText,
    String? cancelText,
    bool showConfirmButton = false,
    Widget? extraWidget, // For custom content below code
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = Localizations.localeOf(context).languageCode == 'zh';
    
    return show<bool>(
      context: context,
      title: title,
      icon: icon,
      barrierDismissible: !showConfirmButton,
      content: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
              ? [
                  const Color(0xFF1E293B),
                  const Color(0xFF0F172A),
                ]
              : [
                  const Color(0xFFF8FAFC),
                  primaryColor.withOpacity(0.02),
                ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: primaryColor.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
          minWidth: 450,
        ),
        child: Column(
          children: [
            // 1. Extra Widget (Top)
            if (extraWidget != null)
               Container(
                 decoration: BoxDecoration(
                   border: Border(bottom: BorderSide(color: primaryColor.withOpacity(0.1))),
                   color: isDark ? Colors.black12 : Colors.grey.withOpacity(0.02),
                 ),
                 padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                 child: extraWidget,
               ),

            // 2. Code Area (Expanded)
            Expanded(
              child: Stack(
                children: [
                  // 代码内容区域
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 语言标签
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.data_object_rounded,
                                  size: 14,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'JSON',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: primaryColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // 代码文本
                          SelectableText(
                            code,
                            style: TextStyle(
                              fontFamily: 'Courier New',
                              fontSize: 13,
                              height: 1.6,
                              color: isDark 
                                ? const Color(0xFFE2E8F0) 
                                : const Color(0xFF1E293B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // 复制按钮
                  if (onCopy != null)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onCopy,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark
                                ? theme.colorScheme.surface.withOpacity(0.95)
                                : Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: primaryColor.withOpacity(0.3),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.copy_rounded,
                                  size: 16,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  l10n ? '复制' : 'Copy',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText ?? (l10n ? '关闭' : 'Close')),
        ),
        if (showConfirmButton)
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: Text(confirmText ?? (l10n ? '开始' : 'Start')),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
      ],
    );
  }
}
