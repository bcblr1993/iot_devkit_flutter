# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目简介

跨平台 Flutter **桌面**应用(macOS / Windows / Linux),面向 IoT 开发者的工具箱:MQTT 设备模拟器、JSON 格式化、时间戳转换、证书生成、工时记录(timesheet)。把它当作高密度的操作型工具,而非展示型页面 —— UI 偏稳定、可预测、低噪声、适合高频重复使用。

交流默认使用中文;代码与注释使用英文。

## 常用命令

```bash
flutter pub get                          # 同步依赖(改动依赖或 l10n 输入后才需要)
flutter analyze --no-pub                 # 静态分析(flutter_lints)
dart run custom_lint                     # Lab Design System 规则(颜色/间距/圆角)
flutter test --no-pub                    # 全部测试
flutter test --no-pub test/services/scheduler_service_test.dart   # 单文件
flutter test --no-pub --name "substring of test description"      # 单用例
flutter run -d macos                     # 本地运行(也可 -d windows / -d linux)
flutter run -d macos -t lib/main_gallery.dart  # Lab 组件画廊(设计系统预览)
```

UI 一致性一键检查(等价于 CI):`./scripts/ui_check.sh` —— 依次跑 pub get → analyze → custom_lint → widget smoke → golden。交付任何 UI 改动前请跑这个。

本地网络命令需走代理(`git push`、`flutter pub get` 等):
```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
```

**不能在 macOS 上直接构建 Windows 产物**;需要 Windows 机器或 GitHub Actions(push `v*` tag 触发 `release.yml` 三平台构建)。

## 架构总览

入口 `lib/main.dart` 在 `runZonedGuarded` 中初始化文件日志(`LogStorageService`)、window_manager,然后在首帧前 `await themeManager.load()` 以避免主题闪烁(FOUC)。`MultiProvider` 装配全部全局状态(均为 `ChangeNotifier`):

- **LabThemeManager** — 8 套 Lab 主题 + 明暗模式,持久化到 SharedPreferences。
- **LanguageProvider** — en/zh 切换。
- **StatusRegistry** — 全局状态横幅(底部),用于上报关键错误。
- **TimesheetProvider** — 工时记录。
- **MqttController** — 模拟运行生命周期。
- **StatisticsCollector** — 经 `ChangeNotifierProxyProvider` 从 MqttController 取得,跟随其重建。

注意 `main.dart` 里有一层兼容桥:在 LabTokens 主题上额外注入一个中性的 `AppThemeEffect` extension,只为让尚未迁移的 legacy 页面(simulator_panel、simulator_log_dock、timestamp_tool)读取它时不空崩。迁移完这些页面后这层桥应被移除。

### MQTT 模拟核心(改动前务必先读)

这是应用的业务核心,分层清晰,改动前先理解三者关系:

- `lib/viewmodels/mqtt_view_model.dart` — 表单/配置层。持有所有 `TextEditingController`、SSL/QoS、分组与自定义键配置;负责导入/导出 profile、校验。
- `lib/services/mqtt_controller.dart` — 运行生命周期。`SimulationRunState` 状态机(idle/starting/connecting/running/reconnecting/partialRunning/stopping/failed),协调 manager 与 scheduler。通过工厂注入 `MqttClientManager` 以便测试。
- `lib/services/mqtt/mqtt_client_manager.dart` — 多客户端连接管理 + 指数退避无限重连(2s→30s)。
- `lib/services/mqtt/scheduler_service.dart` — 发送调度。`ScheduleDecision` 决定每 tick 发多少 / 延迟多少 / 丢弃多少(低延迟下的 drop-vs-catch-up 行为)。
- 重型遥测数据生成走 `lib/utils/isolate_worker.dart`(isolate),避免阻塞 UI。

### UI 分层

