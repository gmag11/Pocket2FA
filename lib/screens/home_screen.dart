import 'package:flutter/material.dart';
import '../widgets/account_tile.dart';
import '../data/sample_items.dart';

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
                  textAlignVertical: TextAlignVertical.center,
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

  const _AccountList({required this.selectedGroup, required this.searchQuery});

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
      separatorBuilder: (context, index) => Divider(indent: 20, endIndent: 20,),
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
                onPressed: () {}, // active but no-op for now
                icon: const Icon(Icons.qr_code, color: Colors.white),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  backgroundColor: const Color(0xFF4F63E6), // custom blue to match design
                ),
                label: const Text('New', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () {}, // active but no-op for now
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
            children: [
              InkWell(
                onTap: () {
                  showModalBottomSheet<String>(
                    context: context,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
                    ),
                    builder: (ctx) {
                      return SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              title: const Text('settings', textAlign: TextAlign.center),
                              onTap: () => Navigator.of(ctx).pop('settings'),
                            ),
                            ListTile(
                              title: const Text('accounts', textAlign: TextAlign.center),
                              onTap: () => Navigator.of(ctx).pop('accounts'),
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Center(
                                      child: Text('user@domain.com', style: TextStyle(color: Colors.grey)),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.grey),
                                    onPressed: () => Navigator.of(ctx).pop(), // close without selecting
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ).then((value) {
                    if (value != null) {
                      // handle selection if needed
                      // print('selected: $value');
                    }
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.person_outline, size: 18, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('user@domain.com', style: TextStyle(color: Colors.grey)),
                    SizedBox(width: 6),
                    Icon(Icons.more_vert, size: 18, color: Colors.grey),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
