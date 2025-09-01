import 'package:flutter/material.dart';
import '../models/group_entry.dart';

class AdvancedFormScreen extends StatefulWidget {
  final String userEmail;
  final String serverHost;
  final List<GroupEntry>? groups;

  const AdvancedFormScreen({Key? key, required this.userEmail, required this.serverHost, this.groups}) : super(key: key);

  @override
  State<AdvancedFormScreen> createState() => _AdvancedFormScreenState();
}

class _AdvancedFormScreenState extends State<AdvancedFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serviceCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  String _selectedIconCollection = 'selfh.st';
  String _iconStyle = 'Regular';
  String _selectedGroup = '- No group -';
  String _otpType = 'TOTP';

  @override
  void dispose() {
    _serviceCtrl.dispose();
    _accountCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.groups != null && widget.groups!.isNotEmpty) {
      _selectedGroup = widget.groups!.first.name;
    }
  }

  Widget _buildIconRow() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            decoration: const InputDecoration(labelText: 'Icon', hintText: 'selfh.st'),
            initialValue: _selectedIconCollection,
            onChanged: (v) => _selectedIconCollection = v,
          ),
        ),
        const SizedBox(width: 12),
        DropdownButton<String>(
          value: _iconStyle,
          items: const [
            DropdownMenuItem(value: 'Regular', child: Text('Regular')),
            DropdownMenuItem(value: 'Round', child: Text('Round')),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => _iconStyle = v);
          },
        ),
      ],
    );
  }

  Widget _buildOtpTypeButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => setState(() => _otpType = 'TOTP'),
            child: Text('TOTP', style: TextStyle(color: _otpType == 'TOTP' ? Colors.white : null)),
            style: OutlinedButton.styleFrom(backgroundColor: _otpType == 'TOTP' ? const Color(0xFF4F63E6) : null),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () => setState(() => _otpType = 'HOTP'),
            child: Text('HOTP', style: TextStyle(color: _otpType == 'HOTP' ? Colors.white : null)),
            style: OutlinedButton.styleFrom(backgroundColor: _otpType == 'HOTP' ? const Color(0xFF4F63E6) : null),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () => setState(() => _otpType = 'STEAM'),
            child: Text('STEAM', style: TextStyle(color: _otpType == 'STEAM' ? Colors.white : null)),
            style: OutlinedButton.styleFrom(backgroundColor: _otpType == 'STEAM' ? const Color(0xFF4F63E6) : null),
          ),
        ),
      ],
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
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.qr_code),
                label: const Text('Prefill using a QR Code'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
              ),
              const SizedBox(height: 16),

              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Service', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
                    TextFormField(
                      controller: _serviceCtrl,
                      decoration: const InputDecoration(hintText: 'Google, Twitter, Apple'),
                    ),
                    const SizedBox(height: 20),
                    const Text('Account', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
                    TextFormField(
                      controller: _accountCtrl,
                      decoration: const InputDecoration(hintText: 'John DOE'),
                    ),
                    const SizedBox(height: 20),
                    const Text('Group', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedGroup,
                      items: (
                        (widget.groups != null && widget.groups!.isNotEmpty)
                        ? [DropdownMenuItem(value: '- No group -', child: const Text('- No group -'))] + widget.groups!.map((g) => DropdownMenuItem(value: g.name, child: Text(g.name))).toList()
                        : [const DropdownMenuItem(value: '- No group -', child: Text('- No group -'))]
                      ),
                      onChanged: (v) { if (v != null) setState(() => _selectedGroup = v); },
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'The group to which the account is to be assigned',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    const Text('Choose the type of OTP to create', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
                    const SizedBox(height: 4),
                    const Text(
                      'Time-based OTP or HMAC-based OTP or Steam OTP',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    _buildOtpTypeButtons(),
                    const SizedBox(height: 20),
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
          decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? true) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create not implemented')));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      backgroundColor: const Color(0xFF4F63E6),
                      foregroundColor: Colors.white,
                    ),
                    child: const Padding(padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0), child: Text('Create')),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), child: Text('Cancel')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(child: Text('${widget.userEmail} - ${widget.serverHost}', style: const TextStyle(color: Colors.grey))),
            ],
          ),
        ),
      ),
    );
  }
}
