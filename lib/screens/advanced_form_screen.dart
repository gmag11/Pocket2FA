import 'package:flutter/material.dart';
import '../models/group_entry.dart';

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
                    ),
                    const SizedBox(height: 20),
                    const Text('Account',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 20)),
                    TextFormField(
                      controller: _accountCtrl,
                      decoration: const InputDecoration(hintText: 'John DOE'),
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
                      TextFormField(
                        decoration: const InputDecoration(hintText: ''),
                      ),
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
                          decoration:
                              const InputDecoration(hintText: 'Default is 30')),
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
                      TextFormField(
                        decoration: const InputDecoration(hintText: ''),
                      ),
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
                          decoration:
                              const InputDecoration(hintText: 'Default is 0')),
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
                      TextFormField(
                        decoration: const InputDecoration(hintText: ''),
                      ),
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
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Create not implemented')));
                      }
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
