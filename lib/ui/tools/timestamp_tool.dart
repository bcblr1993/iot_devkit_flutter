import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/generated/app_localizations.dart';
import '../styles/app_theme_effect.dart';

class TimestampTool extends StatefulWidget {
  const TimestampTool({super.key});

  @override
  State<TimestampTool> createState() => _TimestampToolState();
}

class _TimestampToolState extends State<TimestampTool> {
  final _tsController = TextEditingController();
  final _dateController = TextEditingController();
  final _format = DateFormat("yyyy-MM-dd HH:mm:ss");
  
  Timer? _timer;
  DateTime _now = DateTime.now();
  
  // Persistence
  Timer? _saveTimer;
  static const String _kTsInput = 'timestamp_tool_ts_input';
  static const String _kDateInput = 'timestamp_tool_date_input';
  static const String _kTsTz = 'timestamp_tool_ts_tz';
  static const String _kDateTz = 'timestamp_tool_date_tz';
  static const String _kResDate = 'timestamp_tool_res_date';
  static const String _kResTs = 'timestamp_tool_res_ts';

  // Status Bar State
  String _statusMessage = '';
  Color _statusColor = Colors.grey;
  
  // Timezones from original JS
  final List<Map<String, dynamic>> _timezones = [
    {'value': 'UTC', 'label': 'UTC (协调世界时)', 'offset': 0},
    {'value': 'Asia/Shanghai', 'label': 'UTC+8 北京/上海', 'offset': 8},
    {'value': 'Asia/Tokyo', 'label': 'UTC+9 东京', 'offset': 9},
    {'value': 'Asia/Seoul', 'label': 'UTC+9 首尔', 'offset': 9},
    {'value': 'Asia/Singapore', 'label': 'UTC+8 新加坡', 'offset': 8},
    {'value': 'Asia/Hong_Kong', 'label': 'UTC+8 香港', 'offset': 8},
    {'value': 'America/New_York', 'label': 'UTC-5/-4 纽约', 'offset': -5}, 
    {'value': 'America/Los_Angeles', 'label': 'UTC-8/-7 洛杉矶', 'offset': -8},
    {'value': 'America/Chicago', 'label': 'UTC-6/-5 芝加哥', 'offset': -6},
    {'value': 'Europe/London', 'label': 'UTC+0/+1 伦敦', 'offset': 0},
    {'value': 'Europe/Paris', 'label': 'UTC+1/+2 巴黎', 'offset': 1},
    {'value': 'Europe/Berlin', 'label': 'UTC+1/+2 柏林', 'offset': 1},
  ];

  String _selectedTsTz = 'Asia/Shanghai';
  String _selectedDtTz = 'Asia/Shanghai';
  
  String _conversionResultDate = '';
  String _conversionResultTs = '';

