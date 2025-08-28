// legacy model removed: use AccountEntry directly in UI

class AccountEntry {
  final String id;
  final String service;
  final String account;
  final String seed; // secret for TOTP (sample only) - maps to API 'secret'
  final String group;

  // Additional fields returned by GET /twofaccounts
  final int? groupId; // maps to 'group_id'
  final String? otpType; // maps to 'otp_type' (eg. totp/hotp)
  final String? icon; // filename or identifier for an icon
  final int? digits; // number of digits in OTP
  final String? algorithm; // hashing algorithm, e.g. sha1
  final int? period; // time step for TOTP
  // final int? counter; // counter for HOTP
  // Local-only path to the cached icon file. Not part of server model.
  final String? localIcon;

  AccountEntry({
    required this.id,
    required this.service,
    required this.account,
    required this.seed,
    required this.group,
    this.groupId,
    this.otpType,
    this.icon,
    this.digits,
    this.algorithm,
    this.period,
    // this.counter,
    this.localIcon,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'service': service,
        'account': account,
        // API uses 'secret' but local model uses 'seed'
        'secret': seed,
        'group': group,
        if (groupId != null) 'group_id': groupId,
        if (otpType != null) 'otp_type': otpType,
        if (icon != null) 'icon': icon,
        if (digits != null) 'digits': digits,
        if (algorithm != null) 'algorithm': algorithm,
        if (period != null) 'period': period,
        // if (counter != null) 'counter': counter,
  if (localIcon != null) 'local_icon': localIcon,
      };

  factory AccountEntry.fromMap(Map<dynamic, dynamic> m) => AccountEntry(
        id: (m['id'] is String) ? m['id'] as String : (m['id']?.toString() ?? ''),
        service: m['service']?.toString() ?? '',
        account: m['account']?.toString() ?? '',
        // accept both 'secret' (API) and 'seed' (legacy/local)
        seed: m['secret']?.toString() ?? m['seed']?.toString() ?? '',
        group: m['group']?.toString() ?? '',
        groupId: m.containsKey('group_id') && m['group_id'] != null ? (m['group_id'] is int ? m['group_id'] as int : int.tryParse(m['group_id'].toString())) : null,
        otpType: m['otp_type']?.toString(),
        icon: m['icon']?.toString(),
        digits: m.containsKey('digits') && m['digits'] != null ? (m['digits'] is int ? m['digits'] as int : int.tryParse(m['digits'].toString())) : null,
        algorithm: m['algorithm']?.toString(),
        period: m.containsKey('period') && m['period'] != null ? (m['period'] is int ? m['period'] as int : int.tryParse(m['period'].toString())) : null,
        // counter: m.containsKey('counter') && m['counter'] != null ? (m['counter'] is int ? m['counter'] as int : int.tryParse(m['counter'].toString())) : null,
        localIcon: m['local_icon']?.toString(),
      );

  // Legacy conversion removed: UI should use AccountEntry directly and generate OTPs dynamically.

  AccountEntry copyWith({
    String? id,
    String? service,
    String? account,
    String? seed,
    String? group,
    int? groupId,
    String? otpType,
    String? icon,
    int? digits,
    String? algorithm,
    int? period,
    int? counter,
    String? localIcon,
  }) {
    return AccountEntry(
      id: id ?? this.id,
      service: service ?? this.service,
      account: account ?? this.account,
      seed: seed ?? this.seed,
      group: group ?? this.group,
      groupId: groupId ?? this.groupId,
      otpType: otpType ?? this.otpType,
      icon: icon ?? this.icon,
      digits: digits ?? this.digits,
      algorithm: algorithm ?? this.algorithm,
      period: period ?? this.period,
      // counter: counter ?? this.counter,
      localIcon: localIcon ?? this.localIcon,
    );
  }
}
