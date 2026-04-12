import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/map/map_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/splash/splash_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => SplashScreen(
        onComplete: () async {
          final prefs = await SharedPreferences.getInstance();
          final seen = prefs.getBool('onboarding_seen') ?? false;
          appRouter.go(seen ? '/' : '/onboarding');
        },
      ),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => OnboardingScreen(
        onComplete: () => appRouter.go('/'),
      ),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const MapScreen(),
    ),
  ],
);
