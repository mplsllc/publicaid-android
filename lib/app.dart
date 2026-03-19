import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'services/deep_link_service.dart';
import 'services/auth_service.dart';
import 'services/bookmark_service.dart';
import 'services/location_service.dart';
import 'services/plan_service.dart';
import 'services/vault_service.dart';
import 'services/notification_service.dart';
import 'screens/plan_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/guide_screen.dart';
import 'screens/blog_screen.dart';
import 'screens/crisis_screen.dart';
import 'screens/account_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/detail_screen.dart';
import 'screens/docs_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/vault_setup_screen.dart';
import 'widgets/bottom_nav.dart';
import 'theme.dart';

class PublicaidApp extends StatefulWidget {
  const PublicaidApp({super.key});

  @override
  State<PublicaidApp> createState() => _PublicaidAppState();
}

class _PublicaidAppState extends State<PublicaidApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final ApiService _apiService;
  late final AuthService _authService;
  late final BookmarkService _bookmarkService;
  late final PlanService _planService;
  late final VaultService _vaultService;
  late final NotificationService _notificationService;
  late final LocationService _locationService;
  late final DeepLinkService _deepLinkService;
  StreamSubscription<Uri>? _deepLinkSub;
  final _tabNotifier = ValueNotifier<int>(-1);
  bool _initialized = false;
  bool _hasOnboarded = false;
  bool _vaultSetupOffered = false;
  bool _wasLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _authService = AuthService(_apiService);
    _bookmarkService = BookmarkService(_apiService, _authService);
    _planService = PlanService(_apiService, _authService);
    _vaultService = VaultService();
    _notificationService = NotificationService();
    _bookmarkService.setNotificationService(_notificationService);
    _locationService = LocationService();

    _authService.addListener(_onAuthChanged);
    _initialize();
  }

  Future<void> _initialize() async {
    await _locationService.init();
    await _authService.init();
    await _bookmarkService.init();
    await _planService.init();
    _vaultService.setAuthToken(_authService.token);
    _wasLoggedIn = _authService.token != null;

    final prefs = await SharedPreferences.getInstance();
    final hasOnboarded = prefs.getBool('has_onboarded') ?? false;

    // Notification permission is deferred to the onboarding completion handler
    // for new users, so they understand the app before being prompted.
    if (hasOnboarded) {
      await _notificationService.init();
    }

    _notificationService.onNotificationTap = (entityId, entityName) {
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => DetailScreen(
            apiService: _apiService,
            entityId: entityId,
            entityName: entityName,
            bookmarkService: _bookmarkService,
            authService: _authService,
            planService: _planService,
            locationService: _locationService,
          ),
        ),
      );
    };

    // Deep links
    _deepLinkService = DeepLinkService(
      apiService: _apiService,
      locationService: _locationService,
      authService: _authService,
      bookmarkService: _bookmarkService,
      planService: _planService,
      navigatorKey: _navigatorKey,
      switchTab: _switchToTab,
    );

    // Cold-start: check if app was launched from a deep link
    final appLinks = AppLinks();
    final initialUri = await appLinks.getInitialLink();
    if (initialUri != null) {
      _deepLinkService.handleUri(initialUri);
    }

    // Warm: listen for deep links while app is running
    _deepLinkSub = appLinks.uriLinkStream.listen((uri) {
      _deepLinkService.handleUri(uri);
    });

    if (mounted) {
      setState(() {
        _initialized = true;
        _hasOnboarded = hasOnboarded;
      });

      // Show vault setup for logged-in users who haven't created a vault yet
      if (_authService.token != null && !await _vaultService.hasSalt()) {
        _vaultSetupOffered = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) =>
                    VaultSetupScreen(vaultService: _vaultService),
              ),
            );
          }
        });
      }
    }
  }

  void _switchToTab(int index) {
    // Pop back to root if needed, then switch tab via notifier
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    _tabNotifier.value = index;
  }

  void _onAuthChanged() async {
    _bookmarkService.onAuthChanged();
    _planService.onAuthChanged();
    _vaultService.setAuthToken(_authService.token);

    if (_authService.token == null) {
      // Only clear vault keys on explicit logout (was logged in, now isn't).
      // Don't clear on app start when token is null — that would destroy
      // vault keys needed for recovery on reinstall.
      if (_wasLoggedIn) {
        await _vaultService.clearLocal();
      }
      _wasLoggedIn = false;
      _vaultSetupOffered = false;
      return;
    }
    _wasLoggedIn = true;

    if (_initialized && !_vaultSetupOffered && !await _vaultService.hasSalt()) {
      _vaultSetupOffered = true;
      if (mounted) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => VaultSetupScreen(vaultService: _vaultService),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    _authService.removeListener(_onAuthChanged);
    _authService.dispose();
    _bookmarkService.dispose();
    _planService.dispose();
    _locationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Publicaid',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: !_initialized
          ? const _SplashScreen()
          : !_hasOnboarded
              ? OnboardingScreen(
                  locationService: _locationService,
                  authService: _authService,
                  apiService: _apiService,
                  onComplete: ({Widget? then}) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('has_onboarded', true);
                    await _notificationService.init();
                    if (mounted) {
                      setState(() => _hasOnboarded = true);
                      if (then != null) {
                        _navigatorKey.currentState?.push(
                          MaterialPageRoute(builder: (_) => then),
                        );
                      }
                    }
                  },
                )
              : _AppShell(
                  apiService: _apiService,
                  authService: _authService,
                  bookmarkService: _bookmarkService,
                  planService: _planService,
                  vaultService: _vaultService,
                  locationService: _locationService,
                  tabNotifier: _tabNotifier,
                ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo-light.png',
              height: 40,
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppShell extends StatefulWidget {
  final ApiService apiService;
  final AuthService authService;
  final BookmarkService bookmarkService;
  final PlanService planService;
  final VaultService vaultService;
  final LocationService locationService;
  final ValueNotifier<int> tabNotifier;

  const _AppShell({
    required this.apiService,
    required this.authService,
    required this.bookmarkService,
    required this.planService,
    required this.vaultService,
    required this.locationService,
    required this.tabNotifier,
  });

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    widget.tabNotifier.addListener(_onTabSwitch);
    _screens = [
      HomeScreen(
        apiService: widget.apiService,
        locationService: widget.locationService,
        authService: widget.authService,
        bookmarkService: widget.bookmarkService,
        planService: widget.planService,
        onSwitchTab: (index) => setState(() => _currentIndex = index),
        onOpenAccount: () => _handleMenuNav('account'),
      ),
      SearchScreen(
        apiService: widget.apiService,
        locationService: widget.locationService,
        authService: widget.authService,
        bookmarkService: widget.bookmarkService,
        planService: widget.planService,
      ),
      GuideScreen(
        apiService: widget.apiService,
        locationService: widget.locationService,
        onNavigate: _handleMenuNav,
        authService: widget.authService,
      ),
      BlogScreen(
        apiService: widget.apiService,
        locationService: widget.locationService,
        onNavigate: _handleMenuNav,
        authService: widget.authService,
      ),
      CrisisScreen(
        onNavigate: _handleMenuNav,
        authService: widget.authService,
      ),
    ];
  }

  @override
  void dispose() {
    widget.tabNotifier.removeListener(_onTabSwitch);
    super.dispose();
  }

  void _onTabSwitch() {
    final index = widget.tabNotifier.value;
    if (index >= 0 && index < _screens.length) {
      setState(() => _currentIndex = index);
    }
  }

  void _handleMenuNav(String route) {
    switch (route) {
      case 'home':
        setState(() => _currentIndex = 0);
        break;
      case 'login':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LoginScreen(
              authService: widget.authService,
              apiService: widget.apiService,
            ),
          ),
        );
        break;
      case 'account':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AccountScreen(
              authService: widget.authService,
              apiService: widget.apiService,
              planService: widget.planService,
              vaultService: widget.vaultService,
              onNavigate: _handleMenuNav,
            ),
          ),
        );
        break;
      case 'plan':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlanScreen(
              planService: widget.planService,
              apiService: widget.apiService,
              locationService: widget.locationService,
            ),
          ),
        );
        break;
      case 'register':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RegisterScreen(
              authService: widget.authService,
              apiService: widget.apiService,
            ),
          ),
        );
        break;
      case 'docs':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DocsScreen(onNavigate: _handleMenuNav),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: IndexedStack(
          key: ValueKey(_currentIndex),
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
