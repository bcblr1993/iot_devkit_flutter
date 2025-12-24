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
  String get changeInterval => '变化频率 (秒)';

  @override
  String get fullInterval => '全量频率 (秒)';

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
  String get formatTieNiu => '铁牛格式';

  @override
  String get formatTieNiuEmpty => '铁牛空数据格式';

  @override
  String get importFailed => '导入失败';

  @override
  String get confirmImport => '确认导入';

  @override
  String get importWarning => '配置文件校验通过。\n\n导入将覆盖当前所有配置，是否确认？';

  @override
  String get cancel => '取消';

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
  String get enableSsl => '启用 SSL/TLS';

  @override
  String get caCertificate => 'CA 证书';

  @override
  String get clientCertificate => '客户端证书';

  @override
  String get privateKey => '私钥';

  @override
  String get previewPayload => '预览数据';

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
  String get themeMidnightPurple => '午夜紫罗兰 (Midnight)';

  @override
  String get themeSunsetOrange => '日落橙光 (Sunset)';

  @override
  String get themeSakuraPink => '樱花粉嫩 (Sakura)';

  @override
  String get themeCyberTeal => '赛博青 (Cyber)';

  @override
  String get themeGoldenHour => '黄金时刻 (Golden)';

  @override
  String get themeLavenderDream => '薰衣草梦境 (Lavender)';

  @override
  String get menuOpenLogs => '打开日志文件夹';

  @override
  String get menuSettings => '设置';
}
