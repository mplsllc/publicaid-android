import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/bookmark_service.dart';
import 'services/location_service.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/guide_screen.dart';
import 'screens/blog_screen.dart';
import 'screens/account_screen.dart';
import 'widgets/bottom_nav.dart';
import 'theme.dart';

class PublicaidApp extends StatefulWidget {
  const PublicaidApp({super.key});

  @override
  State<PublicaidApp> createState() => _PublicaidAppState();
}

class _PublicaidAppState extends State<PublicaidApp> {
  late final ApiService _apiService;
  late final AuthService _authService;
  late final BookmarkService _bookmarkService;
  late final LocationService _locationService;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _authService = AuthService(_apiService);
    _bookmarkService = BookmarkService(_apiService, _authService);
    _locationService = LocationService();

    _authService.addListener(_onAuthChanged);
    _initialize();
  }

  Future<void> _initialize() async {
    await _locationService.init();
    await _authService.init();
    await _bookmarkService.init();
    if (mounted) setState(() => _initialized = true);
  }

  void _onAuthChanged() {
    _bookmarkService.onAuthChanged();
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    _authService.dispose();
    _bookmarkService.dispose();
    _locationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: AppColors.navyBlue,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    return MaterialApp(
      title: 'Publicaid',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: _initialized
          ? _AppShell(
              apiService: _apiService,
              authService: _authService,
              bookmarkService: _bookmarkService,
              locationService: _locationService,
            )
          : const _SplashScreen(),
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
  final LocationService locationService;

  const _AppShell({
    required this.apiService,
    required this.authService,
    required this.bookmarkService,
    required this.locationService,
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
    _screens = [
      HomeScreen(
        apiService: widget.apiService,
        locationService: widget.locationService,
        onSwitchTab: (index) => setState(() => _currentIndex = index),
        onOpenAccount: _openAccountScreen,
      ),
      SearchScreen(
        apiService: widget.apiService,
        locationService: widget.locationService,
      ),
      GuideScreen(
        apiService: widget.apiService,
        locationService: widget.locationService,
      ),
      BlogScreen(
        apiService: widget.apiService,
      ),
    ];
  }

  void _openAccountScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccountScreen(
          authService: widget.authService,
          apiService: widget.apiService,
        ),
      ),
    );
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
