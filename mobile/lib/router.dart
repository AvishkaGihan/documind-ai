import 'package:documind_ai/features/auth/providers/auth_provider.dart';
import 'package:documind_ai/features/auth/screens/login_screen.dart';
import 'package:documind_ai/features/auth/screens/signup_screen.dart';
import 'package:documind_ai/features/chat/screens/chat_screen.dart';
import 'package:documind_ai/features/library/screens/library_screen.dart';
import 'package:documind_ai/features/settings/screens/settings_screen.dart';
import 'package:documind_ai/shared/widgets/app_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final initialLocationProvider = Provider<String>((ref) => '/library');

final appRouterProvider = Provider<GoRouter>((ref) {
  final initialLocation = ref.watch(initialLocationProvider);
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: initialLocation,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isAuthenticated = authState.value?.isAuthenticated ?? false;
      final isPublicRoute =
          location == '/auth/login' || location == '/auth/signup';
      final isProtectedRoute =
          location == '/library' ||
          location.startsWith('/chat/') ||
          location == '/settings';

      if (!isAuthenticated && isProtectedRoute) {
        return '/auth/login';
      }
      if (isAuthenticated && isPublicRoute) {
        return '/library';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (context, state) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            initialLocation: '/chat/active',
            routes: [
              GoRoute(
                path: '/chat/:documentId',
                builder: (context, state) {
                  final documentId =
                      state.pathParameters['documentId'] ?? 'active';
                  return ChatScreen(documentId: documentId);
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
