# IoT DevKit Flutter UI Design System

更新时间：2026-05-14

## 结论

`shadcn/ui` 不适合直接接入本项目。它是 React、Tailwind、CSS 变量和组件源码复制体系，而本项目是 Flutter 桌面应用。

但它的核心思想非常适合本项目：

- 先定设计 token，再写页面。
- 先沉淀基础组件，再做业务界面。
- 让 Codex 按项目规则改 UI，而不是每次自由发挥。
- 老项目小步迁移，不做全站一把梭。

因此本项目采用“Flutter 版 shadcn 思路”：用 Flutter 的 `ThemeData`、`ColorScheme`、`ThemeExtension` 和项目内组件来形成稳定 UI 基座。

## 当前技术栈判断

- UI 框架：Flutter Material 3。
- 状态管理：Provider。
- 本地存储：SharedPreferences。
- 桌面能力：window_manager、file_picker、path_provider。
- 核心业务：MQTT 模拟上送、数据生成、低延迟调度、日志与监控。
- 当前 UI 基座：
  - `lib/services/theme_manager.dart`
  - `lib/ui/styles/app_theme_effect.dart`
  - `lib/ui/components/`
  - `lib/ui/shell/`

## 设计目标

本项目是桌面工具，首屏不是营销页面。设计应该服务于高频操作：

- 信息密度高，但分组清楚。
- 表单稳定，不因为 hover、校验、主题切换、语言切换而跳动。
- 状态来源唯一，避免重复显示“就绪”“运行中”等冲突信息。
- 主操作突出，次操作可扫视。
- 日志、监控、配置区互不抢占注意力。
- 深色/浅色主题都可读，不能只在单一主题下好看。

## Token 映射

不要照搬 shadcn CSS token。应映射到 Flutter 主题。

| shadcn 思路 | Flutter 落点 | 本项目使用方式 |
| --- | --- | --- |
| `--background` | `scaffoldBackgroundColor` / `colorScheme.surface` | 页面背景 |
| `--foreground` | `colorScheme.onSurface` | 主要文字 |
| `--card` | `colorScheme.surfaceContainerLowest` | 面板、卡片、输入背景 |
| `--muted` | `colorScheme.surfaceContainerLow` / `onSurfaceVariant` | 次级区域与弱文字 |
| `--primary` | `colorScheme.primary` | 主按钮、选中态、关键图标 |
| `--primary-foreground` | `colorScheme.onPrimary` | 主按钮文字 |
| `--border` | `colorScheme.outlineVariant` | 面板边框、分割线 |
| `--input` | `InputDecorationTheme` / `AppInputDecoration` | 表单边框与填充 |
| `--destructive` | `colorScheme.error` | 删除、失败、危险操作 |
| `--radius` | `AppThemeEffect.borderRadius` + 组件默认 8px | 圆角体系 |
| motion token | `AppThemeEffect.animationCurve` | 主题动效和局部过渡 |
| icon set | `AppThemeEffect.icons` | 不同主题的图标风格 |

## 基础组件基座

新增 UI 时优先复用这些组件：

| 场景 | 优先使用 |
| --- | --- |
| 分组面板 | `AppSection` |
| 输入框 | `AppInputDecoration.filled` |
| 自适应表单网格 | `FormGrid` |
| 计数/状态 chip | `MetricChip` |
| 紧凑图标操作 | `IconTooltipButton` |
| 页面导航 | `AppNavigationRail` |
| 内容切换 | `MainContentSwitcher` |
| 设置入口 | `SettingsMenu` |
| 日志底座 | `LogConsole` / `SimulatorLogDock` |

只有当现有组件无法表达明确新模式时，才新增组件。新增组件应放在 `lib/ui/components/` 或具体 feature 目录，而不是散落在页面文件里。

## Flutter 组件对应关系

| shadcn 组件 | Flutter / 当前项目对应 |
| --- | --- |
| Button | `FilledButton`、`OutlinedButton`、`TextButton`、`IconButton` |
| Card | `AppSection` 或语义面板容器 |
| Input | `TextField` / `TextFormField` + `AppInputDecoration` |
| Select | `DropdownButtonFormField`，必须考虑 `isExpanded` 与长文案 |
| Dialog | `AppDialogHelper` 或局部统一 Dialog |
| Tabs | `SegmentedButton` / `TabBar`，按场景选择 |
| Badge | `MetricChip` 或新增语义状态 chip |
| Sheet | 桌面侧栏可使用 `ProfileSidebar` 风格，避免移动端抽屉思维 |
| Table | 暂无统一表格组件，新增前先设计桌面密度和横向滚动策略 |
| Toast | `AppToast`，后续应统一替换零散 SnackBar |

## 页面布局规范

### App Shell

- 左侧 `NavigationRail` 是一级导航，不再额外堆顶部大导航。
- 设置入口保持在 rail 底部，弹出菜单不得出屏或遮住关键表单。
- 内容区使用 `MainContentSwitcher` 保持状态，但测试要注意隐藏页仍在 widget tree 中。

### Simulator

