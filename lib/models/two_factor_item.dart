class Pocket2FA {
  final String service;
  final String account;
  final String twoFa;
  final String nextTwoFa;
  final String group;
  // Optional local file path for a cached icon. If present the UI should show it.
  final String? localIcon;

  const Pocket2FA({required this.service, required this.account, required this.twoFa, required this.nextTwoFa, required this.group, this.localIcon});

  factory Pocket2FA.fromMap(Map<String, String> m) => Pocket2FA(
    service: m['service'] ?? '',
    account: m['account'] ?? '',
    twoFa: m['2fa'] ?? '',
    nextTwoFa: m['next_2fa'] ?? '',
    group: m['group'] ?? '',
    localIcon: m['local_icon'],
  );

  Map<String, String?> toMap() => {
    'service': service,
    'account': account,
    '2fa': twoFa,
    'next_2fa': nextTwoFa,
    'group': group,
    'local_icon': localIcon,
  };
}
