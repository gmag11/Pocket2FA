import 'dart:collection';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';

/// Severity level of a log entry.
enum LogLevel { debug, info, warning, error }

/// A single log entry.
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String name;
  final String message;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.name,
    required this.message,
  });

  String get levelTag {
    switch (level) {
      case LogLevel.debug:
        return 'D';
      case LogLevel.info:
        return 'I';
      case LogLevel.warning:
        return 'W';
      case LogLevel.error:
        return 'E';
    }
  }

  @override
  String toString() {
    final ts = timestamp.toIso8601String();
    return '[$ts][$levelTag][$name] $message';
  }
}

/// Singleton in-memory log service.
///
/// Captures log entries from across the app and makes them available
/// for display or export. Intended for diagnostic/debugging purposes.
///
/// Log capture is gated on [SettingsService.debugLoggingEnabled]. When
/// disabled, all [log] calls are no-ops.
class LogService {
  LogService._internal();

  static final LogService instance = LogService._internal();

  /// Maximum number of entries kept in memory.
  static const int _maxEntries = 1000;

  final Queue<LogEntry> _entries = Queue<LogEntry>();
  bool _notificationScheduled = false;

  /// Notifier that fires whenever a new log entry is added.
  final ValueNotifier<int> entryCount = ValueNotifier<int>(0);

  /// Whether logging capture is enabled. Controlled externally by SettingsService.
  bool enabled = false;

  /// Returns an unmodifiable snapshot of current log entries (oldest first).
  List<LogEntry> get entries => List.unmodifiable(_entries);

  /// Records a new log entry. No-op when [enabled] is false.
  /// Always forwards to `developer.log` for IDE debugging regardless of the setting.
  void log(
    String message, {
    String name = 'App',
    LogLevel level = LogLevel.info,
  }) {
    // Always output to developer.log for IDE debugging
    developer.log('$name: $message', name: name);

    if (!enabled) return;

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      name: name,
      message: message,
    );
    _entries.addLast(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeFirst();
    }
    // Defer notification to avoid setState-during-build errors
    // when log() is called from within a widget build phase.
    if (!_notificationScheduled) {
      _notificationScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notificationScheduled = false;
        entryCount.value = _entries.length;
      });
    }
  }

  /// Convenience shortcuts.
  void debug(String message, {String name = 'App'}) =>
      log(message, name: name, level: LogLevel.debug);

  void info(String message, {String name = 'App'}) =>
      log(message, name: name, level: LogLevel.info);

  void warning(String message, {String name = 'App'}) =>
      log(message, name: name, level: LogLevel.warning);

  void error(String message, {String name = 'App'}) =>
      log(message, name: name, level: LogLevel.error);

  /// Clears all stored log entries.
  void clear() {
    _entries.clear();
    entryCount.value = 0;
  }

  /// Returns all log entries as a single plain-text string.
  String exportAsText() {
    final buf = StringBuffer();
    buf.writeln('Pocket2FA Diagnostic Log');
    buf.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buf.writeln('Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    buf.writeln('Dart SDK: ${Platform.version}');
    buf.writeln('─' * 60);
    for (final entry in _entries) {
      buf.writeln(entry.toString());
    }
    return buf.toString();
  }

  /// Saves the log to a file in the app's temporary directory and returns the path,
  /// or null if the save fails.
  Future<File?> exportToFile() async {
    try {
      final dir = await getTemporaryDirectory();
      final fileName =
          'pocket2fa_log_${DateTime.now().millisecondsSinceEpoch}.txt';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(exportAsText());
      return file;
    } catch (e) {
      log('Failed to export log to file: $e', name: 'LogService', level: LogLevel.error);
      return null;
    }
  }
}
