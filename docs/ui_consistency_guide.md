# UI 一致性治理指南

> 适用项目：`iot_devkit_flutter`
> 维护者：UI 平台 / Lab Console 迁移负责人
> 最近更新：2026-05-20

本指南是 UI 一致性治理三层防线的使用手册。如果你在写一个新组件、迁移一个老页面、修一个视觉 bug，先读这一篇。

---

## 1. 三层防线全景

```
┌────────────────────────────────────────────────────────────────┐
│ L1  静态约束                                                    │
│ flutter analyze + dart run custom_lint                          │
│ 规则包：tooling/lab_lints/                                       │
│   · avoid_hardcoded_color (ERROR)                               │
│   · avoid_raw_edge_insets (WARNING)                             │
│   · prefer_lab_tokens     (INFO)                                │
├────────────────────────────────────────────────────────────────┤
│ L2  视觉回归                                                    │
│ flutter test test/golden/                                       │
│ 基线：test/golden/goldens/*.png （signal 暗 + paper 亮 × 5 组件）│
├────────────────────────────────────────────────────────────────┤
│ L3  端到端冒烟（既有）                                            │
│ flutter test test/widgets/                                      │
│ 既有的 widget smoke，不在本治理新增范围                            │
└────────────────────────────────────────────────────────────────┘
```

CI 入口：[.github/workflows/ui_check.yml](../.github/workflows/ui_check.yml)
本地一键：`./scripts/ui_check.sh`

---

## 2. 写新代码：用什么、不用什么

### 颜色

| 场景 | ✅ 应该 | ❌ 不应该 |
|---|---|---|
| 主色 / 强调色 | `Theme.of(context).colorScheme.primary` | `Color(0xff00ff88)` |
| 文本主色 | `Theme.of(context).colorScheme.onSurface` | `Colors.black` |
| 状态绿（成功） | `LabTokens.of(context).ok` | `Colors.green` |
| 状态橙（警告） | `LabTokens.of(context).warn` | `Colors.orange` |
| 错误红 | `Theme.of(context).colorScheme.error` | `Colors.red.shade400` |
| 边框 | `colorScheme.outline` / `outlineVariant` | `Color(0xff333333)` |

### 间距 (padding / margin / gap)

| 设计语义 | ✅ Token | 像素 |
|---|---|---|
| 极小（图标内距） | `tokens.sXxs` | 2 |
| 微小 | `tokens.sXs` | 4 |
| 小（字段间） | `tokens.sSm` | 6 |
| 标准（控件内） | `tokens.sMd` | 8 |
| 中（卡片内） | `tokens.sLg` | 12 |
| 大（分组间） | `tokens.sXl` | 16 |
| 超大 | `tokens.s2xl` / `s3xl` / `s4xl` | 20 / 24 / 32 |

### 圆角

| 设计语义 | ✅ Token | 像素 |
|---|---|---|
| 微圆角（角标） | `tokens.rXs` | 2 |
| 小（chip / pill） | `tokens.rSm` | 4 |
| 标准（按钮） | `tokens.rMd` | 6 |
| 中（输入框 / 弹层） | `tokens.rLg` | 8 |
| 大（卡片 / dialog） | `tokens.rXl` | 12 |

### 组件复用优先级

新建 UI 时，依次查：

1. `lib/ui/lab/components/`（设计系统原子组件）
2. `lib/ui/components/`（项目通用组件）
3. 同 feature 目录下已存在的 widget

只有当现有组件**无法表达明确新模式**时才新增，并放进 `lib/ui/lab/components/` 或对应 feature 目录，不要散落在页面文件里。

---

## 3. 跑检查

### 本地一键

```bash
./scripts/ui_check.sh
```

等价于：

```bash
flutter pub get
flutter analyze --no-pub               # ① 内建 lint
dart run custom_lint                   # ② Lab token 规则
flutter test --no-pub test/widgets/    # ③ widget smoke
flutter test --no-pub test/golden/     # ④ 视觉回归
```

### 单独看 Lab token 违规

```bash
dart run custom_lint
```

会打印每一条违规 + 严重度（ERROR/WARNING/INFO），CI 在任何违规上都会失败。

---

## 4. golden 失败怎么办

### 4.1 失败分类

CI 报 `test/golden/lab_xxx_golden_test.dart` 失败时，先判断：

