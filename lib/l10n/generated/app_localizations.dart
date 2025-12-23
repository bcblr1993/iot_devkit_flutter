import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'IoT DevKit'**
  String get appTitle;

  /// No description provided for @navSimulator.
  ///
  /// In en, this message translates to:
  /// **'Simulator'**
  String get navSimulator;

  /// No description provided for @navTimestamp.
  ///
  /// In en, this message translates to:
  /// **'Timestamp'**
  String get navTimestamp;

  /// No description provided for @navJson.
  ///
  /// In en, this message translates to:
  /// **'JSON'**
  String get navJson;

  /// No description provided for @startSimulation.
  ///
  /// In en, this message translates to:
  /// **'START SIMULATION'**
  String get startSimulation;

  /// No description provided for @stopSimulation.
  ///
  /// In en, this message translates to:
  /// **'STOP SIMULATION'**
  String get stopSimulation;

  /// No description provided for @mqttBroker.
  ///
  /// In en, this message translates to:
  /// **'MQTT Broker'**
  String get mqttBroker;

  /// No description provided for @dataStatistics.
  ///
  /// In en, this message translates to:
  /// **'Data Statistics'**
  String get dataStatistics;

  /// No description provided for @unitMessages.
  ///
  /// In en, this message translates to:
  /// **'msgs'**
  String get unitMessages;

  /// No description provided for @unitDevices.
  ///
  /// In en, this message translates to:
  /// **'devices'**
  String get unitDevices;

  /// No description provided for @host.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get host;

  /// No description provided for @port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// No description provided for @topic.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get topic;

  /// No description provided for @deviceConfig.
  ///
  /// In en, this message translates to:
  /// **'Device Configuration'**
  String get deviceConfig;

  /// No description provided for @startIndex.
  ///
  /// In en, this message translates to:
  /// **'Start Index'**
  String get startIndex;

  /// No description provided for @endIndex.
  ///
  /// In en, this message translates to:
  /// **'End Index'**
  String get endIndex;

  /// No description provided for @interval.
  ///
  /// In en, this message translates to:
  /// **'Interval (s)'**
  String get interval;

  /// No description provided for @format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get format;

  /// No description provided for @dataPointCount.
  ///
  /// In en, this message translates to:
  /// **'Data Point Count'**
  String get dataPointCount;

  /// No description provided for @basicMode.
  ///
  /// In en, this message translates to:
  /// **'Basic Mode'**
  String get basicMode;

  /// No description provided for @advancedMode.
  ///
  /// In en, this message translates to:
  /// **'Advanced Mode'**
  String get advancedMode;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @totalDevices.
  ///
  /// In en, this message translates to:
  /// **'Total Devices'**
  String get totalDevices;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @totalSuccessFail.
  ///
  /// In en, this message translates to:
  /// **'Total/Success/Fail'**
  String get totalSuccessFail;

  /// No description provided for @latency.
  ///
  /// In en, this message translates to:
  /// **'Latency'**
  String get latency;

  /// No description provided for @logs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logs;

  /// No description provided for @clearLogs.
  ///
  /// In en, this message translates to:
  /// **'Clear Logs'**
  String get clearLogs;

  /// No description provided for @autoScrollOn.
  ///
  /// In en, this message translates to:
  /// **'Auto-scroll ON'**
  String get autoScrollOn;

  /// No description provided for @autoScrollOff.
  ///
  /// In en, this message translates to:
  /// **'Auto-scroll OFF'**
  String get autoScrollOff;

  /// No description provided for @timestampConverter.
  ///
  /// In en, this message translates to:
  /// **'Timestamp Converter'**
  String get timestampConverter;

  /// No description provided for @timestampInput.
  ///
  /// In en, this message translates to:
  /// **'Timestamp (ms or s)'**
  String get timestampInput;

  /// No description provided for @dateInput.
  ///
  /// In en, this message translates to:
  /// **'Date (yyyy-MM-dd HH:mm:ss)'**
  String get dateInput;

  /// No description provided for @convert.
  ///
  /// In en, this message translates to:
  /// **'Convert'**
  String get convert;

  /// No description provided for @resetToNow.
  ///
  /// In en, this message translates to:
  /// **'Reset to Now'**
  String get resetToNow;

  /// No description provided for @jsonFormatter.
  ///
  /// In en, this message translates to:
  /// **'JSON Formatter'**
  String get jsonFormatter;

  /// No description provided for @formatAction.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get formatAction;

  /// No description provided for @minifyAction.
  ///
  /// In en, this message translates to:
  /// **'Minify'**
  String get minifyAction;

  /// No description provided for @copyAction.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyAction;

  /// No description provided for @clearAction.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearAction;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @groupManagement.
  ///
  /// In en, this message translates to:
  /// **'Simulation Groups'**
  String get groupManagement;

  /// No description provided for @addGroup.
  ///
  /// In en, this message translates to:
  /// **'Add Group'**
  String get addGroup;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group Name'**
  String get groupName;

  /// No description provided for @prefixes.
  ///
  /// In en, this message translates to:
  /// **'Prefixes'**
  String get prefixes;

  /// No description provided for @clientId.
  ///
  /// In en, this message translates to:
  /// **'Client ID'**
  String get clientId;

  /// No description provided for @deviceName.
  ///
  /// In en, this message translates to:
  /// **'Device Name'**
  String get deviceName;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @totalKeys.
  ///
  /// In en, this message translates to:
  /// **'Total Keys'**
  String get totalKeys;

  /// No description provided for @selectTheme.
  ///
  /// In en, this message translates to:
  /// **'Select Theme'**
  String get selectTheme;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @customKeys.
  ///
  /// In en, this message translates to:
  /// **'Custom Keys'**
  String get customKeys;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @keyName.
  ///
  /// In en, this message translates to:
  /// **'Key Name'**
  String get keyName;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @mode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get mode;

  /// No description provided for @min.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get min;

  /// No description provided for @max.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get max;

  /// No description provided for @staticValue.
  ///
  /// In en, this message translates to:
  /// **'Static Value'**
  String get staticValue;

  /// No description provided for @themeAdminixEmerald.
  ///
  /// In en, this message translates to:
  /// **'Adminix Emerald'**
  String get themeAdminixEmerald;

  /// No description provided for @timestampToDate.
  ///
  /// In en, this message translates to:
  /// **'Timestamp → Date'**
  String get timestampToDate;

  /// No description provided for @dateToTimestamp.
  ///
  /// In en, this message translates to:
  /// **'Date → Timestamp'**
  String get dateToTimestamp;

  /// No description provided for @timezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get timezone;

  /// No description provided for @currentDate.
  ///
  /// In en, this message translates to:
  /// **'Current Date'**
  String get currentDate;

  /// No description provided for @currentTimestamp.
  ///
  /// In en, this message translates to:
  /// **'Current Timestamp'**
  String get currentTimestamp;

  /// No description provided for @inputLabel.
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get inputLabel;

  /// No description provided for @treeViewLabel.
  ///
  /// In en, this message translates to:
  /// **'Tree View'**
  String get treeViewLabel;

  /// No description provided for @itemsLabel.
  ///
  /// In en, this message translates to:
  /// **'items'**
  String get itemsLabel;

  /// No description provided for @enterJsonHint.
  ///
  /// In en, this message translates to:
  /// **'Enter JSON to view tree'**
  String get enterJsonHint;

  /// No description provided for @invalidJson.
  ///
  /// In en, this message translates to:
  /// **'Invalid JSON'**
  String get invalidJson;

  /// No description provided for @exportConfig.
  ///
  /// In en, this message translates to:
  /// **'Export Config'**
  String get exportConfig;

  /// No description provided for @importConfig.
  ///
  /// In en, this message translates to:
  /// **'Import Config'**
  String get importConfig;

  /// No description provided for @configExported.
  ///
  /// In en, this message translates to:
  /// **'Configuration Saved Successfully'**
  String get configExported;

  /// No description provided for @configExportCancelled.
  ///
  /// In en, this message translates to:
  /// **'Export Cancelled'**
  String get configExportCancelled;

  /// No description provided for @configImported.
  ///
  /// In en, this message translates to:
  /// **'Configuration imported'**
  String get configImported;

  /// No description provided for @configExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get configExportFailed;

  /// No description provided for @changeRatio.
  ///
  /// In en, this message translates to:
  /// **'Change Ratio (0-1)'**
  String get changeRatio;

  /// No description provided for @changeInterval.
  ///
  /// In en, this message translates to:
  /// **'Change Interval (s)'**
  String get changeInterval;

  /// No description provided for @fullInterval.
  ///
  /// In en, this message translates to:
  /// **'Full Interval (s)'**
  String get fullInterval;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @typeInteger.
  ///
  /// In en, this message translates to:
  /// **'Integer'**
  String get typeInteger;

  /// No description provided for @typeFloat.
  ///
  /// In en, this message translates to:
  /// **'Float'**
  String get typeFloat;

  /// No description provided for @typeString.
  ///
  /// In en, this message translates to:
  /// **'String'**
  String get typeString;

  /// No description provided for @typeBoolean.
  ///
  /// In en, this message translates to:
  /// **'Boolean'**
  String get typeBoolean;

  /// No description provided for @modeStatic.
  ///
  /// In en, this message translates to:
  /// **'Static'**
  String get modeStatic;

  /// No description provided for @modeIncrement.
  ///
  /// In en, this message translates to:
  /// **'Increment'**
  String get modeIncrement;

  /// No description provided for @modeRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get modeRandom;

  /// No description provided for @modeToggle.
  ///
  /// In en, this message translates to:
  /// **'Toggle'**
  String get modeToggle;

  /// No description provided for @pasteAction.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get pasteAction;

  /// No description provided for @expandAll.
  ///
  /// In en, this message translates to:
  /// **'Expand All'**
  String get expandAll;

  /// No description provided for @collapseAll.
  ///
  /// In en, this message translates to:
  /// **'Collapse All'**
  String get collapseAll;

  /// No description provided for @searchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchLabel;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get searchHint;

  /// No description provided for @formatSuccess.
  ///
  /// In en, this message translates to:
  /// **'Formatted successfully'**
  String get formatSuccess;

  /// No description provided for @minifySuccess.
  ///
  /// In en, this message translates to:
  /// **'Minified successfully'**
  String get minifySuccess;

  /// No description provided for @copySuccess.
  ///
  /// In en, this message translates to:
  /// **'Copied successfully'**
  String get copySuccess;

  /// No description provided for @useCurrentTime.
  ///
  /// In en, this message translates to:
  /// **'Use Current Time'**
  String get useCurrentTime;

  /// No description provided for @copyDate.
  ///
  /// In en, this message translates to:
  /// **'Copy Date'**
  String get copyDate;

  /// No description provided for @copyTimestamp.
  ///
  /// In en, this message translates to:
  /// **'Copy Timestamp'**
  String get copyTimestamp;

  /// No description provided for @conversionResult.
  ///
  /// In en, this message translates to:
  /// **'CONVERSION RESULT'**
  String get conversionResult;

  /// No description provided for @formatError.
  ///
  /// In en, this message translates to:
  /// **'Format Error'**
  String get formatError;

  /// No description provided for @dateInputHint.
  ///
  /// In en, this message translates to:
  /// **'yyyy-MM-dd HH:mm:ss'**
  String get dateInputHint;

  /// No description provided for @expandLogs.
  ///
  /// In en, this message translates to:
  /// **'Expand Logs'**
  String get expandLogs;

  /// No description provided for @collapseLogs.
  ///
  /// In en, this message translates to:
  /// **'Collapse Logs'**
  String get collapseLogs;

  /// No description provided for @formatDefault.
  ///
  /// In en, this message translates to:
  /// **'Default Format'**
  String get formatDefault;

  /// No description provided for @formatTieNiu.
  ///
  /// In en, this message translates to:
  /// **'Tie Niu Format'**
  String get formatTieNiu;

  /// No description provided for @formatTieNiuEmpty.
  ///
  /// In en, this message translates to:
  /// **'Tie Niu Empty Format'**
  String get formatTieNiuEmpty;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import Failed'**
  String get importFailed;

  /// No description provided for @confirmImport.
  ///
  /// In en, this message translates to:
  /// **'Confirm Import'**
  String get confirmImport;

  /// No description provided for @importWarning.
  ///
  /// In en, this message translates to:
  /// **'Configuration file validation passed.\n\nImporting will overwrite all current settings. Do you want to continue?'**
  String get importWarning;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @menuAbout.
  ///
  /// In en, this message translates to:
  /// **'About IoT DevKit'**
  String get menuAbout;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'A powerful MQTT Device Simulator for IoT development.\nBuilt with Flutter & Dart.'**
  String get aboutDescription;

  /// No description provided for @aboutFooter.
  ///
  /// In en, this message translates to:
  /// **'Copyright © 2025 Chen Xu & Antigravity'**
  String get aboutFooter;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @settingsLocked.
  ///
  /// In en, this message translates to:
  /// **'Settings locked while running'**
  String get settingsLocked;

  /// No description provided for @maxGroupsReached.
  ///
  /// In en, this message translates to:
  /// **'Maximum 12 groups allowed'**
  String get maxGroupsReached;

  /// No description provided for @groupLabel.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get groupLabel;

  /// No description provided for @limitExceeded.
  ///
  /// In en, this message translates to:
  /// **'Limit exceeded'**
  String get limitExceeded;

  /// No description provided for @ignored.
  ///
  /// In en, this message translates to:
  /// **'Ignored'**
  String get ignored;

  /// No description provided for @themeMatrixEmerald.
  ///
  /// In en, this message translates to:
  /// **'Matrix Emerald'**
  String get themeMatrixEmerald;

  /// No description provided for @themeForestMint.
  ///
  /// In en, this message translates to:
  /// **'Forest Mint'**
  String get themeForestMint;

  /// No description provided for @themeArcticBlue.
  ///
  /// In en, this message translates to:
  /// **'Arctic Blue'**
  String get themeArcticBlue;

  /// No description provided for @themeDeepOcean.
  ///
  /// In en, this message translates to:
  /// **'Deep Ocean'**
  String get themeDeepOcean;

  /// No description provided for @themeCrimsonNight.
  ///
  /// In en, this message translates to:
  /// **'Crimson Night'**
  String get themeCrimsonNight;

  /// No description provided for @themeRubyElegance.
  ///
  /// In en, this message translates to:
  /// **'Ruby Elegance'**
  String get themeRubyElegance;

  /// No description provided for @themeVoidBlack.
  ///
  /// In en, this message translates to:
  /// **'Void Black'**
  String get themeVoidBlack;

  /// No description provided for @themeGraphitePro.
  ///
  /// In en, this message translates to:
  /// **'Graphite Pro'**
  String get themeGraphitePro;

  /// No description provided for @logMaximize.
  ///
  /// In en, this message translates to:
  /// **'Maximize Logs'**
  String get logMaximize;

  /// No description provided for @logRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore Logs'**
  String get logRestore;

  /// No description provided for @copyJson.
  ///
  /// In en, this message translates to:
  /// **'Copy JSON'**
  String get copyJson;

  /// No description provided for @jsonCopied.
  ///
  /// In en, this message translates to:
  /// **'JSON copied to clipboard'**
  String get jsonCopied;

  /// No description provided for @sectionDeviceScope.
  ///
  /// In en, this message translates to:
  /// **'Device Scope'**
  String get sectionDeviceScope;

  /// No description provided for @sectionNamingAuth.
  ///
  /// In en, this message translates to:
  /// **'Naming & Authentication'**
  String get sectionNamingAuth;

  /// No description provided for @sectionDataConfig.
  ///
  /// In en, this message translates to:
  /// **'Data Configuration'**
  String get sectionDataConfig;

  /// No description provided for @statSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get statSent;

  /// No description provided for @statSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get statSuccess;

  /// No description provided for @statFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statFailed;

  /// No description provided for @enableSsl.
  ///
  /// In en, this message translates to:
  /// **'Enable SSL/TLS'**
  String get enableSsl;

  /// No description provided for @caCertificate.
  ///
  /// In en, this message translates to:
  /// **'CA Certificate'**
  String get caCertificate;

  /// No description provided for @clientCertificate.
  ///
  /// In en, this message translates to:
  /// **'Client Certificate'**
  String get clientCertificate;

  /// No description provided for @privateKey.
  ///
  /// In en, this message translates to:
  /// **'Private Key'**
  String get privateKey;

  /// No description provided for @previewPayload.
  ///
  /// In en, this message translates to:
  /// **'Preview Payload'**
  String get previewPayload;

  /// No description provided for @payloadPreview.
  ///
  /// In en, this message translates to:
  /// **'Payload Preview'**
  String get payloadPreview;

  /// No description provided for @selectFile.
  ///
  /// In en, this message translates to:
  /// **'Select File'**
  String get selectFile;

  /// No description provided for @previewAndStart.
  ///
  /// In en, this message translates to:
  /// **'Preview & Start'**
  String get previewAndStart;

  /// No description provided for @startNow.
  ///
  /// In en, this message translates to:
  /// **'Start Simulation'**
  String get startNow;

  /// No description provided for @confirmStartHint.
  ///
  /// In en, this message translates to:
  /// **'Click Confirm to start simulation with this payload structure.'**
  String get confirmStartHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
