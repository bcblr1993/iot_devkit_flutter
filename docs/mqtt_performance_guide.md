# MQTT 模拟器性能测试与扩容指南

本文用于回答三个问题：当前工作负载到底是多少、单进程上限如何测、何时应拆成多个进程。文中的本地实测来自 2026-07-13 的 Mac + Mosquitto 回环测试，只能作为客户端侧基线，**不能等同于远端 Windows + ThingsBoard 的精确上限**。

## 1. 当前 2000 设备工作负载

截图中的高级模式参数为：

- 设备数 `D = 2000`
- 每台设备总键数 `K = 500`
- 变化比例 `r = 0.3`
- 变化周期 `Tc = 1s`
- 全量周期 `Tf = 300s`
- QoS `0`
- 随机变化关闭

先定义：

- 每条变化消息的点数：`C = floor(K × r)`
- 全量摊平窗口：`Wf = min(Tf, 2s)`；当前调度器最多只把一次全量摊到 2 秒

常态变化上送：

```text
消息数/s = D / Tc
点数/s   = D × C / Tc
```

全量窗口新增压力（保守的“全量与变化同时发送”模型）：

```text
新增消息数/s = D / Wf
新增点数/s   = D × K / Wf
峰值消息数/s = D / Tc + D / Wf
峰值点数/s   = D × C / Tc + D × K / Wf
```

代入当前参数：

| 阶段 | 消息数/s | 点数/s |
|---|---:|---:|
| 常态变化上送 | 2,000 | 300,000 |
| 全量新增压力 | 1,000 | 500,000 |
| 保守重叠峰值 | 3,000 | 800,000 |

因此“500 点、秒级上送”不能直接理解为持续 `2000 × 500 = 100 万点/s`。常态实际是每台 150 个变化点，即 30 万点/s；真正危险的是每 300 秒一次、在约 2 秒内出现的全量尖峰。

当前调度代码只会在对应全量已经发布成功、且变化 tick 位于它之后时，抑制这一条已被覆盖的变化消息。如果变化 tick 先到或全量失败，变化消息仍会作为兜底发出，避免为了降峰而丢数据。因此 65 万点/s 只是全量及时完成时的理想峰值，最坏仍接近 80 万点/s；容量测试统一按更重的 80 万点/s 模型验收。

## 2. 可复用容量工具

工具入口：[`tool/mqtt_capacity_benchmark.dart`](../tool/mqtt_capacity_benchmark.dart)。它直接复用项目的 `PersistentIsolateManager`、`WorkerInput`、UTF-8 payload buffer 生成链和同版本 `mqtt_client`，默认执行历史故障对应的保守重叠压力：

- 每秒为每个设备生成 `floor(keys × changeRatio)` 个变化点；
- 全量按源码的最大 2 秒窗口摊开；
- 将全量周期从 300 秒压缩为 10 秒，14 秒内覆盖启动全量和第二次全量；
- 全量期间仍保留变化消息，以验证最坏情况下的客户端余量。

缩短全量周期会提高尖峰出现频率，但不会改变单次 2 秒全量窗口的理论瞬时峰值。

### 2.1 参数与失败路径自检

```bash
dart run tool/mqtt_capacity_benchmark.dart --self-check
```

应输出：

```json
{"event":"self-check","passed":true,"checks":["valid-argument-parse","invalid-argument-rejection","early-failure-outcome-initialization"]}
```

### 2.2 启动本地 Broker

macOS 已安装 Mosquitto 时：

```bash
mosquitto -p 18884
```

另开终端记录 broker 实收 PUBLISH 计数：

```bash
mosquitto_sub \
  -h 127.0.0.1 \
  -p 18884 \
  -t '$SYS/broker/publish/messages/received' \
  -v
```

`published` 表示 `mqtt_client.publishMessage()` 已接受消息，并不自动等同于 broker 已接收。测试前后 `$SYS/broker/publish/messages/received` 的增量应与工具的 `published` 一致；如果 broker 禁止 `$SYS`，应改用 broker 自带监控指标。

