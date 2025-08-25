class TwoFactorItem {
  final String service;
  final String account;
  final String twoFa;
  final String nextTwoFa;
  final String group;

  const TwoFactorItem({required this.service, required this.account, required this.twoFa, required this.nextTwoFa, required this.group});

  factory TwoFactorItem.fromMap(Map<String, String> m) => TwoFactorItem(
    service: m['service'] ?? '',
    account: m['account'] ?? '',
    twoFa: m['2fa'] ?? '',
    nextTwoFa: m['next_2fa'] ?? '',
    group: m['group'] ?? '',
  );

  Map<String, String> toMap() => {
    'service': service,
    'account': account,
    '2fa': twoFa,
    'next_2fa': nextTwoFa,
    'group': group,
  };
}
