import 'package:flutter/material.dart';
import '../widgets/account_tile.dart';
import '../services/settings_service.dart';
import 'settings_screen.dart';
import 'accounts_screen.dart';
import '../data/sample_items.dart';
import '../models/server_connection.dart';
import '../models/two_factor_item.dart';
import '../services/api_service.dart';

class HomePage extends StatefulWidget {
  final SettingsService settings;
  const HomePage({required this.settings, super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _selectedGroup = 'All (0)';
  String _searchQuery = '';
  late final TextEditingController _searchController;
  late final FocusNode _searchFocus;
  List<ServerConnection> _servers = [];
  String? _selectedServerId;
  int? _selectedAccountIndex;
  List<TwoFactorItem> _currentItems = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocus = FocusNode();
    _loadServers();
  }

  Future<void> _loadServers() async {
    final storage = widget.settings.storage;
    List<ServerConnection> servers = [];
    String? restoredServerId;
    int? restoredAccountIndex;
    if (storage != null) {
      final box = storage.box;
      final raw = box.get('servers');
      if (raw != null) {
        servers = (raw as List<dynamic>)
            .map((e) => ServerConnection.fromMap(Map<dynamic, dynamic>.from(e)))
            .toList();
      }
      // Try to restore previously selected server/account
      final selRaw = box.get('selected');
      if (selRaw != null) {
        try {
          final m = Map<dynamic, dynamic>.from(selRaw);
          restoredServerId = m['serverId'] as String?;
          restoredAccountIndex = m['accountIndex'] is int ? m['accountIndex'] as int : (m['accountIndex'] == null ? null : int.tryParse(m['accountIndex'].toString()));
        } catch (_) {
          restoredServerId = null;
          restoredAccountIndex = null;
        }
      }
    }
    setState(() {
      _servers = servers;
      if (_servers.isNotEmpty) {
        // If we restored a selection and it exists in the servers list, use it; otherwise default to first
        if (restoredServerId != null) {
          final idx = _servers.indexWhere((s) => s.id == restoredServerId);
          if (idx != -1) {
            final srv = _servers[idx];
            _selectedServerId = srv.id;
            _selectedAccountIndex = (restoredAccountIndex != null && srv.accounts.length > restoredAccountIndex) ? restoredAccountIndex : (srv.accounts.isNotEmpty ? 0 : null);
            // Prefer sample data by URL when available
            final sample = sampleServers.firstWhere((ss) => ss.url == srv.url, orElse: () => srv);
            _currentItems = sample.accounts;
            _selectedGroup = 'All (${_currentItems.length})';
          } else {
            // restored server not present anymore, fallback to first
            final first = _servers[0];
            _selectedServerId = first.id;
            // Prefer sample data by URL when available
            final sampleFirst = sampleServers.firstWhere((ss) => ss.url == first.url, orElse: () => first);
            _selectedAccountIndex = sampleFirst.accounts.isNotEmpty ? 0 : null;
            _currentItems = sampleFirst.accounts;
            _selectedGroup = 'All (${_currentItems.length})';
          }
        } else {
          final first = _servers[0];
          _selectedServerId = first.id;
          // Prefer sample data by URL when available for the default server as well
          final sampleFirst = sampleServers.firstWhere((ss) => ss.url == first.url, orElse: () => first);
          _selectedAccountIndex = sampleFirst.accounts.isNotEmpty ? 0 : null;
          _currentItems = sampleFirst.accounts;
          _selectedGroup = 'All (${_currentItems.length})';
        }
      } else {
        _selectedServerId = null;
        _selectedAccountIndex = null;
        _currentItems = [];
        _selectedGroup = 'All (0)';
      }
    });

    // Configure ApiService for the selected server (if any). Ignore errors here.
    if (_selectedServerId != null) {
      try {
        final srv = _servers.firstWhere((s) => s.id == _selectedServerId);
        ApiService.instance.setServer(srv);
      } catch (_) {}
    }
  }

  Future<void> _openServerAccountSelector() async {
    if (_servers.isEmpty) return;
    final choice = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (c) {
        // Size the sheet based on number of servers (tile height + header), capped to 80% of screen
        final mq = MediaQuery.of(c).size;
        const double tileH = 72.0;
        const double headerH = 56.0;
        final desired = headerH + (_servers.length * tileH);
        final maxH = mq.height * 0.8;
        final height = desired.clamp(120.0, maxH);

        return SafeArea(
          child: SizedBox(
            height: height,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Align(alignment: Alignment.centerLeft, child: Text('Servers', style: Theme.of(context).textTheme.titleMedium)),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: _servers.length,
                    itemBuilder: (ctx, idx) {
                      final srv = _servers[idx];
                      final isActive = srv.id == _selectedServerId;
                      return ListTile(
                        title: Text('${srv.name} (${Uri.parse(srv.url).host})'),
                        subtitle: Text(srv.url),
                        trailing: isActive ? const Icon(Icons.check, color: Colors.green) : null,
                        onTap: () {
                          Navigator.of(ctx).pop({'serverId': srv.id, 'accountIndex': null});
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice != null) {
      final serverId = choice['serverId'] as String;
      final accountIndex = choice['accountIndex'] as int?;
      final server = _servers.firstWhere((s) => s.id == serverId);
      // Prefer sample data for display when available
      final sample = sampleServers.firstWhere((ss) => ss.url == server.url, orElse: () => server);
      setState(() {
        _selectedServerId = serverId;
        _selectedAccountIndex = accountIndex;
        _currentItems = sample.accounts;
        _selectedGroup = 'All (${_currentItems.length})';
      });

      // Persist selection
      final storage = widget.settings.storage;
      if (storage != null) {
        try {
          await storage.box.put('selected', {'serverId': serverId, 'accountIndex': accountIndex});
        } catch (_) {
          // Non-fatal: ignore persistence errors
        }
      }

      // Configure ApiService for the newly selected server. Show error if it fails.
      try {
        ApiService.instance.setServer(server);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error configuring API: $e')));
        }
      }
    }
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
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final screenW = MediaQuery.of(context).size.width;
                  // For very wide screens center the main content and cap width so columns stay together
          if (screenW > 1400) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1400),
              child: _AccountList(selectedGroup: _groupKey(_selectedGroup), searchQuery: _searchQuery, settings: widget.settings, items: _currentItems),
                      ),
                    );
                  }
            return _AccountList(selectedGroup: _groupKey(_selectedGroup), searchQuery: _searchQuery, settings: widget.settings, items: _currentItems);
                },
              ),
            ),
            _BottomBar(
              settings: widget.settings,
              servers: _servers,
              selectedServerId: _selectedServerId,
              selectedAccountIndex: _selectedAccountIndex,
              onOpenSelector: _openServerAccountSelector,
              onOpenAccounts: () async {
                if (widget.settings.storage != null) {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (c) => AccountsScreen(storage: widget.settings.storage!)));
                  // After returning from AccountsScreen, reload servers from storage
                  await _loadServers();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Storage not available')));
                }
              },
            ),
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
  final SettingsService settings;
  final List<TwoFactorItem> items;

  const _AccountList({required this.selectedGroup, required this.searchQuery, required this.settings, required this.items});

  @override
  Widget build(BuildContext context) {
  // If no servers/items available, return empty
  if (items.isEmpty) return const Center(child: Text('No servers registered', style: TextStyle(color: Colors.grey)));

  final base = selectedGroup == 'All' || selectedGroup.isEmpty
    ? items
    : items.where((i) => i.group == selectedGroup).toList();

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

    final width = MediaQuery.of(context).size.width;
    int columns;
    if (width > 1200) {
      columns = 3;
    } else if (width > 800) {
      columns = 2;
    } else {
      columns = 1;
    }

    if (columns == 1) {
      return ListView.separated(
        itemCount: filtered.length,
        separatorBuilder: (context, index) => Divider(indent: 20, endIndent: 20,),
        itemBuilder: (context, index) {
          final item = filtered[index];
          return AccountTile(item: item, settings: settings);
        },
      );
    }

    // Multi-column grid for wide screens (up to 3 columns)
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 16,
        mainAxisExtent: 92, // enough to contain the 72px tile plus spacing
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        return Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
          ),
          child: AccountTile(item: item, settings: settings),
        );
      },
    );
  }
}

