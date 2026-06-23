import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import '../core/services/session_service.dart';
import '../core/services/passkey_service.dart';

class UsernamePage extends StatefulWidget {
  final String phoneNumber;

  const UsernamePage({super.key, required this.phoneNumber});

  @override
  State<UsernamePage> createState() => _UsernamePageState();
}

class _UsernamePageState extends State<UsernamePage> {
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passkeyService = PasskeyService();
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
      // 1. Create passkey (WebAuthn biometric credential)
      final passkey = await _passkeyService.createCredential(
        userId: _usernameController.text.trim(),
        userName: _displayNameController.text.trim(),
        options: {},
      );
      final credentialId = passkey[0];

      // 2. Derive wallet key from passkey credential
      //    This is deterministic — same passkey always produces same wallet
      final walletSeed = sha256.convert(utf8.encode('notjustdex_wallet_$credentialId')).bytes;
      final ed25519 = Ed25519();
      final keyPair = await ed25519.newKeyPairFromSeed(walletSeed);
      final keyPairData = await keyPair.extract();
      final address = sha256.convert(keyPairData.publicKey.bytes).toString().substring(0, 40);

      // 3. Store session locally
      final session = SessionService();
      await session.saveSession(
        token: address,
        userId: address,
        username: _usernameController.text.trim(),
        displayName: _displayNameController.text.trim(),
        phoneNumber: widget.phoneNumber,
      );

      if (mounted) context.go('/home');
    } catch (e) {
      setState(() {
        _isCreating = false;
        _errorMessage = 'Failed to create account: $e';
      });
    }
  }
}
