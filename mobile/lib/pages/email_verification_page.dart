import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// Holds password-authenticated members just before discoverability until the
/// email address that represents their account has been verified.
class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({
    super.key,
    required this.email,
    this.onVerified,
  });
  final String? email;
  final VoidCallback? onVerified;

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool _working = false;
  String? _message;

  Future<void> _resend() async {
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      await AuthService.instance.resendEmailVerification();
      if (mounted) {
        setState(() => _message = 'Verification email sent.');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'We could not send another email yet. Please try again shortly.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _checkVerification() async {
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      final verified = await AuthService.instance.reloadEmailVerification();
      if (verified) {
        widget.onVerified?.call();
      } else if (mounted) {
        setState(
          () => _message =
              'Not verified yet. Open the link in your email, then check again.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.mark_email_read_outlined, size: 52),
                const SizedBox(height: 24),
                Text(
                  'Verify your email',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'We sent a verification link to ${widget.email ?? 'your email address'}. Verify it before turning on nearby discovery. If you don’t see it, check your spam or junk folder.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.4),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 18),
                  Text(
                    _message!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _working ? null : _checkVerification,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: _working
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('I verified my email'),
                ),
                TextButton(
                  onPressed: _working ? null : _resend,
                  child: const Text('Resend verification email'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
