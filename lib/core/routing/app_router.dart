import 'package:go_router/go_router.dart';
import '../../features/map/map_screen.dart';
import '../../features/splash/splash_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => SplashScreen(
        onComplete: () => appRouter.go('/'),
      ),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const MapScreen(),
    ),
  ],
);
