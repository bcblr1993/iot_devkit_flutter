// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'IoT DevKit';

  @override
  String get navSimulator => '数据模拟';

  @override
  String get navTimestamp => '时间转换';

  @override
  String get navJson => 'JSON工具';

  @override
  String get startSimulation => '开始模拟';

  @override
  String get stopSimulation => '停止模拟';

  @override
  String get starting => '启动中...';

  @override
  String get stopping => '停止中...';

  @override
  String get mqttBroker => 'MQTT 代理配置';

  @override
  String get dataStatistics => '数据统计';

  @override
  String get unitMessages => '条';

  @override
  String get unitDevices => '台';

  @override
  String get host => '服务器地址';

  @override
  String get port => '端口';

  @override
  String get topic => '主题';

  @override
  String get deviceConfig => '设备配置';

  @override
  String get simBasicHint => '基础模式按单一模板批量生成一组连续编号的设备。';

  @override
  String get simAdvancedHint => '高级分组会覆盖基础设置——每个分组独立定义设备与负载。';

  @override
  String get startIndex => '起始索引';

  @override
  String get endIndex => '结束索引';

  @override
  String get interval => '发送间隔 (秒)';

  @override
  String get format => '数据格式';

  @override
  String get dataPointCount => '数据点数量';

  @override
  String get basicMode => '基础模式';

  @override
  String get advancedMode => '高级模式';

  @override
  String get statistics => '统计信息';

  @override
  String get totalDevices => '设备总数';

  @override
  String get online => '在线数';

  @override
  String get totalSuccessFail => '总数/成功/失败';

  @override
  String get latency => '延迟';

  @override
  String get logs => '日志控制台';

  @override
  String get clearLogs => '清空日志';

  @override
  String get autoScrollOn => '自动滚动: 开';

  @override
  String get autoScrollOff => '自动滚动: 关';

  @override
  String get timestampConverter => '时间戳转换';

  @override
  String get timestampInput => '时间戳 (毫秒或秒)';

  @override
  String get dateInput => '日期时间 (yyyy-MM-dd HH:mm:ss)';

  @override
  String get convert => '转换';

  @override
  String get resetToNow => '重置为当前';

  @override
  String get jsonFormatter => 'JSON 格式化';

  @override
  String get formatAction => '格式化';

  @override
  String get minifyAction => '压缩';

  @override
  String get copyAction => '复制';

  @override
  String get clearAction => '清空';

  @override
  String get ready => '就绪';

  @override
  String get logNoMatch => '没有匹配日志';

  @override
  String get logClearFilter => '清除筛选';

  @override
  String get groupManagement => '模拟分组管理';

  @override
  String get addGroup => '添加分组';

  @override
  String get groupName => '分组名称';

  @override
  String get prefixes => '前缀配置';

  @override
  String get clientId => 'Client ID';

  @override
  String get deviceName => '设备名称';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get totalKeys => '键总数';

  @override
  String get selectTheme => '选择主题';

  @override
  String get selectLanguage => '选择语言';

  @override
  String get customKeys => '自定义 Key';

  @override
  String get customKeysMaster => '总开关';

  @override
  String get customKeysMasterHint => '关闭后所有自定义 Key 均不生成或发送；重新开启会恢复每项原来的开关状态。';

  @override
  String get customKeysMasterLimitHint => '生效项超过键总数，请先停用多余 Key 后再开启总开关。';

  @override
  String get customKeyActive => '生效';

  @override
  String get customKeyInactive => '停用';

  @override
  String get customKeyPending => '待生效';

  @override
  String get customKeyPendingHint => '总开关已关闭；此项会在重新开启后按当前状态生效。';

  @override
  String get customKeyToggleLabel => '自定义 Key 是否生效';

  @override
  String get customKeyToggleHint => '关闭后保留此 Key 配置，但不会生成或发送。';

  @override
  String get customKeyEnableLimitHint => '已达到键总数上限，请先停用一个生效 Key。';

  @override
  String customKeyCount(int enabled, int limit, int total) {
    return '生效 $enabled/$limit · 已保留 $total 个';
  }

  @override
  String get add => '添加';

  @override
  String get keyName => '键名称';

  @override
  String get type => '类型';

  @override
  String get mode => '模式';

  @override
  String get min => '最小值';

  @override
  String get max => '最大值';

  @override
  String get staticValue => '固定值';

  @override
  String get themeAdminixEmerald => '翡翠之都 (Adminix)';

  @override
  String get timestampToDate => '时间戳 → 日期';

  @override
  String get dateToTimestamp => '日期 → 时间戳';

  @override
  String get timezone => '时区';

  @override
  String get currentDate => '当前日期';

  @override
  String get currentTimestamp => '当前时间戳';

  @override
  String get inputLabel => '输入';

  @override
  String get treeViewLabel => '树形视图';

  @override
  String get itemsLabel => '项';

  @override
  String loadMoreJsonItems(int visible, int total) {
    return '加载更多（$visible/$total）';
  }

  @override
  String get enterJsonHint => '输入 JSON 以查看树形结构';

  @override
  String get invalidJson => '无效的 JSON';

  @override
  String get exportConfig => '导出配置';

  @override
  String get importConfig => '导入配置';

  @override
  String get configExported => '配置保存成功';

  @override
  String get configExportCancelled => '导出已取消';

  @override
  String get configImported => '配置已导入';

  @override
  String get configExportFailed => '导出失败';

  @override
  String get changeRatio => '变化百分比 (0-1)';

  @override
  String get randomChange => '随机变化';

  @override
  String get randomChangeDesc => '每次从全部键中随机选取上送（数量仍按变化百分比），而非固定前 N 个。';

  @override
  String get changeInterval => '变化频率 (秒)';

  @override
  String get fullInterval => '全量频率 (秒, 0=关闭)';

  @override
  String get delete => '删除';

  @override
  String get typeInteger => '整数';

  @override
  String get typeFloat => '浮点数';

  @override
  String get typeString => '字符串';

  @override
  String get typeBoolean => '布尔值';

  @override
  String get modeStatic => '固定';

  @override
  String get modeIncrement => '递增';

  @override
  String get modeRandom => '随机';

  @override
  String get modeToggle => '切换';

  @override
  String get pasteAction => '粘贴';

  @override
  String get expandAll => '展开全部';

  @override
  String get collapseAll => '折叠全部';

  @override
  String get searchLabel => '搜索';

  @override
  String get searchHint => '搜索...';

  @override
  String get formatSuccess => '格式化成功';

  @override
  String get minifySuccess => '压缩成功';

  @override
  String get copySuccess => '复制成功';

  @override
  String get useCurrentTime => '使用当前时间';

  @override
  String get copyDate => '复制日期';

  @override
  String get copyTimestamp => '复制时间戳';

  @override
  String get conversionResult => '转换结果';

  @override
  String get formatError => '格式错误';

  @override
  String get dateInputHint => 'yyyy-MM-dd HH:mm:ss';

  @override
  String get expandLogs => '展开日志';

  @override
  String get collapseLogs => '折叠日志';

  @override
  String get dataFormat => '数据格式';

  @override
  String get formatDefault => '默认格式';

  @override
  String get formatSimpleKv => '简单键值';

  @override
  String get formatTbTimestamp => '带时间戳';

  @override
  String get formatTbArray => '时间戳数组';

  @override
  String get formatTieNiu => '铁牛格式';

  @override
  String get formatTieNiuEmpty => '铁牛空数据格式';

  @override
  String get formatSimpleKvDesc => '服务器接收时间为时间戳';

  @override
  String get formatTbTimestampDesc => '当前模拟器时间为时间戳';

  @override
  String get formatTbArrayDesc => '当前模拟器时间，数组形式上送';

  @override
  String get formatTieNiuDesc => '铁牛设备数据格式';

  @override
  String get formatTieNiuEmptyDesc => '铁牛空数据格式';

  @override
  String get importFailed => '导入失败';

  @override
  String get confirmImport => '确认导入';

  @override
  String get importWarning => '配置文件校验通过。\n\n导入将覆盖当前所有配置，是否确认？';

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

  @override
  String get toolTimesheet => '工时管理';

  @override
  String get tsDailyLog => '每日记录';

  @override
  String get tsWeeklyReport => '周报导出';

  @override
  String get tsTaskContent => '工作内容';

  @override
  String get tsCategory => '分类';

  @override
  String get tsDuration => '时长';

  @override
  String get tsStartTime => '开始时间';

  @override
  String get tsEndTime => '结束时间';

  @override
  String get tsCopyReport => '复制周报';

  @override
  String get tsNoTasks => '今日暂无记录';

  @override
  String get tsCatDev => '研发';

  @override
  String get tsCatMeeting => '会议';

  @override
  String get tsCatReview => '评审';

  @override
  String get tsCatOther => '其他';

  @override
  String get tsDeleteConfirm => '确定删除这条记录吗？';

  @override
  String get tsExportHint => '周报已复制到剪贴板！';

  @override
  String get confirm => '确定';

  @override
  String get menuAbout => '关于 IoT DevKit';

  @override
  String get aboutDescription => '物联网开发工具箱 - MQTT 模拟 & 时间转换等工具集。';

  @override
  String get author => '作者';

  @override
  String get authorName => 'ChenYanNan';

  @override
  String get releaseDate => '发布日期';

  @override
  String get aboutFooter => '版权所有 © 2025 ChenYanNan';

  @override
  String get close => '关闭';

  @override
  String get settingsLocked => '运行中配置已锁定';

  @override
  String get maxGroupsReached => '最多允许添加 12 个分组';

  @override
  String get groupLabel => '分组';

  @override
  String get limitExceeded => '超出限制';

  @override
  String get ignored => '已忽略';

  @override
  String get themeMatrixEmerald => '矩阵翡翠 (Matrix)';

  @override
  String get themeForestMint => '森林薄荷 (Forest)';

  @override
  String get themeArcticBlue => '极地冰蓝 (Arctic)';

  @override
  String get themeDeepOcean => '深海蔚蓝 (Ocean)';

  @override
  String get themeCrimsonNight => '深红暗夜 (Crimson)';

  @override
  String get themeRubyElegance => '红宝石雅致 (Ruby)';

  @override
  String get themeVoidBlack => '虚空纯黑 (Void)';

  @override
  String get themeGraphitePro => '石墨专业版 (Graphite)';

  @override
  String get themeMidnightBlue => '深夜蓝调 (Midnight)';

  @override
  String get logMaximize => '最大化日志';

  @override
  String get logRestore => '还原日志';

  @override
  String get copyJson => '复制 JSON';

  @override
  String get jsonCopied => 'JSON 已复制到剪贴板';

  @override
  String get sectionDeviceScope => '设备范围';

  @override
  String get sectionNamingAuth => '命名与认证';

  @override
  String get sectionDataConfig => '数据配置';

  @override
  String get statSent => '已发送';

  @override
  String get statSuccess => '成功数';

  @override
  String get statFailed => '失败数';

  @override
  String get statPublishFailed => '发布失败';

  @override
  String get statLateDropped => '调度丢弃';

  @override
  String get statGenerationErrors => '生成错误';

  @override
  String get statPointsPerSecond => '点每秒';

  @override
  String get enableSsl => '启用 SSL/TLS';

  @override
  String get caCertificate => 'CA 证书';

  @override
  String get clientCertificate => '客户端证书';

  @override
  String get privateKey => '私钥';

  @override
  String get previewPayload => '数据预览';

  @override
  String get payloadPreview => '数据预览';

  @override
  String get selectFile => '选择文件';

  @override
  String get previewAndStart => '预览并启动';

  @override
  String get startNow => '开始模拟';

  @override
  String get confirmStartHint => '点击确认以使用此数据结构开始模拟。';

  @override
  String get performanceMode => '高性能模式 (关闭日志)';

  @override
  String get performanceModeDescription => '关闭逐条发送明细日志，以获得最大吞吐量';

  @override
  String autoProcessPlanSingle(String steady, String peak, String limit) {
    return '预计常态 $steady 点/秒，峰值 $peak 点/秒；按每个发送进程 $limit 点/秒的上限，单进程即可完成。';
  }

  @override
  String autoProcessPlanMultiple(
      String steady, String peak, String limit, int count) {
    return '预计常态 $steady 点/秒，峰值 $peak 点/秒；按每个发送进程 $limit 点/秒的上限，将自动启动 $count 个发送进程。';
  }

  @override
  String get autoProcessPlanUnsatisfied =>
      '至少有一个设备自身已超过单进程点数上限，按设备分片无法保证每个进程都低于设定值。';

  @override
  String get autoProcessPlanSingleDeviceUnsatisfied =>
      '单个设备的峰值负载已超过单进程点数上限，增加本机进程也无法拆分该设备的负载。';

  @override
  String get autoProcessPlanShardDistributionUnsatisfied =>
      '设备分片后仍有进程超过点数上限，当前设备范围无法均匀分配到满足上限。';

  @override
  String autoProcessSafetyLimitExceeded(int required, int limit) {
    return '该负载至少需要 $required 个发送进程，超过当前机器自动启动安全上限 $limit 个。请降低模拟负载，或拆分到多台机器运行。';
  }

  @override
  String startProcessCount(int count) {
    return '启动 $count 个进程';
  }

  @override
  String autoProcessesStarting(int count) {
    return '正在启动 $count 个发送进程……';
  }

  @override
  String autoProcessesReady(int ready, int count) {
    return '$ready/$count 个发送进程已就绪，正在连接设备。';
  }

  @override
  String autoProcessLaunchFailed(String error) {
    return '发送进程启动失败：$error';
  }

  @override
  String get statProcesses => '进程';

  @override
  String get unknownError => '未知错误';

  @override
  String get themePolarBlue => '极地冰蓝 (Ice Blue)';

  @override
  String get themePorcelainRed => '绯红白瓷 (Porcelain)';

  @override
  String get themeWisteriaWhite => '紫藤云烟 (Wisteria)';

  @override
  String get themeAmberGlow => '晨曦琥珀 (Amber)';

  @override
  String get themeGraphiteMono => '极简石墨 (Graphite)';

  @override
  String get themeAzureCoast => '蔚蓝海岸 (Azure)';

  @override
  String get themeCosmicVoid => '深空虚无 (Void)';

  @override
  String get themeMatchaMochi => '抹茶麻薯 (Matcha)';

  @override
  String get themeNeonCyberpunk => '霓虹赛博 (Neon)';

  @override
  String get themeNordicFrost => '北欧霜雪 (Nordic)';

  @override
  String get menuOpenLogs => '打开日志文件夹';

  @override
  String get menuSettings => '设置';

  @override
  String get qosLabel => 'QoS 级别';

  @override
  String get qosTooltip0 => '至多一次 (0)';

  @override
  String get qosTooltip1 => '至少一次 (1)';

  @override
  String get qosTooltip2 => '仅一次 (2)';

  @override
  String get qos0 => 'QoS 0';

  @override
  String get qos1 => 'QoS 1';

  @override
  String get qos2 => 'QoS 2';

  @override
  String get mqttProtocolVersion => 'MQTT 协议版本';

  @override
  String get mqttProtocolV311 => 'MQTT 3.1.1（推荐）';

  @override
  String get mqttProtocolV31 => 'MQTT 3.1（旧版兼容）';

  @override
  String get formValidationFailed => '表单验证失败，请检查红色字段。';

  @override
  String get fieldRequired => '此项必填';

  @override
  String get invalidNumber => '请输入有效的数字';

  @override
  String get dashboardTPS => '吞吐量 (TPS)';

  @override
  String get dashboardBandwidth => '带宽';

  @override
  String get dashboardLatency => '平局延迟';

  @override
  String get chartTitleThroughput => '吞吐量趋势';

  @override
  String get chartTitleLatency => '延迟趋势';

  @override
  String get cpuUsage => 'CPU';

  @override
  String get memoryUsage => '内存';

  @override
  String get perfSuccessRate => '成功率';

  @override
  String get perfResources => '资源占用';

  @override
  String get perfOnline => '在线';

  @override
  String get perfWaitingData => '等待数据…';

  @override
  String get profiles => '配置列表';

  @override
  String get newProfile => '新建配置';

  @override
  String get profileName => '配置名称';

  @override
  String get renameProfile => '重命名配置';

  @override
  String get deleteProfile => '删除配置';

  @override
  String get deleteConfirm => '确定要删除该配置吗？';

  @override
  String get rename => '重命名';

  @override
  String get noProfiles => '暂无配置';

  @override
  String get profileActive => '使用中';

  @override
  String get searchProfiles => '搜索配置';

  @override
  String get duplicate => '复制';

  @override
  String get navCertificates => '证书生成';

  @override
  String get certGenerator => '证书生成';

  @override
  String get certGeneratorDescription => '生成 ThingsBoard HTTPS 与 MQTTS 自签名证书包。';

  @override
  String get certUsage => '用途';

  @override
  String get certUsageHttps => 'HTTPS';

  @override
  String get certUsageMqtts => 'MQTTS';

  @override
  String get certUsageShared => 'HTTPS + MQTTS';

  @override
  String get certFormat => '证书格式';

  @override
  String get certPassword => '证书密码';

  @override
  String get certPasswordHint => '用于私钥密码和 keystore 密码';

  @override
  String get certSanAddresses => '证书绑定地址 SAN';

  @override
  String get certSanHint => '一行一个 IP/域名，也可以用逗号分隔';

  @override
  String get certHostsIp => 'hosts 绑定 IP';

  @override
  String get certHostsIpHint => '可选，用于生成 hosts.example.txt';

  @override
  String get certHostsIpInvalid => 'hosts 绑定 IP 无效';

  @override
  String get certParsedAddresses => '解析结果';

  @override
  String get certOutputPreview => '输出预览';

  @override
  String get certFiles => '文件';

  @override
  String get certEnv => 'ThingsBoard 环境变量';

  @override
  String get certGenerateZip => '生成 ZIP 包';

  @override
  String get certOpenFolder => '打开文件夹';

  @override
  String get certCopyConfig => '复制配置';

  @override
  String get certGenerated => '证书包已生成';

  @override
  String get certGenerationCancelled => '已取消生成';

  @override
  String get certGenerationFailed => '证书生成失败';

  @override
  String get certAddressRequired => '至少需要一个 IP 或域名';

  @override
  String get certPasswordRequired => '请输入证书密码';

  @override
  String get certPemNoPasswordHint => 'PEM 私钥不加密；如需密码保护请选择 PKCS12';

  @override
  String get certInvalidAddresses => '无效地址';

  @override
  String get certLocalDefaults => '会默认包含 localhost、127.0.0.1 和 ::1。';

  @override
  String get certOpenSslHint => '内置生成引擎，无需安装 OpenSSL。';

  @override
  String get certZipSavedTo => 'ZIP 已保存到';

  @override
  String get certHostsExample => 'hosts 示例';

  @override
  String get certEndpointVerify => '端点证书验证';

  @override
  String get certEndpointVerifyHint =>
      '输入 ThingsBoard 主机和端口，自动判断该端口是否启用 TLS、证书是否匹配当前访问地址。';

  @override
  String get certEndpointHost => '主机';

  @override
  String get certEndpointHostHint => '例如 10.8.0.219 或 tb.example.com';

  @override
  String get certEndpointPort => '端口';

  @override
  String get certEndpointPortHint => '例如 8080、8443、8883';

  @override
  String get certEndpointVerifyAction => '验证端点';

  @override
  String get certEndpointPortInvalid => '端口必须是 1-65535';

  @override
  String get certEndpointVerifyFailed => '端点验证失败';

  @override
  String get certEndpointReadyTrusted => 'TLS 可用，证书已被系统信任';

  @override
  String get certEndpointReadyUntrusted => 'TLS 可用，但证书尚未被系统信任';

  @override
  String get certEndpointHostMismatch => 'TLS 可用，但证书 SAN 与主机不匹配';

  @override
  String get certEndpointPlainHttpOnly => '该端口当前是普通 HTTP，证书没有生效';

  @override
  String get certEndpointUnreachable => '端点不可达或协议不匹配';

  @override
  String get certEndpointTlsAvailable => 'TLS';

  @override
  String get certEndpointPlainHttpAvailable => 'HTTP';

  @override
  String get certEndpointSystemTrust => '系统信任';

  @override
  String get certEndpointHostMatch => '主机匹配';

  @override
  String get certEndpointCertificate => '证书';

  @override
  String get certEndpointSubject => '主题';

  @override
  String get certEndpointIssuer => '签发者';

  @override
  String get certEndpointValidity => '有效期';

  @override
  String get certEndpointSan => 'SAN';

  @override
  String get certEndpointError => '错误';

  @override
  String get certEndpointNoCertificate => '未读取到服务端证书';

  @override
  String get certEndpointYes => '是';

  @override
  String get certEndpointNo => '否';

  @override
  String get showPassword => '显示密码';

  @override
  String get hidePassword => '隐藏密码';

  @override
  String get enableSubscriptions => '启用订阅';

  @override
  String get subscriptionsTitle => '订阅';

  @override
  String get subscriptionsHint => '所有模拟设备连接成功后会订阅以下 topic';

  @override
  String get subscriptionsEmpty => '暂无订阅，点击 + 或选择预设';

  @override
  String get subscriptionAdd => '新增订阅';

  @override
  String get subscriptionTopicHint => 'Topic 过滤器（支持 + 和 #）';

  @override
  String get subscriptionTopicRequired => 'Topic 不能为空';

  @override
  String get subscriptionQos => 'QoS';

  @override
  String get subscriptionEnabledTooltip => '启用 / 禁用该订阅';

  @override
  String get subscriptionDelete => '删除该订阅';

  @override
  String get subscriptionAutoAck => '自动回包';

  @override
  String get subscriptionAutoAckHint =>
      '收到 ThingsBoard RPC 请求时，自动向 v1/devices/me/rpc/response/<id> 回一个空响应';

  @override
  String get subscriptionPresetThingsBoardRpc => '预设：ThingsBoard RPC';

  @override
  String get subscriptionPresetThingsBoardAttributes => '预设：共享属性';

  @override
  String get themeTagSignal => '默认 · 青柠绿';

  @override
  String get themeTagPlasma => '赛博朋克 · 品红';

  @override
  String get themeTagCobalt => '科技蓝';

  @override
  String get themeTagAmber => 'CRT · 暖调';

  @override
  String get themeTagMint => '自然 · 青绿';

  @override
  String get themeTagPaper => '浅色 · 日光';

  @override
  String get themeTagLinen => '浅色 · 暖陶土';

  @override
  String get themeTagSlate => '浅色 · 冷钴蓝';
}
