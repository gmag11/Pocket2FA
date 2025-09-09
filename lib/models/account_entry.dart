// legacy model removed: use AccountEntry directly in UI

class AccountEntry {
  final int id;
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
  final int? counter; // counter for HOTP
  // Local-only path to the cached icon file. Not part of server model.
  final String? localIcon;
  // Whether this entry is synchronized with the server. True for accounts
  // received from the API; false for locally created unsynced accounts.
  final bool synchronized;
  final bool deleted;

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
    this.counter,
    this.localIcon,
    this.synchronized = true,
    this.deleted = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'service': service,
        'account': account,
        // API uses 'secret' but local model uses 'seed'
        'secret': seed,
        'group': group,
        'synchronized': synchronized,
        'deleted': deleted,
        if (groupId != null) 'group_id': groupId,
        if (otpType != null) 'otp_type': otpType,
        if (icon != null) 'icon': icon,
        if (digits != null) 'digits': digits,
        if (algorithm != null) 'algorithm': algorithm,
        if (period != null) 'period': period,
        if (counter != null) 'counter': counter,
        if (localIcon != null) 'local_icon': localIcon,
      };

  factory AccountEntry.fromMap(Map<dynamic, dynamic> m) => AccountEntry(
        id: m.containsKey('id') && m['id'] != null
            ? (m['id'] is int
                ? m['id'] as int
                : int.tryParse(m['id'].toString()) ?? 0)
            : 0,
        service: m['service']?.toString() ?? '',
        account: m['account']?.toString() ?? '',
        // accept both 'secret' (API) and 'seed' (legacy/local)
        seed: m['secret']?.toString() ?? m['seed']?.toString() ?? '',
        group: m['group']?.toString() ?? '',
        groupId: m.containsKey('group_id') && m['group_id'] != null
            ? (m['group_id'] is int
                ? m['group_id'] as int
                : int.tryParse(m['group_id'].toString()))
            : null,
        otpType: m['otp_type']?.toString(),
        icon: m['icon']?.toString(),
        digits: m.containsKey('digits') && m['digits'] != null
            ? (m['digits'] is int
                ? m['digits'] as int
                : int.tryParse(m['digits'].toString()))
            : null,
        algorithm: m['algorithm']?.toString(),
        period: m.containsKey('period') && m['period'] != null
            ? (m['period'] is int
                ? m['period'] as int
                : int.tryParse(m['period'].toString()))
            : null,
        counter: m.containsKey('counter') && m['counter'] != null
            ? (m['counter'] is int
                ? m['counter'] as int
                : int.tryParse(m['counter'].toString()))
            : null,
        localIcon: m['local_icon']?.toString(),
        // If the server provided the entry, consider it synchronized. If the
        // map explicitly contains a 'synchronized' value, respect it.
        synchronized: m.containsKey('synchronized')
            ? (m['synchronized'] == true ||
                m['synchronized']?.toString() == 'true')
            : true,
        deleted: m.containsKey('deleted')
            ? (m['deleted'] == true || m['deleted']?.toString() == 'true')
            : false,
      );

  // Legacy conversion removed: UI should use AccountEntry directly and generate OTPs dynamically.

  AccountEntry copyWith({
    int? id,
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
    bool? synchronized,
    bool? deleted,
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
      synchronized: synchronized ?? this.synchronized,
      deleted: deleted ?? this.deleted,
    );
  }
}
