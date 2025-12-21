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
  String get startSimulation => 'START SIMULATION';

  @override
  String get stopSimulation => 'STOP SIMULATION';

  @override
  String get mqttBroker => 'MQTT Broker';

  @override
  String get host => 'Host';

  @override
  String get port => 'Port';

  @override
  String get topic => 'Topic';

  @override
  String get deviceConfig => 'Device Configuration';

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
  String get themeVercelLight => 'Vercel Light';

  @override
  String get themeGithubDark => 'GitHub Dark';

  @override
  String get themeDracula => 'Dracula';

  @override
  String get themeMonokai => 'Monokai Pro';

  @override
  String get themeNordic => 'Nordic Snow';

  @override
  String get themeSolarized => 'Solarized Dark';

  @override
  String get themeDeepOcean => 'Deep Ocean';

  @override
  String get themeSakura => 'Sakura Pink';

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
  String get enterJsonHint => 'Enter JSON to view tree';

  @override
  String get invalidJson => 'Invalid JSON';

  @override
  String get exportConfig => 'Export Config';

  @override
  String get importConfig => 'Import Config';

  @override
  String get configExported => 'Configuration exported';

  @override
  String get configImported => 'Configuration imported';

  @override
  String get configExportFailed => 'Export failed';

  @override
  String get changeRatio => 'Change Ratio (0-1)';

  @override
  String get changeInterval => 'Change Interval (s)';

  @override
  String get fullInterval => 'Full Interval (s)';

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
  String get formatDefault => 'Default Format';

  @override
  String get formatTieNiu => 'Tie Niu Format';

  @override
  String get formatTieNiuEmpty => 'Tie Niu Empty Format';

  @override
  String get importFailed => 'Import Failed';

  @override
  String get confirmImport => 'Confirm Import';

  @override
  String get importWarning =>
      'Configuration file validation passed.\n\nImporting will overwrite all current settings. Do you want to continue?';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';
}
