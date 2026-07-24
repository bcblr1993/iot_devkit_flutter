// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'IoT DevKit';

  @override
  String get navSimulator => 'Simulator';

  @override
  String get navTimestamp => 'Timestamp';

  @override
  String get navJson => 'JSON';

  @override
  String get navTextDiff => 'Text Diff';

  @override
  String get startSimulation => 'START SIMULATION';

  @override
  String get stopSimulation => 'STOP SIMULATION';

  @override
  String get starting => 'STARTING...';

  @override
  String get stopping => 'STOPPING...';

  @override
  String get mqttBroker => 'MQTT Broker';

  @override
  String get dataStatistics => 'Data Statistics';

  @override
  String get unitMessages => 'msgs';

  @override
  String get unitDevices => 'devices';

  @override
  String get host => 'Host';

  @override
  String get port => 'Port';

  @override
  String get topic => 'Topic';

  @override
  String get deviceConfig => 'Device Configuration';

  @override
  String get simBasicHint =>
      'Basic mode generates a batch of sequential devices from a single template.';

  @override
  String get simAdvancedHint =>
      'Advanced groups override Basic settings — each group defines its own devices and payload.';

  @override
  String get startIndex => 'Start Index';

  @override
  String get endIndex => 'End Index';

  @override
  String get interval => 'Interval (s)';

  @override
  String get format => 'Format';

  @override
  String get dataPointCount => 'Data Point Count';

  @override
  String get basicMode => 'Basic Mode';

  @override
  String get advancedMode => 'Advanced Mode';

  @override
  String get statistics => 'Statistics';

  @override
  String get totalDevices => 'Total Devices';

  @override
  String get online => 'Online';

  @override
  String get totalSuccessFail => 'Total/Success/Fail';

  @override
  String get latency => 'Latency';

  @override
  String get logs => 'Logs';

  @override
  String get clearLogs => 'Clear Logs';

  @override
  String get autoScrollOn => 'Auto-scroll ON';

  @override
  String get autoScrollOff => 'Auto-scroll OFF';

  @override
  String get timestampConverter => 'Timestamp Converter';

  @override
  String get timestampInput => 'Timestamp (ms or s)';

  @override
  String get dateInput => 'Date (yyyy-MM-dd HH:mm:ss)';

  @override
  String get convert => 'Convert';

  @override
  String get resetToNow => 'Reset to Now';

  @override
  String get jsonFormatter => 'JSON Formatter';

  @override
  String get formatAction => 'Format';

  @override
  String get minifyAction => 'Minify';

  @override
  String get copyAction => 'Copy';

  @override
  String get clearAction => 'Clear';

  @override
  String get ready => 'Ready';

  @override
  String get logNoMatch => 'No matching logs';

  @override
  String get logClearFilter => 'Clear filters';

  @override
  String get groupManagement => 'Simulation Groups';

  @override
  String get addGroup => 'Add Group';

  @override
  String get groupName => 'Group Name';

  @override
  String get prefixes => 'Prefixes';

  @override
  String get clientId => 'Client ID';

  @override
  String get deviceName => 'Device Name';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get totalKeys => 'Total Keys';

  @override
  String get selectTheme => 'Select Theme';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get customKeys => 'Custom Keys';

  @override
  String get customKeysMaster => 'Master switch';

  @override
  String get customKeysMasterHint =>
      'When off, no custom keys are generated or sent. Turning it back on restores each key\'s previous state.';

  @override
  String get customKeysMasterLimitHint =>
      'Too many keys are selected. Disable the extras before turning the master switch on.';

  @override
  String get customKeyActive => 'Active';

  @override
  String get customKeyInactive => 'Inactive';

  @override
  String get customKeyPending => 'Pending';

  @override
  String get customKeyPendingHint =>
      'The master switch is off. This key will use its current state when custom keys are enabled again.';

  @override
  String get customKeyToggleLabel => 'Whether this custom key is active';

  @override
  String get customKeyToggleHint =>
      'When off, this key is kept but not generated or sent.';

  @override
  String get customKeyEnableLimitHint =>
      'The total-key limit is reached. Disable an active key first.';

  @override
  String customKeyCount(int enabled, int limit, int total) {
    return 'Active $enabled/$limit · $total saved';
  }

  @override
  String get add => 'Add';

  @override
  String get keyName => 'Key Name';

  @override
  String get type => 'Type';

  @override
  String get mode => 'Mode';

  @override
  String get min => 'Min';

  @override
  String get max => 'Max';

  @override
  String get staticValue => 'Static Value';

  @override
  String get themeAdminixEmerald => 'Adminix Emerald';

  @override
  String get timestampToDate => 'Timestamp → Date';

  @override
  String get dateToTimestamp => 'Date → Timestamp';

  @override
  String get timezone => 'Timezone';

  @override
  String get currentDate => 'Current Date';

  @override
  String get currentTimestamp => 'Current Timestamp';

  @override
  String get inputLabel => 'Input';

  @override
  String get treeViewLabel => 'Tree View';

  @override
  String get itemsLabel => 'items';

  @override
  String loadMoreJsonItems(int visible, int total) {
    return 'Load more ($visible/$total)';
  }

  @override
  String get enterJsonHint => 'Enter JSON to view tree';

  @override
  String get invalidJson => 'Invalid JSON';

  @override
  String get exportConfig => 'Export Config';

  @override
  String get importConfig => 'Import Config';

  @override
  String get configExported => 'Configuration Saved Successfully';

  @override
  String get configExportCancelled => 'Export Cancelled';

  @override
  String get configImported => 'Configuration imported';

  @override
  String get configExportFailed => 'Export failed';

  @override
  String get changeRatio => 'Change Ratio (0-1)';

  @override
  String get randomChange => 'Random change';

  @override
  String get randomChangeDesc =>
      'Report a random subset of keys (still sized by the change ratio) instead of always the first N.';

  @override
  String get changeInterval => 'Change Interval (s)';

  @override
  String get fullInterval => 'Full Interval (s, 0=off)';

  @override
  String get delete => 'Delete';

  @override
  String get typeInteger => 'Integer';

  @override
  String get typeFloat => 'Float';

  @override
  String get typeString => 'String';

  @override
  String get typeBoolean => 'Boolean';

  @override
  String get modeStatic => 'Static';

  @override
  String get modeIncrement => 'Increment';

  @override
  String get modeRandom => 'Random';

  @override
  String get modeToggle => 'Toggle';

  @override
  String get pasteAction => 'Paste';

  @override
  String get expandAll => 'Expand All';

  @override
  String get collapseAll => 'Collapse All';

  @override
  String get searchLabel => 'Search';

  @override
  String get searchHint => 'Search...';

  @override
  String get formatSuccess => 'Formatted successfully';

  @override
  String get minifySuccess => 'Minified successfully';

  @override
  String get copySuccess => 'Copied successfully';

  @override
  String get useCurrentTime => 'Use Current Time';

  @override
  String get copyDate => 'Copy Date';

  @override
  String get copyTimestamp => 'Copy Timestamp';

  @override
  String get conversionResult => 'CONVERSION RESULT';

  @override
  String get formatError => 'Format Error';

  @override
  String get dateInputHint => 'yyyy-MM-dd HH:mm:ss';

  @override
  String get expandLogs => 'Expand Logs';

  @override
  String get collapseLogs => 'Collapse Logs';

  @override
  String get dataFormat => 'Data Format';

  @override
  String get formatDefault => 'Default Format';

  @override
  String get formatSimpleKv => 'Simple key-value';

  @override
  String get formatTbTimestamp => 'Client-side timestamp';

  @override
  String get formatTbArray => 'Array (timestamped)';

  @override
  String get formatTieNiu => 'Tie Niu Format';

  @override
  String get formatTieNiuEmpty => 'Tie Niu Empty Format';

  @override
  String get formatSimpleKvDesc => 'Server receive time as timestamp';

  @override
  String get formatTbTimestampDesc => 'Simulator\'s current time as timestamp';

  @override
  String get formatTbArrayDesc => 'Simulator\'s current time, sent as an array';

  @override
  String get formatTieNiuDesc => 'Tie Niu device data format';

  @override
  String get formatTieNiuEmptyDesc => 'Tie Niu empty-data format';

  @override
  String get importFailed => 'Import Failed';

  @override
  String get confirmImport => 'Confirm Import';

  @override
  String get importWarning =>
      'Configuration file validation passed.\n\nImporting will overwrite all current settings. Do you want to continue?';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get toolTimesheet => 'Timesheet';

  @override
  String get tsDailyLog => 'Daily Log';

  @override
  String get tsWeeklyReport => 'Weekly Report';

  @override
  String get tsTaskContent => 'Task Content';

  @override
  String get tsCategory => 'Category';

  @override
  String get tsDuration => 'Duration';

  @override
  String get tsStartTime => 'Start Time';

  @override
  String get tsEndTime => 'End Time';

  @override
  String get tsCopyReport => 'Copy Report';

  @override
  String get tsNoTasks => 'No tasks recorded for this day.';

  @override
  String get tsCatDev => 'Development';

  @override
  String get tsCatMeeting => 'Meeting';

  @override
  String get tsCatReview => 'Review';

  @override
  String get tsCatOther => 'Other';

  @override
  String get tsDeleteConfirm => 'Delete this log entry?';

  @override
  String get tsExportHint => 'Weekly report copied to clipboard!';

  @override
  String get confirm => 'Confirm';

  @override
  String get menuAbout => 'About IoT DevKit';

  @override
  String get aboutDescription =>
      'A powerful MQTT Device Simulator for IoT development.\nBuilt with Flutter & Dart.';

  @override
  String get author => 'Author';

  @override
  String get authorName => 'ChenYanNan';

  @override
  String get releaseDate => 'Release Date';

  @override
  String get aboutFooter => 'Copyright © 2025 ChenYanNan';

  @override
  String get close => 'Close';

  @override
  String get settingsLocked => 'Settings locked while running';

  @override
  String get maxGroupsReached => 'Maximum 12 groups allowed';

  @override
  String get groupLabel => 'Group';

  @override
  String get limitExceeded => 'Limit exceeded';

  @override
  String get ignored => 'Ignored';

  @override
  String get themeMatrixEmerald => 'Matrix Emerald';

  @override
  String get themeForestMint => 'Forest Mint';

  @override
  String get themeArcticBlue => 'Arctic Blue';

  @override
  String get themeDeepOcean => 'Deep Ocean';

  @override
  String get themeCrimsonNight => 'Crimson Night';

  @override
  String get themeRubyElegance => 'Ruby Elegance';

  @override
  String get themeVoidBlack => 'Void Black';

  @override
  String get themeGraphitePro => 'Graphite Pro';

  @override
  String get themeMidnightBlue => 'Midnight Blue';

  @override
  String get logMaximize => 'Maximize Logs';

  @override
  String get logRestore => 'Restore Logs';

  @override
  String get copyJson => 'Copy JSON';

  @override
  String get jsonCopied => 'JSON copied to clipboard';

  @override
  String get sectionDeviceScope => 'Device Scope';

  @override
  String get sectionNamingAuth => 'Naming & Authentication';

  @override
  String get sectionDataConfig => 'Data Configuration';

  @override
  String get statSent => 'Sent';

  @override
  String get statSuccess => 'Success';

  @override
  String get statFailed => 'Failed';

  @override
  String get statPublishFailed => 'Publish Failures';

  @override
  String get statLateDropped => 'Schedule Drops';

  @override
  String get statGenerationErrors => 'Generation Errors';

  @override
  String get statPointsPerSecond => 'Points/s';

  @override
  String get enableSsl => 'Enable SSL/TLS';

  @override
  String get caCertificate => 'CA Certificate';

  @override
  String get clientCertificate => 'Client Certificate';

  @override
  String get privateKey => 'Private Key';

  @override
  String get previewPayload => 'Preview Payload';

  @override
  String get payloadPreview => 'Payload Preview';

  @override
  String get selectFile => 'Select File';

  @override
  String get previewAndStart => 'Preview & Start';

  @override
  String get startNow => 'Start Simulation';

  @override
  String get confirmStartHint =>
      'Click Confirm to start simulation with this payload structure.';

  @override
  String get performanceMode => 'Performance Mode (Disable Logs)';

  @override
  String get performanceModeDescription =>
      'Disables detailed per-message logs for maximum throughput';

  @override
  String autoProcessPlanSingle(String steady, String peak, String limit) {
    return 'Estimated steady load: $steady points/s; peak load: $peak points/s. One sending process is sufficient under the $limit points/s limit.';
  }

  @override
  String autoProcessPlanMultiple(
      String steady, String peak, String limit, int count) {
    return 'Estimated steady load: $steady points/s; peak load: $peak points/s. With a $limit points/s limit per sending process, $count sending processes will start automatically.';
  }

  @override
  String get autoProcessPlanUnsatisfied =>
      'At least one device exceeds the per-process point limit by itself. Device sharding cannot keep every process below the configured limit.';

  @override
  String get autoProcessPlanSingleDeviceUnsatisfied =>
      'One device\'s peak load exceeds the per-process point limit. Starting more local processes cannot split that device\'s load.';

  @override
  String get autoProcessPlanShardDistributionUnsatisfied =>
      'At least one process still exceeds the point limit after device sharding. The current device ranges cannot be distributed evenly enough to satisfy the limit.';

  @override
  String autoProcessSafetyLimitExceeded(int required, int limit) {
    return 'This load requires at least $required sending processes, exceeding this machine\'s automatic startup safety limit of $limit. Reduce the simulated load or split it across multiple machines.';
  }

  @override
  String startProcessCount(int count) {
    return 'Start $count Processes';
  }

  @override
  String autoProcessesStarting(int count) {
    return 'Starting $count sending processes...';
  }

  @override
  String autoProcessesReady(int ready, int count) {
    return '$ready/$count sending processes are ready and connecting devices.';
  }

  @override
  String autoProcessLaunchFailed(String error) {
    return 'Unable to start sending processes: $error';
  }

  @override
  String get statProcesses => 'Processes';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get themePolarBlue => 'Polar Blue';

  @override
  String get themePorcelainRed => 'Porcelain Red';

  @override
  String get themeWisteriaWhite => 'Wisteria White';

  @override
  String get themeAmberGlow => 'Amber Glow';

  @override
  String get themeGraphiteMono => 'Graphite Mono';

  @override
  String get themeAzureCoast => 'Azure Coast';

  @override
  String get themeCosmicVoid => 'Cosmic Void';

  @override
  String get themeMatchaMochi => 'Matcha Mochi';

  @override
  String get themeNeonCyberpunk => 'Neon Cyberpunk';

  @override
  String get themeNordicFrost => 'Nordic Frost';

  @override
  String get menuOpenLogs => 'Open Logs Location';

  @override
  String get menuSettings => 'Settings';

  @override
  String get qosLabel => 'QoS Level';

  @override
  String get qosTooltip0 => 'At most once (0)';

  @override
  String get qosTooltip1 => 'At least once (1)';

  @override
  String get qosTooltip2 => 'Exactly once (2)';

  @override
  String get qos0 => 'QoS 0';

  @override
  String get qos1 => 'QoS 1';

  @override
  String get qos2 => 'QoS 2';

  @override
  String get mqttProtocolVersion => 'MQTT Protocol';

  @override
  String get mqttProtocolV311 => 'MQTT 3.1.1 (Recommended)';

  @override
  String get mqttProtocolV31 => 'MQTT 3.1 (Legacy)';

  @override
  String get formValidationFailed =>
      'Form validation failed. Please check red fields.';

  @override
  String get fieldRequired => 'Required';

  @override
  String get invalidNumber => 'Invalid Number';

  @override
  String get dashboardTPS => 'Throughput';

  @override
  String get dashboardBandwidth => 'Bandwidth';

  @override
  String get dashboardLatency => 'Latency';

  @override
  String get chartTitleThroughput => 'Throughput Trend';

  @override
  String get chartTitleLatency => 'Latency Trend';

  @override
  String get cpuUsage => 'CPU';

  @override
  String get memoryUsage => 'Mem';

  @override
  String get perfSuccessRate => 'Success Rate';

  @override
  String get perfResources => 'Resources';

  @override
  String get perfOnline => 'Online';

  @override
  String get perfWaitingData => 'Waiting for data…';

  @override
  String get profiles => 'Profiles';

  @override
  String get newProfile => 'New Profile';

  @override
  String get profileName => 'Profile Name';

  @override
  String get renameProfile => 'Rename Profile';

  @override
  String get deleteProfile => 'Delete Profile';

  @override
  String get deleteConfirm => 'Are you sure you want to delete this profile?';

  @override
  String get rename => 'Rename';

  @override
  String get noProfiles => 'No Profiles';

  @override
  String get profileActive => 'Active';

  @override
  String get searchProfiles => 'Search profiles';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get navCertificates => 'Certificates';

  @override
  String get optionalTools => 'Optional tools';

  @override
  String get textDiffDescription =>
      'Compare two texts locally and inspect line-by-line changes.';

  @override
  String get textDiffOriginal => 'Original text';

  @override
  String get textDiffModified => 'Modified text';

  @override
  String get textDiffOriginalHint => 'Paste the original text here...';

  @override
  String get textDiffModifiedHint => 'Paste the modified text here...';

  @override
  String get textDiffResult => 'Comparison result';

  @override
  String get textDiffEmpty => 'Enter text on either side to start comparing.';

  @override
  String get textDiffNoChanges => 'The two texts are identical.';

  @override
  String get textDiffSwap => 'Swap sides';

  @override
  String get textDiffCopyPatch => 'Copy patch';

  @override
  String get textDiffAdded => 'Added';

  @override
  String get textDiffRemoved => 'Removed';

  @override
  String get textDiffChanged => 'Changed';

  @override
  String textDiffSummary(int added, int removed, int changed) {
    return '$added added · $removed removed · $changed changed';
  }

  @override
  String get certGenerator => 'Certificate Generator';

  @override
  String get certGeneratorDescription =>
      'Generate ThingsBoard HTTPS and MQTTS self-signed certificate packages.';

  @override
  String get certUsage => 'Usage';

  @override
  String get certUsageHttps => 'HTTPS';

  @override
  String get certUsageMqtts => 'MQTTS';

  @override
  String get certUsageShared => 'HTTPS + MQTTS';

  @override
  String get certFormat => 'Certificate Format';

  @override
  String get certPassword => 'Certificate Password';

  @override
  String get certPasswordHint => 'Used for private key and keystore passwords';

  @override
  String get certSanAddresses => 'Certificate SAN Addresses';

  @override
  String get certSanHint => 'One IP/domain per line, or comma separated';

  @override
  String get certHostsIp => 'Hosts Binding IP';

  @override
  String get certHostsIpHint => 'Optional. Used to generate hosts.example.txt';

  @override
  String get certHostsIpInvalid => 'Hosts binding IP is invalid';

  @override
  String get certParsedAddresses => 'Parsed Addresses';

  @override
  String get certOutputPreview => 'Output Preview';

  @override
  String get certFiles => 'Files';

  @override
  String get certEnv => 'ThingsBoard Env';

  @override
  String get certGenerateZip => 'Generate ZIP';

  @override
  String get certOpenFolder => 'Open Folder';

  @override
  String get certCopyConfig => 'Copy Config';

  @override
  String get certGenerated => 'Certificate package generated';

  @override
  String get certGenerationCancelled => 'Generation cancelled';

  @override
  String get certGenerationFailed => 'Certificate generation failed';

  @override
  String get certAddressRequired => 'At least one IP or domain is required';

  @override
  String get certPasswordRequired => 'Password is required';

  @override
  String get certPemNoPasswordHint =>
      'PEM private keys are not encrypted. Use PKCS12 for password protection.';

  @override
  String get certInvalidAddresses => 'Invalid addresses';

  @override
  String get certLocalDefaults =>
      'localhost, 127.0.0.1 and ::1 are always included.';

  @override
  String get certOpenSslHint =>
      'Built-in generator. No OpenSSL installation is required.';

  @override
  String get certZipSavedTo => 'ZIP saved to';

  @override
  String get certHostsExample => 'Hosts Example';

  @override
  String get certEndpointVerify => 'Endpoint Certificate Check';

  @override
  String get certEndpointVerifyHint =>
      'Enter a ThingsBoard host and port to check whether TLS is enabled and whether the certificate matches the access address.';

  @override
  String get certEndpointHost => 'Host';

  @override
  String get certEndpointHostHint => 'For example 10.8.0.219 or tb.example.com';

  @override
  String get certEndpointPort => 'Port';

  @override
  String get certEndpointPortHint => 'For example 8080, 8443, or 8883';

  @override
  String get certEndpointVerifyAction => 'Check Endpoint';

  @override
  String get certEndpointPortInvalid => 'Port must be 1-65535';

  @override
  String get certEndpointVerifyFailed => 'Endpoint check failed';

  @override
  String get certEndpointReadyTrusted =>
      'TLS is available and trusted by the system';

  @override
  String get certEndpointReadyUntrusted =>
      'TLS is available, but the certificate is not trusted by the system';

  @override
  String get certEndpointHostMismatch =>
      'TLS is available, but the certificate SAN does not match the host';

  @override
  String get certEndpointPlainHttpOnly =>
      'This port is plain HTTP. The certificate is not active';

  @override
  String get certEndpointUnreachable =>
      'Endpoint is unreachable or protocol does not match';

  @override
  String get certEndpointTlsAvailable => 'TLS';

  @override
  String get certEndpointPlainHttpAvailable => 'HTTP';

  @override
  String get certEndpointSystemTrust => 'System Trust';

  @override
  String get certEndpointHostMatch => 'Host Match';

  @override
  String get certEndpointCertificate => 'Certificate';

  @override
  String get certEndpointSubject => 'Subject';

  @override
  String get certEndpointIssuer => 'Issuer';

  @override
  String get certEndpointValidity => 'Validity';

  @override
  String get certEndpointSan => 'SAN';

  @override
  String get certEndpointError => 'Error';

  @override
  String get certEndpointNoCertificate => 'No server certificate was read';

  @override
  String get certEndpointYes => 'Yes';

  @override
  String get certEndpointNo => 'No';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get enableSubscriptions => 'Enable subscriptions';

  @override
  String get subscriptionsTitle => 'Subscriptions';

  @override
  String get subscriptionsHint =>
      'Topics every simulated device subscribes to after connecting';

  @override
  String get subscriptionsEmpty =>
      'No subscriptions. Click + or pick a preset.';

  @override
  String get subscriptionAdd => 'Add subscription';

  @override
  String get subscriptionTopicHint => 'Topic filter (supports + and #)';

  @override
  String get subscriptionTopicRequired => 'Topic is required';

  @override
  String get subscriptionQos => 'QoS';

  @override
  String get subscriptionEnabledTooltip => 'Enable / disable this subscription';

  @override
  String get subscriptionDelete => 'Remove subscription';

  @override
  String get subscriptionAutoAck => 'Auto-ACK';

  @override
  String get subscriptionAutoAckHint =>
      'On a ThingsBoard RPC request, auto-publish an empty response to v1/devices/me/rpc/response/<id>';

  @override
  String get subscriptionPresetThingsBoardRpc => 'Preset: ThingsBoard RPC';

  @override
  String get subscriptionPresetThingsBoardAttributes =>
      'Preset: Shared Attributes';

  @override
  String get themeTagSignal => 'default · lime';

  @override
  String get themeTagPlasma => 'cyberpunk · magenta';

  @override
  String get themeTagCobalt => 'tech blue';

  @override
  String get themeTagAmber => 'CRT · warm';

  @override
  String get themeTagMint => 'nature · teal';

  @override
  String get themeTagPaper => 'light · for daylight';

  @override
  String get themeTagLinen => 'light · warm clay';

  @override
  String get themeTagSlate => 'light · cool cobalt';
}
