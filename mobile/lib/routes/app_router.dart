import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/controller/role_session_controller.dart';
import '../features/companion/view/companion_page.dart';
import '../features/doctor/view/doctor_page.dart';
import '../features/mother/view/mother_page.dart';
import '../features/shared/view/role_picker_page.dart';
import '../features/shared/view/route_error_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      if (state.uri.path != '/') return null;
      final role = await ref.read(roleSessionProvider.future);
      return role?.location ?? '/roles';
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(
        path: '/roles',
        builder: (context, state) => const RolePickerPage(),
      ),
      GoRoute(path: '/mother', builder: (context, state) => const MotherPage()),
      GoRoute(
        path: '/companion',
        builder: (context, state) => const CompanionPage(),
      ),
      GoRoute(path: '/doctor', builder: (context, state) => const DoctorPage()),
    ],
    errorBuilder: (context, state) =>
        RouteErrorPage(message: state.error?.toString() ?? 'Route not found'),
  );
  ref.onDispose(router.dispose);
  return router;
});
