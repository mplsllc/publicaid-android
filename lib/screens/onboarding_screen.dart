import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../theme.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final LocationService locationService;
  final AuthService authService;
  final ApiService apiService;
  final Future<void> Function({Widget? then}) onComplete;

  const OnboardingScreen({
    super.key,
    required this.locationService,
    required this.authService,
    required this.apiService,
    required this.onComplete,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pageCount = 4;

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _requestLocation() async {
    await widget.locationService.requestPermission();
    _next();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.5, -0.87),
            end: Alignment(0.5, 0.87),
            colors: [Color(0xFF0D3B6E), Color(0xFF1565C0)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    _WelcomePage(onNext: _next),
                    _FeaturesPage(onNext: _next),
                    _LocationPage(onRequest: _requestLocation),
                    _ReadyPage(
                      onSignIn: () => widget.onComplete(
                        then: LoginScreen(
                          authService: widget.authService,
                          apiService: widget.apiService,
                        ),
                      ),
                      onBrowse: () => widget.onComplete(),
                    ),
                  ],
                ),
              ),
              _DotIndicator(count: _pageCount, current: _page),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 1 — Welcome
// ---------------------------------------------------------------------------

class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;
  const _WelcomePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/logo-light.png', height: 48),
          const SizedBox(height: 40),
          const Text(
            'Welcome to Publicaid',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'InstrumentSerif',
              fontSize: 32,
              fontWeight: FontWeight.w400,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Find help near you — a national directory of social services',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 56),
          _PrimaryButton(label: 'Get Started', onPressed: onNext),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 2 — Features
// ---------------------------------------------------------------------------

class _FeaturesPage extends StatelessWidget {
  final VoidCallback onNext;
  const _FeaturesPage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    const features = [
      (Icons.search_rounded, 'Find services near you'),
      (Icons.bookmark_border_rounded, 'Save and organize services'),
      (Icons.checklist_rounded, 'Build a personal action plan'),
      (Icons.folder_outlined, 'Store important documents securely'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What you can do',
            style: TextStyle(
              fontFamily: 'InstrumentSerif',
              fontSize: 28,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          ...features.map((f) => _FeatureRow(icon: f.$1, label: f.$2)),
          const SizedBox(height: 48),
          _PrimaryButton(label: 'Next', onPressed: onNext),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'DMSans',
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 3 — Location permission
// ---------------------------------------------------------------------------

class _LocationPage extends StatelessWidget {
  final Future<void> Function() onRequest;
  const _LocationPage({required this.onRequest});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Find services near you',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'InstrumentSerif',
              fontSize: 28,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'We only use your location to show nearby results. It\'s never shared.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),
          _PrimaryButton(label: 'Enable Location', onPressed: onRequest),
          const SizedBox(height: 16),
          _SkipButton(
            label: 'Skip',
            onPressed: onRequest, // advances to next page either way
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 4 — Ready
// ---------------------------------------------------------------------------

class _ReadyPage extends StatelessWidget {
  final VoidCallback onSignIn;
  final VoidCallback onBrowse;
  const _ReadyPage({required this.onSignIn, required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            "You're all set!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'InstrumentSerif',
              fontSize: 32,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Sign in to sync bookmarks across devices, or start browsing now.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),
          _PrimaryButton(label: 'Sign In', onPressed: onSignIn),
          const SizedBox(height: 16),
          _SkipButton(label: 'Start Browsing', onPressed: onBrowse),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _PrimaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.navyBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'DMSans',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _SkipButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'DMSans',
          fontSize: 15,
          color: Colors.white.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _DotIndicator extends StatelessWidget {
  final int count;
  final int current;
  const _DotIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: i == current ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: i == current
                ? Colors.white
                : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