### 2.3 单进程复现 2000 设备

容量数据必须使用 AOT 可执行文件，不能把 `dart run` 的 JIT 首次编译抖动与下表 AOT 结果直接比较。项目固定使用 Flutter 3.41.8，请先确认当前 `flutter` 及其内置 `dart` 来自该版本，再编译 benchmark：

```bash
flutter --version
flutter pub get
mkdir -p build/benchmark
dart compile exe tool/mqtt_capacity_benchmark.dart \
  -o build/benchmark/mqtt_capacity_benchmark

./build/benchmark/mqtt_capacity_benchmark \
  --host 127.0.0.1 \
  --port 18884 \
  --clients 2000 \
  --keys 500 \
  --change-ratio 0.3 \
  --change-interval-seconds 1 \
  --full-interval-seconds 10 \
  --duration-seconds 14 \
  --qos 0 \
  --prefix single_2000
```

工具输出一行 `connected` JSON 和一行最终 `result` JSON。退出码定义：

| 退出码 | 含义 |
|---:|---|
| 0 | 全部客户端连接、无发布失败、无 busy skip、无未排空任务，且发布延迟 P99 小于变化周期 |
| 1 | Broker 预检或运行错误 |
| 2 | 测试完成，但容量通过标准未满足 |
| 64 | 参数错误 |
| 130 | 用户中断 |

`skippedBusy` 是 benchmark 自己的容量信号：某设备到达下一计划槽时，上一条同类 payload 的生成和 publish Future 仍未完成，于是跳过当前槽。它不是正式应用里的 `ScheduleDecision.skippedCount`，不能与界面“调度丢弃”逐条等同。

### 2.4 容量阶梯

建议每档独立进程运行，避免前一档的堆和连接影响下一档：

```bash
# 沿用上一节由 Flutter 3.41.8 内置 Dart 生成的 AOT 可执行文件。
for clients in 2000 2500 3000 3500 4000; do
  ./build/benchmark/mqtt_capacity_benchmark \
    --host 127.0.0.1 \
    --port 18884 \
    --clients "$clients" \
    --keys 500 \
    --change-ratio 0.3 \
    --change-interval-seconds 1 \
    --full-interval-seconds 10 \
    --duration-seconds 14 \
    --prefix "single_$clients"
done
```

必须同时记录：连接成功数、`published/offered`、`skippedBusy`、发布失败、P95/P99/Max 延迟、每秒点数、RSS，以及 broker 实收消息增量。只看 CPU 或平均 TPS 会掩盖 2 秒全量尖峰。

## 3. 2026-07-13 本地实测

测试环境：10 核、64 GB Apple Silicon Mac，本机 Mosquitto 2.0.22、QoS 0、AOT benchmark；测试时桌面还有其他进程运行。每档 14 秒，`full=10s`，包含两轮完整全量。表格采用“全量与变化重叠”的历史故障压力模型，正式调度器的全量覆盖去重会比它略轻。

### 3.1 修复前单进程基线

| 设备数 | offered | published | busy skip | 平均消息/s | 平均点/s | P95 ms | P99 ms | Max ms | 峰值 RSS MiB | 判断 |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 500 | 8,000 | 8,000 | 0 | 571 | 110,705 | 19 | 22 | 29 | 59 | 余量充足 |
| 1,000 | 16,000 | 16,000 | 0 | 1,143 | 221,406 | 32 | 39 | 67 | 68 | 余量充足 |
| 1,500 | 24,000 | 24,000 | 0 | 1,714 | 332,099 | 358 | 418 | 507 | 83 | 建议单进程安全线 |
| 1,750 | 28,000 | 28,000 | 0 | 1,998 | 387,160 | 773 | 878 | 1,051 | 93 | 可运行，但余量较小 |
| 1,850 | 29,600 | 29,600 | 0 | 2,110 | 408,788 | 840 | 945 | 1,065 | 临界 |
| 1,950 | 31,200 | 31,200 | 0 | 2,198 | 425,842 | 957 | 1,022 | 1,116 | P99 已越过 1 秒，不建议 |
| 2,000 | 32,000 | 30,440 | 1,560 | 2,107 | 412,904 | 1,553 | 1,732 | 1,962 | 101 | 明确过载，跳过 4.875% tick |

