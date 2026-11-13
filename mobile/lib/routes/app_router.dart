import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/controller/auth_controller.dart';
import '../features/auth/models/password_reset_flow.dart';
import '../features/auth/view/password_reset_page.dart';
import '../features/auth/view/register_page.dart';
import '../features/companion/view/companion_page.dart';
import '../features/doctor/view/doctor_page.dart';
import '../features/mother/view/mother_page.dart';
import '../features/mother/view/mother_chat_page.dart';
import '../features/mother/view/mother_calendar_page.dart';
import '../features/mother/view/mother_story_detail_page.dart';
import '../features/mother/view/mother_meditation_pages.dart';
import '../features/mother/models/mother_story.dart';
import '../features/mother/view/mother_profile_page.dart';
import '../features/mother/view/mother_profile_edit_page.dart';
import '../features/auth/view/login_page.dart';
import '../features/shared/view/role_picker_page.dart';
import '../features/shared/view/route_error_page.dart';
import '../features/shared/view/splash_page.dart';
import '../models/app_role.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider).asData?.value;
      if (auth == null) {
        return state.uri.path == '/' || _roleForLocation(state.uri.path) != null
            ? '/roles'
            : null;
      }
      final session = auth.session;
      final location = state.uri.path;
      final routeRole = _roleForLocation(location);

      if (location == '/') {
        return session?.user.role?.location ?? '/roles';
      }

      if (session != null) {
        final role = session.user.role;
        if (role == null) return '/unauthorized';
        if (location == '/splash' ||
            location == '/roles' ||
            location == '/login' ||
            location == '/register' ||
            _isPasswordResetLocation(location)) {
          return role.location;
        }
        if (routeRole != null && routeRole != role) {
          return '/unauthorized';
        }
        return null;
      }

      if (routeRole != null) return '/login';
      if (location == '/login' && auth.selectedRole == null) return '/roles';
      if (location == '/register' && auth.selectedRole == null) return '/roles';
      if ((location == '/verify-reset-code' || location == '/new-password') &&
          state.extra is! PasswordResetFlow) {
        return '/reset-password';
      }
      if (location == '/roles' ||
          location == '/login' ||
          location == '/unauthorized') {
        return null;
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const Scaffold()),
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(
        path: '/roles',
        builder: (context, state) => const RolePickerPage(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) =>
            const PasswordResetPage(stage: PasswordResetStage.email),
      ),
      GoRoute(
        path: '/verify-reset-code',
        builder: (context, state) {
          final flow = state.extra;
          return PasswordResetPage(
            stage: PasswordResetStage.code,
            flow: flow is PasswordResetFlow ? flow : null,
          );
        },
      ),
      GoRoute(
        path: '/new-password',
        builder: (context, state) {
          final flow = state.extra;
          return PasswordResetPage(
            stage: PasswordResetStage.newPassword,
            flow: flow is PasswordResetFlow ? flow : null,
          );
        },
      ),
      GoRoute(
        path: '/unauthorized',
        builder: (context, state) => const RouteErrorPage(
          title: 'Akses tidak tersedia',
          message: 'Akun ini tidak memiliki akses ke halaman tersebut.',
        ),
      ),
      GoRoute(
        path: '/mother',
        builder: (context, state) => MotherPage(
          showWeeklyEpds: state.uri.queryParameters['epds'] == 'due',
        ),
      ),
      GoRoute(
        path: '/mother/meditation',
        builder: (context, state) => const MotherMeditationListPage(),
      ),
      GoRoute(
        path: '/mother/chat',
        builder: (context, state) => const MotherChatPage(),
      ),
      GoRoute(
        path: '/mother/calendar',
        builder: (context, state) => const MotherCalendarPage(),
      ),
      GoRoute(
        path: '/mother/profile',
        builder: (context, state) => const MotherProfilePage(),
      ),
      GoRoute(
        path: '/mother/profile/edit',
        builder: (context, state) => const MotherProfileEditPage(),
      ),
      GoRoute(
        path: '/mother/calendar/story',
        builder: (context, state) {
          final story = state.extra;
          return MotherStoryDetailPage(
            story: story is MotherStory ? story : null,
          );
        },
      ),
      GoRoute(
        path: '/mother/meditation/breathing',
        builder: (context, state) => const MotherBreathingSessionPage(),
      ),
      GoRoute(
        path: '/companion',
        builder: (context, state) => const CompanionPage(),
      ),
      GoRoute(path: '/doctor', builder: (context, state) => const DoctorPage()),
    ],
    errorBuilder: (context, state) =>
        const RouteErrorPage(message: 'Route not found'),
  );
  ref.listen(authControllerProvider, (previous, next) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
});

AppRole? _roleForLocation(String location) {
  for (final role in AppRole.values) {
    if (role.location == location || location.startsWith('${role.location}/')) {
      return role;
    }
  }
  return null;
}

bool _isPasswordResetLocation(String location) =>
    location == '/reset-password' ||
    location == '/verify-reset-code' ||
    location == '/new-password';
