import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/account_entry.dart';
import '../models/group_entry.dart';
import '../services/api_service.dart';
import '../services/entry_creation_service.dart';

class AdvancedFormScreen extends StatefulWidget {
  final String userEmail;
  final String serverHost;
  final List<GroupEntry>? groups;
  final AccountEntry? existingEntry; // For editing

  const AdvancedFormScreen({
    super.key,
    required this.userEmail,
    required this.serverHost,
    this.groups,
    this.existingEntry,
  });

  @override
  State<AdvancedFormScreen> createState() => _AdvancedFormScreenState();
}

class _AdvancedFormScreenState extends State<AdvancedFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serviceCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  String _selectedGroup = '- No group -';
  String _otpType = 'TOTP';
  // Advanced options state
  int _digits = 6;
  String _algorithm = 'sha1';
  final _periodCtrl = TextEditingController();
  final _counterCtrl = TextEditingController();
  bool _secretUnlocked =
      false; // State to control whether the secret is unlocked
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void dispose() {
    _serviceCtrl.dispose();
    _accountCtrl.dispose();
    _periodCtrl.dispose();
    _counterCtrl.dispose();
    _secretCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // If an existing entry is present, initialize fields with its values
    if (widget.existingEntry != null) {
      final entry = widget.existingEntry!;
      _serviceCtrl.text = entry.service;
      _accountCtrl.text = entry.account;
      _secretCtrl.text = entry.seed;

      // Configure the group
      if (entry.group.isNotEmpty) {
        _selectedGroup = entry.group;
      }

      // Configurar el tipo de OTP
      _otpType = entry.otpType?.toUpperCase() ?? 'TOTP';

      // Configurar opciones avanzadas
      _digits = entry.digits ?? 6;
      _algorithm = entry.algorithm?.toLowerCase() ?? 'sha1';

      // Configure period or counter according to the type
      if (_otpType == 'HOTP') {
        _counterCtrl.text = (entry.counter ?? 0).toString();
      } else {
        _periodCtrl.text = (entry.period ?? 30).toString();
      }

      // In edit mode, the secret starts locked
      _secretUnlocked = false;
    } else {
      // In create mode, the secret is always unlocked
      _secretUnlocked = true;
    }
  }

  Widget _buildOtpTypeButtons() {
    final isEditMode = widget.existingEntry != null;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed:
                isEditMode ? null : () => setState(() => _otpType = 'TOTP'),
            style: OutlinedButton.styleFrom(
                backgroundColor:
                    _otpType == 'TOTP' ? const Color(0xFF4F63E6) : null),
            child: Text(l10n.totpLabel,
                style: TextStyle(
                    color: _otpType == 'TOTP'
                        ? Colors.white
                        : (isEditMode ? Colors.grey : null))),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed:
                isEditMode ? null : () => setState(() => _otpType = 'HOTP'),
            style: OutlinedButton.styleFrom(
                backgroundColor:
                    _otpType == 'HOTP' ? const Color(0xFF4F63E6) : null),
            child: Text(l10n.hotpLabel,
                style: TextStyle(
                    color: _otpType == 'HOTP'
                        ? Colors.white
                        : (isEditMode ? Colors.grey : null))),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed:
                isEditMode ? null : () => setState(() => _otpType = 'STEAM'),
            style: OutlinedButton.styleFrom(
                backgroundColor:
                    _otpType == 'STEAM' ? const Color(0xFF4F63E6) : null),
            child: Text(l10n.steamLabel,
                style: TextStyle(
                    color: _otpType == 'STEAM'
                        ? Colors.white
                        : (isEditMode ? Colors.grey : null))),
          ),
        ),
      ],
    );
  }

  Widget _buildSecretField() {
    final isEditMode = widget.existingEntry != null;
    final canEdit = !isEditMode || _secretUnlocked;
    return TextFormField(
      controller: _secretCtrl,
      // Keep the field enabled so suffixIcon remains interactive; use readOnly to prevent editing when locked.
      enabled: true,
      readOnly: !canEdit,
      enableInteractiveSelection: canEdit,
    obscureText:
      isEditMode && !_secretUnlocked, // Hide text when it's locked
      decoration: InputDecoration(
        hintText: canEdit ? '' : l10n.secretLockedHint,
        filled: !canEdit,
        fillColor: !canEdit ? Colors.grey[100] : null,
        border: OutlineInputBorder(
          borderSide: BorderSide(
            color: !canEdit ? Colors.grey : Colors.blue,
          ),
        ),
        // Lock button moved inside the field as suffixIcon. It toggles visibility and editability.
        suffixIcon: isEditMode
            ? IconButton(
                icon: Icon(
                  _secretUnlocked ? Icons.lock_open : Icons.lock,
                  color: _secretUnlocked ? Colors.green : Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _secretUnlocked = !_secretUnlocked;
                    if (!_secretUnlocked) {
                      // When locking, clear the selection
                      _secretCtrl.selection =
                          TextSelection.collapsed(offset: 0);
                    }
                  });
                },
                tooltip: _secretUnlocked
                    ? 'Lock secret field'
                    : 'Unlock secret field',
              )
            : null,
      ),
      validator: (v) {
        final s = v?.trim() ?? '';
        if (s.isEmpty) return l10n.secretRequired;
        // Normalize by removing spaces but do NOT change case; Base32 must be uppercase
        final cleaned = s.replaceAll(' ', '');
        // Base32: letters A-Z and digits 2-7, optionally padded with '=' characters at the end
        final base32Regex = RegExp(r'^[A-Z2-7]+=*$');
        if (!base32Regex.hasMatch(cleaned)) {
          return l10n.secretBase32Error;
        }
        return null;
      },
    );
  }

  Widget _buildDigitsSelector() {
    return Row(
      children: [6, 7, 8, 9, 10].map((d) {
        final selected = _digits == d;
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: OutlinedButton(
            onPressed: () => setState(() => _digits = d),
            style: OutlinedButton.styleFrom(
                backgroundColor: selected ? const Color(0xFF4F63E6) : null),
            child: Text(d.toString(),
                style: TextStyle(color: selected ? Colors.white : null)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAlgorithmButtons() {
    final algs = ['sha1', 'sha256', 'sha512', 'md5'];
    return Row(
      children: algs.map((a) {
        final selected = _algorithm == a;
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: OutlinedButton(
            onPressed: () => setState(() => _algorithm = a),
            style: OutlinedButton.styleFrom(
                backgroundColor: selected ? const Color(0xFF4F63E6) : null),
            child: Text(a,
                style: TextStyle(color: selected ? Colors.white : null)),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title:
              Text(widget.existingEntry != null ? l10n.update : l10n.create)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.serviceLabel,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 20)),
                    TextFormField(
                      controller: _serviceCtrl,
                      decoration: InputDecoration(hintText: l10n.serviceHint),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? l10n.serviceRequired
                          : null,
                    ),
                    const SizedBox(height: 20),
                    Text(l10n.accountLabel,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 20)),
                    TextFormField(
                      controller: _accountCtrl,
                      decoration: InputDecoration(hintText: l10n.accountHint),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? l10n.accountRequired
                          : null,
                    ),
                    const SizedBox(height: 20),
                    Text(l10n.groupLabel,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 20)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedGroup,
                      items: [
                        DropdownMenuItem(
                            value: '- No group -',
                            child: Text(l10n.noGroupOption)),
                        if (widget.groups != null && widget.groups!.isNotEmpty)
                          ...widget.groups!
                              .where((g) =>
                                  !g.name.toLowerCase().startsWith('all'))
                              .map((g) => DropdownMenuItem(
                                  value: g.name, child: Text(g.name)))
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedGroup = v);
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.groupHint,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    Text(l10n.chooseOtpType,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 20)),
                    const SizedBox(height: 4),
                    Text(
                      l10n.otpTypeHint,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    _buildOtpTypeButtons(),

                    const SizedBox(height: 20),

                    // Secret and options depend on OTP type
                    if (_otpType == 'TOTP') ...[
                      Text(l10n.secretLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 20)),
                      _buildSecretField(),
                      const SizedBox(height: 4),
                      Text(
                        l10n.secretHint,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Text(l10n.optionsLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 20)),
                      const SizedBox(height: 4),
                      Text(l10n.optionsHint,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 12),
                      Text(l10n.digitsLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        l10n.digitsHint,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      _buildDigitsSelector(),
                      const SizedBox(height: 12),
                      Text(l10n.algorithmLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        l10n.algorithmHint,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      _buildAlgorithmButtons(),
                      const SizedBox(height: 12),
                      Text(l10n.periodLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                      const SizedBox(height: 8),
                      TextFormField(
                          controller: _periodCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              InputDecoration(hintText: l10n.periodDefaultHint),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            return int.tryParse(v.trim()) == null
                                ? l10n.periodDefaultHint
                                : null;
                          }),
                      const SizedBox(height: 4),
                      Text(
                        l10n.periodHint,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                    ] else if (_otpType == 'HOTP') ...[
                      Text(l10n.secretLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 20)),
                      _buildSecretField(),
                      const SizedBox(height: 4),
                      Text(
                        l10n.secretHint,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Text(l10n.optionsLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 20)),
                      const SizedBox(height: 4),
                      Text(l10n.optionsHint,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 12),
                      Text(l10n.digitsLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        l10n.digitsHint,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      _buildDigitsSelector(),
                      const SizedBox(height: 12),
                      Text(l10n.algorithmLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        l10n.algorithmHint,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      _buildAlgorithmButtons(),
                      const SizedBox(height: 12),
                      Text(l10n.counterLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                      const SizedBox(height: 8),
                      TextFormField(
                          controller: _counterCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              hintText: l10n.counterDefaultHint),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            return int.tryParse(v.trim()) == null
                                ? l10n.counterDefaultHint
                                : null;
                          }),
                      const SizedBox(height: 4),
                      Text(
                        l10n.counterHint,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                    ] else ...[
                      Text(l10n.secretLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 20)),
                      _buildSecretField(),
                      const SizedBox(height: 4),
                      Text(
                        l10n.secretLockedHint,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // Fixed bottom container with action buttons and user/host line
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: ElevatedButton(
                      onPressed: () async {
                        final ok = _formKey.currentState?.validate() ?? false;
                        if (!ok) return;
                    
                        // Determine the selected group ID (if any)
                        int? selectedGroupId;
                        if (_selectedGroup != '- No group -' &&
                            widget.groups != null) {
                          for (final g in widget.groups!) {
                            if (g.name == _selectedGroup) {
                              selectedGroupId = g.id;
                              break;
                            }
                          }
                        }
                    
                        final navigator = Navigator.of(context);
                    
                        if (widget.existingEntry != null) {
                          // EDIT: Update existing entry
                          final updatedEntry = widget.existingEntry!.copyWith(
                            service: _serviceCtrl.text.trim(),
                            account: _accountCtrl.text.trim(),
                            seed: _secretCtrl.text.trim(),
                            // Preserve the original icon unless the user explicitly changed it.
                            icon: widget.existingEntry?.icon,
                            group: _selectedGroup == '- No group -'
                                ? ''
                                : _selectedGroup,
                            groupId: selectedGroupId,
                            otpType: _otpType,
                            digits: _digits,
                            algorithm: _algorithm,
                            period: _otpType == 'HOTP'
                                ? null
                                : (_periodCtrl.text.trim().isEmpty
                                    ? 30
                                    : int.tryParse(_periodCtrl.text.trim()) ??
                                        30),
                            counter: _otpType == 'HOTP'
                                ? (_counterCtrl.text.trim().isEmpty
                                    ? 0
                                    : int.tryParse(_counterCtrl.text.trim()) ?? 0)
                                : null,
                            synchronized: false, // mark as unsynced by default
                          );
                    
                          developer.log(
                              'AdvancedForm: updated entry service=${updatedEntry.service} account=${updatedEntry.account} id=${updatedEntry.id}',
                              name: 'AdvancedForm');
                    
                          // Attempt immediate server update (silent on failure)
                          try {
                            final resp = await ApiService.instance
                                .updateAccountFromEntry(updatedEntry);
                            if (resp.containsKey('id')) {
                              // Preserve any locally cached icon file path so the UI
                              // continues showing the avatar until the sync process
                              // refreshes or re-downloads it.
                              var serverEntry = AccountEntry.fromMap(
                                      Map<dynamic, dynamic>.from(resp))
                                  .copyWith(
                                synchronized: true,
                                localIcon: widget.existingEntry?.localIcon,
                              );
                              developer.log(
                                  'AdvancedForm: updated on server id=${serverEntry.id}',
                                  name: 'AdvancedForm');
                              navigator.pop(serverEntry);
                              return;
                            } else {
                              developer.log(
                                  'AdvancedForm: server update returned unexpected payload, returning local unsynced entry',
                                  name: 'AdvancedForm');
                            }
                          } catch (e) {
                            try {
                              if (e is DioException) {
                                developer.log(
                                    'AdvancedForm: server update DioException status=${e.response?.statusCode} data=${e.response?.data}',
                                    name: 'AdvancedForm');
                              }
                            } catch (_) {}
                            developer.log(
                                'AdvancedForm: server update failed (ignored): $e',
                                name: 'AdvancedForm');
                          }
                    
                          // If we reach here, server update did not succeed — return local unsynced entry
                          navigator.pop(updatedEntry);
                        } else {
                          // CREATE: Create new entry
                          final entry = EntryCreationService.buildManualEntry(
                            service: _serviceCtrl.text.trim(),
                            account: _accountCtrl.text.trim(),
                            secret: _secretCtrl.text.trim(),
                            group: _selectedGroup == '- No group -'
                                ? ''
                                : _selectedGroup,
                            groupId: selectedGroupId,
                            otpType: _otpType,
                            digits: _digits,
                            algorithm: _algorithm,
                            period: _periodCtrl.text.trim().isEmpty
                                ? (_otpType == 'TOTP' ? 30 : 0)
                                : int.tryParse(_periodCtrl.text.trim()) ??
                                    (_otpType == 'TOTP' ? 30 : 0),
                          );
                    
                          developer.log(
                              'AdvancedForm: local entry created service=${entry.service} account=${entry.account} id=${entry.id} synchronized=${entry.synchronized}',
                              name: 'AdvancedForm');
                    
                          // Use our service to attempt server-side creation
                          developer.log(
                              'AdvancedForm: attempting immediate server create for service=${entry.service} account=${entry.account}',
                              name: 'AdvancedForm');
                    
                          try {
                            final serverEntry =
                                await EntryCreationService.createEntryOnServer(
                                    entry,
                                    serverHost: widget.serverHost,
                                    groups: widget.groups,
                                    context: context,
                                    sourceTag: 'AdvancedForm');
                    
                            if (serverEntry != null && serverEntry.synchronized) {
                              developer.log(
                                  'AdvancedForm: created on server id=${serverEntry.id}',
                                  name: 'AdvancedForm');
                              navigator.pop(serverEntry);
                              return;
                            } else {
                              developer.log(
                                  'AdvancedForm: server create returned no id, returning local entry',
                                  name: 'AdvancedForm');
                            }
                          } catch (e) {
                            try {
                              if (e is DioException) {
                                developer.log(
                                    'AdvancedForm: server create DioException status=${e.response?.statusCode} data=${e.response?.data}',
                                    name: 'AdvancedForm');
                              }
                            } catch (_) {}
                            developer.log(
                                'AdvancedForm: server create failed (ignored): $e',
                                name: 'AdvancedForm');
                          }
                    
                          developer.log(
                              'AdvancedForm: created local AccountEntry: ${entry.toMap()}',
                              name: 'AdvancedForm');
                          navigator.pop(entry);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        backgroundColor: const Color(0xFF4F63E6),
                        foregroundColor: Colors.white,
                      ),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20.0, vertical: 12.0),
                          child: Text(widget.existingEntry != null
                              ? l10n.update
                              : l10n.create)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 12.0),
                        child: Text(l10n.cancel)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                  child: Text(
                      l10n.userAtHost(widget.userEmail, widget.serverHost),
                      style: const TextStyle(color: Colors.grey))),
            ],
          ),
        ),
      ),
    );
  }
}