- MQTT 连接配置、模式切换、设备配置、Key/分组配置、状态条、操作区、日志 dock 必须层级清晰。
- 运行态下可禁用配置输入，但停止按钮必须始终可理解、可触达。
- 高级模式分组表单需要优先保证不溢出、不丢输入、不因折叠展开重建丢状态。

### Log Console

- 底部日志条只承担日志入口和最新状态预览，不放太多统计 chip。
- 展开态应具备过滤、搜索、复制、清空、导出、自动滚动开关。
- 日志空态、过滤空态、错误态要有统一视觉。

### Timesheet

- 当前定位是轻量记事本，不做复杂项目管理。
- 只保留“日期、今天做了什么、几个小时、当天记录、复制周报”核心路径。
- 保存、删除、复制反馈应统一到项目反馈体系。

### Tool Pages

- Timestamp 和 JSON 是工具型页面，优先稳定输入输出区域。
- 工具条按钮不要因为 toast、弹窗或窗口宽度被遮挡。
- 大文本输入、树形视图、搜索结果需要稳定滚动策略。

## 视觉规范

- 默认圆角：8px。
- 紧凑工具按钮：32px 到 40px。
- 主操作按钮高度：40px 到 44px。
- 表单内容 padding：水平 12px，垂直 12px。
- 页面外边距：桌面常规 12px 到 16px。
- 面板阴影应克制，优先用边框和背景层级。
- 不使用装饰性渐变球、漂浮装饰、营销式 hero。
- 不使用大面积单一高饱和色压住整个工具界面。

## 颜色规则

允许：

```dart
final colors = Theme.of(context).colorScheme;
color: colors.primary;
border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.42));
```

避免：

```dart
color: Colors.red;
backgroundColor: const Color(0xFF123456);
```

例外：

- 协议、日志等级、成功/失败等已经有业务语义的颜色。
- 但如果同一颜色出现多次，应抽成统一语义 helper 或组件。

## 文案与国际化

- 新增用户可见文案必须进入 `lib/l10n/app_en.arb` 和 `lib/l10n/app_zh.arb`。
- 协议字段、单位、日志原文、测试 fixture 可以保留硬编码。
- UI 文案要短，避免在按钮中放解释型句子。
- 错误提示必须说明用户可以做什么，而不是只写 “failed”。

## 反馈规范

当前项目存在 `AppToast`、`SnackBar`、内联提示并存。后续整改方向：

- 成功、警告、错误、处理中统一入口。
- 表单局部错误使用内联反馈。
- 全局操作成功可使用 toast。
- 删除确认使用 Dialog。
- 复制类操作不应出现笨重底部 SnackBar。

## Codex 改 UI 的默认流程

1. 先读当前页面和共享组件。
2. 判断是否能复用 `lib/ui/components/`。
3. 只改当前模块，不顺手重构无关页面。
4. 保留业务逻辑、Provider 契约、路由索引、配置格式。
5. 新增或调整用户可见文案时同步 ARB。
6. 补或更新 widget smoke。
7. 运行 `flutter analyze --no-pub` 和 `flutter test --no-pub`。
8. 发布前再跑 `flutter build macos --no-pub`。

## 适合优先整改的模块

| 优先级 | 模块 | 原因 |
| --- | --- | --- |
| P0 | 日志展开态 | 直接影响长时间模拟可观测性 |
| P0 | 动态表单状态 | 分组、Key 输入不应在折叠/导入/主题切换后丢失 |
| P1 | 反馈体系 | Toast、SnackBar、内联提示需要统一 |
| P1 | 设置/主题/语言弹窗 | 已是高频入口，且影响整体质感 |
| P1 | JSON 工具布局 | 大输入和树形视图需要更稳定的工具体验 |
| P2 | Style Guide 页面 | 用于后续人工验收主题和组件一致性 |

## 测试守门

| 变更类型 | 必跑测试 |
| --- | --- |
| 全局 UI、导航、主题、语言 | `flutter test --no-pub test/widgets/all_features_smoke_test.dart` |
| App shell | `flutter test --no-pub test/widgets/home_screen_smoke_test.dart` |
| 日志控制台 | `flutter test --no-pub test/widgets/log_console_test.dart` |
| 模拟器生命周期 | `flutter test --no-pub test/services/mqtt_controller_lifecycle_test.dart` |
| 调度与低延迟策略 | `flutter test --no-pub test/services/scheduler_service_test.dart` |
| 大数量性能 | `flutter test --no-pub test/services/simulation_load_test.dart` |

最终合并前建议运行：

```bash
flutter analyze --no-pub
flutter test --no-pub
```

发布前运行：

```bash
flutter build macos --no-pub
```

## 不做事项

- 不直接接入 shadcn/ui。
- 不引入 Tailwind。
- 不为了 UI 改造重写 MQTT、调度、数据生成、导入导出。
- 不一次性全站重构。
- 不绕过现有测试直接发布。

## 与原 shadcn 指南的关系

本文件吸收的是 shadcn 指南里的工程方法：

- token 化。
- 组件基座。
- Codex 规则。
- 小步迁移。
- 每次改动可验证。

不是吸收它的 React 实现。
