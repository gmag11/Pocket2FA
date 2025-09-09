import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../widgets/account_tile.dart';
import '../services/settings_service.dart';
import '../models/account_entry.dart';

class AccountList extends StatefulWidget {
  final String selectedGroup;
  final String searchQuery;
  final SettingsService settings;
  final List<AccountEntry> items;
  final Future<void> Function()? onRefresh;
  final ScrollController? scrollController;
  final bool isManageMode;
  final Set<int> selectedAccountIds;
  final ValueChanged<int> onToggleAccountSelection;
  final ValueChanged<AccountEntry>? onEditAccount; // Nuevo callback para edición

  const AccountList({
    required this.selectedGroup,
    required this.searchQuery,
    required this.settings,
    required this.items,
    this.onRefresh,
    this.scrollController,
    required this.isManageMode,
    required this.selectedAccountIds,
    required this.onToggleAccountSelection,
    this.onEditAccount, // Agregar al constructor
    super.key,
  });

  @override
  State<AccountList> createState() => _AccountListState();
}

class _AccountListState extends State<AccountList> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Filter out deleted items to prevent crashes
    final filteredItems = widget.items.where((item) => !item.deleted).toList();
    
    // Helper refresh wrapper that uses provided onRefresh when available.
    Future<void> handleRefresh() async {
      if (widget.onRefresh != null) {
        await widget.onRefresh!();
      }
    }

    // If no accounts/items available, return informative message but keep pull-to-refresh
    if (filteredItems.isEmpty) {
      // Safe check for no servers: avoid null lints
      final storage = widget.settings.storage;
      bool noServers = false;
      if (storage != null && storage.isUnlocked) {
        try {
          final raw = storage.box.get('servers');
          noServers = raw == null || (raw as List).isEmpty;
        } on StateError catch (_) {
          noServers = true; // Assume no servers if storage locked/unavailable
        }
      } else {
        noServers = true; // Assume no servers if storage locked/unavailable
      }
      return RefreshIndicator(
        onRefresh: handleRefresh,
        child: ListView(
          controller: widget.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Center(
              child: Text(
                noServers
                    ? l10n.noServersConfigured
                    : l10n.noAccounts,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    final base = widget.selectedGroup == 'All' || widget.selectedGroup.isEmpty
        ? filteredItems
        : filteredItems.where((i) => i.group == widget.selectedGroup).toList();

    final query = widget.searchQuery.toLowerCase();
    final filtered = query.isEmpty
        ? base
        : base.where((i) {
            final s = i.service.toLowerCase();
            final a = i.account.toLowerCase();
            return s.contains(query) || a.contains(query);
          }).toList();

    // No results after filtering — still allow pull-to-refresh
    if (filtered.isEmpty) {
      return RefreshIndicator(
        onRefresh: handleRefresh,
        child: ListView(
          controller: widget.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
            children: [
            const SizedBox(height: 120),
            Center(child: Text(l10n.noResults, style: const TextStyle(color: Colors.grey))),
          ],
        ),
      );
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
      return RefreshIndicator(
        onRefresh: handleRefresh,
        child: ListView.separated(
          controller: widget.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: filtered.length,
          separatorBuilder: (context, index) => Divider(indent: 20, endIndent: 20,),
          itemBuilder: (context, index) {
            try {
              final item = filtered[index];
              return AccountTile(
                item: item, 
                settings: widget.settings,
                isManageMode: widget.isManageMode,
                isSelected: widget.selectedAccountIds.contains(item.id),
                onToggleSelection: () => widget.onToggleAccountSelection(item.id),
                onEdit: widget.onEditAccount != null ? () => widget.onEditAccount!(item) : null,
              );
            } catch (e) {
                return ListTile(
                leading: const Icon(Icons.error, color: Colors.red),
                title: Text(l10n.errorDisplayingAccount),
                subtitle: Text(e.toString()),
                isThreeLine: true,
                dense: true,
              );
            }
          },
        ),
      );
    }

    // Multi-column grid for wide screens (up to 3 columns) — wrap with RefreshIndicator
    return RefreshIndicator(
      onRefresh: handleRefresh,
      child: GridView.builder(
        controller: widget.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 16,
          mainAxisExtent: 92, // enough to contain the 72px tile plus spacing
        ),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          try {
            final item = filtered[index];
            return Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
              ),
              child: AccountTile(
                key: ValueKey(item.id), 
                item: item, 
                settings: widget.settings,
                isManageMode: widget.isManageMode,
                isSelected: widget.selectedAccountIds.contains(item.id),
                onToggleSelection: () => widget.onToggleAccountSelection(item.id),
                onEdit: widget.onEditAccount != null ? () => widget.onEditAccount!(item) : null,
              ),
            );
          } catch (e) {
              return Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
              ),
              child: ListTile(
                leading: const Icon(Icons.error, color: Colors.red),
                title: Text(l10n.errorDisplayingAccount),
                subtitle: Text(e.toString()),
                isThreeLine: true,
                dense: true,
              ),
            );
          }
        },
      ),
    );
  }
}
