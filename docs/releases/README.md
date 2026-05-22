# GitHub Release 发布说明风格

以后发布 `vX.Y.Z` 时，GitHub Actions 会自动生成类似产品更新日志的中文发布说明。

## 标题

发布标题固定为：

```text
IoT DevKit vX.Y.Z
```

## 正文结构

正文优先使用 `docs/releases/vX.Y.Z.md`。如果没有对应文件，则根据本次版本区间内的 Git commit 自动分组生成：

- `新增`：`feat`、`新增`、`支持`
- `修复`：`fix`、`修复`、`问题`
- `优化`：`refactor`、`style`、`ui`、`优化`、`重构`、`release`
- `验证`：`test`、`ci`、`build`、`验证`、`测试`

建议重要版本手工新增 `docs/releases/vX.Y.Z.md`，保持下面这种格式：

```markdown
## 新增

- 新增某个能力。

## 修复

- 修复某个现场问题。

## 验证

- 已通过 `flutter analyze --no-pub`、`flutter test --no-pub` 和 `flutter build macos --no-pub`。

**完整更新日志：** [vX.Y.Y...vX.Y.Z](https://github.com/bcblr1993/iot_devkit_flutter/compare/vX.Y.Y...vX.Y.Z)
```
