import 'package:flutter/material.dart';
import '../ui/lab/lab.dart';
import 'platform_ui_helper.dart';

/// 统一对话框样式工具类
/// 采用与关于对话框一致的现代设计风格
class AppDialogHelper {
  // Dialog corner radius sits above the token scale's max (rXl = 12) by
  // design — kept as a named constant to stay off the literal-args lint.
  static const double _dialogRadius = 20;

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
    final tokens = LabTokens.of(context);
    final primaryColor = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_dialogRadius)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_dialogRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      theme.colorScheme.surface,
                      theme.colorScheme.surface.withValues(alpha: 0.95),
                    ]
                  : [
                      theme.colorScheme.surfaceContainerLowest,
                      primaryColor.withValues(alpha: 0.02),
                    ],
            ),
            boxShadow: PlatformUIHelper.optimizeShadows([
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ]),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题区域
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                    tokens.s3xl, tokens.s3xl, tokens.s3xl, tokens.sXl),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Container(
                        padding: EdgeInsets.all(tokens.sMd),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(tokens.rXl),
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
                  padding: EdgeInsets.all(tokens.s3xl),
                  child: content,
                ),
              ),

              // 操作按钮区域
              if (actions != null && actions.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                      tokens.s3xl, tokens.sXl, tokens.s3xl, tokens.s3xl),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.08),
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

    /// Keeps the confirm action visible but disabled when the caller needs to
    /// explain why the current input cannot proceed.
    bool confirmEnabled = true,
    Widget? extraWidget, // For custom content below code
  }) {
    final theme = Theme.of(context);
    final tokens = LabTokens.of(context);
    final colors = theme.colorScheme;
    final primaryColor = colors.primary;
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
                    colors.surfaceContainerLow,
                    colors.surfaceContainerLowest,
                  ]
                : [
                    colors.surfaceContainerLowest,
                    primaryColor.withValues(alpha: 0.02),
                  ],
          ),
          borderRadius: BorderRadius.circular(tokens.rXl),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: PlatformUIHelper.optimizeShadows([
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
          minWidth: 450,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Shrink wrap height
          crossAxisAlignment: CrossAxisAlignment.stretch, // Fix: Fill width
          children: [
            // 1. Extra Widget (Top)
            if (extraWidget != null)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color: primaryColor.withValues(alpha: 0.1))),
                  color: colors.onSurface.withValues(alpha: isDark ? 0.08 : 0.02),
                ),
                padding: EdgeInsets.fromLTRB(
                    tokens.s2xl, tokens.sLg, tokens.s2xl, tokens.sLg),
                child: extraWidget,
              ),

            // 2. Code Area (Flexible)
            Flexible(
              fit: FlexFit.loose,
              child: Stack(
                children: [
                  // 代码内容区域
                  Container(
                    width: double.infinity, // Fix: Ensure full width
                    padding: EdgeInsets.all(tokens.s2xl),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 语言标签
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: tokens.sLg, vertical: tokens.sXs),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(tokens.rMd),
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
                              // onSurface is guaranteed to contrast against
                              // the surfaceContainer* gradient above in both
                              // themes, so no separate light/dark literal
                              // is needed here.
                              color: colors.onSurface,
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
                        color: colors.surface.withValues(alpha: 0),
                        child: InkWell(
                          onTap: onCopy,
                          borderRadius: BorderRadius.circular(tokens.rLg),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: tokens.sLg, vertical: tokens.sMd),
                            decoration: BoxDecoration(
                              // colorScheme.surface already adapts per
                              // theme/brightness, so one expression covers
                              // both branches the isDark ternary used to.
                              color: colors.surface.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(tokens.rLg),
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.3),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.shadow.withValues(alpha: 0.08),
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
            onPressed:
                confirmEnabled ? () => Navigator.of(context).pop(true) : null,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: Text(confirmText ?? (l10n ? '开始' : 'Start')),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: colors.onPrimary,
              padding: EdgeInsets.symmetric(
                  horizontal: tokens.s2xl, vertical: tokens.sLg),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.rXl),
              ),
            ),
          ),
      ],
    );
  }

  /// 显示带文本输入框的对话框
  static Future<void> showTextFieldDialog({
    required BuildContext context,
    required String title,
    String? hintText,
    String? initialValue,
    required String confirmText,
    required String cancelText,
    required Function(String) onConfirm,
  }) {
    final controller = TextEditingController(text: initialValue);
    final theme = Theme.of(context);
    final tokens = LabTokens.of(context);

    return show(
      context: context,
      title: title,
      icon: Icons.edit_rounded,
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: hintText,
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(tokens.rXl)),
          filled: true,
          fillColor: theme.colorScheme.surface,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(cancelText),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm(controller.text);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            padding: EdgeInsets.symmetric(
                horizontal: tokens.s2xl, vertical: tokens.sLg),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.rXl)),
          ),
          child: Text(confirmText),
        ),
      ],
    );
  }
}
