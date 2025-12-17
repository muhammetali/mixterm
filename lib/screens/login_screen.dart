import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../utils/theme.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const LoginScreen({super.key, required this.onUnlocked});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isCreating = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkIfCreating();
  }

  void _checkIfCreating() {
    final storage = context.read<StorageService>();
    setState(() {
      _isCreating = !storage.hasMasterPassword;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });

    final storage = context.read<StorageService>();
    final password = _passwordController.text;

    if (_isCreating) {
      if (password.length < 6) {
        setState(() {
          _error = 'Password must be at least 6 characters';
          _isLoading = false;
        });
        return;
      }

      if (password != _confirmController.text) {
        setState(() {
          _error = 'Passwords do not match';
          _isLoading = false;
        });
        return;
      }

      await storage.setMasterPassword(password);
      widget.onUnlocked();
    } else {
      if (storage.verifyMasterPassword(password)) {
        widget.onUnlocked();
      } else {
        setState(() {
          _error = 'Incorrect password';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.terminal,
                size: 64,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                'MixTerm',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _isCreating
                    ? 'Create a master password to secure your data'
                    : 'Enter your master password to unlock',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Master Password',
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
                  if (!_isCreating) {
                    _submit();
                  }
                },
              ),
              if (_isCreating) ...[
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.errorColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppTheme.errorColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppTheme.errorColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isCreating ? 'Create Password' : 'Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
