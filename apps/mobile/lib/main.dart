import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'src/shell/home_shell.dart';
import 'src/onboarding/welcome_page.dart';
import 'src/onboarding/phone_entry_page.dart';
import 'src/onboarding/verification_page.dart';
import 'src/onboarding/username_page.dart';
import 'src/onboarding/tour_page.dart';
import 'src/onboarding/auth_page.dart';
import 'src/core/modules/app_module.dart';
import 'src/core/modules/feed_module.dart';
import 'src/core/modules/chat_module.dart';
import 'src/core/modules/discover_module.dart';
import 'src/core/modules/notifications_module.dart';
import 'src/core/modules/profile_module.dart';
import 'src/core/services/session_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DexChatsApp());
}

class DexChatsApp extends StatefulWidget {
  const DexChatsApp({super.key});

  @override
  State<DexChatsApp> createState() => _DexChatsAppState();
}

class _DexChatsAppState extends State<DexChatsApp> {
  late List<AppModule> _modules;
  late ModuleRouter _moduleRouter;
  final _session = SessionService();
  bool _isCheckingSession = true;
  bool _hasSession = false;

  @override
  void initState() {
    super.initState();
    _modules = _createModules();
    _moduleRouter = ModuleRouter(_modules);
    _checkSession();
  }

  Future<void> _checkSession() async {
    final hasSession = await _session.tryRestore();
    if (mounted) {
      setState(() {
        _hasSession = hasSession;
        _isCheckingSession = false;
      });
    }
  }

  List<AppModule> _createModules() {
    return [
      FeedModule(),
      ChatModule(),
      DiscoverModule(),
      NotificationsModule(),
      ProfileModule(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DexChats',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      routerConfig: _buildRouter(),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData.dark(useMaterial3: true).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6C63FF),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0D0D0D),
    );
  }

  GoRouter _buildRouter() {
    final baseRoutes = [
      // If checking session, show no route (splash will handle)
      GoRoute(
        path: '/',
        builder: (_, __) {
          if (_isCheckingSession) {
            return const _SplashScreen();
          }
          if (_hasSession) {
            // Already logged in — go to home
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/home');
            });
            return const _SplashScreen();
          }
          return const WelcomePage();
        },
      ),
      GoRoute(
        path: '/tour',
        builder: (_, __) => const TourPage(),
      ),
      GoRoute(
        path: '/auth',
        builder: (_, state) => AuthPage(
          mode: state.extra as String? ?? 'register',
        ),
      ),
      GoRoute(
        path: '/onboarding/phone',
        builder: (_, __) => const PhoneEntryPage(),
      ),
      GoRoute(
        path: '/onboarding/verify',
        builder: (_, state) => VerificationPage(
          phoneNumber: state.extra as String,
        ),
      ),
      GoRoute(
        path: '/onboarding/username',
        builder: (_, state) => UsernamePage(
          phoneNumber: state.extra as String,
        ),
      ),
      GoRoute(
        path: '/browser',
        builder: (_, state) => BrowserPage(
          initialUrl: state.extra as String? ?? 'https://dexchats.io',
        ),
      ),
    ];

    final allRoutes = _moduleRouter.build(baseRoutes);

    return GoRouter(
      initialLocation: '/',
      routes: [
        ...allRoutes,
        GoRoute(
          path: '/home',
          builder: (_, __) => HomeShell(modules: _modules),
        ),
      ],
    );
  }
}

/// Brief splash while checking for existing session.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

// Browser page re-export for the router
class BrowserPage extends StatelessWidget {
  final String initialUrl;
  const BrowserPage({super.key, required this.initialUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(initialUrl)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.language, size: 64),
            const SizedBox(height: 16),
            Text('Browser module not connected',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(initialUrl, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
