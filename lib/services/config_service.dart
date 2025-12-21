import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/group_config.dart';
import '../models/custom_key_config.dart';

class ConfigService {
  static const String _storageKey = 'simulator_config';
  static const String _appSignature = 'iot_devkit_flutter_v1';

  /// Saves the current configuration to local storage (auto-save)
  static Future<void> saveToLocalStorage(Map<String, dynamic> config) async {
    final prefs = await SharedPreferences.getInstance();
    final serialized = _serializeConfig(config);
    await prefs.setString(_storageKey, jsonEncode(serialized));
  }

  /// Loads the configuration from local storage
  static Future<Map<String, dynamic>?> loadFromLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);
    if (data == null) return null;
    try {
      return jsonDecode(data);
    } catch (e) {
      return null;
    }
  }

  /// Exports configuration to a JSON file
  static Future<({bool success, String? error, bool cancelled})> exportToFile(Map<String, dynamic> config) async {
    try {
      final serialized = _serializeConfig(config);
      // Add app signature for validation
      serialized['_app_signature'] = _appSignature;
      serialized['_export_time'] = DateTime.now().toIso8601String();
      
      final jsonString = const JsonEncoder.withIndent('  ').convert(serialized);
      
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Configuration',
        fileName: 'iot_simulator_config.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (outputPath != null) {
        final file = File(outputPath);
        await file.writeAsString(jsonString);
        return (success: true, error: null, cancelled: false);
      }
      return (success: false, error: null, cancelled: true);
    } catch (e) {
      print('Export error: $e');
      return (success: false, error: e.toString(), cancelled: false);
    }
  }

  /// Imports configuration from a JSON file
  /// Returns a record with the config and validation result
  static Future<({Map<String, dynamic>? config, String? error})> importFromFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final Map<String, dynamic> parsed = jsonDecode(content);
        
        // Validate app signature
        final signature = parsed['_app_signature'];
        if (signature == null) {
          return (config: null, error: '无效的配置文件：缺少应用签名。该文件可能不是由此应用导出的。');
        }
        if (signature != _appSignature) {
          return (config: null, error: '配置文件版本不兼容：签名为 "$signature"，期望 "$_appSignature"。');
        }
        
        // Remove meta fields before returning
        parsed.remove('_app_signature');
        parsed.remove('_export_time');
        
        return (config: parsed, error: null);
      }
    } catch (e) {
      print('Import error: $e');
      return (config: null, error: '导入失败：文件格式错误或已损坏。');
    }
    return (config: null, error: null); // User cancelled
  }

  /// Helper to convert complex objects in the config map to JSON-friendly format
  static Map<String, dynamic> _serializeConfig(Map<String, dynamic> config) {
    final Map<String, dynamic> result = Map.from(config);
    
    if (result['custom_keys'] != null && result['custom_keys'] is List<CustomKeyConfig>) {
      result['custom_keys'] = (result['custom_keys'] as List<CustomKeyConfig>).map((e) => e.toJson()).toList();
    }
    
    if (result['groups'] != null && result['groups'] is List<GroupConfig>) {
      result['groups'] = (result['groups'] as List<GroupConfig>).map((e) => e.toJson()).toList();
    }
    
    return result;
  }
}
