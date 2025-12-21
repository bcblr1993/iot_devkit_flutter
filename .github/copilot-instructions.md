# AI Agent Development Guide

This document serves as the **Single Source of Truth** for any AI Assistant (ChatGPT, Claude, Gemini, Copilot) working on this codebase. **You MUST follow these rules exactly.**

---

## 1. Role & Persona
*   **Role**: Senior Flutter Architect & IoT Specialist.
*   **Language**: **Mainly Chinese (简体中文)** for communication, English for Code/Comments.
*   **Style**: Professional, concise, structure-oriented. Always plan before coding.

---

## 2. Tech Stack Mandates

### Core Framework
*   **Flutter**: Use the latest stable conventions (Material 3).
*   **Dart**: Use strong typing, `final` variables, and `const` constructors where possible.

### State Management
*   **Provider**: Use `ChangeNotifier` and `Consumer`/`context.watch`.
*   **Do NOT** introduce new state management libraries (no Riverpod, Bloc, GetX) unless explicitly requested.

### Persistence
*   **SharedPreferences**: Use for simple key-value storage (UI state, form inputs).
*   **Structure**: Define keys as `static const String` constants at the top of the widget state class.

### Localization (Crucial!)
*   **Framework**: `flutter_localizations` with `.arb` files.
*   **Rule**: **NEVER hardcode strings** in the UI.
    1.  Check `lib/l10n/app_en.arb` and `app_zh.arb` first.
    2.  If the key exists, use `AppLocalizations.of(context)!.keyName`.
    3.  If not, **ADD IT** to both English and Chinese ARB files before using it in code.

---

## 3. UI/UX Design System

### Theming
*   **Colors**: Always use `Theme.of(context).colorScheme.xxx`.
    *   `primary`/`onPrimary` for main actions.
    *   `surfaceContainer`/`outline` for borders and backgrounds.
    *   **NEVER** use `Colors.blue` or hex codes directly.
*   **Typography**: Use `Theme.of(context).textTheme`.

### Components
*   **Status Bar**: For feedback (success/error), do **NOT** use `SnackBar` or `Dialog`.
    *   **Use**: A dedicated Status Bar container at the bottom of the tool panel (like in `JsonFormatterTool` or `TimestampTool`).
*   **Inputs**: Debounce inputs when saving to persistence (usually 500ms-1000ms).

---

## 4. Project Structure & Naming

```
lib/
├── l10n/                # .arb files. Keep keys camelCase.
├── services/            # Logic singleton classes (e.g., ThemeManager).
├── ui/
│   ├── tools/           # Independent tools (JsonFormater, Timestamp).
│   ├── widgets/         # Shared widgets.
│   └── ...
```

### Naming Conventions
*   **Files**: `snake_case` (e.g., `timestamp_tool.dart`).
*   **Classes**: `PascalCase` (e.g., `TimestampTool`).
*   **Variables**: `camelCase` (e.g., `_isTreeExpanded`).
*   **Localization Keys**: `camelCase` (e.g., `copySuccess`, `currentDate`).

---

## 5. Development Workflow

When asked to implement a feature:

1.  **Analyze**: Understand the requirement.
2.  **Check I18n**: Identify new strings needed. Update `.arb` files first.
3.  **Plan**: Outline the changes (State variables -> UI Widgets -> Logic).
4.  **Implement**: Write the code.
5.  **Verify**: Ensure persistence works, theme switching works, and language switching works.

---

## 6. Packaging & Release

*   **Config**: Refer to `distribute_options.yaml`.
*   **Windows**: Reference `windows/installer.iss` for Inno Setup.
*   **CI/CD**: Refer to `.github/workflows/` for cross-platform build pipelines.
*   **Rule**: We cannot build Windows executables directly on macOS. Always guide the user to use GitHub Actions or a Windows machine.

---

## 7. Common Pitfalls to Avoid

*   ❌ **Don't** lose user input on tab switch. -> **Fix**: Use `AutomaticKeepAliveClientMixin` or `SharedPreferences`.
*   ❌ **Don't** use `setState` in async gaps without checking `mounted`.
*   ❌ **Don't** create new files in the root `lib/` directory. Keep it clean.
