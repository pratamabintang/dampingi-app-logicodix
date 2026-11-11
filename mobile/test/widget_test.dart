import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/app.dart';
import 'package:mobile/core/widgets/app_empty.dart';
import 'package:mobile/core/widgets/app_error.dart';
import 'package:mobile/core/widgets/app_loading.dart';
import 'package:mobile/features/auth/repositories/mock_auth_repository.dart';
import 'package:mobile/features/auth/view/login_page.dart';
import 'package:mobile/features/auth/view/register_page.dart';
import 'package:mobile/features/companion/view/companion_page.dart';
import 'package:mobile/features/doctor/view/doctor_page.dart';
import 'package:mobile/features/mother/view/mother_page.dart';
import 'package:mobile/features/shared/view/role_picker_page.dart';
import 'package:mobile/features/shared/view/route_error_page.dart';
import 'package:mobile/features/shared/view/splash_page.dart';
import 'package:mobile/models/app_role.dart';
import 'package:mobile/services/role_repository.dart';

class _TestRoleRepository extends RoleRepository {
  @override
  Future<AppRole?> loadStartupRole() async => AppRole.mother;
}

void main() {
  Future<void> startApp(
    WidgetTester tester, {
    Duration mockLatency = Duration.zero,
    Size viewport = const Size(390, 844),
    bool waitForRolePicker = true,
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roleRepositoryProvider.overrideWithValue(_TestRoleRepository()),
          mockAuthRepositoryProvider.overrideWithValue(
            MockAuthRepository(latency: mockLatency),
          ),
        ],
        child: const DampingiApp(),
      ),
    );
    if (waitForRolePicker) {
      for (
        var attempt = 0;
        attempt < 30 && find.byKey(const Key('role-mother')).evaluate().isEmpty;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(RolePickerPage), findsOneWidget);
    }
  }

  Future<void> selectRoleAndOpenLogin(
    WidgetTester tester, {
    required String role,
  }) async {
    await tester.tap(find.byKey(Key('role-$role')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('role-login')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
  }

  Future<void> enterCredentials(
    WidgetTester tester, {
    required String email,
    required String password,
  }) async {
    await tester.enterText(find.byType(TextFormField).at(0), email);
    await tester.enterText(find.byType(TextFormField).at(1), password);
  }

  Future<void> tapLoginSubmit(WidgetTester tester) async {
    final submitButton = find.byKey(const Key('login-submit'));
    if (submitButton.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        submitButton,
        160,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    } else {
      await tester.ensureVisible(submitButton);
    }
    await tester.tap(submitButton);
  }

  testWidgets('login matches Figma content and keeps its actions working', (
    tester,
  ) async {
    await startApp(tester);
    await selectRoleAndOpenLogin(tester, role: 'mother');

    expect(find.text('DEBUG'), findsNothing);
    expect(
      Theme.of(tester.element(find.byType(LoginPage)))
          .textTheme
          .bodyLarge
          ?.fontFamily,
      GoogleFonts.dmSans().fontFamily,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('login-image-frame'))),
      Offset.zero,
    );
    expect(
      tester.getSize(find.byKey(const Key('login-image-frame'))),
      const Size(390, 489),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('login-panel'))),
      const Offset(5, 352),
    );
    expect(
      tester.getSize(find.byKey(const Key('login-panel'))),
      const Size(380, 492),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('login-email'))),
      const Offset(29, 466),
    );
    expect(
      tester.getSize(find.byKey(const Key('login-email'))),
      const Size(332, 70),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('login-password'))),
      const Offset(29, 560),
    );
    expect(
      tester.getSize(find.byKey(const Key('login-password'))),
      const Size(332, 70),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('login-actions'))),
      const Offset(29, 654),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('login-submit'))),
      const Offset(29, 696),
    );
    expect(
      tester.getSize(find.byKey(const Key('login-submit'))),
      const Size(332, 48),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('login-register-row'))),
      const Offset(29, 768),
    );

    expect(find.text('Dampingi'), findsOneWidget);
    expect(find.text('Halo, Senang melihatmu kembali!'), findsOneWidget);
    expect(find.text('Masukan email anda'), findsOneWidget);
    expect(find.text('Ingat saya'), findsOneWidget);
    expect(find.text('Lupa kata sandi?'), findsOneWidget);
    expect(find.text('Daftar sekarang'), findsOneWidget);
    expect(find.textContaining('demo1234'), findsNothing);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);

    await tester.tap(find.byKey(const Key('login-remember-me')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.tap(find.byKey(const Key('login-reset-password')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reset-email-page')), findsOneWidget);
  });

  testWidgets('login registration link opens the registration page', (
    tester,
  ) async {
    await startApp(tester);
    await selectRoleAndOpenLogin(tester, role: 'mother');

    await tester.tap(find.byKey(const Key('login-register')));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterPage), findsOneWidget);
  });

  testWidgets('login validates required and malformed input', (tester) async {
    await startApp(tester);
    await selectRoleAndOpenLogin(tester, role: 'mother');

    await tapLoginSubmit(tester);
    await tester.pumpAndSettle();
    expect(find.text('Email wajib diisi.'), findsOneWidget);
    expect(find.text('Kata sandi wajib diisi.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');
    await tester.enterText(find.byType(TextFormField).at(1), 'demo1234');
    await tapLoginSubmit(tester);
    await tester.pumpAndSettle();
    expect(find.text('Masukkan alamat email yang valid.'), findsOneWidget);
  });

  testWidgets('login success routes to each selected role', (tester) async {
    await startApp(tester);
    await selectRoleAndOpenLogin(tester, role: 'mother');
    await enterCredentials(
      tester,
      email: 'demo.mother@dampingi.test',
      password: 'demo1234',
    );
    await tapLoginSubmit(tester);
    await tester.pumpAndSettle();
    expect(find.byType(MotherPage), findsOneWidget);

    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();
    await selectRoleAndOpenLogin(tester, role: 'companion');
    await enterCredentials(
      tester,
      email: 'demo.companion@dampingi.test',
      password: 'demo1234',
    );
    await tapLoginSubmit(tester);
    await tester.pumpAndSettle();
    expect(find.byType(CompanionPage), findsOneWidget);

    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();
    await selectRoleAndOpenLogin(tester, role: 'professional');
    await enterCredentials(
      tester,
      email: 'demo.doctor@dampingi.test',
      password: 'demo1234',
    );
    await tapLoginSubmit(tester);
    await tester.pumpAndSettle();
    expect(find.byType(DoctorPage), findsOneWidget);
  });

  testWidgets('login exposes loading state and disables form controls', (
    tester,
  ) async {
    await startApp(tester, mockLatency: const Duration(seconds: 1));
    await selectRoleAndOpenLogin(tester, role: 'mother');
    await enterCredentials(
      tester,
      email: 'demo.mother@dampingi.test',
      password: 'demo1234',
    );
    await tapLoginSubmit(tester);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).first).enabled,
      isFalse,
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(MotherPage), findsOneWidget);
  });

  testWidgets('failed login and mock network/server errors are friendly', (
    tester,
  ) async {
    await startApp(tester);
    await selectRoleAndOpenLogin(tester, role: 'mother');
    await enterCredentials(
      tester,
      email: 'demo.mother@dampingi.test',
      password: 'wrong-password',
    );
    await tapLoginSubmit(tester);
    await tester.pumpAndSettle();
    expect(find.text('Email atau kata sandi tidak benar.'), findsOneWidget);

    await enterCredentials(
      tester,
      email: 'network@dampingi.test',
      password: 'demo1234',
    );
    await tapLoginSubmit(tester);
    await tester.pumpAndSettle();
    expect(
      find.text('Tidak dapat terhubung. Periksa jaringan lalu coba lagi.'),
      findsOneWidget,
    );

    await enterCredentials(
      tester,
      email: 'server@dampingi.test',
      password: 'demo1234',
    );
    await tapLoginSubmit(tester);
    await tester.pumpAndSettle();
    expect(
      find.text('Layanan sedang bermasalah. Coba lagi beberapa saat.'),
      findsOneWidget,
    );
  });

  testWidgets('role mismatch is rejected and wrong role routes are guarded', (
    tester,
  ) async {
    await startApp(tester);
    await selectRoleAndOpenLogin(tester, role: 'mother');
    await enterCredentials(
      tester,
      email: 'demo.companion@dampingi.test',
      password: 'demo1234',
    );
    await tapLoginSubmit(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('Peran akun tidak sesuai'), findsOneWidget);

    await enterCredentials(
      tester,
      email: 'demo.mother@dampingi.test',
      password: 'demo1234',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.byType(MotherPage), findsOneWidget);

    GoRouter.of(tester.element(find.byType(MotherPage))).go('/doctor');
    await tester.pumpAndSettle();
    expect(find.byType(RouteErrorPage), findsOneWidget);
    expect(find.text('Akses tidak tersedia'), findsOneWidget);
  });

  testWidgets('unauthenticated role route redirects to login', (tester) async {
    await startApp(tester);
    GoRouter.of(tester.element(find.byType(RolePickerPage))).go('/companion');
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('role picker uses the Figma role copy and emoji', (tester) async {
    await startApp(tester);

    expect(find.text('Pilih Peranmu di Dampingi'), findsOneWidget);
    expect(find.text('Saya Pendamping Ibu'), findsOneWidget);
    expect(find.text('👩‍🍼'), findsOneWidget);
    expect(find.text('👨‍💼'), findsOneWidget);
    expect(find.text('🩺'), findsOneWidget);
    expect(find.byKey(const Key('role-create-account')), findsOneWidget);
    expect(find.byKey(const Key('role-login')), findsOneWidget);
  });

  testWidgets('registration validates and creates a mock account by role', (
    tester,
  ) async {
    await startApp(tester);
    await tester.tap(find.byKey(const Key('role-companion')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('role-create-account')));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterPage), findsOneWidget);

    await tester.tap(find.byKey(const Key('register-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Nama wajib diisi.'), findsOneWidget);
    expect(find.text('Email wajib diisi.'), findsOneWidget);
    expect(find.text('Kata sandi wajib diisi.'), findsOneWidget);

    Future<void> enterField(String key, String value) async {
      await tester.enterText(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(TextFormField),
        ),
        value,
      );
    }

    await enterField('register-name', 'Rani Pratama');
    await enterField('register-email', 'rani@dampingi.test');
    await enterField('register-password', 'secret123');
    await enterField('register-confirm-password', 'secret123');
    await tester.ensureVisible(find.byKey(const Key('register-submit')));
    await tester.tap(find.byKey(const Key('register-submit')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);

    await enterCredentials(
      tester,
      email: 'rani@dampingi.test',
      password: 'secret123',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.byType(CompanionPage), findsOneWidget);
  });

  testWidgets('register login link opens the existing login page', (
    tester,
  ) async {
    await startApp(tester);
    await tester.tap(find.byKey(const Key('role-create-account')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('register-login')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets(
    'password reset flow validates and navigates through demo pages',
    (tester) async {
      await startApp(tester);
      await selectRoleAndOpenLogin(tester, role: 'mother');

      await tester.tap(find.byKey(const Key('login-reset-password')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reset-email-page')), findsOneWidget);

      await tester.tap(find.byKey(const Key('reset-submit-email')));
      await tester.pumpAndSettle();
      expect(find.text('Email wajib diisi.'), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('reset-email')),
          matching: find.byType(TextFormField),
        ),
        'mother@dampingi.test',
      );
      await tester.tap(find.byKey(const Key('reset-submit-email')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reset-code-page')), findsOneWidget);
      expect(find.text('Kode demo: 123456'), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('reset-code')),
          matching: find.byType(TextFormField),
        ),
        '000000',
      );
      await tester.tap(find.byKey(const Key('reset-submit-code')));
      await tester.pumpAndSettle();
      expect(
        find.text('Kode demo tidak valid. Gunakan 123456.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('reset-code')),
          matching: find.byType(TextFormField),
        ),
        '123456',
      );
      await tester.tap(find.byKey(const Key('reset-submit-code')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reset-newPassword-page')), findsOneWidget);

      await tester.tap(find.byKey(const Key('reset-submit-newPassword')));
      await tester.pumpAndSettle();
      expect(find.text('Kata sandi wajib diisi.'), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('reset-new-password')),
          matching: find.byType(TextFormField),
        ),
        'new-secret',
      );
      await tester.tap(find.byKey(const Key('reset-submit-newPassword')));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(
        find.text('Mode demo: kata sandi belum diubah pada akun server.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('reset verification routes require an email-step flow', (
    tester,
  ) async {
    await startApp(tester);
    GoRouter.of(tester.element(find.byType(RolePickerPage)))
        .go('/verify-reset-code');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reset-email-page')), findsOneWidget);
  });

  testWidgets('unknown routes show a generic not-found page', (tester) async {
    await startApp(tester);
    GoRouter.of(tester.element(find.byType(RolePickerPage))).go('/unknown');
    await tester.pumpAndSettle();
    expect(find.byType(RouteErrorPage), findsOneWidget);
    expect(find.text('Page not found'), findsOneWidget);
  });

  testWidgets('logout clears the dummy session and returns to role selection', (
    tester,
  ) async {
    await startApp(tester);
    await selectRoleAndOpenLogin(tester, role: 'mother');
    await enterCredentials(
      tester,
      email: 'demo.mother@dampingi.test',
      password: 'demo1234',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Peranmu di Dampingi'), findsOneWidget);

    GoRouter.of(tester.element(find.byType(RolePickerPage))).go('/mother');
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('page-state widgets render loading, error, and empty states', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppLoading(message: 'Memuat data'),
              AppError(message: 'Gagal memuat data'),
              AppEmpty(message: 'Belum ada data'),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Memuat data'), findsOneWidget);
    expect(find.text('Gagal memuat data'), findsOneWidget);
    expect(find.text('Belum ada data'), findsOneWidget);
  });

  testWidgets('splash shows the local Figma assets then opens role selection', (
    tester,
  ) async {
    await startApp(tester, waitForRolePicker: false);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(SplashPage), findsOneWidget);
    expect(find.text('Dampingi'), findsOneWidget);
    final illustration = find.byKey(const Key('splash-illustration'));
    expect(illustration, findsOneWidget);
    expect(tester.getSize(illustration).width, moreOrLessEquals(223.152));
    expect(tester.getSize(illustration).height, moreOrLessEquals(207.992));

    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pumpAndSettle();
    expect(find.byType(RolePickerPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('role picker remains usable on a short screen', (tester) async {
    await startApp(tester, viewport: const Size(360, 600));

    expect(find.byKey(const Key('role-mother')), findsOneWidget);
    expect(find.byKey(const Key('role-create-account')), findsOneWidget);
    expect(find.byKey(const Key('role-login')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