  @override
  void initState() {
    super.initState();
    _startTimer();
    _loadState();
    _tsController.addListener(_saveDelayed);
    _dateController.addListener(_saveDelayed);
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_statusMessage.isEmpty) {
      _statusMessage = AppLocalizations.of(context)?.ready ?? 'Ready';
    }
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _saveTimer?.cancel();
    _tsController.dispose();
    _dateController.dispose();
    super.dispose();
  }
  
  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _tsController.text = prefs.getString(_kTsInput) ?? '';
        _dateController.text = prefs.getString(_kDateInput) ?? '';
        _selectedTsTz = prefs.getString(_kTsTz) ?? 'Asia/Shanghai';
        _selectedDtTz = prefs.getString(_kDateTz) ?? 'Asia/Shanghai';
        _conversionResultDate = prefs.getString(_kResDate) ?? '';
        _conversionResultTs = prefs.getString(_kResTs) ?? '';
        
        // Validate timezone values just in case
        if (!_timezones.any((t) => t['value'] == _selectedTsTz)) _selectedTsTz = 'Asia/Shanghai';
        if (!_timezones.any((t) => t['value'] == _selectedDtTz)) _selectedDtTz = 'Asia/Shanghai';
      });
    }
  }
  
  void _saveDelayed() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _saveState);
  }
  
  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTsInput, _tsController.text);
    await prefs.setString(_kDateInput, _dateController.text);
    await prefs.setString(_kTsTz, _selectedTsTz);
    await prefs.setString(_kDateTz, _selectedDtTz);
    await prefs.setString(_kResDate, _conversionResultDate);
    await prefs.setString(_kResTs, _conversionResultTs);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  void _setStatus(String msg, Color color) {
    setState(() {
      _statusMessage = msg;
      _statusColor = color;
    });
  }

  void _convertTsToDate() {
    final tsStr = _tsController.text.trim();
    if (tsStr.isEmpty) return;
    
    final l10n = AppLocalizations.of(context)!;
    
    try {
      int ts = int.parse(tsStr);
      // Heuristic: seconds vs ms
      if (ts < 10000000000) ts *= 1000;
      
      final tzInfo = _timezones.firstWhere((e) => e['value'] == _selectedTsTz);
      final offsetHours = tzInfo['offset'] as int;
      
      // Create UTC date -> add offset -> format
      final utcDate = DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true);
      final targetDate = utcDate.add(Duration(hours: offsetHours));
      
      setState(() {
        _conversionResultDate = _format.format(targetDate);
        _setStatus(l10n.formatSuccess, Colors.green); 
      });
      _saveState(); // Save result
    } catch (e) {
        setState(() {
          _conversionResultDate = 'Error';
           _setStatus('${l10n.formatError}: $e', Theme.of(context).colorScheme.error);
        });
        _saveState(); // Save error state
    }
  }

  void _convertDateToTs() {
    final dateStr = _dateController.text.trim();
    if (dateStr.isEmpty) return;
    
    final l10n = AppLocalizations.of(context)!;
    
    try {
      DateTime parsed = DateTime.parse(dateStr.replaceAll('/', '-').replaceAll(' ', 'T')); 
      
      final tzInfo = _timezones.firstWhere((e) => e['value'] == _selectedDtTz);
      final offsetHours = tzInfo['offset'] as int;
      
      final wallTimeAsUtc = DateTime.utc(parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute, parsed.second);
      final realUtc = wallTimeAsUtc.subtract(Duration(hours: offsetHours));
      
      setState(() {
        _conversionResultTs = realUtc.millisecondsSinceEpoch.toString();
        _setStatus(l10n.formatSuccess, Colors.green);
      });
      _saveState(); // Save result
    } catch (e) {
        try {
           final parsed = _format.parse(dateStr); 
           final tzInfo = _timezones.firstWhere((e) => e['value'] == _selectedDtTz);
           final offsetHours = tzInfo['offset'] as int;
           final wallTimeAsUtc = DateTime.utc(parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute, parsed.second);
           final realUtc = wallTimeAsUtc.subtract(Duration(hours: offsetHours));
           setState(() {
             _conversionResultTs = realUtc.millisecondsSinceEpoch.toString();
             _setStatus(l10n.formatSuccess, Colors.green);
           });
           _saveState();
        } catch (e2) {
           setState(() {
             _conversionResultTs = 'Error'; 
             _setStatus(l10n.formatError, Theme.of(context).colorScheme.error);
           }); 
           _saveState();
        }
    }
  }
  
  Future<void> _copy(String text) async {
    if (text.isEmpty || text == 'Error' || text == '---') return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
       _setStatus(AppLocalizations.of(context)!.copySuccess, Colors.green);
    }
  }
  
  void _fillCurrentTs() {
    _tsController.text = DateTime.now().millisecondsSinceEpoch.toString();
    _convertTsToDate();
  }
  
  void _fillCurrentDate() {
    _dateController.text = _format.format(DateTime.now());
    _convertDateToTs();
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effect = theme.extension<AppThemeEffect>() ?? 
                   const AppThemeEffect(animationCurve: Curves.easeInOut, layoutDensity: 1.0, icons: AppIcons.standard);

    return Padding(
      padding: EdgeInsets.all(16.0 * effect.layoutDensity),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
           // 1. Hero Header
           Card(
             elevation: 0,
             color: colorScheme.primaryContainer,
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
             child: Padding(
               padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 32.0),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(l10n.currentDate.toUpperCase(), style: TextStyle(color: colorScheme.onPrimaryContainer.withOpacity(0.6), letterSpacing: 1.2, fontSize: 12, fontWeight: FontWeight.bold)),
                       const SizedBox(height: 8),
                       Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           SelectableText(_format.format(_now), style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer, fontFamily: 'Monospace')),
                           const SizedBox(width: 8),
                           IconButton(
                             onPressed: () => _copy(_format.format(_now)),
                             icon: Icon(effect.icons.copy, color: colorScheme.onPrimaryContainer.withOpacity(0.7), size: 18),
                             tooltip: l10n.copyDate,
                           ),
                         ],
                       ),
                     ],
                   ),
                   Container(width: 2, height: 60, color: colorScheme.onPrimaryContainer.withOpacity(0.2)),
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.end,
                     children: [
                       Text(l10n.currentTimestamp.toUpperCase(), style: TextStyle(color: colorScheme.onPrimaryContainer.withOpacity(0.6), letterSpacing: 1.2, fontSize: 12, fontWeight: FontWeight.bold)),
                       const SizedBox(height: 8),
                       Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           SelectableText(_now.millisecondsSinceEpoch.toString(), style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer, fontFamily: 'Monospace')),
                           const SizedBox(width: 8),
                           IconButton(
                             onPressed: () => _copy(_now.millisecondsSinceEpoch.toString()),
                             icon: Icon(effect.icons.copy, color: colorScheme.onPrimaryContainer.withOpacity(0.7), size: 18),
                             tooltip: l10n.copyTimestamp,
                           ),
                         ],
                       ),
                     ],
                   ),
                 ],
               ),
             ),
           ),
           const SizedBox(height: 20),
           
           // 2. Converters Row
           Expanded(
             child: Row(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 // TS -> Date Panel
                 Expanded(
                   child: _buildConverterPanel(
                     context,
                     title: l10n.timestampToDate,
                     icon: effect.icons.time,
                     effect: effect,
                     inputWidget: TextField(
                        controller: _tsController,
                        decoration: InputDecoration(
                          labelText: l10n.timestampInput,
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.history),
                            tooltip: l10n.useCurrentTime,
                            onPressed: _fillCurrentTs,
                          )
                        ),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onSubmitted: (_) => _convertTsToDate(),
                     ),
                     timezoneValue: _selectedTsTz,
                     onTimezoneChanged: (v) { setState(() => _selectedTsTz = v!); _saveState(); },
                     onConvert: _convertTsToDate,
                     resultValue: _conversionResultDate,
                     isPlaceholder: _conversionResultDate.isEmpty,
                   ),
                 ),
                 const SizedBox(width: 20),
                 // Date -> TS Panel
                 Expanded(
                   child: _buildConverterPanel(
                     context,
                     title: l10n.dateToTimestamp,
                     icon: effect.icons.calendar,
                     effect: effect,
                     inputWidget: TextField(
                        controller: _dateController,
                        decoration: InputDecoration(
                          labelText: l10n.dateInput,
                          hintText: l10n.dateInputHint,
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.history),
                            tooltip: l10n.useCurrentTime,
                            onPressed: _fillCurrentDate,
                          )
                        ),
                        onSubmitted: (_) => _convertDateToTs(),
                     ),
                     timezoneValue: _selectedDtTz,
                     onTimezoneChanged: (v) { setState(() => _selectedDtTz = v!); _saveState(); },
                     onConvert: _convertDateToTs,
                     resultValue: _conversionResultTs,
                     isPlaceholder: _conversionResultTs.isEmpty,
                   ),
                 ),
               ],
             ),
           ),
           
           // 3. Status Bar (Bottom)
           Container(
             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
             margin: const EdgeInsets.only(top: 12),
             decoration: BoxDecoration(
               color: _statusColor.withOpacity(0.1),
               borderRadius: BorderRadius.circular(8),
               border: Border.all(color: _statusColor.withOpacity(0.3)),
             ),
             child: Row(
               children: [
                 Icon(Icons.info_outline, size: 16, color: _statusColor),
                 const SizedBox(width: 8),
                 Expanded(
                   child: Text(
                     _statusMessage,
                     style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold, fontSize: 13),
                     maxLines: 1,
                     overflow: TextOverflow.ellipsis,
                   ),
                 ),
               ],
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildConverterPanel(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget inputWidget,
    required String timezoneValue,
    required ValueChanged<String?> onTimezoneChanged,
    required VoidCallback onConvert,
    required String resultValue,
    required bool isPlaceholder,
    required AppThemeEffect effect,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(24.0 * effect.layoutDensity),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 12),
                Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 24 * effect.layoutDensity),
            inputWidget,
            SizedBox(height: 16 * effect.layoutDensity),
            DropdownButtonFormField<String>(
              borderRadius: BorderRadius.circular(12),
              dropdownColor: theme.colorScheme.surface,
              style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
              iconEnabledColor: theme.colorScheme.onSurface.withOpacity(0.7),
              value: timezoneValue,
              decoration: InputDecoration(labelText: l10n.timezone, border: const OutlineInputBorder()),
              items: _timezones.map((e) => DropdownMenuItem(value: e['value'] as String, child: Text(e['label'] as String))).toList(),
              onChanged: onTimezoneChanged,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: onConvert,
                icon: const Icon(Icons.sync_alt),
                label: Text(l10n.convert),
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.conversionResult, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SelectableText(
                      isPlaceholder ? '---' : resultValue,
                      style: TextStyle(
                        fontSize: 28, 
                        fontWeight: FontWeight.bold,
                        color: isPlaceholder || resultValue == 'Error' ? colorScheme.onSurfaceVariant : colorScheme.primary,
                        fontFamily: 'Monospace'
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (!isPlaceholder && resultValue != 'Error') ...[
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => _copy(resultValue),
                        icon: const Icon(Icons.copy, size: 18),
                        label: Text(l10n.copyAction),
                      )
                    ]
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