这张表是修复前基线，用于解释截图现象，不能再作为优化版容量结论。旧版并不是在 2000 台时“完全发不出去”，而是在全量尖峰中任务延迟跨过下一秒槽，吞吐开始下降并出现跳过。

根因是 `mqtt_client` 的 `logging(on: false)` 只关闭了日志输出，却保留默认的 `logPayloads=true`。每次发布仍会把完整 MQTT 消息逐字节格式化成字符串，然后再把结果丢弃；500 点 payload 约 8 KB，这段无效工作在全量窗口占用了大量主 isolate 时间。优化版显式使用 `logging(on: false, logPayloads: false)`，并由生成 isolate 直接返回 UTF-8 `Uint8Buffer`，主 isolate 不再逐字符构造 payload buffer；这同时修复了旧 `addString()` 对中文 JSON 不是正确 UTF-8 的问题。

### 3.2 优化后单进程容量

| 设备数 | offered / published | busy skip | P95 ms | P99 ms | Max ms | 判断 |
|---:|---:|---:|---:|---:|---:|---|
| 2,000 | 32,000 / 32,000 | 0 | 34 | 43 | 57 | 余量充足，目标配置通过 |
| 3,000 | 48,000 / 48,000 | 0 | 约 390-461 | 约 454-516 | 约 520-721 | 通过，但需 Windows 长测 |
| 3,500 | 56,000 / 56,000 | 0 | 822 | 907 | 1,008 | 单次通过，已接近跨秒边缘 |
| 4,000 | 61,226 / 64,000 | 2,774 | 1,287 | 1,372 | > 1,372 | 明确过载 |

同一台机器上，2000 台从修复前的 `30,440 / 32,000`、跳过 1,560 条、P99 1,732 ms，提升为 `32,000 / 32,000`、零跳过、P99 43 ms。按这个保守 benchmark，单进程测得的边界约在 3500 到 4000 台之间；3500 已没有足够时延余量，不能直接当生产安全线。对用户当前 2000 台配置，客户端侧余量充足；实际 Windows + `10.8.8.68` 仍必须完成 660 秒端到端复测。

### 3.3 双进程，每进程 1000 设备（修复前扩容验证）

| 指标 | 进程 A | 进程 B | 合计/结论 |
|---|---:|---:|---:|
| offered / published | 16,000 / 16,000 | 16,000 / 16,000 | 32,000 / 32,000 |
| busy skip | 0 | 0 | 0 |
| 平均消息/s | 1,143 | 1,143 | 2,285 |
| 平均点/s | 221,405 | 221,400 | 442,805 |
| P95 | 35.2 ms | 35.3 ms | 两边均远低于 1 秒 |
| Max | 61.0 ms | 63.2 ms | 无跨秒积压 |
| 峰值 RSS | 约 68 MiB | 约 68 MiB | 合计约 136 MiB |
| Broker 实收 | 16,000 | 16,000 | 精确增加 32,000 |

双进程没有减少 payload 计算总量，但把 MQTT 客户端、Future 回调、publish 调用和事件队列分到两个主 isolate，能够利用更多 CPU 核。优化版会按 shard 数均分生成 worker 预算，例如 10 核双进程每边 4 个 worker，而不是每边都创建 9 个；每个 shard 也写入独立日志文件，避免两个进程争用同一个日志。代价是占用更多内存，以及两个进程需要独立观察和停止。

## 4. 测试边界

本工具适合定位“客户端生成/调度/发送链是否先到上限”，但它不是端到端 ThingsBoard 验收：

