import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/app.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/widgets/app_card.dart';
import 'package:mobile/core/widgets/app_empty.dart';
import 'package:mobile/core/widgets/app_error.dart';
import 'package:mobile/core/widgets/app_loading.dart';
import 'package:mobile/core/widgets/app_profile_avatar.dart';
import 'package:mobile/features/auth/repositories/auth_repository.dart';
import 'package:mobile/features/auth/repositories/mock_auth_repository.dart';
import 'package:mobile/features/auth/controller/auth_controller.dart';
import 'package:mobile/features/auth/view/login_page.dart';
import 'package:mobile/features/auth/view/register_page.dart';
import 'package:mobile/features/companion/view/companion_page.dart';
import 'package:mobile/features/companion/view/companion_extra_pages.dart';
import 'package:mobile/features/connections/repositories/connection_repository.dart';
import 'package:mobile/features/connections/preview_invite_codes.dart';
import 'package:mobile/features/connections/view/koneksi_page.dart';
import 'package:mobile/features/doctor/view/doctor_page.dart';
import 'package:mobile/features/mother/view/mother_page.dart';
import 'package:mobile/features/mother/view/mother_profile_page.dart';
import 'package:mobile/features/mother/view/mother_profile_edit_page.dart';
import 'package:mobile/features/mother/view/mother_notifications_page.dart';
import 'package:mobile/features/mother/repositories/mother_story_repository.dart';
import 'package:mobile/features/shared/view/role_picker_page.dart';
import 'package:mobile/features/shared/view/route_error_page.dart';
import 'package:mobile/features/shared/view/splash_page.dart';
import 'package:mobile/models/app_role.dart';
import 'package:mobile/services/role_repository.dart';

