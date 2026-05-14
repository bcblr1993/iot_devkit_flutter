# AGENTS.md

## Project Role

This is a Flutter desktop app for IoT MQTT device simulation, timestamp conversion, JSON tooling, and a lightweight timesheet note flow.

Treat this project as a product tool, not a marketing site. UI changes should be dense, predictable, and operational. Prefer stable controls, clear status, low visual noise, and fast repeated use.

## Core Commands

Use these commands before handing off relevant changes:

```bash
flutter analyze --no-pub
flutter test --no-pub
flutter build macos --no-pub
```

Use `flutter pub get` only when dependencies or generated localization inputs require it.

## UI System Rules

- Do not introduce React, Tailwind, or shadcn/ui packages. This is a Flutter app.
- Use the project’s Flutter design system instead:
  - `ThemeManager` for themes and `ColorScheme` tokens.
  - `AppThemeEffect` for density, icon style, radius, and motion flavor.
  - `lib/ui/components/` for reusable UI primitives.
  - `AppSection`, `AppInputDecoration`, `FormGrid`, `MetricChip`, and `IconTooltipButton` before creating new local one-off widgets.
- Use semantic theme colors such as `colorScheme.primary`, `surfaceContainerLowest`, `surfaceContainerLow`, `outlineVariant`, `onSurface`, `onSurfaceVariant`, and `error`.
- Avoid hardcoded colors in widgets. Exceptions are protocol/status-specific colors already established by the project, but prefer wrapping them in a semantic helper if reused.
- Use 8px as the default component radius. Larger radius must have a specific reason.
- Keep toolbar, button, form, and grid dimensions stable so hover, validation, loading text, or localization does not shift layout.
- Do not nest decorative cards inside decorative cards. Use panels only for meaningful grouped controls or repeated records.
- Prefer icon buttons with tooltips for compact tool actions. Use text buttons for explicit commands.
- All user-visible text must go through ARB localization unless it is a protocol name, unit, log payload, or test fixture.

## Feature Boundaries

Do not modify these business paths as part of a UI-only task:

- MQTT connection lifecycle, reconnect logic, start/stop semantics, and scheduler behavior.
- Telemetry payload generation rules and low-latency drop-vs-catch-up behavior.
- Simulation validation rules unless the request is explicitly about validation.
- Config import/export format.
- Timesheet persistence format.
- Routing/navigation index contracts between `AppNavigationRail` and `MainContentSwitcher`.

If a UI issue appears to require business logic changes, stop and explain the dependency first.

## Preferred UI Migration Order

For broad UI work, move one module at a time:

1. App shell and navigation.
2. Shared components in `lib/ui/components/`.
3. Simulator configuration panels.
4. Log console and monitoring surfaces.
5. Timesheet.
6. Settings, theme, language, and dialogs.
7. Tool pages: timestamp and JSON.

Each module should end with focused tests.

## Testing Expectations

- App shell or navigation changes must update or run `test/widgets/home_screen_smoke_test.dart`.
- Cross-feature UI changes must update or run `test/widgets/all_features_smoke_test.dart`.
- Log console layout changes must update or run `test/widgets/log_console_test.dart`.
- Simulation lifecycle changes must update or run `test/services/mqtt_controller_lifecycle_test.dart`.
- Scheduler/timing changes must update or run `test/services/scheduler_service_test.dart`.
- Large-data or performance-sensitive changes must update or run `test/services/simulation_load_test.dart`.

Do not trust isolated unit tests alone for app-shell work. Run widget smoke tests whenever navigation, provider wiring, dialogs, localization, or theme switching changes.

## Codex Workflow

- Read the existing widget/component before editing.
- Keep changes narrowly scoped to the requested module.
- Prefer improving existing shared primitives over adding repeated local styles.
- Do not reformat unrelated files.
- Do not revert user changes.
- Report modified files, verification commands, and any residual risk.

## Git And Release Style

Use Chinese emoji Conventional Commit messages, for example:

```text
✨ feat(ui): 统一模拟器配置面板样式
🐛 fix(log): 修复日志控制台窄屏溢出
🚀 release: 发布 v1.5.5 全功能冒烟测试版本
```

Before release:

1. Update `pubspec.yaml` version.
2. Run analyze and tests.
3. Commit intentionally.
4. Create an annotated `vX.Y.Z` tag.
5. Push `main` and the tag to trigger GitHub Actions.