- 复用了真实 payload isolate 和 MQTT client，但使用 50ms bucket 调度，没有复用正式应用的逐设备 `Timer`、`SchedulerService`、`StatisticsCollector` 和 Flutter UI；
- 本地匿名回环没有 Windows 调度差异、真实网卡、RTT、丢包、TLS、认证、broker 限流、ThingsBoard transport/rule chain/queue/storage 开销；
- 默认将全量从 300 秒压缩成 10 秒，只保持单次 2 秒峰值近似一致；
- benchmark 默认保留全量窗口中的变化上送，是历史故障的保守压力；正式调度器仅在全量已成功时才可能抑制被覆盖的变化 tick；
- QoS 0 的 `publishMessage()` 成功只表示客户端库接受发送，必须结合 broker 或服务端计数；
- 结果受 CPU 型号、电源模式、后台进程、Dart JIT/AOT、broker 配置和温度影响，至少重复三次并取最差结果；
- 本地 Mac/Mosquitto 的“2000 余量充足、3500 边缘、4000 过载”不能直接写成远端 Windows/ThingsBoard 上限。

如果本地双进程通过而远端失败，下一步应检查远端 broker、ThingsBoard transport、规则链、队列和存储；如果本地已经出现 busy skip，则应先解决客户端进程内瓶颈。

## 5. 应用内自动多进程

正式应用现在会在点击“开始模拟”时先计算容量计划，不需要用户手工打开多个窗口：

1. 以每个发送进程 `300,000 点/秒` 为规划上限；
2. 按调度器真实规则计算常态点速率和最坏 2 秒重叠峰值；
3. 在预览弹窗中显示预计常态、峰值、单进程上限和所需发送进程数；
4. 用户确认后，由当前 GUI 进程自动启动隐藏 worker，并按设备编号切成互不重叠的 shard；
5. GUI 汇总所有 worker 的在线数、发布失败、调度丢弃、点速率和内存；点击一次“停止”即可停止全部 worker。

当前截图参数的计划是：

```text
常态：300,000 点/秒
全量重叠峰值：800,000 点/秒
发送进程数：ceil(800,000 / 300,000) = 3
```

因此开始时会提示“启动 3 个进程”。这里的 3 个是**发送 worker**；Windows 任务管理器还会看到一个负责界面和汇总的主进程，所以操作系统层面共 4 个 `iot_devkit.exe`。配置和密码通过父子进程匿名管道传递，不会写入命令行或临时配置文件。

自动启动还有机器级保护：最多使用 `min(16, 逻辑 CPU 数 - 1)` 个发送 worker，且最低按 2 个计算。若容量计划超过保护上限，弹窗会显示需要数量和本机上限，并禁用启动按钮，避免一次拉起上百个完整 Flutter 进程拖死机器。此时应降低单机设备/点数，或拆到多台负载机。

`300,000 点/秒` 是本次按用户要求设置的保守自动分片阈值，不是所有机器都相同的物理极限。最终是否通过仍以“发布失败、调度丢弃、生成错误均为 0，且 broker/平台实收一致”为准。

## 6. Windows 正式应用复测

正式结论必须在实际 Windows 负载机和目标 `10.8.8.68:1883` 上，用 Release 应用运行至少两个 300 秒全量周期。

### 6.1 构建与基础检查

在 Windows PowerShell、仓库根目录执行：

```powershell
git pull --ff-only
flutter --version  # 第一行必须是 Flutter 3.41.8
flutter pub get
flutter analyze --no-pub
flutter test --no-pub test/services/simulation_load_test.dart
flutter build windows --release

$exe = (Resolve-Path '.\build\windows\x64\runner\Release\iot_devkit.exe').Path
```

先导入或确认同一份高级模式 profile：设备范围 1-2000、500 keys、变化比例 0.3、变化 1 秒、全量 300 秒、QoS 0、Broker `10.8.8.68:1883`。

### 6.2 自动多进程正式验证

正常双击 Release 应用并加载 1-2000 的同一份高级模式配置。点击“开始模拟”后，应看到容量提示为常态 30 万点/秒、峰值 80 万点/秒、自动启动 3 个发送进程；确认后状态栏应从 `进程 0/3` 变为 `进程 3/3`。无需再手工启动三个窗口。

