import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import '../models/group_entry.dart';
import '../models/account_entry.dart';
import '../services/api_service.dart';

class AdvancedFormScreen extends StatefulWidget {
  final String userEmail;
  final String serverHost;
  final List<GroupEntry>? groups;

  const AdvancedFormScreen(
      {super.key,
      required this.userEmail,
      required this.serverHost,
      this.groups});

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
  // Default to no group selected. The dropdown will show '- No group -' by default.
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
      appBar: AppBar(title: const Text('New account')),
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
                      // Determine the selected group's id (if any)
                      int? selectedGroupId;
                      if (_selectedGroup != '- No group -' && widget.groups != null) {
                        for (final g in widget.groups!) {
                          if (g.name == _selectedGroup) {
                            selectedGroupId = g.id;
                            break;
                          }
                        }
                      }

                      // Build AccountEntry with id -1 to mark unsynced initially
                      final entry = AccountEntry(
                        id: -1,
                        service: _serviceCtrl.text.trim(),
                        account: _accountCtrl.text.trim(),
                        seed: _secretCtrl.text.trim(),
                        group: _selectedGroup == '- No group -' ? '' : _selectedGroup,
                        groupId: selectedGroupId,
                        otpType: _otpType.toLowerCase(),
                        icon: null,
                        digits: _digits,
                        algorithm: _algorithm,
                        period: _periodCtrl.text.trim().isEmpty ? null : int.tryParse(_periodCtrl.text.trim()),
                        localIcon: null,
                        synchronized: false,
                      );

                      // Log creation of local entry (redact secret)
                      try {
                        developer.log('AdvancedForm: local entry created service=${entry.service} account=${entry.account} id=${entry.id} synchronized=${entry.synchronized}', name: 'AdvancedForm');
                      } catch (_) {}

                      // Attempt to create on server immediately. If ApiService is
                      // configured and the call succeeds, use the returned
                      // representation (with server id) and mark synchronized=true.
                      // If it fails, swallow the error and keep the local unsynced entry.
                      developer.log('AdvancedForm: attempting immediate server create for service=${entry.service} account=${entry.account}', name: 'AdvancedForm');
                      final navigator = Navigator.of(context);
                      try {
                        final resp = await ApiService.instance.createAccountFromEntry(entry, groupId: entry.groupId);
                        if (resp.containsKey('id')) {
                          final created = AccountEntry.fromMap(Map<dynamic, dynamic>.from(resp)).copyWith(synchronized: true);
                          developer.log('AdvancedForm: created on server id=${created.id}', name: 'AdvancedForm');
                          navigator.pop(created);
                          return;
                        } else {
                          developer.log('AdvancedForm: server create returned no id, returning local entry', name: 'AdvancedForm');
                        }
                      } catch (e) {
                        // Log response details when available (DioException may contain server response)
                        try {
                          if (e is DioException) {
                            developer.log('AdvancedForm: server create DioException status=${e.response?.statusCode} data=${e.response?.data}', name: 'AdvancedForm');
                          }
                        } catch (_) {}
                        developer.log('AdvancedForm: server create failed (ignored): $e', name: 'AdvancedForm');
                        // ignore and fallback to returning the local unsynced entry
                      }

                      developer.log('AdvancedForm: created local AccountEntry: ${entry.toMap()}', name: 'AdvancedForm');
                      navigator.pop(entry);
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                      backgroundColor: const Color(0xFF4F63E6),
                      foregroundColor: Colors.white,
                    ),
                    child: const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 20.0, vertical: 12.0),
                        child: Text('Create')),
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
