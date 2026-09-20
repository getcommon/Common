import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';
import '../services/auth_service.dart';

/// The signed-out front door. Authentication stays here so the bootstrap gate
/// can continue to react to authStateChanges without navigation work in the UI.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  String? _error;
  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.signInWithGoogle();
      // BootstrapGate reacts to authStateChanges and handles the next route.
    } catch (error) {
      debugPrint('Google sign-in failed: $error');
      if (mounted) setState(() => _error = 'Google sign-in failed: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.signInWithApple();
      // BootstrapGate reacts to authStateChanges and handles the next route.
    } catch (error) {
      debugPrint('Apple sign-in failed: $error');
      if (mounted) setState(() => _error = 'Apple sign-in failed: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open link')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final horizontalPadding = size.width >= 700 ? 64.0 : 24.0;
    final contentWidth = size.width >= 700 ? 500.0 : double.infinity;
    final supportsAppleSignIn = !kIsWeb && (Platform.isIOS || Platform.isMacOS);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF241E1B), AppColors.backgroundDark]
                : const [Color(0xFFFFFCFA), AppColors.backgroundLight],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentWidth),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _entranceController,
                  curve: Curves.easeOut,
                ),
                child: SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, .035),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _entranceController,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      16,
                      horizontalPadding,
                      28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Wordmark(),
                        SizedBox(height: size.height < 700 ? 28 : 48),
                        const _EditorialPortrait(),
                        const SizedBox(height: 26),
                        Text(
                          'A little more\n+common ground.',
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                color: colors.onSurface,
                                fontSize: 37,
                                height: 1.08,
                                letterSpacing: -1.35,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Meet people nearby who share the things that make a day feel more like yours.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                                height: 1.45,
                                letterSpacing: .1,
                              ),
                        ),
                        SizedBox(height: size.height < 700 ? 26 : 36),
                        if (_error != null) ...[
                          _SignInError(message: _error!),
                          const SizedBox(height: 14),
                        ],
                        _AuthButton(
                          onPressed: _loading ? null : _handleGoogleSignIn,
                          loading: _loading,
                          icon: const FaIcon(FontAwesomeIcons.google, size: 18),
                          label: 'Continue with Google',
                          backgroundColor: isDark
                              ? AppColors.surfaceDark
                              : AppColors.surfaceLight,
                          foregroundColor: colors.onSurface,
                          borderColor: isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight,
                        ),
                        if (supportsAppleSignIn) ...[
                          const SizedBox(height: 12),
                          _AuthButton(
                            onPressed: _loading ? null : _handleAppleSignIn,
                            loading: _loading,
                            icon: const FaIcon(
                              FontAwesomeIcons.apple,
                              size: 20,
                            ),
                            label: 'Continue with Apple',
                            backgroundColor: isDark
                                ? AppColors.textPrimaryDark
                                : const Color(0xFF241E1C),
                            foregroundColor: isDark
                                ? AppColors.backgroundDark
                                : Colors.white,
                            borderColor: Colors.transparent,
                          ),
                        ],
                        const SizedBox(height: 20),
                        _TermsAndPrivacy(
                          isDark: isDark,
                          onTermsTap: () =>
                              _launchUrl('https://commongrounds.app/terms'),
                          onPrivacyTap: () =>
                              _launchUrl('https://commongrounds.app/privacy'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'C',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Common',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
            fontSize: 21,
            fontWeight: FontWeight.w600,
            letterSpacing: -.45,
          ),
        ),
      ],
    );
  }
}

class _EditorialPortrait extends StatelessWidget {
  const _EditorialPortrait();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: AspectRatio(
        aspectRatio: 1.25,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/eren_editorial_portrait.png',
              fit: BoxFit.cover,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x800D0908)],
                  stops: [.38, 1],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 15,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFCFD69F),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Real people, meaningful overlap',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignInError extends StatelessWidget {
  const _SignInError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: .09),
        border: Border.all(color: AppColors.error.withValues(alpha: .25)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.onPressed,
    required this.loading,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
  });

  final VoidCallback? onPressed;
  final bool loading;
  final Widget icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: borderColor),
          ),
        ),
        child: loading
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  color: foregroundColor,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconTheme(
                    data: IconThemeData(color: foregroundColor),
                    child: icon,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: foregroundColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TermsAndPrivacy extends StatelessWidget {
  const _TermsAndPrivacy({
    required this.isDark,
    required this.onTermsTap,
    required this.onPrivacyTap,
  });

  final bool isDark;
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  @override
  Widget build(BuildContext context) {
    final muted = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: muted, height: 1.45);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          const TextSpan(text: 'By continuing, you agree to our '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _InlineLink(label: 'Terms', onTap: onTermsTap),
          ),
          const TextSpan(text: ' and '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _InlineLink(label: 'Privacy Policy', onTap: onPrivacyTap),
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _InlineLink extends StatelessWidget {
  const _InlineLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.primary.withValues(alpha: .55),
        ),
      ),
    );
  }
}
