import 'package:flutter/material.dart';
import '../../utils/theme.dart';

class MasterPasswordDialog extends StatefulWidget {
  final bool isCreating;
  final Function(String) onSubmit;

  const MasterPasswordDialog({
    super.key,
    required this.isCreating,
    required this.onSubmit,
  });

  @override
  State<MasterPasswordDialog> createState() => _MasterPasswordDialogState();
}

class _MasterPasswordDialogState extends State<MasterPasswordDialog> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _passwordController.text;

    if (widget.isCreating) {
      if (password.length < 6) {
        setState(() {
          _error = 'Password must be at least 6 characters';
        });
        return;
      }

      if (password != _confirmController.text) {
        setState(() {
          _error = 'Passwords do not match';
        });
        return;
      }
    }

    widget.onSubmit(password);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.lock, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text(widget.isCreating
              ? 'Create Master Password'
              : 'Enter Master Password'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isCreating)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'This password will be used to encrypt your server credentials. Make sure to remember it!',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofocus: true,
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
            onSubmitted: (_) {
              if (!widget.isCreating) {
                _submit();
              }
            },
          ),
          if (widget.isCreating) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _confirmController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirm = !_obscureConfirm;
                    });
                  },
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.errorColor),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 16,
                    color: AppTheme.errorColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(widget.isCreating ? 'Create' : 'Unlock'),
        ),
      ],
    );
  }
}
