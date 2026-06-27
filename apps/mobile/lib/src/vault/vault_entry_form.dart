import 'package:flutter/material.dart';
import 'package:notjustdex_identity_kernel/identity_kernel.dart';

class VaultEntryFormPage extends StatefulWidget {
  final VaultService vaultService;
  final VaultEntry? existingEntry;

  const VaultEntryFormPage({
    super.key,
    required this.vaultService,
    this.existingEntry,
  });

  @override
  State<VaultEntryFormPage> createState() => _VaultEntryFormPageState();
}

class _VaultEntryFormPageState extends State<VaultEntryFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  late VaultEntryType _selectedType;
  late Map<String, TextEditingController> _fieldControllers;
  final List<String> _tags = [];
  bool _isSaving = false;

  final _passwordGenerator = PasswordGenerator();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingEntry?.name ?? '');
    _notesController = TextEditingController(text: widget.existingEntry?.notes ?? '');
    _selectedType = widget.existingEntry?.type ?? VaultEntryType.password;
    _fieldControllers = {};
    if (widget.existingEntry != null) {
      for (final entry in widget.existingEntry!.fields.entries) {
        _fieldControllers[entry.key] = TextEditingController(text: entry.value);
      }
      _tags.addAll(widget.existingEntry!.tags);
    }
    _initFieldControllers();
  }

  void _initFieldControllers() {
    final fields = _fieldsForType(_selectedType);
    for (final field in fields) {
      _fieldControllers.putIfAbsent(field, () => TextEditingController());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _fieldsForType(VaultEntryType type) {
    switch (type) {
      case VaultEntryType.password:
        return ['username', 'password', 'url'];
      case VaultEntryType.creditCard:
        return ['cardNumber', 'expiryDate', 'cvv', 'cardholderName', 'bankName'];
      case VaultEntryType.totp:
        return ['secret', 'issuer', 'accountName'];
      case VaultEntryType.secureNote:
        return [];
      case VaultEntryType.identity:
        return ['firstName', 'lastName', 'email', 'phone', 'address'];
      case VaultEntryType.apiKey:
        return ['apiKey', 'baseUrl', 'username'];
      case VaultEntryType.bankAccount:
        return ['accountNumber', 'routingNumber', 'bankName', 'swiftCode', 'iban'];
      case VaultEntryType.custom:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingEntry != null ? 'Edit Entry' : 'New Entry'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<VaultEntryType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: VaultEntryType.values.map((t) {
                return DropdownMenuItem(value: t, child: Text(t.displayName));
              }).toList(),
              onChanged: widget.existingEntry != null
                  ? null
                  : (v) {
                      if (v == null) return;
                      setState(() {
                        _selectedType = v;
                        _fieldControllers.clear();
                        _initFieldControllers();
                      });
                    },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            ..._buildTypeSpecificFields(theme),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            Text('Tags', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ..._tags.map((t) => Chip(
                      label: Text(t),
                      onDeleted: () => setState(() => _tags.remove(t)),
                    )),
                ActionChip(
                  label: const Text('+ Add tag'),
                  onPressed: _addTag,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSpecificFields(ThemeData theme) {
    final fields = _fieldsForType(_selectedType);
    if (_selectedType == VaultEntryType.password) {
      return Column(
        children: [
          ...fields.map((f) => _buildField(f, f == 'password')),
          _buildPasswordGenerator(theme),
        ],
      );
    }
    if (_selectedType == VaultEntryType.totp) {
      return Column(
        children: [
          ...fields.map((f) => _buildField(f)),
          _buildTotpInfo(theme),
        ],
      );
    }
    return Column(
      children: fields.map((f) => _buildField(f)).toList(),
    );
  }

  Widget _buildField(String key, {bool isPassword = false}) {
    final label = _fieldLabel(key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: _fieldControllers[key],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        obscureText: isPassword,
      ),
    );
  }

  Widget _buildPasswordGenerator(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Password Generator', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _generatedPassword.isEmpty
                        ? 'Tap generate for a secure password'
                        : _generatedPassword,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _generatePassword,
                ),
              ],
            ),
            if (_generatedPassword.isNotEmpty) ...[
              Text(
                'Strength: ${_passwordGenerator.estimateStrength(_generatedPassword)}',
                style: TextStyle(
                  color: _strengthColor(_passwordGenerator.estimateStrength(_generatedPassword)),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () {
                  _fieldControllers['password']?.text = _generatedPassword;
                },
                child: const Text('Use this password'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTotpInfo(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Enter the TOTP secret key from your service provider. '
                'The vault will generate 30-second rotating codes.',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _generatedPassword = '';

  void _generatePassword() {
    setState(() {
      _generatedPassword = _passwordGenerator.generate(
        length: 24,
        useUpper: true,
        useLower: true,
        useDigits: true,
        useSymbols: true,
        excludeAmbiguous: true,
      );
    });
  }

  Color _strengthColor(String strength) {
    switch (strength) {
      case 'Weak':
        return Colors.red;
      case 'Fair':
        return Colors.orange;
      case 'Good':
        return Colors.yellow;
      case 'Strong':
        return Colors.green;
      case 'Very Strong':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _addTag() {
    showDialog(
      context: context,
      builder: (_) => _AddTagDialog(onAdd: (tag) {
        setState(() => _tags.add(tag));
      }),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final fields = <String, String>{};
      for (final entry in _fieldControllers.entries) {
        if (entry.value.text.isNotEmpty) {
          fields[entry.key] = entry.value.text;
        }
      }

      if (widget.existingEntry != null) {
        final updated = widget.existingEntry!.copyWith(
          name: _nameController.text.trim(),
          fields: fields,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          tags: List.from(_tags),
        );
        await widget.vaultService.updateEntry(updated);
      } else {
        await widget.vaultService.addEntry(
          name: _nameController.text.trim(),
          type: _selectedType,
          fields: fields,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          tags: List.from(_tags),
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _fieldLabel(String key) {
    switch (key) {
      case 'username':
        return 'Username';
      case 'password':
        return 'Password';
      case 'url':
        return 'Website URL';
      case 'cardNumber':
        return 'Card Number';
      case 'expiryDate':
        return 'Expiry Date (MM/YY)';
      case 'cvv':
        return 'CVV';
      case 'cardholderName':
        return 'Cardholder Name';
      case 'bankName':
        return 'Bank Name';
      case 'secret':
        return 'TOTP Secret Key';
      case 'issuer':
        return 'Issuer';
      case 'accountName':
        return 'Account Name';
      case 'firstName':
        return 'First Name';
      case 'lastName':
        return 'Last Name';
      case 'email':
        return 'Email';
      case 'phone':
        return 'Phone';
      case 'address':
        return 'Address';
      case 'apiKey':
        return 'API Key';
      case 'baseUrl':
        return 'Base URL';
      case 'accountNumber':
        return 'Account Number';
      case 'routingNumber':
        return 'Routing Number';
      case 'swiftCode':
        return 'SWIFT Code';
      case 'iban':
        return 'IBAN';
      default:
        return key;
    }
  }
}

class _AddTagDialog extends StatefulWidget {
  final ValueChanged<String> onAdd;

  const _AddTagDialog({required this.onAdd});

  @override
  State<_AddTagDialog> createState() => _AddTagDialogState();
}

class _AddTagDialogState extends State<_AddTagDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Tag'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'Tag name',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_controller.text.trim().isNotEmpty) {
              widget.onAdd(_controller.text.trim());
              Navigator.of(context).pop();
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