| 情况 | 处理 |
|---|---|
| **意外回归**：你没动 Lab 组件，golden 却挂了 | 这是真 bug。看 diff，定位是哪个 commit 引入了视觉变化 |
| **预期变化**：你刚改了 Lab 组件 / token 值 | 走 4.2 流程刷新基线 |
| **平台/字体环境差异** | 永远在 Ubuntu 上跑 CI；本地若不是 Ubuntu，肉眼 diff 后再决定 |

### 4.2 刷新基线流程

```bash
# 全量刷
./scripts/ui_golden_update.sh

# 只刷某一组件
./scripts/ui_golden_update.sh lab_buttons
```

**刷完务必**：

1. 用图片浏览器肉眼 diff `test/golden/goldens/*.png` 是否符合预期
2. commit message 在末尾追加一段「golden 刷新原因」，例如：

   ```
   ...

   goldens: refreshed lab_buttons because LabButton.hPad sm: 8 → 10
   reviewer: please eyeball test/golden/goldens/lab_buttons_*.png
   ```

3. PR review 时，diff 视图中如果看到 `goldens/*.png` 变化，必须人工肉眼比对，不要只看代码

### 4.3 看 diff 截图

CI 失败时会上传 artifact `golden-failures`，里面是 `test/golden/failures/` 下的 PNG，类似 BackstopJS 的 diff 报告：

- `xxx_masterImage.png` — 仓库里的基线
- `xxx_testImage.png` — 这次跑出来的实际渲染
- `xxx_isolatedDiff.png` — 高亮像素差异（红色）

本地复现：跑完 `flutter test test/golden/` 失败后，直接打开 `test/golden/failures/`。

---

## 5. 迁移 legacy 文件

`lib/main.dart`、`lib/ui/widgets/*`、`lib/ui/screens/*`、`lib/utils/*` 等 25 个文件首行带有：

```dart
// ignore_for_file: avoid_hardcoded_color, avoid_raw_edge_insets, prefer_lab_tokens
```

这是迁移期豁免，标记"还没用 LabTokens 重写"。**当你迁移一个文件时**：

1. 把硬编码颜色/间距/圆角全部替换为 `colorScheme.*` / `LabTokens.of(context).*`
2. 跑 `dart run custom_lint`，确认该文件 0 违规
3. **删掉文件首行的 `// ignore_for_file:` 那一行**（或只保留还没解决的规则）
4. 跑 `./scripts/ui_check.sh` 全套通过后提交

迁移粒度：按你已存的偏好 — 每组件独立 commit，未授权不 push。

---

## 6. 增加新的 golden 覆盖

当你向 `lib/ui/lab/components/` 加新原子组件时：

1. 在 `test/golden/` 新建 `lab_xxx_golden_test.dart`，结构参考已有 5 个文件
2. 用 `pumpGoldenPair(tester, base: 'lab_xxx', child: ...)` 一次性生成 signal + paper 两张 PNG
3. **golden 文本只能用 ASCII**（测试环境无 CJK fallback，详见 `_lab_harness.dart` 顶部注释）
4. 跑 `./scripts/ui_golden_update.sh lab_xxx` 生成基线
5. 肉眼 review 两张 PNG 后入库

---

## 7. PR Checklist（贴到 PR 描述里）

```markdown
## UI 一致性自检

- [ ] `./scripts/ui_check.sh` 本地通过
- [ ] 触动 Lab 组件或 token 时，已重新生成 golden 并人工 review PNG
- [ ] 迁移了 legacy 文件时，已删除对应的 `// ignore_for_file:` 行
- [ ] 新增 Lab 原子组件时，已补 golden 测试
- [ ] PR 描述中说明了 goldens 变化的原因（如有）
```

---

## 8. 相关文件索引

| 路径 | 作用 |
|---|---|
| [`lib/ui/lab/`](../lib/ui/lab/) | Lab Console 设计系统（tokens + 组件） |
| [`tooling/lab_lints/`](../tooling/lab_lints/) | 自定义 lint 规则包 |
| [`test/golden/`](../test/golden/) | 视觉回归测试 + 基线 PNG |
| [`test/flutter_test_config.dart`](../test/flutter_test_config.dart) | 字体加载（确保 golden 跨机器一致） |
| [`scripts/ui_check.sh`](../scripts/ui_check.sh) | 本地一键检查 |
| [`scripts/ui_golden_update.sh`](../scripts/ui_golden_update.sh) | 刷新基线工具 |
| [`.github/workflows/ui_check.yml`](../.github/workflows/ui_check.yml) | CI 兜底 |
| [`docs/flutter_ui_design_system.md`](flutter_ui_design_system.md) | 设计系统设计原则 |
