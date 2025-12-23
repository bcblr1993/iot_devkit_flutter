# UI组件使用规范

本项目已建立统一的UI组件库,所有新功能开发必须复用以下组件:

## 对话框组件 - `AppDialogHelper`

路径: `lib/utils/app_dialog_helper.dart`

### 使用方式

```dart
import '../../utils/app_dialog_helper.dart';

// 通用对话框
AppDialogHelper.show(
  context: context,
  title: '标题',
  icon: Icons.info,
  content: Text('内容'),
  actions: [按钮列表],
);

// 确认对话框
final confirmed = await AppDialogHelper.showConfirm(
  context: context,
  title: '确认操作',
  message: '确定要执行此操作吗?',
);

// 错误对话框
await AppDialogHelper.showError(
  context: context,
  title: '错误',
  message: '操作失败',
);

// 代码预览对话框
await AppDialogHelper.showCodePreview(
  context: context,
  title: '预览',
  code: jsonString,
  onCopy: () => {},
);
```

---

## 消息通知组件 - `AppToast`

路径: `lib/utils/app_toast.dart`

### 使用方式

```dart
import '../../utils/app_toast.dart';

AppToast.success(context, '操作成功');
AppToast.error(context, '操作失败');
AppToast.warning(context, '警告信息');
AppToast.info(context, '提示信息');
```

### 特性

- 单实例模式,新通知替换旧通知
- 右上角浮动显示
- 颜色自动适配主题

---

## 禁止事项

1. ❌ 不要直接使用 `showDialog()` + `AlertDialog`
2. ❌ 不要直接使用 `ScaffoldMessenger.showSnackBar()`
3. ❌ 不要自定义底部状态栏提示
