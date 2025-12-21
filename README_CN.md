# IoT DevKit - MQTT 电子仿真器 (Flutter 版)

**IoT DevKit** 是专为物联网开发者打造的强大跨平台工具箱。它目前集成了强大的 MQTT 模拟器、JSON 格式化/查看工具以及时间戳转换工具。

本项目已从旧版本由 **Flutter** 重构，支持 macOS、Windows 和 Linux 三大桌面平台。

## 🚀 核心功能

### 1. MQTT 模拟器 (MQTT Simulator)
*   **基础模式**：模拟单个设备发送遥测数据。
*   **高级模式**：模拟成千上万个设备，支持复杂的发送策略。
*   **灵活配置**：
    *   支持随机数、递增、静态值、布尔翻转等多种数据定义方式。
    *   支持导入/导出模拟配置文件 (`.json`)。
*   **高性能**：专为高频数据生成而优化。

### 2. JSON 格式化工具 (JSON Formatter Tool)
*   **校验与格式化**：支持 JSON 格式化与压缩 (Minify)，并提供错误提示。
*   **交互式树状视图**：支持折叠/展开的 JSON 树形结构，便于查看复杂数据。
*   **持久化**：自动保存您的输入内容和查看状态，防止数据丢失。
*   **搜索功能**：可在特定 JSON 路径中过滤键和值。

### 3. 时间戳转换器 (Timestamp Converter)
*   **实时时钟**：显示毫秒级精度的当前时间。
*   **双向转换**：支持时间戳 (秒/毫秒) 与日期字符串之间的互转。
*   **多时区支持**：内置全球主流时区选择。
*   **持久化**：记住您的输入历史和时区选择。
*   **智能复制**：一键复制转换结果。

### 4. UI/UX 体验
*   **现代设计**：基于 Material 3 风格的响应式布局。
*   **多主题支持**：内置 8+ 款精美主题 (科技蓝、赛博朋克、自然绿等)。
*   **国际化**：全面支持简体中文 (`zh`) 和 英文 (`en`)。
*   **统一反馈**：采用非侵入式的底部状态栏展示操作反馈。

---

## 🛠 技术栈

*   **框架**：Flutter (Dart)
*   **状态管理**：Provider (`ChangeNotifier`)
*   **本地存储**：Shared Preferences (用于持久化)
*   **MQTT**：`mqtt_client` 库
*   **国际化**：`flutter_localizations` (.arb 文件)
*   **打包工具**：`flutter_distributor` / Inno Setup (Windows)

---

## 📂 项目结构

```
lib/
├── l10n/                  # 国际化资源文件 (.arb)
├── models/                # 数据模型 (配置, 枚举)
├── services/              # 业务逻辑 (MQTT服务, 主题管理)
├── ui/
│   ├── pages/             # 主要页面 (如首页)
│   ├── tools/             # 独立工具组件 (JsonTool, TimestampTool)
│   ├── widgets/           # 可复用组件 (侧边栏, 面板)
│   └── styles/            # 主题定义
└── main.dart              # 程序入口与全局 Provider 设置
```

---

## ⚡️ 快速开始

### 前置条件
*   已安装 [Flutter SDK](https://flutter.dev/docs/get-started/install)。
*   推荐使用 VS Code 或 Android Studio。

### 安装步骤
1.  克隆仓库到本地。
2.  安装依赖：
    ```bash
    flutter pub get
    ```
3.  生成国际化代码 (如有需要)：
    ```bash
    flutter gen-l10n
    ```

### 本地运行
```bash
# MacOS
flutter run -d macos

# Windows
flutter run -d windows
```

---

## 📦 构建与打包

### 手动构建
*   **macOS**: `flutter build macos --release` (产物路径: `build/macos/Build/Products/Release/`)
*   **Windows**: `flutter build windows --release` (产物路径: `build/windows/runner/Release/`)

### 自动化打包 (推荐)
本项目配置了 `flutter_distributor` 和 GitHub Actions。

1.  **本地打包**：
    *   安装工具：`dart pub global activate flutter_distributor`
    *   生成 MacOS DMG：`flutter_distributor release --name release --jobs macos-dmg`
    *   生成 Windows EXE：`flutter_distributor release --name release --jobs windows-exe` (需要安装 Inno Setup)

2.  **CI/CD (GitHub Actions)**：
    *   只需打一个 tag (如 `v1.0.0`) 并推送到 GitHub，即可触发 `.github/workflows` 中定义的自动构建流程。

---

## 📝 作者

**Chen Xu**
*   项目：IoT DevKit Refactor
