# IoT DevKit - MQTT Electron Simulator (Flutter Version)

**IoT DevKit** is a powerful, cross-platform utility toolkit designed for IoT developers. It currently features a robust MQTT Simulator, JSON formatting/viewing tools, and Timestamp conversion utilities.

This project has been refactored from an older version to a modern **Flutter** application, supporting macOS, Windows, and Linux.

## 🚀 Key Features

### 1. MQTT Simulator
*   **Basic Mode**: Simulate a single device sending telemetry data.
*   **Advanced Mode**: Simulate thousands of devices with complex strategies.
*   **Configuration**: 
    *   Support for random, increment, static, and toggle data definition.
    *   Import/Export simulation profiles (`.json`).
*   **Performance**: Optimized for high-frequency data generation.

### 2. JSON Formatter Tool
*   **Validation & Formatting**: Format/Minify JSON with error handling.
*   **Interactive Tree View**: Collapsible/Expandable JSON tree for easy navigation.
*   **Persistence**: Automatically saves your input and state.
*   **Search**: Filter keys and values within specific JSON paths.

### 3. Timestamp Converter
*   **Real-time Clock**: Displays millisecond-precision current time.
*   **Bi-directional Conversion**: Convert between Timestamp (ms/s) and Date strings.
*   **Timezone Support**: Extensive list of global timezones.
*   **Persistence**: Remembers your last inputs and timezone selections.
*   **Smart Copy**: One-click copy for results.

### 4. UI/UX
*   **Modern Design**: Material 3 styled UI with responsive layouts.
*   **Multi-Theme**: 8+ Custom themes (Tech Blue, Cyberpunk, Nature Green, etc.).
*   **Internationalization**: Full support for English (`en`) and Chinese (`zh`).
*   **Unified Feedback**: Non-intrusive bottom status bars for actions.

---

## 🛠 Tech Stack

*   **Framework**: Flutter (Dart)
*   **State Management**: Provider (`ChangeNotifier`)
*   **Storage**: Shared Preferences (Local persistence)
*   **MQTT**: `mqtt_client` package
*   **Localization**: `flutter_localizations` (.arb files)
*   **Packaging**: `flutter_distributor` / Inno Setup (Windows)

---

## 📂 Project Structure

```
lib/
├── l10n/                  # Localization (.arb) + generated AppLocalizations
├── models/                # Data models (configs, schema, simulation context)
├── services/              # Business logic (theme, config/profile, certificates, logging)
│   └── mqtt/              # Client manager + send scheduler
├── viewmodels/            # Provider/ChangeNotifier state (MqttViewModel, Timesheet)
├── ui/
│   ├── shell/             # App shell: navigation rail, content switcher, status banner
│   ├── screens/           # Top-level screens (Home, Timesheet)
│   ├── lab/               # Lab design system (tokens + atomic components + gallery)
│   ├── components/        # Shared UI primitives (AppSection, FormGrid, MetricChip, ...)
│   ├── tools/             # Standalone tools (JSON, Timestamp, Certificate generator)
│   ├── widgets/           # Simulator-specific widgets (config, log console, monitor, ...)
│   └── styles/            # Theme constants / effects
├── utils/                 # Helpers (isolate worker, dialogs, toast, statistics)
├── config/                # Static constants
├── main.dart              # App entry & Provider setup
└── main_gallery.dart      # Lab design-system gallery entry
```

---

## ⚡️ Getting Started

### Prerequisites
*   [Flutter SDK](https://flutter.dev/docs/get-started/install) installed.
*   VS Code or Android Studio (recommended).

### Installation
1.  Clone the repository.
2.  Install dependencies:
    ```bash
    flutter pub get
    ```
3.  Generate localization files (if needed):
    ```bash
    flutter gen-l10n
    ```

### Running Locally
```bash
# MacOS
flutter run -d macos

# Windows
flutter run -d windows
```

---

## 📦 Building & Packaging

### Manual Build
*   **macOS**: `flutter build macos --release` (Output: `build/macos/Build/Products/Release/`)
*   **Windows**: `flutter build windows --release` (Output: `build/windows/runner/Release/`)

### Automated Packaging (Recommended)
This project uses `flutter_distributor` and GitHub Actions.

1.  **Local Packaging**:
    *   Install: `dart pub global activate flutter_distributor`
    *   MacOS DMG: `flutter_distributor release --name release --jobs macos-dmg`
    *   Windows EXE: `flutter_distributor release --name release --jobs windows-exe` (Requires Inno Setup)

2.  **CI/CD (GitHub Actions)**:
    *   Push a tag (e.g., `v1.0.0`) to GitHub to trigger the auto-build workflow defined in `.github/workflows`.

---

## 📝 Author

**Chen Xu**
*   Project: IoT DevKit Refactor
