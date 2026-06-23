import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notjustdex_identity_kernel/notjustdex_identity_kernel.dart';

class VaultDetailPage extends StatefulWidget {
  final VaultEntry entry;
  final VaultService vaultService;

  const VaultDetailPage({
    super.key,
    required this.entry,
    required this.vaultService,
  });

  @override
  State<VaultDetailPage> createState() => _VaultDetailPageState();
}

class _VaultDetailPageState extends State<VaultDetailPage> {
  late VaultEntry _entry;
  final Map<String, bool> _revealedFields = {};
  Timer? _totpTimer;
  String _totpCode = '';
  int _totpSecondsLeft = 30;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    widget.vaultService.recordAccess(_entry.id);
    if (_entry.type == VaultEntryType.totp) {
      _startTotpTimer();
    }
  }

  @override
  void dispose() {
    _totpTimer?.cancel();
    super.dispose();
  }

  void _startTotpTimer() {
    _generateTotp();
    _totpTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _totpSecondsLeft = 30 - (DateTime.now().millisecondsSinceEpoch ~/ 1000 % 30);
      });
      if (_totpSecondsLeft >= 30 || _totpSecondsLeft <= 0) {
        _generateTotp();
      }
    });
  }

  void _generateTotp() {
    final secret = _entry.fields['secret'];
    if (secret == null || secret.isEmpty) {
      _totpCode = 'N/A';
      return;
    }
    _totpCode = _computeTotp(secret);
  }

  String _computeTotp(String secret) {
    try {
      final time = DateTime.now().millisecondsSinceEpoch ~/ 1000 ~/ 30;
      final secretBytes = _base32Decode(secret);
      final message = List<int>.generate(8, (i) => (time >> (56 - i * 8)) & 0xFF);
      final hmac = _sha1Hmac(secretBytes, message);
      final offset = hmac[hmac.length - 1] & 0xF;
      final code = ((hmac[offset] & 0x7F) << 24) |
          ((hmac[offset + 1] & 0xFF) << 16) |
          ((hmac[offset + 2] & 0xFF) << 8) |
          (hmac[offset + 3] & 0xFF);
      final totp = (code % 1000000).toString().padLeft(6, '0');
      return totp;
    } catch (_) {
      return 'Error';
    }
  }

  List<int> _base32Decode(String input) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final clean = input.toUpperCase().replaceAll(RegExp(r'[^A-Z2-7]'), '');
    final bytes = <int>[];
    var buffer = 0;
    var bitsLeft = 0;
    for (var i = 0; i < clean.length; i++) {
      final val = chars.indexOf(clean[i]);
      if (val == -1) continue;
      buffer = (buffer << 5) | val;
      bitsLeft += 5;
      if (bitsLeft >= 8) {
        bytes.add((buffer >> (bitsLeft - 8)) & 0xFF);
        bitsLeft -= 8;
      }
    }
    return bytes;
  }

  List<int> _sha1Hmac(List<int> key, List<int> message) {
    final blockSize = 64;
    if (key.length > blockSize) {
      key = _sha1(key);
    }
    if (key.length < blockSize) {
      key = [...key, ...List.filled(blockSize - key.length, 0)];
    }

    final oKeyPad = <int>[];
    final iKeyPad = <int>[];
    for (var i = 0; i < blockSize; i++) {
      oKeyPad.add(key[i] ^ 0x5C);
      iKeyPad.add(key[i] ^ 0x36);
    }

    final innerHash = _sha1([...iKeyPad, ...message]);
    return _sha1([...oKeyPad, ...innerHash]);
  }

  List<int> _sha1(List<int> data) {
    final h0 = 0x67452301;
    final h1 = 0xEFCDAB89;
    final h2 = 0x98BADCFE;
    final h3 = 0x10325476;
    final h4 = 0xC3D2E1F0;

    final ml = data.length * 8;
    var padded = List<int>.from(data);
    padded.add(0x80);
    while ((padded.length % 64) != 56) {
      padded.add(0);
    }
    for (var i = 7; i >= 0; i--) {
      padded.add((ml >> (i * 8)) & 0xFF);
    }

    var a = h0, b = h1, c = h2, d = h3, e = h4;

    for (var chunk = 0; chunk < padded.length; chunk += 64) {
      final w = List<int>.generate(80, (_) => 0);
      for (var i = 0; i < 16; i++) {
        w[i] = (padded[chunk + i * 4] << 24) |
            (padded[chunk + i * 4 + 1] << 16) |
            (padded[chunk + i * 4 + 2] << 8) |
            padded[chunk + i * 4 + 3];
      }
      for (var i = 16; i < 80; i++) {
        w[i] = _rotl32(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
      }

      var ta = a, tb = b, tc = c, td = d, te = e;

      for (var i = 0; i < 80; i++) {
        int f, k;
        if (i < 20) {
          f = (tb & tc) | ((~tb) & td);
          k = 0x5A827999;
        } else if (i < 40) {
          f = tb ^ tc ^ td;
          k = 0x6ED9EBA1;
        } else if (i < 60) {
          f = (tb & tc) | (tb & td) | (tc & td);
          k = 0x8F1BBCDC;
        } else {
          f = tb ^ tc ^ td;
          k = 0xCA62C1D6;
        }
        final temp = (_rotl32(ta, 5) + f + te + k + w[i]) & 0xFFFFFFFF;
        te = td;
        td = tc;
        tc = _rotl32(tb, 30);
        tb = ta;
        ta = temp;
      }

      a = (a + ta) & 0xFFFFFFFF;
      b = (b + tb) & 0xFFFFFFFF;
      c = (c + tc) & 0xFFFFFFFF;
      d = (d + td) & 0xFFFFFFFF;
      e = (e + te) & 0xFFFFFFFF;
    }

    final result = <int>[];
    for (final v in [a, b, c, d, e]) {
      result.add((v >> 24) & 0xFF);
      result.add((v >> 16) & 0xFF);
      result.add((v >> 8) & 0xFF);
      result.add(v & 0xFF);
    }
    return result;
  }

  int _rotl32(int x, int n) => ((x << n) | (x >> (32 - n))) & 0xFFFFFFFF;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_entry.name),
        actions: [
          IconButton(
            icon: Icon(
              _entry.isFavorite ? Icons.star : Icons.star_outline,
              color: _entry.isFavorite ? Colors.amber : null,
            ),
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editEntry,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteEntry,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(theme),
          const SizedBox(height: 24),
          if (_entry.type == VaultEntryType.totp) _buildTotpSection(theme),
          ..._buildFields(theme),
          if (_entry.notes != null && _entry.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSection('Notes', theme),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_entry.notes!),
              ),
            ),
          ],
          if (_entry.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSection('Tags', theme),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _entry.tags
                  .map((t) => Chip(label: Text(t)))
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          _buildMetadata(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final typeIcon = _iconForType(_entry.type);
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(typeIcon, size: 32, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 12),
          Text(_entry.name,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          Text(_entry.type.displayName,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildTotpSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              _totpCode,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: _totpSecondsLeft < 5 ? Colors.red : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _totpSecondsLeft / 30,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: _totpSecondsLeft < 5 ? Colors.red : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_totpSecondsLeft}s remaining',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _totpCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('TOTP code copied')),
                );
              },
              child: const Text('Copy Code'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFields(ThemeData theme) {
    final fields = _entry.fields.entries.toList();
    if (fields.isEmpty) return [];

    return [
      _buildSection('Details', theme),
      const SizedBox(height: 8),
      ...fields.map((f) => _buildFieldCard(f.key, f.value, theme)),
    ];
  }

  Widget _buildFieldCard(String key, String value, ThemeData theme) {
    final isSecret = key == 'password' || key == 'cvv' || key == 'secret' ||
        key == 'apiKey' || key == 'cardNumber' || key == 'ssn';
    final revealed = _revealedFields[key] ?? false;
    final label = _fieldLabel(key);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(label, style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurfaceVariant,
        )),
        subtitle: Text(
          isSecret && !revealed ? '••••••••' : value,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSecret)
              IconButton(
                icon: Icon(revealed ? Icons.visibility_off : Icons.visibility),
                onPressed: () async {
                  if (!revealed) {
                    // In production: trigger biometric auth here
                    setState(() => _revealedFields[key] = true);
                  } else {
                    setState(() => _revealedFields[key] = false);
                  }
                },
              ),
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label copied')),
                );
                if (isSecret) {
                  Future.delayed(const Duration(seconds: 30), () {
                    Clipboard.setData(const ClipboardData(text: ''));
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, ThemeData theme) {
    return Text(title,
        style: theme.textTheme.titleSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ));
  }

  Widget _buildMetadata(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection('Metadata', theme),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _metaRow('Created', _formatDate(_entry.createdAt), theme),
                const SizedBox(height: 4),
                _metaRow('Updated', _formatDate(_entry.updatedAt), theme),
                if (_entry.accessedAt != null) ...[
                  const SizedBox(height: 4),
                  _metaRow('Last accessed', _formatDate(_entry.accessedAt!), theme),
                ],
                const SizedBox(height: 4),
                _metaRow('Version', '${_entry.version}', theme),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _metaRow(String label, String value, ThemeData theme) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              )),
        ),
        Text(value, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  String _formatDate(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleFavorite() async {
    await widget.vaultService.toggleFavorite(_entry.id);
    setState(() {
      _entry = _entry.copyWith(isFavorite: !_entry.isFavorite);
    });
  }

  Future<void> _editEntry() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VaultEntryFormPage(
          vaultService: widget.vaultService,
          existingEntry: _entry,
        ),
      ),
    );
    if (result == true && mounted) {
      final updated = widget.vaultService.getEntry(_entry.id);
      if (updated != null) {
        setState(() => _entry = updated);
      }
    }
  }

  Future<void> _deleteEntry() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Entry'),
        content: Text('Delete "${_entry.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.vaultService.deleteEntry(_entry.id);
      if (mounted) Navigator.of(context).pop(true);
    }
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

  String _fieldLabel(String key) {
    switch (key) {
      case 'username': return 'Username';
      case 'password': return 'Password';
      case 'url': return 'Website URL';
      case 'cardNumber': return 'Card Number';
      case 'expiryDate': return 'Expiry Date';
      case 'cvv': return 'CVV';
      case 'cardholderName': return 'Cardholder Name';
      case 'bankName': return 'Bank Name';
      case 'secret': return 'TOTP Secret';
      case 'issuer': return 'Issuer';
      case 'accountName': return 'Account Name';
      case 'firstName': return 'First Name';
      case 'lastName': return 'Last Name';
      case 'email': return 'Email';
      case 'phone': return 'Phone';
      case 'address': return 'Address';
      case 'apiKey': return 'API Key';
      case 'baseUrl': return 'Base URL';
      case 'accountNumber': return 'Account Number';
      case 'routingNumber': return 'Routing Number';
      case 'swiftCode': return 'SWIFT Code';
      case 'iban': return 'IBAN';
      default: return key;
    }
  }
}
