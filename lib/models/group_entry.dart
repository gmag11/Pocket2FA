class GroupEntry {
  final int id;
  final String name;
  final int twofaccountsCount;

  GroupEntry(
      {required this.id, required this.name, required this.twofaccountsCount});

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'twofaccounts_count': twofaccountsCount,
      };

  factory GroupEntry.fromMap(Map<dynamic, dynamic> m) => GroupEntry(
        id: m['id'] is int
            ? m['id'] as int
            : int.tryParse(m['id']?.toString() ?? '') ?? 0,
        name: m['name']?.toString() ?? '',
        twofaccountsCount: m.containsKey('twofaccounts_count') &&
                m['twofaccounts_count'] != null
            ? (m['twofaccounts_count'] is int
                ? m['twofaccounts_count'] as int
                : int.tryParse(m['twofaccounts_count'].toString()) ?? 0)
            : 0,
      );

  @override
  String toString() =>
      'GroupEntry(id: $id, name: $name, twofaccountsCount: $twofaccountsCount)';
}
