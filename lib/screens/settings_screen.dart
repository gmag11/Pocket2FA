import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  final SettingsService settings;
  const SettingsScreen({required this.settings, super.key});

  // Base accent color used across this screen. Derived shades are computed
  // locally so the UI matches the requested palette.
  static const Color _baseAccent = Color(0xFF4F63E6);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: AnimatedBuilder(
        animation: settings,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // GENERAL Section
              _buildSectionHeader('GENERAL'),
              const SizedBox(height: 12),
              
              // Code formatting setting
              _buildSettingTile(
                icon: Icons.code,
                title: l10n.codeFormatting,
                trailing: Switch(
                  value: settings.enabled,
                  onChanged: (v) => settings.setEnabled(v),
                  activeThumbColor: _baseAccent,
                ),
              ),
              
              if (settings.enabled) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 56.0),
                  child: Row(
                    children: [
                      _formatButton(
                          context,
                          settings.format == CodeFormat.spaced3,
                          l10n.byTrio,
                          '123 456',
                          () => settings.setFormat(CodeFormat.spaced3)),
                      const SizedBox(width: 8),
                      _formatButton(
                          context,
                          settings.format == CodeFormat.spaced2,
                          l10n.byPair,
                          '12 34 56',
                          () => settings.setFormat(CodeFormat.spaced2)),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              // SECURITY Section
              _buildSectionHeader('SECURITY'),
              const SizedBox(height: 12),
              
              // Biometric protection
              _buildSettingTile(
                icon: Icons.fingerprint,
                title: l10n.biometricProtection,
                trailing: Builder(builder: (ctx) {
                  final messenger = ScaffoldMessenger.of(ctx);
                  final supported = settings.biometricsSupported;
                  final switchWidget = Switch(
                    value: settings.biometricEnabled,
                    onChanged: supported
                        ? (v) async {
                            // capture localized messages before awaiting
                            final l = AppLocalizations.of(ctx)!;
                            final enabledMsg = l.biometricEnabled;
                            final disabledMsg = l.biometricDisabled;
                            final operationFailedMsg = l.operationFailed;
                            final ok =
                                await settings.setBiometricEnabled(v);
                            messenger.showSnackBar(SnackBar(
                              content: Text(ok
                                  ? (v ? enabledMsg : disabledMsg)
                                  : operationFailedMsg),
                            ));
                          }
                        : null,
                    activeThumbColor: _baseAccent,
                  );
                  if (!supported) {
                    final l2 = AppLocalizations.of(ctx)!;
                    return Tooltip(
                        message: l2.biometricsNotAvailable,
                        child: switchWidget);
                  }
                  return switchWidget;
                }),
              ),
              
              // Hide OTPs setting
              _buildSettingTile(
                icon: Icons.visibility_off,
                title: l10n.hideOtpsOnHome,
                subtitle: l10n.longPressReveal,
                trailing: Switch(
                  value: settings.hideOtps,
                  onChanged: (v) => settings.setHideOtps(v),
                  activeThumbColor: _baseAccent,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // SYNCHRONIZATION Section
              _buildSectionHeader('SYNCHRONIZATION'),
              const SizedBox(height: 12),
              
              // Sync on Home open
              _buildSettingTile(
                icon: Icons.sync,
                title: l10n.syncOnHomeOpen,
                trailing: Switch(
                  value: settings.syncOnOpen,
                  onChanged: (v) => settings.setSyncOnOpen(v),
                  activeThumbColor: _baseAccent,
                ),
              ),
              
              // Automatic sync
              _buildSettingTile(
                icon: Icons.schedule,
                title: l10n.autoSync,
                trailing: Switch(
                  value: settings.autoSyncEnabled,
                  onChanged: (v) => settings.setAutoSyncEnabled(v),
                  activeThumbColor: _baseAccent,
                ),
              ),
              
              // Sync interval (only shown when auto-sync is enabled)
              if (settings.autoSyncEnabled) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Text('Sync every', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 12),
                      _buildIntervalSelector(),
                      const SizedBox(width: 12),
                      const Text('minutes', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, size: 24, color: Colors.grey[700]),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              )
            : null,
        trailing: trailing,
      ),
    );
  }

  Widget _buildIntervalSelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            onPressed: settings.autoSyncIntervalMinutes > 1
                ? () => settings.setAutoSyncIntervalMinutes(
                    settings.autoSyncIntervalMinutes - 1)
                : null,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '${settings.autoSyncIntervalMinutes}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: () => settings.setAutoSyncIntervalMinutes(
                settings.autoSyncIntervalMinutes + 1),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget _formatButton(BuildContext context, bool selected, String label,
      String sample, VoidCallback onTap) {
    // Slightly lighten the selected background so the button reads as "selected"
    // but less saturated than the raw accent color.
    final bg =
        selected ? Color.lerp(_baseAccent, Colors.white, 0.22)! : Colors.white;
    final fg = selected ? Colors.white : Colors.black87;
    // Use a lighter border when selected to match the lighter background.
    final borderColor = selected
        ? Color.lerp(_baseAccent, Colors.white, 0.18)!
        : Colors.grey.shade300;
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
              Text(sample,
                  style: TextStyle(
                      color: fg, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
