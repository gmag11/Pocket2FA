import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'dart:developer' as developer;
import '../services/api_service.dart';
import '../models/server_connection.dart';
import '../models/user_preferences.dart';

Future<ServerConnection?> showServerAddEditDialog({
  required BuildContext context,
  required String title,
  ServerConnection? initial,
}) async {
  final nameCtrl = TextEditingController(text: initial?.name ?? '');
  final urlCtrl = TextEditingController(text: initial?.url ?? '');
  final apiCtrl = TextEditingController(text: initial?.apiKey ?? '');
  final isEdit = initial != null;
  final l10n = AppLocalizations.of(context)!;

  bool obscure = true;
  bool revealEnabled = !isEdit;
  bool cleared = !isEdit;
  final apiFocus = FocusNode();

  bool loading = false;
  String? errorText;

  return showDialog<ServerConnection?>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c2, setStateSB) {
        Future<void> validateAndClose() async {
          setStateSB(() {
            errorText = null;
            loading = true;
          });
          final urlText = urlCtrl.text.trim();
          final apiKeyText = apiCtrl.text.trim();
          if (urlText.isEmpty) {
            setStateSB(() {
              errorText = l10n.urlRequired;
              loading = false;
            });
            return;
          }

          final temp = ServerConnection(
            id: initial?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
            name: nameCtrl.text,
            url: urlCtrl.text,
            apiKey: apiKeyText,
            accounts: initial?.accounts ?? [],
            userEmail: initial?.userEmail ?? '',
          );

          try {
            final m = await ApiService.instance.validateServer(temp);
            try {
              developer.log('AccountsScreen: /api/v1/user response -> $m',
                  name: 'AccountsScreen');
            } catch (_) {}

            final sc = ServerConnection(
              id: temp.id,
              name: temp.name,
              url: temp.url,
              apiKey: temp.apiKey,
              accounts: temp.accounts,
              userId: m['id'] is int
                  ? m['id'] as int
                  : int.tryParse(m['id'].toString()),
              userName: m['name'] as String?,
              userEmail: m['email'] as String? ?? '',
              oauthProvider: m['oauth_provider']?.toString(),
              authenticatedByProxy: m['authenticated_by_proxy'] as bool?,
              preferences: m['preferences'] != null
                  ? UserPreferences.fromMap(
                      Map<dynamic, dynamic>.from(m['preferences'] as Map))
                  : null,
              isAdmin: m['is_admin'] as bool?,
            );

            if (!context.mounted) return;
            setStateSB(() {
              loading = false;
            });
            Navigator.of(context).pop(sc);
            return;
          } catch (e) {
            final msg = ApiService.instance.friendlyErrorMessage(e);
            setStateSB(() {
              errorText = msg;
              loading = false;
            });
            return;
          }
        }

        Widget apiFieldLocal() {
          return TextField(
            controller: apiCtrl,
            focusNode: apiFocus,
            decoration: InputDecoration(
              labelText: l10n.apiKeyLabel,
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: revealEnabled
                    ? () => setStateSB(() => obscure = !obscure)
                    : null,
              ),
            ),
            obscureText: obscure,
            onTap: () {
              if (isEdit && !cleared) {
                apiCtrl.clear();
                cleared = true;
                setStateSB(() => revealEnabled = true);
                apiFocus.requestFocus();
              }
            },
            onChanged: (v) {
              if (!revealEnabled) setStateSB(() => revealEnabled = true);
            },
          );
        }

        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                      labelText: l10n.nameLabel)),
              TextField(
                  controller: urlCtrl,
                  decoration: InputDecoration(
                      labelText: l10n.urlLabel)),
              apiFieldLocal(),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(errorText!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(c).pop(null),
                child: Text(l10n.cancel)),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      await validateAndClose();
                    },
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEdit
                      ? l10n.save
                      : l10n.add),
            ),
          ],
        );
      },
    ),
  );
}
