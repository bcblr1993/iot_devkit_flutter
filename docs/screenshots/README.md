# Screenshots

这里保存 README 使用的真实运行截图。当前截图来自 macOS Release 构建：

| 文件名 | 用途 | 推荐尺寸 |
|---|---|---|
| `01-mqtt-simulator.png` | 主屏：MQTT 模拟器配置、订阅、指标、日志 | 1600×1000 |
| `02-timestamp-converter.png` | 时间戳转换工具页 | 1600×1000 |
| `03-cert-generator.png` | 证书生成工具页 | 1600×1000 |

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

README 引用上述 3 张图片。替换截图时请保持文件名一致，并避免嵌入真实 broker、证书、账号或客户信息。