- `lib/ui/shell/` — 应用骨架:`AppNavigationRail`(左侧导航)+ `MainContentSwitcher`(按 index 切换)+ settings/status banner。两者之间的导航 index 契约是约定接口,UI-only 任务勿改。
- `lib/ui/screens/` — `home_screen`(主壳,含日志节流逻辑)、`timesheet_screen`。
- `lib/ui/lab/` — **Lab Design System**:`tokens/`(LabTokens 间距/圆角、LabThemes、oklch 色彩、文本主题)+ `components/`(原子组件)+ `lab_gallery`(画廊预览)。
- `lib/ui/components/` — 项目通用组件:`AppSection`、`AppInputDecoration`、`FormGrid`、`MetricChip`、`IconTooltipButton`、`AppEmptyState`。
- `lib/ui/tools/` — 独立工具:证书生成、JSON 格式化、时间戳。
- `lib/ui/widgets/` — 模拟器专用 widget(config section、groups/custom keys manager、log console、performance monitor、profile sidebar、json tree view)。
- `lib/ui/styles/` — `app_constants`、`app_theme_effect`(legacy 兼容)。

`lib/services/` 还含证书工具链(generator / package builder / address parser)、config/profile 持久化、`simulation_config_validator`、`log_storage_service`。

## 关键约定

### 状态管理
仅用 **Provider + ChangeNotifier**(`context.watch` / `Consumer`)。**不要**引入 Riverpod / Bloc / GetX,除非明确要求。SharedPreferences 用于简单 KV 持久化,key 定义为类顶部的 `static const String`,写入时做 500–1000ms 防抖。

### 国际化(硬性要求)
所有用户可见文本(含 tooltip、日志消息)**禁止硬编码**(中英文都不行)。例外:协议名、单位、log payload、测试 fixture。流程:先查 `lib/l10n/app_en.arb` 与 `app_zh.arb` → 有则用 `AppLocalizations.of(context)!.keyName` → 没有就**同时**加到两个 arb 文件再用。改了 arb 后跑 `flutter pub get`(`generate: true` 会重新生成 `lib/l10n/generated/`,勿手改 generated 文件)。key 用 camelCase。

### UI 设计系统(三层防线)
- **L1 静态**:`flutter analyze` + `dart run custom_lint`(规则包 `tooling/lab_lints/`)。`avoid_hardcoded_color`=ERROR、`avoid_raw_edge_insets`=WARNING、`prefer_lab_tokens`=INFO。
- **L2 视觉回归**:`flutter test test/golden/` —— 每个 Lab 组件有 signal(暗)+ paper(亮)两张基线 PNG。
- **L3 冒烟**:`flutter test test/widgets/`。

颜色用语义 token,**禁止** `Colors.blue` / `Color(0xRRGGBB)`:主色 `Theme.of(context).colorScheme.primary`、文本 `onSurface`/`onSurfaceVariant`、边框 `outline`/`outlineVariant`、错误 `colorScheme.error`、状态色 `LabTokens.of(context).ok`/`.warn`。间距/圆角用 `LabTokens.of(context).sXxx`/`.rXxx`(见 [docs/ui_consistency_guide.md](docs/ui_consistency_guide.md) 表格)。默认组件圆角 8px。

新建组件复用优先级:`lib/ui/lab/components/` → `lib/ui/components/` → 同 feature 目录已有 widget;实在没有才新增,且要放进设计系统或对应 feature 目录,不要散落在页面文件里。

反馈用底部 Status Bar 容器,**不要**用 `SnackBar` 或 `Dialog`。保持 toolbar/button/form/grid 尺寸稳定,避免 hover/校验/loading/本地化导致布局抖动。不要在装饰卡片里嵌套装饰卡片。

### legacy 文件迁移
约 25 个 legacy 文件首行有 `// ignore_for_file: avoid_hardcoded_color, ...` 豁免。迁移某文件时:替换全部硬编码 → `dart run custom_lint` 确认该文件 0 违规 → **删掉首行 ignore 注释**(或只留未解决的规则)→ `./scripts/ui_check.sh` 全绿后提交。迁移粒度:**每组件独立 commit**,提交前跑 analyze + smoke,**未授权不要 push**。

