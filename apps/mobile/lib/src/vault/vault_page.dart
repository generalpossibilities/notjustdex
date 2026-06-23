import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notjustdex_identity_kernel/notjustdex_identity_kernel.dart';

class VaultPage extends StatefulWidget {
  final VaultService vaultService;

  const VaultPage({super.key, required this.vaultService});

  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  final _searchController = TextEditingController();
  List<VaultEntry> _entries = [];
  VaultEntryType? _selectedType;
  String _searchQuery = '';
  bool _showFavorites = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      if (_showFavorites) {
        _entries = widget.vaultService.getFavorites();
      } else if (_selectedType != null) {
        _entries = widget.vaultService.getEntriesByType(_selectedType!);
      } else if (_searchQuery.isNotEmpty) {
        _entries = widget.vaultService.searchEntries(_searchQuery);
      } else {
        _entries = widget.vaultService.cachedEntries;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault'),
        actions: [
          IconButton(
            icon: Icon(
              _showFavorites ? Icons.star : Icons.star_outline,
              color: _showFavorites ? Colors.amber : null,
            ),
            onPressed: () {
              setState(() => _showFavorites = !_showFavorites);
              _refresh();
            },
            tooltip: 'Favorites',
          ),
          PopupMenuButton(
            itemBuilder: (_) => [
              PopupMenuItem(
                child: const ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Vault Settings'),
                ),
              ),
              PopupMenuItem(
                child: const ListTile(
                  leading: Icon(Icons.history),
                  title: Text('Audit Log'),
                ),
              ),
              PopupMenuItem(
                child: ListTile(
                  leading: const Icon(Icons.lock),
                  title: const Text('Lock Vault'),
                  onTap: () {
                    widget.vaultService.lock();
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(theme),
          _buildTypeFilter(theme),
          Expanded(
            child: _entries.isEmpty
                ? _buildEmptyState(theme)
                : _buildEntryList(theme),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search vault...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _refresh();
                  },
                )
              : null,
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (v) {
          setState(() => _searchQuery = v);
          _refresh();
        },
      ),
    );
  }

  Widget _buildTypeFilter(ThemeData theme) {
    final types = VaultEntryType.values;
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _filterChip(null, 'All', theme),
          ...types.map((t) => _filterChip(t, t.displayName, theme)),
        ],
      ),
    );
  }

  Widget _filterChip(VaultEntryType? type, String label, ThemeData theme) {
    final selected = _selectedType == type;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => _selectedType = selected ? null : type);
          _refresh();
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 64, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('No entries', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first entry',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryList(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _entries.length,
      itemBuilder: (_, i) {
        final entry = _entries[i];
        return _EntryTile(
          entry: entry,
          vaultService: widget.vaultService,
          onChanged: _refresh,
        );
      },
    );
  }

  void _navigateToForm(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VaultEntryFormPage(vaultService: widget.vaultService),
      ),
    );
    if (result == true) _refresh();
  }
}

class _EntryTile extends StatelessWidget {
  final VaultEntry entry;
  final VaultService vaultService;
  final VoidCallback onChanged;

  const _EntryTile({
    required this.entry,
    required this.vaultService,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeIcon = _iconForType(entry.type);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(typeIcon, color: theme.colorScheme.primary, size: 20),
        ),
        title: Text(entry.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          entry.fields['username'] ?? entry.type.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entry.isFavorite)
              const Icon(Icons.star, size: 16, color: Colors.amber),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _openDetail(context),
            ),
          ],
        ),
        onTap: () => _openDetail(context),
      ),
    );
  }

  void _openDetail(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VaultDetailPage(
          entry: entry,
          vaultService: vaultService,
        ),
      ),
    );
    if (result == true) onChanged();
  }

  IconData _iconForType(VaultEntryType type) {
    switch (type) {
      case VaultEntryType.password:
        return Icons.lock;
      case VaultEntryType.creditCard:
        return Icons.credit_card;
      case VaultEntryType.totp:
        return Icons.timer;
      case VaultEntryType.secureNote:
        return Icons.note;
      case VaultEntryType.identity:
        return Icons.badge;
      case VaultEntryType.apiKey:
        return Icons.vpn_key;
      case VaultEntryType.bankAccount:
        return Icons.account_balance;
      case VaultEntryType.custom:
        return Icons.extension;
    }
  }
}
