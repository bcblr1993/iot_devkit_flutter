import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class LogStorageService {
  static final LogStorageService _instance = LogStorageService._internal();
  static LogStorageService get instance => _instance;

  LogStorageService._internal();

  // Configuration
  static const int _maxFileSize = 30 * 1024 * 1024; // 30 MB
  static const Duration _retentionPeriod = Duration(days: 7);
  static const String _currentLogFileName = 'IoT DevKit.log';
  static const String _logFolderName = 'IoT DevKit';
  
  Directory? _logDirectory;
  File? _currentLogFile;
  IOSink? _sink;
  int _currentFileSize = 0;
  
  final DateFormat _fileFormatter = DateFormat('yyyy-MM-dd_HH-mm-ss');
  final DateFormat _logFormatter = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

  Future<void> init() async {
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      _logDirectory = Directory(p.join(appDocDir.path, _logFolderName, 'logs'));
      
      if (!await _logDirectory!.exists()) {
        await _logDirectory!.create(recursive: true);
      }
      
      // Cleanup old logs on startup
      await _cleanupOldLogs();
      
      // Initialize logging
      await _initializeLogFile();
      
      debugPrint('LogStorageService initialized at: ${_logDirectory!.path}');
    } catch (e) {
      debugPrint('Failed to initialize LogStorageService: $e');
    }
  }

  Future<void> _initializeLogFile() async {
    if (_logDirectory == null) return;

    final File fixedLog = File(p.join(_logDirectory!.path, _currentLogFileName));
    
    if (await fixedLog.exists()) {
      final int length = await fixedLog.length();
      if (length >= _maxFileSize) {
        // Existing file is too big, rotate it immediately
        await _rotateLogFile(existingFile: fixedLog);
      } else {
        // Appending to existing file
        _currentLogFile = fixedLog;
        _currentFileSize = length;
        _sink = _currentLogFile!.openWrite(mode: FileMode.append);
        debugPrint('Appending to existing log file: ${_currentLogFile!.path} (Current size: $_currentFileSize bytes)');
      }
    } else {
      // Create new file
      await _openNewFixedLog();
    }
  }

  Future<void> write(LogRecord record) async {
    if (_sink == null) return;

    try {
      final String timestamp = _logFormatter.format(record.time);
      final String logLine = '[$timestamp] [${record.level.name}] [${record.loggerName}] ${record.message}\n';
      // Use logic similar to before, but check rotation before/after interaction isn't strictly necessary for every line if we check size.
      // But we must convert to bytes to track size.
      final List<int> bytes = logLine.codeUnits;
      
      _sink!.add(bytes);
      _currentFileSize += bytes.length;

      if (record.error != null) {
        final String errorLine = 'Error: ${record.error}\nStack: ${record.stackTrace}\n';
        final List<int> errorBytes = errorLine.codeUnits;
        _sink!.add(errorBytes);
        _currentFileSize += errorBytes.length;
      }
      
      // Check for rotation
      if (_currentFileSize >= _maxFileSize) {
        await _rotateLogFile();
      }
    } catch (e) {
      // Fallback to print if writing fails
      if (kDebugMode) print('Error writing to log file: $e');
    }
  }
  
  /// Rotates the current log file (or specific file) to an archive name.
  /// Then opens a fresh 'IoT DevKit.log'.
  Future<void> _rotateLogFile({File? existingFile}) async {
    try {
      // 1. Close current sink if open
      if (_sink != null) {
        await _sink!.flush();
        await _sink!.close();
        _sink = null;
      }
      
      final File targetFile = existingFile ?? _currentLogFile!;
      
      // 2. Rename current file to timestamped archive
      if (await targetFile.exists()) {
        final String timestamp = _fileFormatter.format(DateTime.now());
        final String archiveName = 'IoT DevKit_$timestamp.log';
        final String archivePath = p.join(_logDirectory!.path, archiveName);
        
        await targetFile.rename(archivePath);
        debugPrint('Archived log file to: $archivePath');
      }
      
      // 3. Open new fixed log
      await _openNewFixedLog();
      
    } catch (e) {
      debugPrint('Failed to rotate log file: $e');
      // If rotation failed, try to reopen current or just fail safe
    }
  }

  Future<void> _openNewFixedLog() async {
     _currentLogFile = File(p.join(_logDirectory!.path, _currentLogFileName));
     _sink = _currentLogFile!.openWrite(mode: FileMode.append);
     _currentFileSize = 0;
     debugPrint('Opened new log file: ${_currentLogFile!.path}');
  }

  Future<void> _cleanupOldLogs() async {
    if (_logDirectory == null) return;
    
    try {
      final DateTime now = DateTime.now();
      final List<FileSystemEntity> files = _logDirectory!.listSync();
      
      int deletedCount = 0;
      for (var file in files) {
        if (file is File && file.path.endsWith('.log')) {
          final String basename = p.basename(file.path);
          // Don't delete the active app.log
          if (basename == _currentLogFileName) continue;

          final FileStat stat = await file.stat();
          final Duration age = now.difference(stat.modified);
          
          if (age > _retentionPeriod) {
            await file.delete();
            deletedCount++;
          }
        }
      }
      if (deletedCount > 0) {
        debugPrint('Cleaned up $deletedCount old log files.');
      }
    } catch (e) {
      debugPrint('Failed to clean up old logs: $e');
    }
  }

  Future<void> openLogFolder() async {
    if (_logDirectory == null) return;
    
    final String path = _logDirectory!.path;
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (e) {
      debugPrint('Failed to open log folder: $e');
    }
  }
  
  Future<void> dispose() async {
    if (_sink != null) {
      await _sink!.flush();
      await _sink!.close();
      _sink = null;
    }
  }
}

