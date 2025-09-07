import 'package:flutter/material.dart';
import '../models/account_entry.dart';
import '../models/group_entry.dart';
import '../services/api_service.dart';
import 'dart:developer' as developer;

class EntryCreationService {
  // Parse otpauth URL and build AccountEntry
  static Future<AccountEntry?> parseOtpAuthUrl(
    String qrContent,
    BuildContext? context,
    {String sourceTag = 'EntryCreation'}
  ) async {
    try {
      final uri = Uri.parse(qrContent);
      if (uri.scheme != 'otpauth' || (uri.host != 'totp' && uri.host != 'hotp')) {
        throw Exception('Not a valid TOTP/HOTP QR code (expected otpauth://totp/ or hotp/)');
      }

      final otpType = uri.host.toLowerCase();
      final params = uri.queryParameters;

      // Log decoded URL and parsed fields (mask secret)
      try {
        String maskSecret(String s) {
          final key = 'secret=';
          final lower = s.toLowerCase();
          final idx = lower.indexOf(key);
          if (idx == -1) return s;
          final start = idx + key.length;
          var end = s.indexOf('&', start);
          if (end == -1) end = s.length;
          return '${s.substring(0, start)}***REDACTED***${s.substring(end)}';
        }
        final masked = maskSecret(uri.toString());
        developer.log('$sourceTag: decoded URL: $masked', name: sourceTag);
        developer.log('$sourceTag: parsed query fields: issuer=${params['issuer']}, label_query=${params['label']}, algorithm=${params['algorithm']}, digits=${params['digits']}, period=${params['period']}, counter=${params['counter']}', name: sourceTag);
      } catch (_) {
        developer.log('$sourceTag: logging failed', name: sourceTag);
      }

      // Extract secret (required)
      final secret = params['secret']?.trim();
      if (secret == null || secret.isEmpty || RegExp(r'^[A-Z2-7]+$').hasMatch(secret.toUpperCase()) == false) {
        throw Exception('Invalid or missing secret (must be uppercase Base32)');
      }

      // Parse label and issuer
      final issuer = params['issuer']?.trim() ?? '';
      String label = '';
      if (uri.path.isNotEmpty && uri.path != '/') {
        label = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
        try { label = Uri.decodeComponent(label); } catch (_) {}
      } else {
        label = params['label'] ?? '';
      }

      String service = issuer.isNotEmpty ? issuer : '';
      String account = label.trim();
      String group = ''; // No group for QR/image creates

      // If label contains colon and no issuer, split for service:account
      if (label.contains(':') && service.isEmpty) {
        final parts = label.split(':');
        service = parts.first.trim();
        account = parts.sublist(1).join(':').trim();
      }

      if (account.isEmpty) account = 'Unknown';
      if (service.isEmpty) {
        service = account.split('@').firstOrNull ?? account;
      }

      // Log final parsed values
      developer.log('$sourceTag: final parsed - service="$service" account="$account" group="$group"', name: sourceTag);

      // Defaults and params
      final algorithm = params['algorithm']?.toUpperCase() ?? 'SHA1';
      final digits = int.tryParse(params['digits'] ?? '6') ?? 6;
      
      // Usamos los campos correctos según el tipo
      int? period;
      int? counter;      if (otpType == 'hotp') {
        // Para HOTP usamos el campo counter
        counter = int.tryParse(params['counter'] ?? '0') ?? 0;
        developer.log('$sourceTag: HOTP counter value: $counter', name: sourceTag);
      } else {
        // Para TOTP usamos el campo period
        period = int.tryParse(params['period'] ?? '30') ?? 30;
      }

      // Build local entry
      var entry = AccountEntry(
        id: -1,
        service: service,
        account: account,
        seed: secret,
        group: group,
        groupId: null,
        otpType: otpType.toUpperCase(),
        icon: null,
        digits: digits,
        algorithm: algorithm,
        period: period,
        counter: counter,
        localIcon: null,
        synchronized: false,
      );

      return entry;
    } catch (e) {
      developer.log('$sourceTag: Parsing failed: $e', name: sourceTag);
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error parsing QR: $e'), backgroundColor: Colors.red),
        );
      }
      return null;
    }
  }

  // Attempt to create entry on server and return the server entry if successful
  static Future<AccountEntry?> createEntryOnServer(
    AccountEntry entry,
    {required String serverHost,
     List<GroupEntry>? groups,
     required BuildContext context,
     String sourceTag = 'EntryCreation'}) async {

    if (serverHost.isEmpty) {
      return entry; // No server host, return local entry
    }

    try {
      // Creamos un mapa para la API con los campos correctos según el tipo
      final Map<String, dynamic> payload = {
        'service': entry.service,
        'account': entry.account,
        'secret': entry.seed,
        'otp_type': entry.otpType ?? 'totp',
        if (entry.digits != null) 'digits': entry.digits,
        if (entry.algorithm != null) 'algorithm': entry.algorithm,
      };
      
      // Añadimos period o counter según el tipo
      if (entry.otpType?.toLowerCase() == 'hotp') {
        // Para HOTP, enviar counter
        if (entry.counter != null) {
          payload['counter'] = entry.counter;
        } else if (entry.period != null) {
          // Fallback a usar period como counter si no hay counter (compatibilidad)
          payload['counter'] = entry.period;
        } else {
          payload['counter'] = 0; // Valor predeterminado
        }
      } else {
        // Para TOTP, enviar period
        if (entry.period != null) {
          payload['period'] = entry.period;
        } else {
          payload['period'] = 30; // Valor predeterminado
        }
      }
      
      if (entry.groupId != null) {
        payload['group_id'] = entry.groupId;
      }      developer.log('$sourceTag: Attempting immediate create for ${entry.service} with type ${entry.otpType}', name: sourceTag);
      developer.log('$sourceTag: API payload: $payload', name: sourceTag);
      
      // Llamar directamente a createAccount en lugar de createAccountFromEntry
      // para evitar que el API siempre incluya period
      final response = await ApiService.instance.createAccount(payload);
      
      // On success, update with server data
      var serverEntry = AccountEntry.fromMap(response).copyWith(synchronized: true);
      
      // Populate group name if server returned group_id but not group
      if (serverEntry.group.isEmpty && serverEntry.groupId != null && groups != null) {
        final groupMatch = groups.firstWhere(
          (g) => g.id == serverEntry.groupId,
          orElse: () => GroupEntry(id: serverEntry.groupId!, name: '', twofaccountsCount: 0),
        );
        if (groupMatch.name.isNotEmpty) {
          serverEntry = serverEntry.copyWith(group: groupMatch.name);
        }
      }
      
      return serverEntry;
    } catch (e) {
      developer.log('$sourceTag: Immediate create failed: $e (keeping local unsynced)', name: sourceTag);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create on server: $e'), backgroundColor: Colors.orange),
        );
      }
      return entry; // Return the local entry on failure
    }
  }
  
  // Validate Base32 secret
  static bool isValidBase32(String secret) {
    final cleaned = secret.toUpperCase().replaceAll(RegExp(r'[^A-Z2-7]'), '');
    return RegExp(r'^[A-Z2-7]+$').hasMatch(cleaned);
  }
  
  // Build a manual entry from form data
  static AccountEntry buildManualEntry({
    required String service,
    required String account,
    required String secret,
    required String otpType,
    required int digits,
    required String algorithm,
    required int period, // Para TOTP es period, para HOTP puede ser el counter
    String group = '',
    int? groupId,
  }) {
    // Asignamos period o counter según el tipo
    int? actualPeriod;
    int? actualCounter;
    
    if (otpType.toUpperCase() == 'HOTP') {
      actualCounter = period >= 0 ? period : 0; // Usamos el parámetro period como counter
    } else {
      actualPeriod = period >= 1 ? period : 30; // Aseguramos que period sea al menos 1 para TOTP
    }

    return AccountEntry(
      id: -1,
      service: service,
      account: account,
      seed: secret,
      group: group,
      groupId: groupId,
      otpType: otpType.toUpperCase(),
      icon: null,
      digits: digits,
      algorithm: algorithm,
      period: actualPeriod,
      counter: actualCounter,
      localIcon: null,
      synchronized: false,
    );
  }
}
