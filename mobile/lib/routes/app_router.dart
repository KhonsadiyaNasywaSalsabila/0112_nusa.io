// File: lib/routes/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/map_explore_screen.dart';
import '../screens/zen_editor_screen.dart';
import '../screens/my_drafts_screen.dart';
import '../screens/place_hub_screen.dart';
import '../screens/bookmarks_screen.dart';
import '../screens/profile_screen.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../main.dart'; // Akses authBloc
import 'go_router_refresh_stream.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/', // Rute pertama kali aplikasi dibuka
  refreshListenable: GoRouterRefreshStream(authBloc.stream),
  redirect: (context, state) {
    final authState = authBloc.state;
    final isGoingToLogin = state.matchedLocation == '/login' || state.matchedLocation == '/register';
    final isGoingToSplash = state.matchedLocation == '/';
    final isGoingToMap = state.matchedLocation == '/map';

    // Jika masih mengecek (Initial / Loading di Splash Screen)
    if (authState is AuthInitial || isGoingToSplash) {
      if (authState is AuthAuthenticated || authState is AuthGuestMode) {
        return '/map';
      }
      if (authState is AuthUnauthenticated || authState is AuthError) {
        return '/login';
      }
      return null; // Biarkan di splash
    }

    // --- SATPAM KETAT (Profile, Drafts, Bookmarks, dll) ---
    // Berlaku bagi Unauthenticated atau GuestMode
    if (authState is AuthUnauthenticated || authState is AuthGuestMode) {
      // Jika Guest Mode sedang di halaman Login, langsung pindah ke Peta
      if (authState is AuthGuestMode && isGoingToLogin) {
        return '/map';
      }
      
      // Hanya izinkan Map untuk Guest
      if (authState is AuthGuestMode && isGoingToMap) return null;
      
      // Jika mencoba akses selain Map/Login, lempar ke login
      if (!isGoingToLogin) {
        return '/login';
      }
    }

    // --- SATPAM SANTAI (Sudah Login) ---
    if (authState is AuthAuthenticated) {
      if (isGoingToLogin || isGoingToSplash) return '/map';
    }

    return null; // Bebas lewat
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const LoginScreen(),
        transitionDuration: const Duration(milliseconds: 1200),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/map',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const MapExploreScreen(),
        transitionDuration: const Duration(milliseconds: 1200),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ),
    GoRoute(
      path: '/zen-editor',
      builder: (context, state) {
        // Menerima data draft (jika sedang mode Edit)
        final extra = state.extra as Map<String, dynamic>?;
        return ZenEditorScreen(draftData: extra);
      },
    ),
    GoRoute(
      path: '/my-drafts',
      builder: (context, state) => const MyDraftsScreen(),
    ),
    GoRoute(
      path: '/place-hub/:id',
      builder: (context, state) {
        final locationId = state.pathParameters['id']!;
        final theme = state.uri.queryParameters['theme'] ?? 'Semua';
        return PlaceHubScreen(locationId: locationId, initialTheme: theme);
      },
    ),
    GoRoute(
      path: '/bookmarks',
      builder: (context, state) => const BookmarksScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
  ],
);