// _IconCircle removed (now unused after refactor)

class _BottomBar extends StatelessWidget {
  final SettingsService settings;
  final List<ServerConnection> servers;
  final String? selectedServerId;
  final int? selectedAccountIndex;
  final VoidCallback onOpenSelector;
  final VoidCallback? onOpenAccounts;

  const _BottomBar({required this.settings, required this.servers, required this.selectedServerId, required this.selectedAccountIndex, required this.onOpenSelector, this.onOpenAccounts});

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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: onOpenSelector,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                      child: Builder(builder: (ctx) {
                        // Compute display text from the selected server/account safely
                        String displayText;
                        if (servers.isEmpty) {
                          displayText = 'no-server';
                        } else {
                          final srv = selectedServerId != null
                              ? servers.firstWhere((s) => s.id == selectedServerId, orElse: () => servers.first)
                              : servers.first;
                          final acct = (selectedAccountIndex != null && srv.accounts.length > selectedAccountIndex!)
                              ? srv.accounts[selectedAccountIndex!].account
                              : 'user@domain.com';
                          displayText = '$acct - ${Uri.parse(srv.url).host}';
                        }
                        return Text(displayText, style: const TextStyle(color: Colors.grey));
                      }),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () {
                      final s = settings;
                      final nav = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
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
                            if (value == 'settings') {
                              // open full settings screen using captured Navigator
                              nav.push(MaterialPageRoute(builder: (c) => SettingsScreen(settings: s)));
                            } else if (value == 'accounts') {
                              // delegate to the owner (HomePage) to open accounts so it can reload afterwards
                              if (onOpenAccounts != null) {
                                onOpenAccounts!();
                              } else {
                                // fallback behaviour: try to open directly if storage is available
                                if (s.storage != null) {
                                  nav.push(MaterialPageRoute(builder: (c) => AccountsScreen(storage: s.storage!)));
                                } else {
                                  messenger.showSnackBar(const SnackBar(content: Text('Storage not available')));
                                }
                              }
                            }
                          }
                        });
                      },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.more_vert, size: 18, color: Colors.grey),
                  ],
                ),
              ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