import 'mother_story_test_data.dart';

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
    bool useLiveDoctorConnections = false,
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roleRepositoryProvider.overrideWithValue(_TestRoleRepository()),
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(latency: mockLatency),
          ),
          motherStoriesProvider.overrideWith(
            (ref) async => motherStoryTestData,
          ),
          if (useLiveDoctorConnections)
            backendTokenProvider.overrideWith((ref) => 'live-access-token'),
          if (useLiveDoctorConnections)
            activeConnectionsProvider.overrideWith(
              (ref) async => const [
                ConnectionPerson(
                  id: 'connection-1',
                  name: 'Ibu dari database',
                  role: 'mother',
                ),
              ],
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

  Future<void> expectPasswordVisibilityToggle(
    WidgetTester tester,
    String fieldKey,
  ) async {
    final editableField = find.descendant(
      of: find.byKey(Key(fieldKey)),
      matching: find.byType(EditableText),
    );
    await tester.ensureVisible(find.byKey(Key(fieldKey)));
    expect(tester.widget<EditableText>(editableField).obscureText, isTrue);
    final primaryColor = Theme.of(tester.element(find.byKey(Key(fieldKey))))
        .colorScheme
        .primary;
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(Key(fieldKey)),
              matching: find.byType(Icon),
            ),
          )
          .color,
      primaryColor,
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(Key(fieldKey)),
        matching: find.byTooltip('Tampilkan kata sandi'),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(editableField).obscureText, isFalse);
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(Key(fieldKey)),
              matching: find.byType(Icon),
            ),
          )
          .color,
      primaryColor,
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(Key(fieldKey)),
        matching: find.byTooltip('Sembunyikan kata sandi'),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(editableField).obscureText, isTrue);
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
      'Mona Sans',
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
    await expectPasswordVisibilityToggle(tester, 'login-password');

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

  testWidgets('system back from sign in returns to the role picker', (
    tester,
  ) async {
    await startApp(tester);
    await selectRoleAndOpenLogin(tester, role: 'mother');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(RolePickerPage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
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
    expect(find.text('Selamat Pagi, Ibu Demo 👋'), findsOneWidget);
    expect(find.byKey(const Key('mother-mood-card')), findsOneWidget);
    expect(find.byKey(const Key('mother-epds-card')), findsOneWidget);
    expect(find.text('EPDS mingguan'), findsOneWidget);
    expect(find.text('Isi Sekarang'), findsOneWidget);
    expect(
      tester.widget<MotherPage>(find.byType(MotherPage)).showWeeklyEpds,
      isTrue,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('mother-epds-card'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('mother-mood-card'))).dy),
    );
    expect(find.byKey(const Key('mother-bottom-navigation')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('mother-nav-profile'))).width,
      56,
    );

    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    final narrowMoodCard = tester.getRect(
      find.byKey(const Key('mother-mood-card')),
    );
    expect(
      tester.getRect(find.text('Jum')).right,
      lessThan(narrowMoodCard.right),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    final narrowStoriesCard = tester.getRect(
      find.byKey(const Key('mother-stories-card')),
    );
    expect(
      tester
          .widget<AppCard>(find.byKey(const Key('mother-stories-card')))
          .backgroundColor,
      (tester
              .widget<Container>(find.byKey(const Key('mother-mood-card')))
              .decoration!
          as BoxDecoration)
          .color,
    );
    final narrowStoryFace = tester.widget<SvgPicture>(
      find.byKey(const Key('mother-story-happy-face')),
    );
    final narrowStoryArrow = tester.getSize(
      find.byKey(const Key('mother-story-happy-arrow')),
    );
    final narrowStorySnippet = tester.widget<Text>(
      find.byKey(const Key('mother-story-very-sad-snippet')),
    );
    expect(narrowMoodCard.width, lessThan(320));
    expect(narrowStoryFace.fit, BoxFit.contain);
    expect(narrowStoryArrow.width, lessThan(24));
    expect(narrowStoryArrow.height, lessThan(24));
    expect(narrowStorySnippet.style?.fontSize, closeTo(16 * 320 / 390, 0.01));
    expect(
      tester
          .getSize(find.byKey(const Key('mother-story-very-happy-tile')))
          .width,
      lessThan(83),
    );
    final narrowHappyFaceSize = tester.getSize(
      find.byKey(const Key('mother-story-happy-face')),
    );
    final narrowVeryHappyFaceSize = tester.getSize(
      find.byKey(const Key('mother-story-very-happy-face')),
    );
    expect(narrowHappyFaceSize.width, closeTo(38 * 320 / 390, 0.01));
    expect(narrowHappyFaceSize.height, closeTo(17.85 * 320 / 390, 0.01));
    expect(narrowVeryHappyFaceSize.width, closeTo(38 * 320 / 390, 0.01));
    expect(narrowVeryHappyFaceSize.height, closeTo(23 * 320 / 390, 0.01));
    expect(
      tester.getSize(find.byKey(const Key('mother-story-divider-1'))).width,
      closeTo(narrowStoriesCard.width - (40 * 320 / 390) - 2, 0.1),
    );
    expect(
      tester.getSize(find.byKey(const Key('mother-story-divider-1'))).height,
      closeTo(20 * 320 / 390, 0.01),
    );
    expect(
      tester
          .getRect(find.byKey(const Key('mother-story-very-happy-tile')))
          .right,
      lessThan(narrowStoriesCard.right),
    );
    expect(
      tester.getSize(find.byKey(const Key('mother-nav-profile'))).width,
      lessThan(56),
    );
    expect(
      tester.getRect(find.byKey(const Key('mother-nav-profile'))).right,
      lessThan(320),
    );

    tester.view.physicalSize = const Size(430, 844);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('mother-nav-profile'))).width,
      greaterThan(56),
    );
    expect(
      tester.getRect(find.byKey(const Key('mother-nav-profile'))).right,
      lessThan(430),
    );

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('mother-story-happy-arrow'))),
      const Size(24, 24),
    );
    expect(
      tester.getSize(find.byKey(const Key('mother-story-happy-face'))).width,
      closeTo(38, 0.01),
    );
    expect(
      tester.getSize(find.byKey(const Key('mother-story-happy-face'))).height,
      closeTo(17.85, 0.01),
    );
    expect(
      tester
          .getSize(find.byKey(const Key('mother-story-very-happy-face')))
          .width,
      closeTo(38, 0.01),
    );
    expect(
      tester
          .getSize(find.byKey(const Key('mother-story-very-happy-face')))
          .height,
      closeTo(23, 0.01),
    );
    final happyFaceSize = tester.getSize(
      find.byKey(const Key('mother-mood-face-kam')),
    );
    final veryHappyFaceSize = tester.getSize(
      find.byKey(const Key('mother-mood-face-jum')),
    );
    expect(happyFaceSize.width, closeTo(38, 0.01));
    expect(happyFaceSize.height, closeTo(17.85, 0.01));
    expect(veryHappyFaceSize.width, closeTo(38, 0.01));
    expect(veryHappyFaceSize.height, closeTo(23, 0.01));
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Lakukan'), findsNothing);

    GoRouter.of(tester.element(find.byType(MotherPage))).go('/mother');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mother-nav-profile')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('mother-profile-scroll')),
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('mother-profile-logout')));
    await tester.tap(find.byKey(const Key('mother-profile-logout')));
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
    expect(find.text('Selamat Pagi, Pendamping Demo 👋'), findsOneWidget);
    expect(find.text('Belum ada Ibu yang anda didampingi'), findsOneWidget);
    expect(
      find.byKey(const Key('companion-enter-mother-code')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('companion-mother-summary')), findsNothing);
    expect(find.text('Apa yang kamu amati hari ini?'), findsOneWidget);
    final companionScroll = find
        .descendant(
          of: find.byKey(const Key('companion-dashboard-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('companion-stories-card')),
      120,
      scrollable: companionScroll,
    );
    expect(find.byKey(const Key('companion-stories-card')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('companion-support-card')),
      120,
      scrollable: companionScroll,
    );
    expect(find.byKey(const Key('companion-support-card')), findsOneWidget);
    expect(find.byKey(const Key('mother-bottom-navigation')), findsOneWidget);
    expect(tester.takeException(), isNull);

    final companionContainer = ProviderScope.containerOf(
      tester.element(find.byType(CompanionPage)),
    );
    companionContainer.read(authControllerProvider.notifier).logout();
    GoRouter.of(tester.element(find.byType(CompanionPage))).go('/roles');
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
    expect(find.text('Halo, dr. Maya Estiyanti'), findsOneWidget);
    expect(find.text(formatStoryDate(DateTime.now())), findsOneWidget);
    expect(find.byKey(const Key('doctor-home-avatar')), findsOneWidget);
    expect(find.byKey(const Key('doctor-connections-card')), findsOneWidget);
    expect(find.byKey(const Key('doctor-connections-open')), findsOneWidget);
    expect(find.byKey(const Key('doctor-patients-card')), findsOneWidget);
    expect(find.byKey(const Key('doctor-bottom-navigation')), findsOneWidget);
    final notificationIcon = tester.widget<SvgPicture>(
      find.descendant(
        of: find.byKey(const Key('doctor-home-notifications')),
        matching: find.byType(SvgPicture),
      ),
    );
    expect(notificationIcon.width, 19.478);
    expect(notificationIcon.height, 22);
    for (final tab in DoctorNavigationTab.values) {
      expect(find.byKey(Key('doctor-nav-item-${tab.name}')), findsOneWidget);
    }
    expect(find.text('Cari nama pasien'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('doctor-patient-search')));
    await tester.enterText(
      find.byKey(const Key('doctor-patient-search')),
      'Menunggu persetujuan',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(find.byKey(const Key('doctor-patient-search-composer')))
          .height,
      53,
    );
    expect(
      tester.getSize(find.byKey(const Key('doctor-patient-search-button'))),
      const Size(36, 36),
    );
    expect(find.byKey(const Key('doctor-patient-search-icon')), findsOneWidget);
    await tester.tap(find.byKey(const Key('doctor-patient-search-button')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('doctor-patient-search')),
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .hasFocus,
      isFalse,
    );
    expect(find.byKey(const Key('doctor-patient-row-0')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('doctor-patient-row-0')),
        matching: find.text('Menunggu persetujuan'),
      ),
      findsOneWidget,
    );
    expect(find.text('Ringkasan Belum ditinjau'), findsNothing);
  });

  testWidgets('doctor reaches the Koneksi screen from the home card', (
    tester,
  ) async {
    await startApp(tester);
    await selectRoleAndOpenLogin(tester, role: 'professional');
    await enterCredentials(
      tester,
      email: 'demo.doctor@dampingi.test',
      password: 'demo1234',
    );
    await tapLoginSubmit(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('doctor-connections-open')));
    await tester.pumpAndSettle();
    expect(find.byType(KoneksiPage), findsOneWidget);
    expect(find.byKey(const Key('koneksi-redeem')), findsOneWidget);
    expect(find.byKey(const Key('doctor-connections-card')), findsNothing);

    await tester.tap(find.byKey(const Key('koneksi-back')));
    await tester.pumpAndSettle();
    expect(find.byType(DoctorPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('doctor home loads connected patients from the backend', (
    tester,
  ) async {
    await startApp(tester, useLiveDoctorConnections: true);
    await selectRoleAndOpenLogin(tester, role: 'professional');
    await enterCredentials(
      tester,
      email: 'demo.doctor@dampingi.test',
      password: 'demo1234',
    );
    await tapLoginSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.text('Ibu dari database'), findsOneWidget);
    expect(find.text('Pasien terhubung'), findsOneWidget);
    expect(find.text('Ny. Shopia Mudj.'), findsNothing);
    expect(find.byKey(const Key('doctor-patients-empty')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('doctor creates, edits, and deletes a patient guide', (
    tester,
  ) async {
    await startApp(tester);
    await selectRoleAndOpenLogin(tester, role: 'professional');
    await enterCredentials(
      tester,
      email: 'demo.doctor@dampingi.test',
      password: 'demo1234',
    );
    await tapLoginSubmit(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('doctor-nav-guide')));
    await tester.pumpAndSettle();
    expect(find.text('Arahkan pasien anda'), findsOneWidget);
    expect(find.text('Arahan anda'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('doctor-guide-create')));
    await tester.tap(find.byKey(const Key('doctor-guide-create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('doctor-guide-form-input')),
      'Beristirahat cukup dan minum air.',
    );
    await tester.tap(find.byKey(const Key('doctor-guide-form-done')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('doctor-guide-success-dialog')),
      findsOneWidget,
    );
    expect(find.text('Arahan berhasil diberikan ke pasien!'), findsOneWidget);
    await tester.tap(find.byKey(const Key('doctor-guide-success-done')));
    await tester.pumpAndSettle();
    expect(find.text('Beristirahat cukup dan minum air.'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('doctor-guide-edit')));
    await tester.tap(find.byKey(const Key('doctor-guide-edit')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('doctor-guide-form-input')))
          .controller
          ?.text,
      'Beristirahat cukup dan minum air.',
    );
    await tester.enterText(
      find.byKey(const Key('doctor-guide-form-input')),
      'Periksa kembali sesuai jadwal.',
    );
    await tester.tap(find.byKey(const Key('doctor-guide-form-done')));
    await tester.pumpAndSettle();
    expect(find.text('Arahan berhasil diperbarui!'), findsOneWidget);
    await tester.tap(find.byKey(const Key('doctor-guide-success-done')));
    await tester.pumpAndSettle();
    expect(find.text('Periksa kembali sesuai jadwal.'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('doctor-guide-delete')));
    await tester.tap(find.byKey(const Key('doctor-guide-delete')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Hapus'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Arahan berhasil dihapus!'), findsOneWidget);
    await tester.tap(find.byKey(const Key('doctor-guide-success-done')));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada arahan untuk pasien ini.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('doctor profile matches the shared profile layout', (
    tester,
  ) async {
    await startApp(tester);
    await selectRoleAndOpenLogin(tester, role: 'professional');
    await enterCredentials(
      tester,
      email: 'demo.doctor@dampingi.test',
      password: 'demo1234',
    );
    await tapLoginSubmit(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('doctor-nav-profile')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('doctor-profile-information-card')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('doctor-profile-avatar')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('doctor-profile-avatar'))),
      const Size(85, 85),
    );
    expect(find.text('Maya Estiyanti'), findsOneWidget);
    expect(find.text('demo.doctor@dampingi.test'), findsOneWidget);
    expect(find.text('AIS128'), findsOneWidget);
    expect(find.text('Ubah Profil'), findsOneWidget);
    expect(find.text('Tambah Pasien'), findsOneWidget);

    await tester.tap(find.byKey(const Key('doctor-profile-edit')));
    await tester.pumpAndSettle();
    expect(find.byType(DoctorProfileEditPage), findsOneWidget);
    expect(find.byKey(const Key('doctor-profile-edit-name')), findsOneWidget);
    await tester.tap(find.byKey(const Key('doctor-profile-edit-back')));
    await tester.pumpAndSettle();
    expect(find.text('Tambah Pasien'), findsOneWidget);

    await tester.tap(find.byKey(const Key('doctor-profile-add-patient')));
    await tester.pumpAndSettle();
    expect(find.byType(KoneksiPage), findsOneWidget);
    await tester.tap(find.byKey(const Key('koneksi-back')));
    await tester.pumpAndSettle();
    expect(find.text('Tambah Pasien'), findsOneWidget);
    expect(find.byKey(const Key('doctor-profile-logout')), findsOneWidget);
    expect(find.byKey(const Key('doctor-bottom-navigation')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'doctor notification affordance still just says there is nothing',
    (tester) async {
      await startApp(tester);
      await selectRoleAndOpenLogin(tester, role: 'professional');
      await enterCredentials(
        tester,
        email: 'demo.doctor@dampingi.test',
        password: 'demo1234',
      );
      await tapLoginSubmit(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('doctor-home-notifications')));
      await tester.pumpAndSettle();

      expect(find.text('Belum ada notifikasi baru.'), findsOneWidget);
      expect(find.byType(DoctorPage), findsOneWidget);
    },
  );

  testWidgets('doctor patients tab shows the Figma patient summary', (
    tester,
  ) async {
    await startApp(tester);
    await selectRoleAndOpenLogin(tester, role: 'professional');
    await enterCredentials(
      tester,
      email: 'demo.doctor@dampingi.test',
      password: 'demo1234',
    );
    await tapLoginSubmit(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('doctor-nav-patients')));
    await tester.pumpAndSettle();
    expect(find.text('Ringkasan pasien'), findsOneWidget);
    expect(find.text('Pilih pasien'), findsOneWidget);
    expect(find.text('Ny. Shopia Mudj.'), findsOneWidget);
    expect(
      tester.getSize(
        find.byKey(const Key('doctor-patient-summary-picker-value')),
      ),
      const Size(300, 76),
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('doctor-patient-picker-name')))
          .style
          ?.color,
      const Color(0xFFF97066),
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const Key('doctor-patient-summary-dropdown')),
              matching: find.byIcon(Icons.keyboard_arrow_down_rounded),
            ),
          )
          .color,
      const Color(0xFFF97066),
    );
    expect(
      (tester
                  .widget<Container>(
                    find.byKey(
                      const Key('doctor-patient-summary-week-background'),
                    ),
                  )
                  .decoration!
              as BoxDecoration)
          .color,
      const Color(0xFFFAFAFA),
    );
    expect(find.text('1-7 Agu 2026'), findsOneWidget);
    expect(
      find.byKey(const Key('doctor-patient-summary-epds')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('doctor-patient-summary-next-week')));
    await tester.pumpAndSettle();
    expect(find.text('8-14 Agu 2026'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('doctor-patient-summary-previous-week')),
    );
    await tester.pumpAndSettle();
    expect(find.text('1-7 Agu 2026'), findsOneWidget);

    final summaryScroll = find
        .descendant(
          of: find.byKey(const Key('doctor-patient-summary-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('doctor-patient-summary-stories')),
      120,
      scrollable: summaryScroll,
    );
    expect(
      find.byKey(const Key('doctor-patient-summary-stories')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('doctor-patient-summary-story-5-row')),
      120,
      scrollable: summaryScroll,
    );
    expect(
      find.byKey(const Key('doctor-patient-summary-story-5-row')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('doctor-nav-item-patients')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('doctor-patient-summary-story-0-row')),
      120,
      scrollable: summaryScroll,
    );
    await tester.ensureVisible(
      find.byKey(const Key('doctor-patient-summary-story-0-row')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('doctor-patient-summary-story-0-row')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Senin, 12 Agustus 2026'), findsOneWidget);
    expect(find.text('Ringkasan AI'), findsOneWidget);
    expect(find.text('Hal Kecil yang berarti'), findsOneWidget);
    expect(find.text('Lihat lebih banyak'), findsOneWidget);
    await tester.tap(find.byKey(const Key('doctor-patient-story-expand')));
    await tester.pumpAndSettle();
    expect(find.text('Lihat lebih sedikit'), findsOneWidget);
    await tester.tap(find.byKey(const Key('doctor-patient-story-back')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('doctor-patient-summary-scroll')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('doctor-nav-home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('doctor-home-avatar')), findsOneWidget);
    expect(find.byKey(const Key('doctor-patients-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('companion links a mother and browses its dashboard tabs', (
    tester,
  ) async {
    await startApp(tester);
    await selectRoleAndOpenLogin(tester, role: 'companion');
    await enterCredentials(
      tester,
      email: 'demo.companion@dampingi.test',
      password: 'demo1234',
    );
    await tapLoginSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Observasi'), findsOneWidget);
    expect(find.bySemanticsLabel('Rekomendasi'), findsOneWidget);
    expect(find.bySemanticsLabel('Panduan'), findsOneWidget);
    final activeHome = tester.widget<Container>(
      find.byKey(const Key('mother-nav-item-home')),
    );
    expect((activeHome.decoration! as BoxDecoration).color, AppTheme.coral);

    await tester.tap(find.byKey(const Key('companion-notification')));
    await tester.pumpAndSettle();
    expect(find.byType(CompanionNotificationsPage), findsOneWidget);
    expect(find.text('Notifikasi anda'), findsOneWidget);
    expect(find.text('Ibu membagikan catatan baru'), findsOneWidget);
    expect(find.byKey(const Key('mother-bottom-navigation')), findsNothing);
    await tester.tap(find.byKey(const Key('companion-notifications-back')));
    await tester.pumpAndSettle();
    expect(find.byType(CompanionPage), findsOneWidget);

    await tester.tap(find.byKey(const Key('companion-observation-start')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('companion-observation-question-dialog')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('companion-observation-answer-2')));
    await tester.tap(
      find.byKey(const Key('companion-observation-question-continue')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('companion-observation-note-dialog')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('companion-observation-title')),
      'Hari yang lebih tenang',
    );
    await tester.tap(find.byKey(const Key('companion-observation-note-back')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('companion-observation-question-dialog')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('companion-observation-question-continue')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hari yang lebih tenang'), findsOneWidget);
    await tester.tap(find.byKey(const Key('companion-observation-note-done')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('companion-observation-success-dialog')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('companion-observation-success-done')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Observasi hari ini - Sudah diisi'), findsOneWidget);

    await tester.tap(find.byKey(const Key('companion-enter-mother-code')));
    await tester.pumpAndSettle();
    expect(find.byType(KoneksiPage), findsOneWidget);
    expect(find.byKey(const Key('koneksi-redeem')), findsOneWidget);
    await tester.tap(find.byKey(const Key('koneksi-back')));
    await tester.pumpAndSettle();
    expect(find.byType(CompanionPage), findsOneWidget);
    expect(find.byKey(const Key('companion-unassigned-card')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mother-nav-item-calendar')));
    await tester.pumpAndSettle();
    expect(find.text('1-7 Agu 2026'), findsOneWidget);
    expect(find.text('Catatan anda'), findsOneWidget);
    expect(
      (tester
                  .widget<Container>(
                    find.byKey(const Key('mother-nav-item-calendar')),
                  )
                  .decoration!
              as BoxDecoration)
              .color,
      AppTheme.coral,
    );

    final observationScroll = find
        .descendant(
          of: find.byKey(const Key('companion-observation-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('companion-observation-note-0')),
      120,
      scrollable: observationScroll,
    );
    await tester.tap(find.byKey(const Key('companion-observation-note-0')));
    await tester.pumpAndSettle();
    expect(find.text('Ringkasan AI'), findsOneWidget);
    expect(find.byKey(const Key('mother-bottom-navigation')), findsNothing);
    await tester.tap(find.byKey(const Key('companion-note-detail-back')));
    await tester.pumpAndSettle();
    expect(find.text('Catatan anda'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mother-nav-chat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('companion-chat-page')), findsOneWidget);
    expect(find.bySemanticsLabel('Observasi'), findsOneWidget);
    expect(find.bySemanticsLabel('Rekomendasi'), findsOneWidget);
    expect(find.bySemanticsLabel('Panduan'), findsOneWidget);
    final activeRecommendation = tester.widget<Container>(
      find.byKey(const Key('mother-nav-item-recommendations')),
    );
    expect(
      (activeRecommendation.decoration! as BoxDecoration).color,
      AppTheme.coral,
    );
    final guideIcon = tester.widget<SvgPicture>(
      find.descendant(
        of: find.byKey(const Key('mother-nav-item-meditation')),
        matching: find.byType(SvgPicture),
      ),
    );
    expect(guideIcon.bytesLoader, isA<SvgAssetLoader>());
    expect(
      (guideIcon.bytesLoader as SvgAssetLoader).assetName,
      'assets/images/navigation/doctor-book.svg',
    );
    expect(find.text('Hai gpt, aku hamil'), findsOneWidget);
    expect(
      find.text('Wow kamu hamil ya semoga lahiranya lancar nanti'),
      findsOneWidget,
    );
    expect(find.text('Ringkasan Percakapan'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('companion-chat-input')),
      'Pesan preview',
    );
    await tester.tap(find.byKey(const Key('companion-chat-send')));
    await tester.pumpAndSettle();
    expect(
      find.text('Mode pratinjau aktif. Pesan belum dikirim ke layanan AI.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('mother-nav-meditation')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('companion-support-screen')), findsOneWidget);
    expect(find.bySemanticsLabel('Panduan'), findsOneWidget);
    final activeGuide = tester.widget<Container>(
      find.byKey(const Key('mother-nav-item-meditation')),
    );
    expect((activeGuide.decoration! as BoxDecoration).color, AppTheme.coral);
    final activeGuideIcon = tester.widget<SvgPicture>(
      find.descendant(
        of: find.byKey(const Key('mother-nav-item-meditation')),
        matching: find.byType(SvgPicture),
      ),
    );
    expect(
      (activeGuideIcon.bytesLoader as SvgAssetLoader).assetName,
      'assets/images/navigation/doctor-book-active.svg',
    );
    expect(find.text('Dukungan hari ini'), findsOneWidget);
    await tester.tap(find.byKey(const Key('companion-support-prompt')));
    await tester.pumpAndSettle();
    expect(
      find.text('Tanyakan dengan lembut, lalu beri waktu untuk bercerita.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('companion-support-prompt')));
    await tester.pumpAndSettle();
    expect(
      find.text('Tanyakan dengan lembut, lalu beri waktu untuk bercerita.'),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('mother-nav-profile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('companion-profile-card')), findsOneWidget);
    final activeProfile = tester.widget<Container>(
      find.byKey(const Key('mother-nav-item-profile')),
    );
    expect((activeProfile.decoration! as BoxDecoration).color, AppTheme.coral);
    expect(find.byType(AppProfileAvatar), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('companion-profile-avatar'))),
      const Size(85, 85),
    );
    final profileAvatar = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('companion-profile-card')),
        matching: find.byType(Image),
      ),
    );
    expect(
      (profileAvatar.image as AssetImage).assetName,
      'assets/images/companion_profile/profile-avatar.png',
    );
    expect(
      find.byKey(const Key('companion-profile-mother-card')),
      findsNothing,
    );
    expect(find.text('Ringkasan mingguan'), findsNothing);
    expect(
      find.byKey(const Key('companion-profile-permissions')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('companion-profile-edit')));
    await tester.pumpAndSettle();
    expect(find.byType(CompanionProfileEditPage), findsOneWidget);
    expect(find.text('Ubah Foto'), findsOneWidget);
    expect(find.text('Simpan Perubahan'), findsOneWidget);
    expect(find.text('Ubah kata sandi'), findsOneWidget);
    expect(find.text('Pendamping Demo'), findsOneWidget);
    expect(find.text('demo.companion@dampingi.test'), findsOneWidget);
    await expectPasswordVisibilityToggle(
      tester,
      'companion-profile-edit-password',
    );
    await expectPasswordVisibilityToggle(
      tester,
      'companion-profile-edit-password-confirmation',
    );
    final editableProfileAvatar = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('companion-profile-edit-avatar')),
        matching: find.byType(Image),
      ),
    );
    expect(
      (editableProfileAvatar.image as AssetImage).assetName,
      'assets/images/companion_profile/profile-avatar.png',
    );
    await tester.drag(
      find.byKey(const Key('companion-profile-edit-scroll')),
      const Offset(0, 1000),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('companion-profile-edit-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('companion-profile-card')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('companion-profile-logout')),
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('companion-profile-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('companion-profile-logout')));
    await tester.pumpAndSettle();
    expect(find.byType(RolePickerPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('companion reaches the Koneksi screen from her profile', (
    tester,
  ) async {
    await startApp(tester);
    await selectRoleAndOpenLogin(tester, role: 'companion');
    await enterCredentials(
      tester,
      email: 'demo.companion@dampingi.test',
      password: 'demo1234',
    );
    await tapLoginSubmit(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mother-nav-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('companion-profile-enter-code')));
    await tester.pumpAndSettle();

    expect(find.byType(KoneksiPage), findsOneWidget);
    expect(find.byKey(const Key('koneksi-redeem')), findsOneWidget);
    expect(find.byKey(const Key('koneksi-issue')), findsOneWidget);

    await tester.tap(find.byKey(const Key('koneksi-back')));
    await tester.pumpAndSettle();
    expect(find.byType(CompanionPage), findsOneWidget);
    expect(find.byKey(const Key('companion-profile-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('weekly EPDS follows the three provided dialog designs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          motherStoriesProvider.overrideWith(
            (ref) async => motherStoryTestData,
          ),
        ],
        child: const MaterialApp(home: MotherPage()),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in [
      'Isi Sekarang',
      'Catat mood hari ini!',
      'Lihat Semua',
    ]) {
      expect(tester.widget<Text>(find.text(label)).style?.fontSize, 16);
    }

    await tester.tap(find.byKey(const Key('mother-epds-start')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mother-weekly-epds-intro-title')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('mother-weekly-epds-continue')),
          )
          .style
          ?.textStyle
          ?.resolve({})
          ?.fontSize,
      16,
    );

    await tester.tap(find.byKey(const Key('mother-weekly-epds-continue')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        '1. Saya dapat tertawa dan melihat sisi lucu dari berbagai hal',
      ),
      findsOneWidget,
    );
    for (var question = 0; question < 10; question++) {
      await tester.tap(find.byKey(const Key('mother-weekly-epds-option-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mother-weekly-epds-next')));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const Key('mother-weekly-epds-preview')), findsOneWidget);
    expect(find.byKey(const Key('mother-weekly-epds-urgent')), findsNothing);

    expect(
      find.byKey(const Key('mother-weekly-epds-complete-message')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('mother-weekly-epds-finish')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mother-weekly-epds-dialog-0')), findsNothing);
  });

  testWidgets(
    'mother notifications match the Figma screen and open from home',
    (tester) async {
      await startApp(tester);
      await selectRoleAndOpenLogin(tester, role: 'mother');
      await enterCredentials(
        tester,
        email: 'demo.mother@dampingi.test',
        password: 'demo1234',
      );
      await tapLoginSubmit(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mother-notifications')));
      await tester.pumpAndSettle();

      expect(find.byType(MotherNotificationsPage), findsOneWidget);
      expect(find.text('Notifikasi anda'), findsOneWidget);
      expect(find.text('Kode Undangan dari Sdr. Enzokulin'), findsOneWidget);
      expect(
        find.text('Kode Undangan dari Dr. Aisyah Salsabila'),
        findsOneWidget,
      );
      expect(
        find.text('Lakukan gerakan yoga ini supaya segar'),
        findsOneWidget,
      );
      expect(
        tester.getSize(
          find.byKey(const Key('mother-notification-companion-code')),
        ),
        const Size(342, 94),
      );
      expect(find.byKey(const Key('mother-bottom-navigation')), findsNothing);

      await tester.tap(
        find.byKey(const Key('mother-notification-companion-code')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('mother-notification-confirm-title')),
        findsOneWidget,
      );
      expect(
        tester.getSize(
          find.byKey(const Key('mother-notification-confirm-dialog')),
        ),
        const Size(342, 364),
      );
      expect(
        tester.getSize(
          find.byKey(const Key('mother-notification-code-sender')),
        ),
        const Size(300, 72),
      );
      expect(find.text('Tn. Enzokulin Samsidan'), findsOneWidget);
      expect(find.text('samsidan@gmail.com'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('mother-notification-confirm-cancel')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('mother-notification-confirm-dialog')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('mother-notification-companion-code')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('mother-notification-confirm-redeem')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tukar kode belum tersedia.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('mother-notifications-back')));
      await tester.pumpAndSettle();
      expect(find.byType(MotherPage), findsOneWidget);
    },
  );

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

  testWidgets('mother dashboard opens the selected note and returns home', (
    tester,
  ) async {
    await startApp(tester);
    await selectRoleAndOpenLogin(tester, role: 'mother');
    await enterCredentials(
      tester,
      email: 'demo.mother@dampingi.test',
      password: 'demo1234',
    );
    await tapLoginSubmit(tester);
    await tester.pumpAndSettle();

    final firstStory = find.byKey(const Key('mother-story-very-sad-row'));
    final homeScroll = find
        .descendant(
          of: find.byKey(
            const PageStorageKey<String>('mother-home-weekly-scroll'),
          ),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(homeScroll, const Offset(0, -160));
    await tester.pumpAndSettle();
    await tester.ensureVisible(firstStory);
    await tester.tap(firstStory);
    await tester.pumpAndSettle();

    expect(find.text('Senin, 12 Agustus 2026'), findsOneWidget);
    expect(find.text('Anda merasa sangat sedih'), findsOneWidget);
    expect(
      find.text(
        'Senang karena ada suami yang bantu aku untuk ke belakang, kok bisa '
        'suami bantu aku ke belakang padahal suami lagi di luar kota.',
      ),
      findsNWidgets(2),
    );

    await tester.tap(find.byKey(const Key('mother-story-detail-back')));
    await tester.pumpAndSettle();
    expect(find.byType(MotherPage), findsOneWidget);

    final secondStory = find.byKey(const Key('mother-story-very-happy-row'));
    await tester.ensureVisible(secondStory);
    await tester.tap(secondStory);
    await tester.pumpAndSettle();
    expect(find.text('Selasa, 2 Agustus 2026'), findsOneWidget);
    expect(find.text('Anda merasa sangat bahagia'), findsOneWidget);
  });

  testWidgets('mother mood entry follows the Figma four-step flow', (
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

    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    final recordMoodButton = find.byKey(const Key('mother-record-mood'));
    await tester.ensureVisible(recordMoodButton);
    await tester.tap(recordMoodButton);
    await tester.pumpAndSettle();

    expect(find.text('Apa yang anda rasakan sekarang?'), findsOneWidget);
    expect(find.byKey(const Key('mother-mood-level-slider')), findsOneWidget);
    expect(
      find.byKey(const Key('mother-mood-dialog-continue')),
      findsOneWidget,
    );
    expect(
      tester.getRect(find.byKey(const Key('mother-mood-entry-dialog'))).width,
      lessThanOrEqualTo(272),
    );

    await tester.tap(find.byKey(const Key('mother-mood-level-4')));
    await tester.tap(find.byKey(const Key('mother-mood-dialog-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Sangat Bahagia'), findsOneWidget);
    expect(
      find.text('Apa yang paling menggambarkan perasaanmu?'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('mother-add-feeling')));
    await tester.pumpAndSettle();
    expect(find.text('Bersyukur'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mother-mood-dialog-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Tulis catatan harian anda'), findsOneWidget);
    expect(find.byKey(const Key('mother-journal-title')), findsOneWidget);
    expect(find.byKey(const Key('mother-journal-story')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mother-mood-dialog-back')));
    await tester.pumpAndSettle();
    expect(find.text('Sangat Bahagia'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mother-mood-dialog-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mother-mood-dialog-continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mother-mood-summary')), findsOneWidget);
    expect(find.text('Sangat Bahagia'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('mother-mood-summary-face'))).width,
      closeTo(100 * 320 / 390, 0.1),
    );
    final summaryFaceCenter = tester.getCenter(
      find.byKey(const Key('mother-mood-summary-face')),
    );
    final summaryExpressionCenter = tester.getCenter(
      find.byKey(const Key('mother-mood-summary-expression')),
    );
    expect(summaryExpressionCenter.dx, closeTo(summaryFaceCenter.dx, 0.1));
    expect(summaryExpressionCenter.dy, closeTo(summaryFaceCenter.dy, 0.1));
    await tester.tap(find.byKey(const Key('mother-mood-summary')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mother-mood-entry-dialog')), findsNothing);
  });

  testWidgets('mother meditation list opens and controls a breathing session', (
    tester,
  ) async {
    await startApp(tester);
    await selectRoleAndOpenLogin(tester, role: 'mother');
    await enterCredentials(
      tester,
      email: 'demo.mother@dampingi.test',
      password: 'demo1234',
    );
    await tapLoginSubmit(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mother-nav-meditation')));
    await tester.pumpAndSettle();
    expect(find.text('Saran hari ini'), findsOneWidget);
    expect(
      find.byKey(const Key('mother-meditation-suggestion')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mother-meditation-activities')),
      findsOneWidget,
    );
    expect(find.text('Meditasi Selamanya'), findsOneWidget);
    expect(find.byKey(const Key('mother-meditation-activity-4')), findsNothing);
    expect(
      find.byKey(const Key('mother-meditation-activity-arrow')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const Key('mother-meditation-suggestion'))),
      const Size(342, 200),
    );
    expect(
      tester.getSize(find.byKey(const Key('mother-meditation-activities'))),
      const Size(342, 334),
    );
    expect(
      tester.getSize(find.byKey(const Key('mother-bottom-navigation'))).height,
      107,
    );

    tester.view.physicalSize = const Size(382, 844);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('mother-meditation-suggestion-start')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Meditasi singkat'), findsOneWidget);
    expect(find.byKey(const Key('mother-breathing-time')), findsOneWidget);
    expect(find.byKey(const Key('mother-breathing-step-1')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('mother-breathing-time'))),
      const Size(238, 90),
    );
    expect(
      tester.getSize(find.byKey(const Key('mother-breathing-step-card-1'))),
      const Size(83, 83),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('mother-breathing-decrement'))).dx,
      lessThan(
        tester
            .getTopLeft(find.byKey(const Key('mother-breathing-increment')))
            .dx,
      ),
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(const Key('mother-breathing-subtract-30-seconds')),
          )
          .dx,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(const Key('mother-breathing-add-30-seconds')),
            )
            .dx,
      ),
    );
    expect(
      tester.widget<Text>(find.text('30 Detik').first).style?.fontFamily,
      'Mona Sans',
    );
    await tester.tap(find.byKey(const Key('mother-breathing-decrement')));
    await tester.pumpAndSettle();
    expect(find.text('02:30'), findsOneWidget);
    await tester.tap(find.byKey(const Key('mother-breathing-increment')));
    await tester.pumpAndSettle();
    expect(find.text('03:00'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('mother-breathing-subtract-30-seconds')),
    );
    await tester.pumpAndSettle();
    expect(find.text('02:30'), findsOneWidget);
    await tester.tap(find.byKey(const Key('mother-breathing-add-30-seconds')));
    await tester.pumpAndSettle();
    expect(find.text('03:00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mother-breathing-back')));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(find.byKey(const Key('mother-meditation-suggestion')))
          .width,
      closeTo(320 - 48 * 320 / 390, 0.1),
    );
    await tester.tap(
      find.byKey(const Key('mother-meditation-suggestion-start')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mother-breathing-increment')));
    await tester.pumpAndSettle();
    expect(find.text('03:30'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('mother-breathing-start')));
    await tester.tap(find.byKey(const Key('mother-breathing-start')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Jeda'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('mother-breathing-reset')));
    await tester.tap(find.byKey(const Key('mother-breathing-reset')));
    await tester.pumpAndSettle();
    expect(find.text('Mulai'), findsOneWidget);
    expect(find.text('03:30'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('mother-breathing-session-scroll')),
      const Offset(0, 1000),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mother-breathing-back')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mother-meditation-list-scroll')),
      findsOneWidget,
    );
  });

  testWidgets('mother calendar is reachable from the bottom navigation', (
    tester,
  ) async {
    await startApp(tester);
    await selectRoleAndOpenLogin(tester, role: 'mother');
    await enterCredentials(
      tester,
      email: 'demo.mother@dampingi.test',
      password: 'demo1234',
    );
    await tapLoginSubmit(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mother-nav-item-calendar')));
    await tester.pumpAndSettle();

    expect(find.text('1-7 Agu 2026'), findsOneWidget);
    expect(
      find.byKey(const Key('mother-calendar-epds-summary')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mother-nav-item-calendar')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mother-calendar-day-Sab')));
    await tester.pumpAndSettle();
    final storyRow = find.byKey(const Key('mother-calendar-story-0-row'));
    await tester.ensureVisible(storyRow);
    await tester.tap(storyRow);
    await tester.pumpAndSettle();

    expect(find.text('Anda merasa bahagia'), findsOneWidget);
    expect(find.text('Ringkasan AI'), findsOneWidget);
    expect(find.byKey(const Key('mother-story-open-chat')), findsOneWidget);
    await tester.tap(find.byKey(const Key('mother-story-detail-back')));
    await tester.pumpAndSettle();
    expect(find.text('Cerita terakhirmu'), findsOneWidget);

    await tester.ensureVisible(storyRow);
    await tester.tap(storyRow);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mother-story-open-chat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mother-chat-input')), findsOneWidget);
  });

  testWidgets('mother profile matches Figma and its privacy toggles work', (
    tester,
  ) async {
    await startApp(tester, viewport: const Size(390, 1237));
    await selectRoleAndOpenLogin(tester, role: 'mother');
    await enterCredentials(
      tester,
      email: 'demo.mother@dampingi.test',
      password: 'demo1234',
    );
    await tapLoginSubmit(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mother-nav-profile')));
    await tester.pumpAndSettle();

    expect(find.byType(MotherProfilePage), findsOneWidget);
    expect(find.byType(AppProfileAvatar), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('mother-profile-avatar'))),
      const Size(85, 85),
    );
    expect(find.text('Dampingi'), findsOneWidget);
    expect(find.text('Ibu Demo'), findsOneWidget);
    expect(find.text('demo.mother@dampingi.test'), findsOneWidget);
    expect(
      find.byKey(const Key('mother-profile-invite-summary')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('mother-profile-connection-summary')),
      findsNothing,
    );
    expect(find.byKey(const Key('mother-profile-sharing-note')), findsNothing);
    expect(find.byKey(const Key('mother-profile-connections')), findsOneWidget);
    expect(find.byKey(const Key('mother-profile-add-companion')), findsNothing);
    expect(find.text('Tambah Pendamping'), findsNothing);
    expect(
      find.text(
        'Pratinjau: pilih data yang boleh dilihat orang yang terhubung',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mother-profile-companion-enzokulin')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mother-profile-companion-indra')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const Key('mother-profile-information-card'))),
      const Size(342, 329),
    );
    expect(
      tester.getSize(find.byKey(const Key('mother-profile-permissions-card'))),
      const Size(342, 494),
    );
    final toggleKey = find.byKey(
      const Key('mother-profile-toggle-enzokulin-weekly-summary'),
    );
    await tester.tap(toggleKey);
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const Key('mother-profile-toggle-enzokulin-weekly-summary-off'),
      ),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const Key('mother-profile-scroll')),
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('mother-profile-logout')));
    await tester.tap(find.byKey(const Key('mother-profile-logout')));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Peranmu di Dampingi'), findsOneWidget);
  });

  testWidgets("mother reaches the Koneksi screen from her profile", (
    tester,
  ) async {
    await startApp(tester);
    await selectRoleAndOpenLogin(tester, role: 'mother');
    await enterCredentials(
      tester,
      email: 'demo.mother@dampingi.test',
      password: 'demo1234',
    );
    await tapLoginSubmit(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mother-nav-profile')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mother-profile-connections')));
    await tester.pumpAndSettle();

    expect(find.byType(KoneksiPage), findsOneWidget);
    expect(find.text('Koneksi'), findsOneWidget);
    expect(find.text(previewInviteCodeForCompanion), findsOneWidget);
    expect(
      find.text(
        'Orang yang terhubung hanya dapat melihat ringkasan mingguan Anda. '
        'Jurnal, mood harian, dan hasil EPDS tetap pribadi.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('koneksi-back')));
    await tester.pumpAndSettle();
    expect(find.byType(MotherProfilePage), findsOneWidget);
  });

  testWidgets('mother can open and return from profile edit design', (
    tester,
  ) async {
    await startApp(tester);
    await selectRoleAndOpenLogin(tester, role: 'mother');
    await enterCredentials(
      tester,
      email: 'demo.mother@dampingi.test',
      password: 'demo1234',
    );
    await tapLoginSubmit(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mother-nav-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mother-profile-edit')));
    await tester.pumpAndSettle();

    expect(find.byType(MotherProfileEditPage), findsOneWidget);
    expect(find.text('Ubah Foto'), findsOneWidget);
    expect(find.text('Simpan Perubahan'), findsOneWidget);
    expect(find.text('Ubah kata sandi'), findsOneWidget);
    expect(find.text('Ibu Demo'), findsOneWidget);
    expect(find.text('demo.mother@dampingi.test'), findsOneWidget);
    await expectPasswordVisibilityToggle(
      tester,
      'mother-profile-edit-password',
    );
    await expectPasswordVisibilityToggle(
      tester,
      'mother-profile-edit-password-confirmation',
    );
    expect(
      tester.getSize(find.byKey(const Key('mother-profile-edit-avatar'))),
      const Size(85, 85),
    );
    expect(
      tester.getSize(find.byKey(const Key('mother-profile-edit-photo'))),
      const Size(121, 48),
    );
    expect(
      tester.getSize(find.byKey(const Key('mother-profile-edit-save'))),
      const Size(342, 48),
    );
    expect(
      tester.getSize(
        find.byKey(const Key('mother-profile-edit-change-password')),
      ),
      const Size(342, 48),
    );
    final avatar = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('mother-profile-edit-avatar')),
        matching: find.byType(Image),
      ),
    );
    expect(
      (avatar.image as AssetImage).assetName,
      'assets/images/mother_home/avatar-a.png',
    );
    await tester.drag(
      find.byKey(const Key('mother-profile-edit-scroll')),
      const Offset(0, 1000),
    );
    await tester.pumpAndSettle();
    final backIcon = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(backIcon.width, 24);
    expect(backIcon.height, 24);

    await tester.tap(find.byKey(const Key('mother-profile-edit-back')));
    await tester.pumpAndSettle();
    expect(find.byType(MotherProfilePage), findsOneWidget);
  });

  testWidgets('mother can open the Figma chat screen without a mock API call', (
    tester,
  ) async {
    await startApp(tester);
    await selectRoleAndOpenLogin(tester, role: 'mother');
    await enterCredentials(
      tester,
      email: 'demo.mother@dampingi.test',
      password: 'demo1234',
    );
    await tapLoginSubmit(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mother-nav-chat')));
    await tester.pumpAndSettle();

    expect(find.text('Dampingi'), findsOneWidget);
    expect(find.byKey(const Key('mother-chat-input')), findsOneWidget);
    expect(find.byKey(const Key('mother-chat-send')), findsOneWidget);
    expect(find.text('Hai gpt, aku hamil'), findsOneWidget);
    expect(
      find.text('Wow kamu hamil ya semoga lahiranya lancar nanti'),
      findsOneWidget,
    );
    expect(find.text('Ringkasan Percakapan'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('mother-chat-composer'))).height,
      53,
    );
    expect(
      tester.getSize(find.byKey(const Key('mother-chat-input'))).height,
      24,
    );
    expect(
      tester.getSize(find.byKey(const Key('mother-chat-send'))),
      const Size(36, 36),
    );
    final editable = tester
        .state<EditableTextState>(find.byType(EditableText))
        .renderEditable;
    final caretRect = editable.getLocalRectForCaret(
      const TextPosition(offset: 0),
    );
    final caretCenter = editable.localToGlobal(caretRect.center);
    final sendButtonRect = tester.getRect(
      find.byKey(const Key('mother-chat-send')),
    );
    expect(
      (caretCenter.dy - sendButtonRect.center.dy).abs(),
      lessThanOrEqualTo(2),
    );

    await tester.enterText(
      find.byKey(const Key('mother-chat-input')),
      'Pesan ini tidak boleh dikirim dengan token mock.',
    );
    await tester.tap(find.byKey(const Key('mother-chat-send')));
    await tester.pumpAndSettle();
    expect(
      find.text('Mode pratinjau aktif. Pesan belum dikirim ke layanan AI.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('mother-chat-input')))
          .controller
          ?.text,
      'Pesan ini tidak boleh dikirim dengan token mock.',
    );
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

  testWidgets(
    'login follows the account role regardless of role selection and guards other roles',
    (tester) async {
      await startApp(tester);
      await selectRoleAndOpenLogin(tester, role: 'mother');
      await enterCredentials(
        tester,
        email: 'demo.companion@dampingi.test',
        password: 'demo1234',
      );
      await tapLoginSubmit(tester);
      await tester.pumpAndSettle();
      expect(find.byType(CompanionPage), findsOneWidget);
      expect(find.textContaining('Peran akun tidak sesuai'), findsNothing);

      GoRouter.of(tester.element(find.byType(CompanionPage))).go('/doctor');
      await tester.pumpAndSettle();
      expect(find.byType(RouteErrorPage), findsOneWidget);
      expect(find.text('Akses tidak tersedia'), findsOneWidget);
    },
  );

  testWidgets('unauthenticated role route redirects to login', (tester) async {
    await startApp(tester);
    GoRouter.of(tester.element(find.byType(RolePickerPage))).go('/companion');
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('role picker uses the Figma role copy and emoji', (tester) async {
    await startApp(tester);

    expect(
      Theme.of(tester.element(find.byType(RolePickerPage)))
          .textTheme
          .bodyMedium
          ?.fontFamily,
      'Mona Sans',
    );
    expect(find.text('Pilih Peranmu di Dampingi'), findsOneWidget);
    expect(find.text('Saya Pendamping Ibu'), findsOneWidget);
    expect(find.byKey(const Key('role-emoji-mother')), findsOneWidget);
    expect(find.byKey(const Key('role-emoji-companion')), findsOneWidget);
    expect(find.byKey(const Key('role-emoji-professional')), findsOneWidget);
    expect(tester.getTopLeft(find.text('Pilih Peranmu di Dampingi')).dy, 43);
    expect(
      tester
          .widget<Text>(find.text('Pilih Peranmu di Dampingi'))
          .style
          ?.fontFamily,
      'Mona Sans',
    );
    expect(
      tester.getSize(find.byKey(const Key('role-mother'))),
      const Size(334, 142),
    );
    expect(
      tester.getSize(find.byKey(const Key('role-emoji-mother'))),
      const Size(36, 36),
    );
    const roleEmojiCharacters = {
      'mother': '🤱',
      'companion': '👨‍💼',
      'professional': '🩺',
    };
    for (final entry in roleEmojiCharacters.entries) {
      final emoji = tester.widget<Text>(
        find.descendant(
          of: find.byKey(Key('role-emoji-${entry.key}')),
          matching: find.byType(Text),
        ),
      );
      expect(emoji.data, entry.value);
    }
    expect(tester.takeException(), isNull);
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
    await expectPasswordVisibilityToggle(tester, 'register-password');
    await expectPasswordVisibilityToggle(tester, 'register-confirm-password');

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
      await expectPasswordVisibilityToggle(tester, 'reset-new-password');

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

    await tester.tap(find.byKey(const Key('mother-nav-profile')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('mother-profile-scroll')),
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('mother-profile-logout')));
    await tester.tap(find.byKey(const Key('mother-profile-logout')));
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
