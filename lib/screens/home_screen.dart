import 'package:flutter/material.dart';

const List<Map<String, String>> sampleItems = [
  {'service': 'Amazon', 'account': 'user+amazon@example.com', '2fa': '110 254', 'next_2fa': '165 719', 'group': 'Personal'},
  {'service': 'Anydesk', 'account': 'device-iPhone-15', '2fa': '630 542', 'next_2fa': '492 255', 'group': 'Devices'},
  {'service': 'Atlassian', 'account': 'user+atlassian@example.com', '2fa': '049 996', 'next_2fa': '531 958', 'group': 'Work'},
  {'service': 'Authelia', 'account': 'user_authelia', '2fa': '857 740', 'next_2fa': '108 089', 'group': 'Personal'},
  {'service': 'Authentik', 'account': 'admin', '2fa': '695 269', 'next_2fa': '346 987', 'group': 'Admin'},
  {'service': 'Authentik', 'account': 'user_auth', '2fa': '929 141', 'next_2fa': '416 287', 'group': 'Personal'},
  {'service': 'Autodesk', 'account': 'user+autodesk@example.com', '2fa': '921 253', 'next_2fa': '239 551', 'group': 'Work'},
  {'service': 'AWS SSO', 'account': 'user_aws', '2fa': '560 595', 'next_2fa': '091 891', 'group': 'Work'},
  {'service': 'BingX', 'account': 'user+bingx@example.com', '2fa': '540 784', 'next_2fa': '485 662', 'group': 'Personal'},
  {'service': 'GitHost', 'account': 'devops', '2fa': '541 678', 'next_2fa': '123 456', 'group': 'Work'},
  {'service': 'Dropbox', 'account': 'user+dropbox@example.com', '2fa': '312 450', 'next_2fa': '654 321', 'group': 'Personal'},
  {'service': 'Google', 'account': 'user+google@example.com', '2fa': '782 901', 'next_2fa': '888 777', 'group': 'Personal'},
  {'service': 'Microsoft', 'account': 'user+microsoft@example.com', '2fa': '450 120', 'next_2fa': '333 222', 'group': 'Work'},
  {'service': 'Facebook', 'account': 'user+facebook@example.com', '2fa': '223 334', 'next_2fa': '101 202', 'group': 'Personal'},
  {'service': 'Twitter', 'account': 'user+twitter@example.com', '2fa': '998 001', 'next_2fa': '909 808', 'group': 'Personal'},
  {'service': 'CustomApp', 'account': 'service_account', '2fa': '010 203', 'next_2fa': '010 011', 'group': 'Admin'},
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _selectedGroup = 'All';
  String _searchQuery = '';
  late final TextEditingController _searchController;
  late final FocusNode _searchFocus;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocus = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<String> _groups() {
    final Map<String, int> counts = {};
    for (final item in sampleItems) {
      final g = item['group'] ?? 'Ungrouped';
      counts[g] = (counts[g] ?? 0) + 1;
    }
    final groups = ['All (${sampleItems.length})'];
    groups.addAll(counts.keys.map((k) => '$k (${counts[k]})'));
    return groups;
  }

  String _groupKey(String display) {
    // Convert 'Work (4)' -> 'Work', 'All (71)' -> 'All'
    final idx = display.indexOf(' (');
    if (idx == -1) return display;
    return display.substring(0, idx);
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _SearchBar(
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            const SizedBox(height: 8),
            // Group selector
            Center(
              child: PopupMenuButton<String>(
                initialValue: _selectedGroup,
                onSelected: (value) {
                  setState(() {
                    _selectedGroup = value;
                  });
                },
                itemBuilder: (context) => groups
                    .map((g) => PopupMenuItem(value: g, child: Text(g)))
                    .toList(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_selectedGroup, style: TextStyle(color: Colors.grey.shade700)),
                    const SizedBox(width: 6),
                    Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey.shade600),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _AccountList(selectedGroup: _groupKey(_selectedGroup), searchQuery: _searchQuery)),
            const _BottomBar(),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  const _SearchBar({this.controller, this.focusNode, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Search',
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountList extends StatelessWidget {
  final String selectedGroup;
  final String searchQuery;

  const _AccountList({required this.selectedGroup, this.searchQuery = ''});

  @override
  Widget build(BuildContext context) {
  final base = selectedGroup == 'All' || selectedGroup.isEmpty
    ? sampleItems
    : sampleItems.where((i) => (i['group'] ?? '') == selectedGroup).toList();

  final query = searchQuery.trim().toLowerCase();
  final filtered = query.isEmpty
    ? base
    : base.where((i) {
      final s = (i['service'] ?? '').toLowerCase();
      final a = (i['account'] ?? '').toLowerCase();
      return s.contains(query) || a.contains(query);
      }).toList();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemBuilder: (context, index) {
        final item = filtered[index % filtered.length];
        return _AccountTile(
          service: item['service']!,
          account: item['account']!,
          twoFa: item['2fa']!,
          nextTwoFa: item['next_2fa'] ?? '',
        );
      },
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72, endIndent: 12),
      itemCount: filtered.length,
    );
  }
}

class _AccountTile extends StatelessWidget {
  final String service;
  final String account;
  final String twoFa;
  final String nextTwoFa;

  const _AccountTile({required this.service, required this.account, required this.twoFa, required this.nextTwoFa});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 12),
          _IconCircle(label: service),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(account, style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(twoFa, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(nextTwoFa, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    const SizedBox(width: 8),
                    Row(
                      children: List.generate(10, (i) {
                        final Color dotColor = i < 6
                            ? Colors.green.shade400
                            : (i < 9 ? Colors.amber.shade600 : Colors.red.shade400);
                        return Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            color: dotColor,
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  final String label;
  const _IconCircle({required this.label});

  @override
  Widget build(BuildContext context) {
    final color = Colors.primaries[label.length % Colors.primaries.length];
    return CircleAvatar(
      radius: 28,
      backgroundColor: color.shade100,
      child: Text(label.characters.first, style: TextStyle(color: color.shade900, fontWeight: FontWeight.bold)),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.add),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  backgroundColor: Colors.indigo,
                ),
                label: const Text('New'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: null,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Manage'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.person_outline, size: 18, color: Colors.grey),
              SizedBox(width: 8),
              Text('gmartin@gmartin.net', style: TextStyle(color: Colors.grey)),
              SizedBox(width: 6),
              Icon(Icons.more_vert, size: 18, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }
}
