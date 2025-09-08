import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import '../models/account_entry.dart';
import '../models/group_entry.dart';
import '../services/entry_creation_service.dart';

class AdvancedFormScreen extends StatefulWidget {
  final String userEmail;
  final String serverHost;
  final List<GroupEntry>? groups;
  final AccountEntry? existingEntry; // Para edición

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
    
    // Si hay una entrada existente, inicializar los campos con sus valores
    if (widget.existingEntry != null) {
      final entry = widget.existingEntry!;
      _serviceCtrl.text = entry.service;
      _accountCtrl.text = entry.account;
      _secretCtrl.text = entry.seed;
      
      // Configurar el grupo
      if (entry.group.isNotEmpty) {
        _selectedGroup = entry.group;
      }
      
      // Configurar el tipo de OTP
      _otpType = entry.otpType?.toUpperCase() ?? 'TOTP';
      
      // Configurar opciones avanzadas
      _digits = entry.digits ?? 6;
      _algorithm = entry.algorithm?.toLowerCase() ?? 'sha1';
      
      // Configurar period o counter según el tipo
      if (_otpType == 'HOTP') {
        _counterCtrl.text = (entry.counter ?? 0).toString();
      } else {
        _periodCtrl.text = (entry.period ?? 30).toString();
      }
    }
  }

  Widget _buildOtpTypeButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => setState(() => _otpType = 'TOTP'),
            style: OutlinedButton.styleFrom(
                backgroundColor:
                    _otpType == 'TOTP' ? const Color(0xFF4F63E6) : null),
            child: Text('TOTP',
                style:
                    TextStyle(color: _otpType == 'TOTP' ? Colors.white : null)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () => setState(() => _otpType = 'HOTP'),
            style: OutlinedButton.styleFrom(
                backgroundColor:
                    _otpType == 'HOTP' ? const Color(0xFF4F63E6) : null),
            child: Text('HOTP',
                style:
                    TextStyle(color: _otpType == 'HOTP' ? Colors.white : null)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () => setState(() => _otpType = 'STEAM'),
            style: OutlinedButton.styleFrom(
                backgroundColor:
                    _otpType == 'STEAM' ? const Color(0xFF4F63E6) : null),
            child: Text('STEAM',
                style: TextStyle(
                    color: _otpType == 'STEAM' ? Colors.white : null)),
          ),
        ),
      ],
    );
  }

  Widget _buildSecretField() {
    return TextFormField(
      controller: _secretCtrl,
      decoration: const InputDecoration(hintText: ''),
      validator: (v) {
        final s = v?.trim() ?? '';
        if (s.isEmpty) return 'Secret is required';
        // Normalize by removing spaces but do NOT change case; Base32 must be uppercase
        final cleaned = s.replaceAll(' ', '');
        // Base32: letters A-Z and digits 2-7, optionally padded with '=' characters at the end
        final base32Regex = RegExp(r'^[A-Z2-7]+=*$');
        if (!base32Regex.hasMatch(cleaned)) {
          return 'Secret must be Base32 (uppercase letters A-Z and digits 2-7)';
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
      appBar: AppBar(title: Text(widget.existingEntry != null ? 'Edit account' : 'New account')),
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
                    const Text('Service',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 20)),
                    TextFormField(
                      controller: _serviceCtrl,
                      decoration: const InputDecoration(
                          hintText: 'Google, Twitter, Apple'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Service is required' : null,
                    ),
                    const SizedBox(height: 20),
                    const Text('Account',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 20)),
                    TextFormField(
                      controller: _accountCtrl,
                      decoration: const InputDecoration(hintText: 'John DOE'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Account is required' : null,
                    ),
                    const SizedBox(height: 20),
                    const Text('Group',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 20)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedGroup,
                      items: [
                        const DropdownMenuItem(value: '- No group -', child: Text('- No group -')),
                        if (widget.groups != null && widget.groups!.isNotEmpty) ...widget.groups!
                            .where((g) => !g.name.toLowerCase().startsWith('all'))
                            .map((g) => DropdownMenuItem(value: g.name, child: Text(g.name)))
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedGroup = v);
                      },
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'The group to which the account is to be assigned',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    const Text('Choose the type of OTP to create',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 20)),
                    const SizedBox(height: 4),
                    const Text(
                      'Time-based OTP or HMAC-based OTP or Steam OTP',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    _buildOtpTypeButtons(),

                    const SizedBox(height: 20),

                    // Secret and options depend on OTP type
                    if (_otpType == 'TOTP') ...[
                      const Text('Secret',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 20)),
                      _buildSecretField(),
                      const SizedBox(height: 4),
                      const Text(
                        'The key used to generate your security codes',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      const Text('Options',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 20)),
                      const SizedBox(height: 4),
                      const Text(
                          'You can leave the following options blank if you don\'t know how to set them.\nThe most commonly used values will be applied.',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 12),
                      const Text('Digits',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                      const SizedBox(height: 4),
                      const Text(
                        'The number of digits of the generated security codes',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      _buildDigitsSelector(),
                      const SizedBox(height: 12),
                      const Text('Algorithm',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                      const SizedBox(height: 4),
                      const Text(
                        'The algorithm used to secure your security codes',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      _buildAlgorithmButtons(),
                      const SizedBox(height: 12),
                      const Text('Period',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                      const SizedBox(height: 8),
                      TextFormField(
                          controller: _periodCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(hintText: 'Default is 30'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            return int.tryParse(v.trim()) == null ? 'Period must be a number' : null;
                          }),
                      const SizedBox(height: 4),
                      const Text(
                        'The period of validity of the generated security codes in second',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                    ] else if (_otpType == 'HOTP') ...[
                      const Text('Secret',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 20)),
                      _buildSecretField(),
                      const SizedBox(height: 4),
                      const Text(
                        'The key used to generate your security codes',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      const Text('Options',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 20)),
                      const SizedBox(height: 4),
                      const Text(
                          'You can leave the following options blank if you don\'t know how to set them.\nThe most commonly used values will be applied.',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 12),
                      const Text('Digits',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      const SizedBox(height: 4),
                      const Text(
                        'The number of digits of the generated security codes',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      _buildDigitsSelector(),
                      const SizedBox(height: 12),
                      const Text('Algorithm',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                     const SizedBox(height: 4),
                      const Text(
                        'The algorithm used to secure your security codes',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      _buildAlgorithmButtons(),
                      const SizedBox(height: 12),
                      const Text('Counter',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      const SizedBox(height: 8),
                      TextFormField(
                          controller: _counterCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(hintText: 'Default is 0'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            return int.tryParse(v.trim()) == null ? 'Counter must be a number' : null;
                          }),
                              const SizedBox(height: 4),
                      const Text(
                        'The initial counter value',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                    ] else ...[
                      const Text('Secret',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 20)),
                      _buildSecretField(),
                      const SizedBox(height: 4),
                      const Text(
                        'The key used to generate your security codes',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
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
        minimum: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      final ok = _formKey.currentState?.validate() ?? false;
                      if (!ok) return;
                      
                      // Determinar el ID del grupo seleccionado (si hay alguno)
                      int? selectedGroupId;
                      if (_selectedGroup != '- No group -' && widget.groups != null) {
                        for (final g in widget.groups!) {
                          if (g.name == _selectedGroup) {
                            selectedGroupId = g.id;
                            break;
                          }
                        }
                      }

                      final navigator = Navigator.of(context);
                      
                      if (widget.existingEntry != null) {
                        // EDICIÓN: Actualizar entrada existente
                        final updatedEntry = widget.existingEntry!.copyWith(
                          service: _serviceCtrl.text.trim(),
                          account: _accountCtrl.text.trim(),
                          seed: _secretCtrl.text.trim(),
                          group: _selectedGroup == '- No group -' ? '' : _selectedGroup,
                          groupId: selectedGroupId,
                          otpType: _otpType,
                          digits: _digits,
                          algorithm: _algorithm,
                          period: _otpType == 'HOTP' ? null : 
                            (_periodCtrl.text.trim().isEmpty ? 30 : 
                            int.tryParse(_periodCtrl.text.trim()) ?? 30),
                          counter: _otpType == 'HOTP' ? 
                            (_counterCtrl.text.trim().isEmpty ? 0 : 
                            int.tryParse(_counterCtrl.text.trim()) ?? 0) : null,
                          synchronized: false, // Marcar como no sincronizado después de editar
                        );

                        developer.log('AdvancedForm: updated entry service=${updatedEntry.service} account=${updatedEntry.account} id=${updatedEntry.id}', name: 'AdvancedForm');
                        navigator.pop(updatedEntry);
                      } else {
                        // CREACIÓN: Crear nueva entrada
                        final entry = EntryCreationService.buildManualEntry(
                          service: _serviceCtrl.text.trim(),
                          account: _accountCtrl.text.trim(),
                          secret: _secretCtrl.text.trim(),
                          group: _selectedGroup == '- No group -' ? '' : _selectedGroup,
                          groupId: selectedGroupId,
                          otpType: _otpType,
                          digits: _digits,
                          algorithm: _algorithm,
                          period: _periodCtrl.text.trim().isEmpty ? 
                            (_otpType == 'TOTP' ? 30 : 0) : 
                            int.tryParse(_periodCtrl.text.trim()) ?? (_otpType == 'TOTP' ? 30 : 0),
                        );

                        developer.log('AdvancedForm: local entry created service=${entry.service} account=${entry.account} id=${entry.id} synchronized=${entry.synchronized}', name: 'AdvancedForm');

                        // Usar nuestro servicio para intentar crear en el servidor
                        developer.log('AdvancedForm: attempting immediate server create for service=${entry.service} account=${entry.account}', name: 'AdvancedForm');
                        
                        try {
                          final serverEntry = await EntryCreationService.createEntryOnServer(
                            entry,
                            serverHost: widget.serverHost,
                            groups: widget.groups,
                            context: context,
                            sourceTag: 'AdvancedForm'
                          );
                          
                          if (serverEntry != null && serverEntry.synchronized) {
                            developer.log('AdvancedForm: created on server id=${serverEntry.id}', name: 'AdvancedForm');
                            navigator.pop(serverEntry);
                            return;
                          } else {
                            developer.log('AdvancedForm: server create returned no id, returning local entry', name: 'AdvancedForm');
                          }
                        } catch (e) {
                          try {
                            if (e is DioException) {
                              developer.log('AdvancedForm: server create DioException status=${e.response?.statusCode} data=${e.response?.data}', name: 'AdvancedForm');
                            }
                          } catch (_) {}
                          developer.log('AdvancedForm: server create failed (ignored): $e', name: 'AdvancedForm');
                        }

                        developer.log('AdvancedForm: created local AccountEntry: ${entry.toMap()}', name: 'AdvancedForm');
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
                        child: Text(widget.existingEntry != null ? 'Update' : 'Create')),
                  ),
                  const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16.0, vertical: 12.0),
              child: Text('Cancel')),
          ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                  child: Text('${widget.userEmail} - ${widget.serverHost}',
                      style: const TextStyle(color: Colors.grey))),
            ],
          ),
        ),
      ),
    );
  }
}
