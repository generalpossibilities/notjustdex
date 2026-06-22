import 'package:flutter/material.dart';
import '../core/services/users_client.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController(text: 'User');
  bool _showSeedPhrase = false;
  String? _profilePicUrl;
  List<String>? _seedPhrase;
  bool _isSaving = false;

  // In production: injected via DI
  final _usersClient = UsersClient();
  String _userId = 'user_demo_id';

  @override
  void dispose() {
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    backgroundImage: _profilePicUrl != null
                        ? NetworkImage(_profilePicUrl!)
                        : null,
                    child: _profilePicUrl == null
                        ? Icon(Icons.person, size: 48, color: theme.colorScheme.primary)
                        : null,
                  ),
                  Positioned(bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text('Profile', style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary)),
          const SizedBox(height: 8),

          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.alternate_email)),
            title: const Text('Username'),
            subtitle: const Text('@username — cannot be changed'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('On-chain', style: TextStyle(fontSize: 10, color: theme.colorScheme.primary)),
            ),
          ),

          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.badge)),
            title: const Text('Display Name'),
            subtitle: Text(_displayNameController.text),
            trailing: const Icon(Icons.chevron_right),
            onTap: _editDisplayName,
          ),

          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.photo)),
            title: const Text('Profile Photo'),
            subtitle: Text(_profilePicUrl != null ? 'Photo set' : 'Add a photo'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickPhoto,
          ),

          const Divider(height: 32),

          Text('Account', style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary)),
          const SizedBox(height: 8),

          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.fingerprint)),
            title: const Text('Passkey'),
            subtitle: const Text('Biometric login — active'),
            trailing: Icon(Icons.check_circle, color: Colors.green, size: 20),
          ),

          const Divider(height: 32),

          Text('Security', style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary)),
          const SizedBox(height: 8),

          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.key)),
            title: const Text('Export Recovery Phrase'),
            subtitle: const Text('24-word phrase for account recovery'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showSeedPhrase ? null : _authenticateAndShow,
          ),
          if (_seedPhrase != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
              ),
              child: Wrap(
                spacing: 12, runSpacing: 10,
                children: List.generate(_seedPhrase!.length, (i) {
                  return Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${i + 1}.',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(_seedPhrase![i],
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  ]);
                }),
              ),
            ),
            const SizedBox(height: 8),
            Text('Never share your recovery phrase. Anyone with it can access your account.',
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
          ],

          const Divider(height: 32),

          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.password)),
            title: const Text('Rotate Seed Phrase'),
            subtitle: const Text('Generate a new 24-word recovery phrase'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _rotateSeedPhrase,
          ),

          const Divider(height: 32),

          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.logout)),
            title: Text('Sign Out', style: TextStyle(color: theme.colorScheme.error)),
          ),
        ],
      ),
    );
  }

  void _editDisplayName() {
    final editingController = TextEditingController(text: _displayNameController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Display Name'),
        content: TextField(
          controller: editingController,
          decoration: const InputDecoration(
            labelText: 'Display Name (min 4 characters)',
            helperText: 'This is your public profile name',
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: _isSaving ? null : () => _saveDisplayName(ctx, editingController.text.trim()),
            child: _isSaving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDisplayName(BuildContext dialogContext, String name) async {
    if (name.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name must be at least 4 characters')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _usersClient.updateProfile(userId: _userId, displayName: name);
      if (mounted) {
        setState(() {
          _displayNameController.text = name;
          _isSaving = false;
        });
      }
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Display name updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  void _pickPhoto() {
    // In production: use image_picker package
    // Stub: simulate a photo selection
    setState(() {
      _profilePicUrl = 'https://storage.notjustdex.io/avatars/${_userId}/photo.jpg';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Photo set (stub — real picker needs image_picker package)')),
    );
  }

  void _authenticateAndShow() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Password'),
        content: TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isSaving = true);
              try {
                final seed = await _usersClient.exportSeed(_userId, _passwordController.text);
                if (mounted) setState(() { _seedPhrase = seed; _showSeedPhrase = true; _isSaving = false; });
              } catch (e) {
                if (mounted) {
                  setState(() => _isSaving = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _rotateSeedPhrase() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rotate Seed Phrase'),
        content: const Text('This will generate a new 24-word recovery phrase. Your old phrase will stop working.\n\nContinue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isSaving = true);
              try {
                final newSeed = await _usersClient.rotateSeed(_userId);
                if (mounted) setState(() { _seedPhrase = newSeed; _showSeedPhrase = true; _isSaving = false; });
              } catch (e) {
                if (mounted) {
                  setState(() => _isSaving = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              }
            },
            child: const Text('Rotate'),
          ),
        ],
      ),
    );
  }
}
