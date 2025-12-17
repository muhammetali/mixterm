import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../models/server.dart';
import '../../providers/server_provider.dart';
import '../../utils/theme.dart';

class AddServerDialog extends StatefulWidget {
  final Server? server;

  const AddServerDialog({super.key, this.server});

  @override
  State<AddServerDialog> createState() => _AddServerDialogState();
}

class _AddServerDialogState extends State<AddServerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passphraseController = TextEditingController();
  final _groupController = TextEditingController();

  AuthType _authType = AuthType.password;
  String? _privateKey;
  String? _privateKeyPath;
  bool _obscurePassword = true;
  bool _obscurePassphrase = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.server != null) {
      _nameController.text = widget.server!.name;
      _hostController.text = widget.server!.host;
      _portController.text = widget.server!.port.toString();
      _usernameController.text = widget.server!.username;
      _passwordController.text = widget.server!.password ?? '';
      _passphraseController.text = widget.server!.passphrase ?? '';
      _groupController.text = widget.server!.group ?? '';
      _authType = widget.server!.authType;
      _privateKey = widget.server!.privateKey;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _passphraseController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  Future<void> _pickPrivateKey() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.path != null) {
        final content = await File(file.path!).readAsString();
        setState(() {
          _privateKey = content;
          _privateKeyPath = file.name;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final serverProvider = context.read<ServerProvider>();

    final server = Server(
      id: widget.server?.id,
      name: _nameController.text.trim(),
      host: _hostController.text.trim(),
      port: int.tryParse(_portController.text) ?? 22,
      username: _usernameController.text.trim(),
      password: _authType == AuthType.password
          ? _passwordController.text
          : null,
      privateKey: _authType == AuthType.key ? _privateKey : null,
      passphrase: _authType == AuthType.key
          ? _passphraseController.text
          : null,
      authType: _authType,
      group: _groupController.text.trim().isEmpty
          ? null
          : _groupController.text.trim(),
    );

    bool success;
    if (widget.server != null) {
      success = await serverProvider.updateServer(server);
    } else {
      success = await serverProvider.addServer(server);
    }

    setState(() {
      _isLoading = false;
    });

    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save server'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.server != null;

    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      isEditing ? Icons.edit : Icons.add,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEditing ? 'Edit Server' : 'Add Server',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'My Server',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _hostController,
                        decoration: const InputDecoration(
                          labelText: 'Host',
                          hintText: '192.168.1.1 or server.com',
                          prefixIcon: Icon(Icons.dns_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Host is required';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _portController,
                        decoration: const InputDecoration(
                          labelText: 'Port',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final port = int.tryParse(value);
                          if (port == null || port < 1 || port > 65535) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    hintText: 'root',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Username is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _groupController,
                  decoration: const InputDecoration(
                    labelText: 'Group (optional)',
                    hintText: 'Production, Development, etc.',
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Authentication',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<AuthType>(
                        title: const Text('Password'),
                        value: AuthType.password,
                        groupValue: _authType,
                        onChanged: (value) {
                          setState(() {
                            _authType = value!;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppTheme.primaryColor,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<AuthType>(
                        title: const Text('SSH Key'),
                        value: AuthType.key,
                        groupValue: _authType,
                        onChanged: (value) {
                          setState(() {
                            _authType = value!;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_authType == AuthType.password)
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (_authType == AuthType.password &&
                          (value == null || value.isEmpty)) {
                        return 'Password is required';
                      }
                      return null;
                    },
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: _pickPrivateKey,
                    icon: const Icon(Icons.key),
                    label: Text(
                      _privateKeyPath ?? 'Select Private Key',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                  if (_privateKey != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.successColor),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: AppTheme.successColor,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Private key loaded',
                            style: TextStyle(
                              color: AppTheme.successColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passphraseController,
                    obscureText: _obscurePassphrase,
                    decoration: InputDecoration(
                      labelText: 'Passphrase (optional)',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassphrase
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassphrase = !_obscurePassphrase;
                          });
                        },
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isEditing ? 'Save' : 'Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