### golden 失败处理
- **基线以 CI(ubuntu-latest + 固定 Flutter 版本)渲染为准**。在本机 macOS 直接跑 `flutter test test/golden/` / `./scripts/ui_check.sh` 会因跨 OS 抗锯齿差异**整体失配**(每个组件都差 ~1%~2%,差异只落在字形/边框边缘)—— 这不是回归,本机这几个 golden 报错可忽略。判断"是否真回归"只在 CI/Linux 上有效。
- 在 **CI/Linux 上**没动 Lab 组件却挂了 = 真回归,看 `test/golden/failures/*.png` diff 定位(差异是整块色差/位移,而非仅边缘抗锯齿)。
- 改了组件/token 需刷新基线:**必须在 Linux 环境生成**,否则刷出来的 macOS 基线又会和 CI 失配。两种方式:① 在 Linux/Docker 里跑 `./scripts/ui_golden_update.sh [组件名]`;② 让 CI 跑一遍,从失败 run 的 `golden-failures` artifact 下载 `*_testImage.png`(即 CI 实际渲染),改名覆盖 `test/golden/goldens/*.png`。两种都要**人工肉眼比对 PNG**,并在 commit message 注明刷新原因。
- golden 文本只能用 ASCII(测试环境无 CJK fallback)。

## 测试映射(改了什么 → 跑什么)

不要只依赖孤立单测;凡是动到导航、Provider 装配、dialog、本地化、主题切换,都要跑 widget smoke。

| 改动 | 必须更新/运行的测试 |
|---|---|
| 应用骨架 / 导航 | `test/widgets/home_screen_smoke_test.dart` |
| 跨功能 UI | `test/widgets/all_features_smoke_test.dart` |
| 日志控制台布局 | `test/widgets/log_console_test.dart` |
| 模拟生命周期 | `test/services/mqtt_controller_lifecycle_test.dart` |
| 调度 / 计时 | `test/services/scheduler_service_test.dart` |
| 大数据量 / 性能敏感 | `test/services/simulation_load_test.dart` |
| Lab 组件 / token | 对应 `test/golden/lab_*_golden_test.dart` |

大范围 UI 工作时按模块逐个推进:① 应用骨架与导航 → ② `lib/ui/components/` 共享组件 → ③ 模拟器配置面板 → ④ 日志/监控 → ⑤ timesheet → ⑥ 设置/主题/语言/dialog → ⑦ 工具页(时间戳、JSON)。每个模块以聚焦测试收尾。

## 不要触碰的业务边界(UI-only 任务中)

MQTT 连接生命周期/重连/start-stop/调度行为、遥测 payload 生成规则与 drop-vs-catch-up、模拟校验规则、config 导入导出格式、timesheet 持久化格式、`AppNavigationRail`↔`MainContentSwitcher` 的导航 index 契约。若 UI 改动看似需要动这些业务逻辑,先停下来说明依赖。

## 常见陷阱

- tab 切换勿丢用户输入 → 用 `AutomaticKeepAliveClientMixin`(见 `keep_alive_wrapper.dart`)或 SharedPreferences。
- async gap 后 `setState`/用 BuildContext 前先查 `mounted`(`use_build_context_synchronously` 已开严格检查)。
- 不要在 `lib/` 根目录新建文件(入口 `main.dart`/`main_gallery.dart` 除外)。

## Git 提交风格

中文 emoji Conventional Commit,例如:
```
✨ feat(ui): 统一模拟器配置面板样式
🐛 fix(log): 修复日志控制台窄屏溢出
🚀 release: 发布 v1.5.5 全功能冒烟测试版本
```

发布流程:更新 `pubspec.yaml` version → analyze + test → commit → 打 annotated `vX.Y.Z` tag → push main 与 tag 触发 GitHub Actions。
