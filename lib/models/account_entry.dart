class AccountEntry {
  final String id;
  final String service;
  final String account;
  final String seed; // secret for TOTP (sample only)
  final String group;

  AccountEntry({required this.id, required this.service, required this.account, required this.seed, required this.group});

  Map<String, dynamic> toMap() => {
        'id': id,
        'service': service,
        'account': account,
        'seed': seed,
        'group': group,
      };

  factory AccountEntry.fromMap(Map<dynamic, dynamic> m) => AccountEntry(
        id: m['id'] as String,
        service: m['service'] as String,
        account: m['account'] as String,
        seed: m['seed'] as String,
        group: m['group'] as String,
      );
}
