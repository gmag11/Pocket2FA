import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../services/log_service.dart';

/// Screen that displays the in-memory diagnostic log.
///
/// The user can:
/// - Scroll through all log entries.
/// - Filter by severity level.
/// - Copy all entries to the clipboard.
/// - Share/export the full log as a text file.
/// - Clear the log.
class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final LogService _logService = LogService.instance;
  int _filterIndex = 0; // 0 = All, 1 = debug, 2 = info, 3 = warning, 4 = error
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<LogEntry> get _filteredEntries {
    final all = _logService.entries;
    if (_filterIndex == 0) return all;
    final level = LogLevel.values[_filterIndex - 1];
    return all.where((e) => e.level == level).toList();
  }

  Color _levelColor(LogLevel level, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (level) {
      case LogLevel.debug:
        return cs.onSurface.withValues(alpha: 0.4);
      case LogLevel.info:
        return cs.primary;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return cs.error;
    }
  }

  String _levelLabel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }

  Future<void> _copyToClipboard(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final text = _logService.exportAsText();
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.logCopied)),
      );
    }
  }

  Future<void> _shareLog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final file = await _logService.exportToFile();
    if (file == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.logExportFailed)),
        );
      }
      return;
    }

    if (Platform.isLinux || Platform.isWindows) {
      // Share is not implemented on desktop: save file to Downloads folder.
      try {
        final downloadsDir = await getDownloadsDirectory();
        final destDir = downloadsDir ?? await getApplicationDocumentsDirectory();
        final fileName = file.uri.pathSegments.last;
        final destPath = '${destDir.path}/$fileName';
        await file.copy(destPath);
        await file.delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.logSavedTo(destPath))),
          );
        }
      } catch (_) {
        try {
          await file.delete();
        } catch (_) {}
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.logExportFailed)),
          );
        }
      }
      return;
    }

    if (context.mounted) {
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/plain')],
        subject: 'Pocket2FA Diagnostic Log',
      );
    }
    // Delete the temp file after share UI is dismissed
    try {
      await file.delete();
    } catch (_) {}
  }

  Future<void> _clearLog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.logClearTitle),
        content: Text(l10n.logClearConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.logClearAction),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _logService.clear();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.logViewerTitle),
        actions: [
          // Filter dropdown
          PopupMenuButton<int>(
            icon: const Icon(Icons.filter_list),
            tooltip: l10n.logFilter,
            initialValue: _filterIndex,
            onSelected: (index) => setState(() => _filterIndex = index),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 0,
                child: Row(
                  children: [
                    if (_filterIndex == 0)
                      const Icon(Icons.check, size: 16)
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Text(l10n.logFilterAll),
                  ],
                ),
              ),
              for (var i = 0; i < LogLevel.values.length; i++)
                PopupMenuItem(
                  value: i + 1,
                  child: Row(
                    children: [
                      if (_filterIndex == i + 1)
                        const Icon(Icons.check, size: 16)
                      else
                        const SizedBox(width: 16),
                      const SizedBox(width: 8),
                      Text(_levelLabel(LogLevel.values[i]),
                          style: TextStyle(
                              color: _levelColor(LogLevel.values[i], context))),
                    ],
                  ),
                ),
            ],
          ),
          // Copy to clipboard
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: l10n.logCopy,
            onPressed: () => _copyToClipboard(context),
          ),
          // Share / export
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: l10n.logShare,
            onPressed: () => _shareLog(context),
          ),
          // Clear
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.logClear,
            onPressed: () => _clearLog(context),
          ),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: _logService.entryCount,
        builder: (context, _, __) {
          final entries = _filteredEntries;
          if (entries.isEmpty) {
            return Center(
              child: Text(
                l10n.logEmpty,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
              ),
            );
          }
          return ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _LogEntryTile(
                entry: entry,
                levelColor: _levelColor(entry.level, context),
                levelLabel: _levelLabel(entry.level),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.small(
        tooltip: l10n.logScrollToBottom,
        onPressed: () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        },
        child: const Icon(Icons.arrow_downward),
      ),
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  final LogEntry entry;
  final Color levelColor;
  final String levelLabel;

  const _LogEntryTile({
    required this.entry,
    required this.levelColor,
    required this.levelLabel,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}.${entry.timestamp.millisecond.toString().padLeft(3, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level badge
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            decoration: BoxDecoration(
              color: levelColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              levelLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: levelColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Timestamp
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 8),
          // Source name
          Text(
            entry.name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 4),
          // Message (expanded)
          Expanded(
            child: Text(
              entry.message,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
