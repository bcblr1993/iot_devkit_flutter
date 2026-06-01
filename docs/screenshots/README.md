# Screenshots

把 app 实际运行截图放到这里，文件名按 README 引用的路径命名即可：

| 文件名 | 用途 | 推荐尺寸 |
|---|---|---|
| `01-mqtt-simulator.png` | 主屏：MQTT 模拟器配置 + 日志 | 1600×1000 |
| `02-json-formatter.png` | JSON 格式化工具页 | 1600×1000 |
| `03-timestamp-converter.png` | 时间戳转换工具页 | 1600×1000 |
| `04-cert-generator.png` | 证书生成工具页 | 1600×1000 |
| `05-timesheet.png` | 工时记录页 | 1600×1000 |
| `06-themes-grid.png` | 8 套主题对比拼图（横向 4×2 或 2×4） | 2000×1200 |

## 怎么截

```bash
# macOS：先把窗口拉到 1600×1000
flutter run -d macos
# 在 app 内截图：Cmd+Shift+4，框选窗口
# 输出到 ~/Desktop/Screen Shot xxx.png，重命名后放入此目录
```

## 命名约定

- 全部 PNG，统一前缀 `NN-feature.png`（NN 是两位数字序号）
- 不要嵌入个人/真实 broker 地址或证书内容
- 图片体积 > 500KB 时用 [`pngquant`](https://pngquant.org/) 压一下：
  ```bash
  pngquant --quality 70-90 *.png --ext .png --force
  ```

README 已经预留对应 `<img>` 引用，文件名一致时自动显示。