PowerShell 可同时确认主进程和隐藏 worker：

```powershell
Get-Process iot_devkit |
  Select-Object Id, CPU, WorkingSet64, PrivateMemorySize64

Get-Counter `
  '\Process(iot_devkit*)\% Processor Time', `
  '\Process(iot_devkit*)\Working Set - Private' `
  -Continuous
```

对当前配置，任务管理器应看到 1 个 GUI 主进程和 3 个隐藏发送 worker。点击软件中的“停止模拟”后，3 个 worker 应全部退出，只保留 GUI 主进程。

### 6.3 手工分片回退方案

如果需要隔离排查自动 supervisor，仍可使用 `--shard=N/M` 手工分片。两个进程加载相同的 1-2000 配置，应用自动将每个分组的设备范围切成互不重叠的两半；原设备编号、client ID、用户名和密码后缀保持不变。两个窗口运行期间不要同时修改或保存 profile；先在普通单进程窗口完成配置并关闭，再启动两个 shard。

同一时刻禁止重复启动相同的 shard（例如两个 `--shard=1/2`），否则重复 client ID 会在 broker 上互相顶下线。

```powershell
$p1 = Start-Process `
  -FilePath $exe `
  -ArgumentList '--shard=1/2', '--performance' `
  -PassThru

$p2 = Start-Process `
  -FilePath $exe `
  -ArgumentList '--shard=2/2', '--performance' `
  -PassThru
```

两边分别启动模拟后，应看到 shard `1/2` 负责前 1000 台、shard `2/2` 负责后 1000 台，总连接数仍为 2000，且不能出现重复 client ID 导致互踢。观察进程资源：

```powershell
Get-Process iot_devkit |
  Select-Object Id, CPU, WorkingSet64, PrivateMemorySize64

Get-Counter `
  '\Process(iot_devkit*)\% Processor Time', `
  '\Process(iot_devkit*)\Working Set - Private' `
  -Continuous
```

测试完成后先在两个窗口停止模拟，再结束进程：

```powershell
Stop-Process -Id $p1.Id, $p2.Id
```

### 6.4 正式通过标准

必须同时满足以下条件，才能说“Windows 正式应用在该配置下通过”；仅看到 CPU/内存还有余量不算通过。

| 检查项 | 通过标准 |
|---|---|
| 连接 | 自动模式 3/3 个 worker 就绪，总计 2000 台在线；无重复 client ID、无持续重连 |
| 发布失败 | GUI 汇总的“发布失败”始终为 0 |
| 生成错误 | GUI 汇总的“生成错误”始终为 0 |
| 调度丢弃 | GUI 汇总的“调度丢弃”始终为 0，尤其是第 300、600 秒全量窗口 |
| 常态点速率 | 3 个 worker 合计稳定接近 30 万点/s；不能只看消息数/s |
| 全量窗口 | 能观察到全量峰值且 1-2 秒后恢复，无长时间跌零、积压或断连；按最坏约 80 万点/s 验收，及时去重时约 65 万点/s 只作理想值参考 |
| Broker/平台实收 | Broker 或 ThingsBoard transport 接收增量与客户端成功发送趋势一致，无持续缺口 |
| 数据落库 | 跨 3 个 shard 抽查首、中、尾设备，500 个 key 完整，`key_1` 在全量后继续递增 |
| 资源 | 经过预热后 CPU、RSS 无持续爬升；600 秒后的内存不能呈无上限增长 |
| 持续时间 | 至少 660 秒，覆盖两次 300 秒周期后的全量尖峰 |

如果自动模式失败，应先根据独立的“发布失败 / 调度丢弃 / 生成错误”指标判断故障属于客户端、网络/broker，还是 ThingsBoard 服务端，再决定拆到多台负载机或优化服务端。单进程客户端边界可用第 2 节的 AOT benchmark 独立测量。
