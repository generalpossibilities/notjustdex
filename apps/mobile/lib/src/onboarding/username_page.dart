import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/services/users_client.dart';
import '../core/services/auth_client.dart';

class UsernamePage extends StatefulWidget {
  final String phoneNumber;

  const UsernamePage({super.key, required this.phoneNumber});

  @override
  State<UsernamePage> createState() => _UsernamePageState();
}

class _UsernamePageState extends State<UsernamePage> {
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _isAvailable = false;
  bool _isChecking = false;
  bool _isCreating = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final username = _usernameController.text.trim();
    final displayName = _displayNameController.text.trim();
    final displayNameValid = displayName.length >= 4;
    final canProceed = username.length >= 4 && _isAvailable && displayNameValid && !_isCreating;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Profile')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose your username', style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              )),
              const SizedBox(height: 8),
              Text('This is your permanent on-chain name. Must be 4+ characters.',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 32),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  prefixText: '@',
                  suffixIcon: username.length >= 4
                      ? _isChecking
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(
                              _isAvailable ? Icons.check_circle : Icons.cancel,
                              color: _isAvailable ? Colors.green : Colors.red)
                      : null,
                ),
                onChanged: (v) {
                  setState(() { _isChecking = v.length >= 4; _isAvailable = false; _errorMessage = ''; });
                  if (v.length >= 4) {
                    Future.delayed(const Duration(milliseconds: 400), () {
                      if (mounted) {
                        setState(() { _isAvailable = true; _isChecking = false; });
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _displayNameController,
                decoration: InputDecoration(
                  labelText: 'Display Name (min 4 characters)',
                  hintText: 'Your public profile name',
                  suffixIcon: displayName.length > 0 && displayName.length < 4
                      ? const Icon(Icons.info_outline, color: Colors.orange, size: 20)
                      : displayName.length >= 4
                          ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                          : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_errorMessage, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
                ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: canProceed ? _createAccount : null,
                child: _isCreating
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 12),
                          Text('Setting up your profile...'),
                        ],
                      )
                    : const Text('Create Account'),
              ),
              const SizedBox(height: 12),
              Text(
                'Your wallet will be created automatically. You won\'t see any blockchain terms.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createAccount() async {
    setState(() { _isCreating = true; _errorMessage = ''; });

    try {
      // 1. Register with users service
      final usersClient = UsersClient();
      final result = await usersClient.createUser(
        widget.phoneNumber,
        _usernameController.text.trim(),
        _displayNameController.text.trim(),
      );

      final userId = result['user']['id'] as String;

      // 2. Register passkey silently
      // In production: use PasskeyService.createCredential()
      // Stub: simulate passkey creation delay
      await Future.delayed(const Duration(milliseconds: 800));

      // 3. Create wallet silently (already done by users service)
      final walletAddr = result['wallet']['address'] as String;

      // 4. Link wallet to auth service
      final authClient = AuthClient();
      await authClient.linkWallet(userId, walletAddr);

      if (mounted) context.go('/home');
    } catch (e) {
      setState(() {
        _isCreating = false;
        _errorMessage = 'Failed to create account: $e';
      });
    }
  }
}
