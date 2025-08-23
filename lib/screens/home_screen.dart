import 'package:flutter/material.dart';
import '../models/two_factor_item.dart';
import '../widgets/account_tile.dart';

final List<TwoFactorItem> sampleItems = [
  TwoFactorItem(service: 'Amazon', account: 'user+amazon@example.com', twoFa: '110 254', nextTwoFa: '165 719', group: 'Personal'),
  TwoFactorItem(service: 'Anydesk', account: 'device-iPhone-15', twoFa: '630 542', nextTwoFa: '492 255', group: 'Devices'),
  TwoFactorItem(service: 'Atlassian', account: 'user+atlassian@example.com', twoFa: '049 996', nextTwoFa: '531 958', group: 'Work'),
  TwoFactorItem(service: 'Authelia', account: 'user_authelia', twoFa: '857 740', nextTwoFa: '108 089', group: 'Personal'),
  TwoFactorItem(service: 'Authentik', account: 'admin', twoFa: '695 269', nextTwoFa: '346 987', group: 'Admin'),
  TwoFactorItem(service: 'Authentik', account: 'user_auth', twoFa: '929 141', nextTwoFa: '416 287', group: 'Personal'),
  TwoFactorItem(service: 'Autodesk', account: 'user+autodesk@example.com', twoFa: '921 253', nextTwoFa: '239 551', group: 'Work'),
  TwoFactorItem(service: 'AWS SSO', account: 'user_aws', twoFa: '560 595', nextTwoFa: '091 891', group: 'Work'),
  TwoFactorItem(service: 'BingX', account: 'user+bingx@example.com', twoFa: '540 784', nextTwoFa: '485 662', group: 'Personal'),
  TwoFactorItem(service: 'GitHost', account: 'devops', twoFa: '541 678', nextTwoFa: '123 456', group: 'Work'),
  TwoFactorItem(service: 'Dropbox', account: 'user+dropbox@example.com', twoFa: '312 450', nextTwoFa: '654 321', group: 'Personal'),
  TwoFactorItem(service: 'Google', account: 'user+google@example.com', twoFa: '782 901', nextTwoFa: '888 777', group: 'Personal'),
  TwoFactorItem(service: 'Microsoft', account: 'user+microsoft@example.com', twoFa: '450 120', nextTwoFa: '333 222', group: 'Work'),
  TwoFactorItem(service: 'Facebook', account: 'user+facebook@example.com', twoFa: '223 334', nextTwoFa: '101 202', group: 'Personal'),
  TwoFactorItem(service: 'Twitter', account: 'user+twitter@example.com', twoFa: '998 001', nextTwoFa: '909 808', group: 'Personal'),
  TwoFactorItem(service: 'CustomApp', account: 'service_account', twoFa: '010 203', nextTwoFa: '010 011', group: 'Admin'),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _selectedGroup = 'All (${sampleItems.length})';
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
      final g = item.group.isEmpty ? 'Ungrouped' : item.group;
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
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller ?? TextEditingController(),
              builder: (context, value, _) {
                final hasText = value.text.isNotEmpty;
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    hintText: 'Search',
                    border: InputBorder.none,
                    isDense: true,
                    suffixIcon: hasText
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              controller?.clear();
                              onChanged?.call('');
                              // keep focus after clearing
                              focusNode?.requestFocus();
                            },
                          )
                        : null,
                  ),
                );
              },
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

  const _AccountList({Key? key, required this.selectedGroup, required this.searchQuery}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final base = selectedGroup == 'All' || selectedGroup.isEmpty
        ? sampleItems
        : sampleItems.where((i) => i.group == selectedGroup).toList();

    final query = searchQuery.toLowerCase();
    final filtered = query.isEmpty
        ? base
        : base.where((i) {
            final s = i.service.toLowerCase();
            final a = i.account.toLowerCase();
            return s.contains(query) || a.contains(query);
          }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No results', style: TextStyle(color: Colors.grey)));
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (context, index) => Divider(indent: 72),
      itemBuilder: (context, index) {
        final item = filtered[index];
        return AccountTile(item: item);
      },
    );
  }
}

// _IconCircle removed (now unused after refactor)

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
