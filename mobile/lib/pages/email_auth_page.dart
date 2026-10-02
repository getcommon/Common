import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// Email/password sign-in and account creation live together so switching
/// between the two never loses the welcome screen's provider choices.
class EmailAuthPage extends StatefulWidget {
  const EmailAuthPage({super.key});

  @override
  State<EmailAuthPage> createState() => _EmailAuthPageState();
}

class _EmailAuthPageState extends State<EmailAuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _creatingAccount = false;
  bool _obscurePassword = true;
  bool _working = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      if (_creatingAccount) {
        await AuthService.instance.createAccountWithEmail(
          email: _email.text,
          password: _password.text,
        );
      } else {
        await AuthService.instance.signInWithEmail(
          email: _email.text,
          password: _password.text,
        );
      }
      // BootstrapGate advances after Firebase auth changes.
    } on AuthFlowException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _message = 'Enter your email address first.');
      return;
    }
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      await AuthService.instance.sendPasswordResetEmail(email);
      if (mounted) {
        setState(
          () => _message =
              'If an account exists for that email, we sent a reset link.',
        );
      }
    } on AuthFlowException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Common Grounds')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _creatingAccount
                          ? 'Create your account'
                          : 'Sign in with email',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _creatingAccount
                          ? 'Use an email you can access. We’ll ask you to verify it before you can appear in Discover.'
                          : 'Welcome back. Enter the email and password for your account.',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return 'Enter your email address.';
                        if (!email.contains('@') || !email.contains('.')) {
                          return 'Enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscurePassword,
                      textInputAction: _creatingAccount
                          ? TextInputAction.next
                          : TextInputAction.done,
                      autofillHints: [
                        _creatingAccount
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      onFieldSubmitted: (_) =>
                          _creatingAccount ? null : _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        helperText: _creatingAccount
                            ? 'At least 8 characters'
                            : null,
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').isEmpty) {
                          return 'Enter your password.';
                        }
                        if (_creatingAccount && value!.length < 8) {
                          return 'Use at least 8 characters.';
                        }
                        return null;
                      },
                    ),
                    if (_creatingAccount) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmation,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                        ),
                        validator: (value) => value != _password.text
                            ? 'Passwords do not match.'
                            : null,
                      ),
                    ],
                    if (_message != null) ...[
                      const SizedBox(height: 20),
                      Text(
                        _message!,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _working ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: _working
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _creatingAccount ? 'Create account' : 'Sign in',
                            ),
                    ),
                    if (!_creatingAccount)
                      TextButton(
                        onPressed: _working ? null : _resetPassword,
                        child: const Text('Forgot password?'),
                      ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: _working
                            ? null
                            : () => setState(() {
                                _creatingAccount = !_creatingAccount;
                                _message = null;
                              }),
                        child: Text(
                          _creatingAccount
                              ? 'Already have an account? Sign in'
                              : 'New here? Create an account',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
