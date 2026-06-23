import 'package:flutter/material.dart';
import 'package:notjustdex_identity_kernel/notjustdex_identity_kernel.dart';

class VaultSettingsPage extends StatefulWidget {
  final VaultService vaultService;

  const VaultSettingsPage({super.key, required this.vaultService});

  @override
  State<VaultSettingsPage> createState() => _VaultSettingsPageState();
}

class _VaultSettingsPageState extends State<VaultSettingsPage> {
  late VaultConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.vaultService.config;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Vault Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('Security', theme),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Biometric Required'),
                  subtitle: const Text('Require biometric verification to reveal secrets'),
                  value: _config.biometricRequired,
                  onChanged: (v) {
                    setState(() => _config = _config.copyWith(biometricRequired: v));
                    widget.vaultService.updateConfig(_config);
                  },
                ),
                ListTile(
                  title: const Text('Auto-Lock Timer'),
                  subtitle: Text(_config.autoLockDuration.displayName),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _selectAutoLock,
                ),
                ListTile(
                  title: const Text('Clipboard Clear Time'),
                  subtitle: Text('${_config.clipboardClearSeconds} seconds'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _selectClipboardClear,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSection('Data', theme),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload),
                  title: const Text('Export Backup'),
                  subtitle: const Text('Create encrypted backup'),
                  onTap: _exportBackup,
                ),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Import Backup'),
                  subtitle: const Text('Restore from backup file'),
                  onTap: _importBackup,
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Audit Log'),
                  subtitle: const Text('View access history'),
                  trailing: Text(
                    '${widget.vaultService.cachedEntries.length} entries',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  onTap: _viewAuditLog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSection('Danger Zone', theme),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Clear Local Cache',
                  style: TextStyle(color: Colors.red)),
              subtitle: const Text('Remove locally cached vault data'),
              onTap: _clearLocalCache,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, ThemeData theme) {
    return Text(title,
        style: theme.textTheme.titleSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ));
  }

  Future<void> _selectAutoLock() async {
    final result = await showDialog<AutoLockDuration>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Auto-Lock Timer'),
        children: AutoLockDuration.values.map((d) {
          return RadioListTile<AutoLockDuration>(
            title: Text(d.displayName),
            value: d,
            groupValue: _config.autoLockDuration,
            onChanged: (v) => Navigator.of(context).pop(v),
          );
        }).toList(),
      ),
    );

    if (result != null) {
      setState(() => _config = _config.copyWith(autoLockDuration: result));
      widget.vaultService.updateConfig(_config);
    }
  }

  Future<void> _selectClipboardClear() async {
    final controller = TextEditingController(
      text: _config.clipboardClearSeconds.toString(),
    );
    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clipboard Clear Time'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Seconds',
            border: OutlineInputBorder(),
            helperText: 'Auto-clear clipboard after N seconds (0 = never)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(controller.text) ?? 30;
              Navigator.of(context).pop(v.clamp(0, 300));
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => _config = _config.copyWith(clipboardClearSeconds: result));
      widget.vaultService.updateConfig(_config);
    }
  }

  Future<void> _exportBackup() async {
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Export Backup'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Backup Password',
            border: OutlineInputBorder(),
            helperText: 'This password will be needed to restore the backup',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Export'),
          ),
        ],
      ),
    );

    if (confirmed == true && passwordController.text.isNotEmpty) {
      try {
        final backup = await widget.vaultService.exportBackup(passwordController.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Backup created (${backup.length} bytes)'),
              action: SnackBarAction(
                label: 'Copy',
                onPressed: () {
                  // In production: copy to clipboard or save to file
                },
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Export failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _importBackup() async {
    final backupController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: backupController,
              decoration: const InputDecoration(
                labelText: 'Backup Data',
                border: OutlineInputBorder(),
                helperText: 'Paste the backup string',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Backup Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirmed == true &&
        backupController.text.isNotEmpty &&
        passwordController.text.isNotEmpty) {
      try {
        final count = await widget.vaultService.importBackup(
          backupController.text,
          passwordController.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imported $count entries')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Import failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _viewAuditLog() async {
    try {
      final log = await widget.vaultService.getAuditLog(limit: 100);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _AuditLogPage(log: log),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load audit log: $e')),
        );
      }
    }
  }

  Future<void> _clearLocalCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Local Cache'),
        content: const Text(
          'This will clear the locally cached vault data. '
          'Entries will be re-fetched from chain on next unlock.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.vaultService.clearLocalCache();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Local cache cleared')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not clear cache: $e')),
          );
        }
      }
    }
  }
}

class _AuditLogPage extends StatelessWidget {
  final List<AuditEntry> log;

  const _AuditLogPage({required this.log});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Audit Log')),
      body: log.isEmpty
          ? Center(
              child: Text('No audit entries',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            )
          : ListView.builder(
              itemCount: log.length,
              itemBuilder: (_, i) {
                final entry = log[i];
                final dt = DateTime.fromMillisecondsSinceEpoch(entry.timestamp);
                final time =
                    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
                return ListTile(
                  leading: Icon(
                    entry.success ? Icons.check_circle : Icons.error,
                    color: entry.success ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  title: Text(entry.action.name),
                  subtitle: Text(
                    '${entry.entryName ?? ''} $time',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  dense: true,
                );
              },
            ),
    );
  }
}
