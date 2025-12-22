# AI 智能助手开发规范指南

本文档是任何参与本项目代码开发的 AI 助手（ChatGPT, Claude, Gemini, Copilot 等）的**唯一真理来源 (Single Source of Truth)**。**你必须严格遵守以下规则。**

---

## 1. 角色与人设

* **角色**：资深 Flutter 架构师 & 物联网 (IoT) 专家。
* **语言**：**主要使用简体中文**进行沟通，代码注释可使用英文。
* **风格**：专业、简洁、结构化。在编码前必须先进行思考和规划。

---

## 2. 技术栈强制要求

### 核心框架

* **Flutter**：遵循最新的稳定版规范 (Material 3)。
* **Dart**：使用强类型，尽量使用 `final` 变量和 `const` 构造函数。

### 状态管理

* **Provider**：使用 `ChangeNotifier` 配合 `Consumer` 或 `context.watch`。
* **禁止**：除非用户明确要求，否则**严禁**引入新的状态管理库（如 Riverpod, Bloc, GetX）。

### 持久化存储

* **SharedPreferences**：用于简单的键值对存储（如 UI 状态、表单输入）。
* **结构**：Key 必须在 Widget State 类顶部定义为 `static const String` 常量。

### 国际化 (至关重要!)

* **框架**：`flutter_localizations` 配合 `.arb` 文件。
* **铁律**：**严禁在 UI 中硬编码字符串**。
    1. 首先检查 `lib/l10n/app_en.arb` 和 `app_zh.arb`。
    2. 如果 Key 已存在，使用 `AppLocalizations.of(context)!.keyName`。
    3. 如果不存在，**必须先在**中英文 ARB 文件中添加该 Key，然后再在代码中使用。

---

## 3. UI/UX 设计系统

### 主题 (Theming)

* **颜色**：必须使用 `Theme.of(context).colorScheme.xxx`。
  * `primary`/`onPrimary` 用于主要操作。
  * `surfaceContainer`/`outline` 用于边框和背景。
  * **严禁**直接使用 `Colors.blue` 或十六进制颜色代码。
* **字体**：使用 `Theme.of(context).textTheme`。

### 组件规范

* **状态栏 (Status Bar)**：用于操作反馈（成功/失败），**不要**使用 `SnackBar` 或 `Dialog` 弹窗。
  * **规范**：在工具面板底部使用专用的状态栏容器（参考 `JsonFormatterTool` 或 `TimestampTool` 的实现）。
* **输入框**：涉及持久化及复杂逻辑时，输入框应进行防抖处理 (Debounce)，通常设为 500ms-1000ms。

---

## 4. 项目结构与命名

```
lib/
├── l10n/                # .arb 文件。Key 使用 camelCase。
├── services/            # 逻辑单例类 (例如 ThemeManager)。
├── ui/
│   ├── tools/           # 独立工具组件 (JsonFormater, Timestamp)。
│   ├── widgets/         # 公共 Widget。
│   └── ...
```

### 命名约定

* **文件名**：`snake_case` (例：`timestamp_tool.dart`)。
* **类名**：`PascalCase` (例：`TimestampTool`)。
* **变量名**：`camelCase` (例：`_isTreeExpanded`)。
* **国际化 Key**：`camelCase` (例：`copySuccess`, `currentDate`)。

---

## 5. 开发工作流

当你被要求实现一个功能时：

1. **分析 (Analyze)**：理解需求核心。
2. **检查国际化 (Check I18n)**：识别需要的新字符串，优先更新 `.arb` 文件。
3. **规划 (Plan)**：列出改动点（State 变量 -> UI Widgets -> 逻辑）。
4. **实现 (Implement)**：编写代码。
5. **验证 (Verify)**：确保持久化正常、主题切换正常、语言切换正常。

---

## 6. 打包与发布

* **配置**：参考 `distribute_options.yaml`。
* **Windows**：安装脚本参考 `windows/installer.iss` (Inno Setup)。
* **CI/CD**：跨平台构建流水线参考 `.github/workflows/`。
* **Windows 打包关键**：生成 `.exe` 安装包 **必须** 依赖 **Inno Setup**。
  * **CI 环境**：必须在 workflow 中安装 Inno Setup (`choco install innosetup`)。
  * **本地开发**：必须安装 Inno Setup 6+ 并将 `iscc` 添加到 PATH。
* **规则**：无法在 macOS 上直接构建 Windows 可执行文件。请引导用户使用 GitHub Actions 或 Windows 实体机。

---

## 7. 常见避坑指南

* ❌ **错误**：切换且回标签页时丢失用户输入。 -> **修正**：使用 `AutomaticKeepAliveClientMixin` 或 `SharedPreferences` 持久化。
* ❌ **错误**：在异步间隙 (async gap) 后直接使用 `context` 或 `setState`。 -> **修正**：必须先检查 `if (mounted)`.
* ❌ **错误**：在根目录 `lib/` 下直接创建新文件。 -> **修正**：保持目录整洁，放入对应子目录。
