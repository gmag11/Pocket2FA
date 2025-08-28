import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatelessWidget {
  final SettingsService settings;
  const SettingsScreen({required this.settings, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: settings,
              builder: (context, _) {
                final enabled = settings.enabled;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: enabled,
                      onChanged: (v) => settings.setEnabled(v),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      fit: FlexFit.loose,
                      child: Text('Code formatting', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: enabled ? null : Colors.grey.shade600)),
                    ),
                    const SizedBox(width: 8),
                    Opacity(
                      opacity: enabled ? 1.0 : 0.45,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _formatButton(context, settings.format == CodeFormat.spaced3, 'by Trio', '123 456', enabled ? () => settings.setFormat(CodeFormat.spaced3) : () {}),
                          const SizedBox(width: 4),
                          _formatButton(context, settings.format == CodeFormat.spaced2, 'by Pair', '12 34 56', enabled ? () => settings.setFormat(CodeFormat.spaced2) : () {}),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _formatButton(BuildContext context, bool selected, String label, String sample, VoidCallback onTap) {
    final bg = selected ? Theme.of(context).colorScheme.primary : Colors.white;
    final fg = selected ? Colors.white : Colors.black87;
    final borderColor = selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300;
    return Material(
      color: bg,
      elevation: selected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          constraints: const BoxConstraints(minWidth: 80, minHeight: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(color: fg, fontSize: 12)),
              const SizedBox(height: 2),
              Text(sample, style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
