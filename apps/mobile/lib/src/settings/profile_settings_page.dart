import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto/crypto.dart';
import 'package:notjustdex_identity_kernel/identity_kernel.dart';
import '../core/services/session_service.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController(text: 'User');
  bool _showSeedPhrase = false;
  String? _avatarCid;
  bool _isSaving = false;
  List<String>? _seedPhrase;
  final _session = SessionService();
  final _ipfs = IpfsClient();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (_session.displayName != null) {
      _displayNameController.text = _session.displayName!;
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  String? get _avatarUrl {
    if (_avatarCid == null) return null;
    return _ipfs.gatewayUrl(_avatarCid!);
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
                    backgroundImage: _avatarUrl != null
                        ? NetworkImage(_avatarUrl!)
                        : null,
                    child: _avatarUrl == null
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
            subtitle: Text('@${_session.username ?? 'username'} — cannot be changed'),
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
            subtitle: Text(_avatarCid != null ? 'Uploaded to IPFS' : 'Add a photo'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickPhoto,
          ),

          if (!_session.isIdentityComplete) ...[
            const Divider(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: theme.colorScheme.onTertiaryContainer, size: 20),
                      const SizedBox(width: 8),
                      Text('Complete your profile', style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Set up your username and wallet to access all features.',
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onTertiaryContainer)),
                  const SizedBox(height: 12),
                  OverflowBar(
                    spacing: 8,
                    overflowAlignment: OverflowBarAlignment.start,
                    children: [
                      if (_session.username == null || _session.username!.isEmpty)
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.alternate_email, size: 18),
                          label: const Text('Choose Username'),
                          onPressed: () => context.push('/onboarding/username',
                              extra: _session.phoneNumber ?? ''),
                        ),
                      if (_session.walletAddress == null || _session.walletAddress!.isEmpty)
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.account_balance_wallet, size: 18),
                          label: const Text('Connect Wallet'),
                          onPressed: () => context.push('/onboarding/wallet-connect',
                              extra: _session.phoneNumber ?? ''),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],

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
            onTap: _showSeedPhrase ? null : _showSeedPhraseAction,
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
            onTap: _rotateSeedPhraseAction,
          ),

          const Divider(height: 32),

          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.logout)),
            title: Text('Sign Out', style: TextStyle(color: theme.colorScheme.error)),
            onTap: _signOut,
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
      await _session.updateDisplayName(name);
      if (mounted) {
        setState(() {
          _displayNameController.text = name;
          _isSaving = false;
        });
      }
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Display name updated (local)')),
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

  Future<void> _pickPhoto() async {
    // In production: use image_picker package to select from gallery/camera
    // image_picker.getImage → Uint8List → IpfsClient.uploadBytes → get CID
    //
    // Stub: simulate photo upload with placeholder data
    setState(() => _isSaving = true);

    try {
      // Simulate picking a photo — in production this is:
      // final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      // final bytes = await picked!.readAsBytes();
      // _avatarCid = await _ipfs.uploadBytes(bytes, fileName: 'avatar.jpg');
      final mockBytes = Uint8List.fromList(utf8.encode('mock_avatar_data'));
      _avatarCid = await _ipfs.uploadBytes(mockBytes, fileName: 'avatar.jpg');

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo uploaded to IPFS: ${_avatarCid!.substring(0, 12)}...')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  void _showSeedPhraseAction() {
    final userId = _session.userId;
    if (userId == null) return;

    final seedHash = sha256.convert(utf8.encode('notjustdex_wallet_$userId')).toString();
    final words = <String>[];
    for (var i = 0; i < 24; i++) {
      words.add(seedHash.substring(i * 2, i * 2 + 4));
    }

    setState(() {
      _seedPhrase = words;
      _showSeedPhrase = true;
    });
  }

  void _rotateSeedPhraseAction() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Seed rotation — implement after onboarding')),
    );
  }

  Future<void> _signOut() async {
    await _session.clearSession();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const _WelcomeRedirect()),
        (_) => false,
      );
    }
  }
}

class _WelcomeRedirect extends StatelessWidget {
  const _WelcomeRedirect();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const _WelcomeRedirect()),
        (_) => false,
      );
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
