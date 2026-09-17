import 'package:flutter/material.dart';
import '../services/local_prefs.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// A short introduction to Common's friendship-first, privacy-safe premise.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // Listen to page changes without setState to avoid rebuilds
    _pageController.addListener(_updatePage);
  }

  void _updatePage() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage && mounted) {
      setState(() {
        _currentPage = page;
      });
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_updatePage);
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    // Don't call setState here to avoid rebuilding during swipe
  }

  Future<void> _completeOnboarding() async {
    await LocalPrefs.setOnboarded(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/welcome');
  }

  void _skipOnboarding() {
    _pageController.animateToPage(
      2, // Jump to last page
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button (top-right) - always rendered, visibility controlled
            SizedBox(
              height: 60,
              child: Visibility(
                visible: _currentPage < 2,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: TextButton(
                      onPressed: _skipOnboarding,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // PageView carousel
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: const [
                  _Slide1FindYourPeople(),
                  _Slide2MatchByInterests(),
                  _Slide3WaveAndConnect(),
                ],
              ),
            ),

            // Page indicators (dots)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: _currentPage == index ? 24 : 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? AppColors.primary
                          : (isDark
                                ? AppColors.textDisabledDark
                                : AppColors.textDisabledLight),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            // Get Started button - always rendered, visibility controlled
            SizedBox(
              height: 80,
              child: Visibility(
                visible: _currentPage == 2,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  child: FilledButton(
                    onPressed: _completeOnboarding,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Slide 1: Common ground
class _Slide1FindYourPeople extends StatelessWidget {
  const _Slide1FindYourPeople();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _buildSlide(
      context: context,
      isDark: isDark,
      emoji: '⌁',
      title: 'Common ground, nearby',
      subtitle:
          'Meet people close by when you share enough of the things that matter.',
      gradient1: AppColors.primary,
      gradient2: AppColors.secondary,
    );
  }
}

// Slide 2: Location privacy
class _Slide2MatchByInterests extends StatelessWidget {
  const _Slide2MatchByInterests();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _buildSlide(
      context: context,
      isDark: isDark,
      emoji: '·',
      title: 'Close, never precise',
      subtitle:
          'We use coarse proximity to introduce people. Your exact location is never shown.',
      gradient1: AppColors.secondary,
      gradient2: AppColors.primaryLight,
    );
  }
}

// Slide 3: Mutual connection
class _Slide3WaveAndConnect extends StatelessWidget {
  const _Slide3WaveAndConnect();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _buildSlide(
      context: context,
      isDark: isDark,
      emoji: '↗',
      title: 'Keep it mutual',
      subtitle:
          'A wave is a simple opening. Conversations begin only when it is returned.',
      gradient1: AppColors.primary,
      gradient2: AppColors.secondaryLight,
    );
  }
}

// Helper function to build slide layout
Widget _buildSlide({
  required BuildContext context,
  required bool isDark,
  required String emoji,
  required String title,
  required String subtitle,
  required Color gradient1,
  required Color gradient2,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Hero emoji with gradient background circle
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [gradient1, gradient2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient1.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 80, height: 1)),
          ),
        ),

        const SizedBox(height: 48),

        // Title
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            height: 1.2,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 16),

        // Subtitle
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            height: 1.5,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    ),
  );
}
