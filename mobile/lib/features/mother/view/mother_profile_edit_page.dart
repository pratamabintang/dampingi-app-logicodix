import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_password_field.dart';
import '../../../core/widgets/app_profile_avatar.dart';
import '../../../core/widgets/app_submit_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../auth/controller/auth_controller.dart';
import '../../auth/validation/auth_form_validators.dart';
import '../../../services/backend_api.dart';
import '../../auth/repositories/profile_repository.dart';

class MotherProfileEditPage extends ConsumerStatefulWidget {
  const MotherProfileEditPage({
    this.avatarAsset = 'assets/images/mother_home/avatar-a.png',
    this.keyPrefix = 'mother-profile-edit',
    this.backLocation = '/mother/profile',
    super.key,
  });

  final String avatarAsset;
  final String keyPrefix;
  final String backLocation;

  @override
  ConsumerState<MotherProfileEditPage> createState() =>
      _MotherProfileEditPageState();
}

class CompanionProfileEditPage extends MotherProfileEditPage {
  const CompanionProfileEditPage({super.key})
    : super(
        avatarAsset: 'assets/images/companion_profile/profile-avatar.png',
        keyPrefix: 'companion-profile-edit',
        backLocation: '/companion',
      );
}

class _MotherProfileEditPageState extends ConsumerState<MotherProfileEditPage> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _profileInitialized = false;
  bool _savingProfile = false;
  bool _changingPassword = false;

  Key _key(String suffix) => Key('${widget.keyPrefix}-$suffix');

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).asData?.value.session?.user;
    if (!_profileInitialized && user != null) {
      _nameController.text = user.name ?? '';
      _emailController.text = user.email;
      _profileInitialized = true;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = (constraints.maxWidth / 390)
                .clamp(0.7, 1.15)
                .toDouble();
            final width = math.min(constraints.maxWidth, 390 * scale);
            double scaled(double value) => value * scale;

            return Center(
              child: SizedBox(
                width: width,
                child: Form(
                  key: _profileFormKey,
                  child: ListView(
                    key: _key('scroll'),
                    padding: EdgeInsets.fromLTRB(
                      scaled(24),
                      scaled(20),
                      scaled(24),
                      scaled(34),
                    ),
                    children: [
                      SizedBox(
                        height: scaled(24),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            key: _key('back'),
                            onPressed: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go(widget.backLocation);
                              }
                            },
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints.tightFor(
                              width: scaled(24),
                              height: scaled(24),
                            ),
                            icon: SvgPicture.asset(
                              'assets/images/mother_profile/arrow-left.svg',
                              width: 24,
                              height: 24,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: scaled(36)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AppProfileAvatar(
                            key: _key('avatar'),
                            assetPath: widget.avatarAsset,
                            size: scaled(85),
                            semanticLabel: 'Foto profil',
                          ),
                          SizedBox(
                            width: scaled(121),
                            height: scaled(48),
                            child: FilledButton(
                              key: _key('photo'),
                              onPressed: () =>
                                  _notify('Fitur ubah foto belum tersedia.'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.coralLight,
                                foregroundColor: AppTheme.coralText,
                                minimumSize: Size(0, scaled(48)),
                                padding: EdgeInsets.symmetric(
                                  horizontal: scaled(20),
                                  vertical: scaled(12),
                                ),
                                elevation: 1,
                                shadowColor: const Color(0x0D101828),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    scaled(8),
                                  ),
                                ),
                                textStyle: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: scaled(16),
                                  fontWeight: FontWeight.w600,
                                  height: 24 / 16,
                                ),
                              ),
                              child: const Text('Ubah Foto'),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: scaled(36)),
                      AppTextField(
                        key: _key('name'),
                        controller: _nameController,
                        label: 'Nama',
                        hintText: 'Masukan nama anda',
                        validator: validateName,
                        inputHeight: scaled(44),
                        textInputAction: TextInputAction.next,
                      ),
                      SizedBox(height: scaled(24)),
                      AppTextField(
                        key: _key('email'),
                        controller: _emailController,
                        label: 'Email',
                        hintText: 'Masukan email anda',
                        validator: validateEmail,
                        enabled: false,
                        keyboardType: TextInputType.emailAddress,
                        inputHeight: scaled(44),
                        textInputAction: TextInputAction.done,
                      ),
                      SizedBox(height: scaled(24)),
                      SizedBox(
                        height: scaled(48),
                        child: AppSubmitButton(
                          key: _key('save'),
                          label: 'Simpan Perubahan',
                          onPressed: _saveProfile,
                          isLoading: _savingProfile,
                          textStyle: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: scaled(16),
                            fontWeight: FontWeight.w600,
                            height: 24 / 16,
                          ),
                          buttonStyle: FilledButton.styleFrom(
                            backgroundColor: AppTheme.coral,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: scaled(20),
                              vertical: scaled(12),
                            ),
                            elevation: 1,
                            shadowColor: const Color(0x0D101828),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(scaled(8)),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: scaled(36)),
                      Form(
                        key: _passwordFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppPasswordField(
                              key: _key('current-password'),
                              controller: _currentPasswordController,
                              label: 'Kata sandi saat ini',
                              hintText: '••••••••',
                              validator: validatePassword,
                              inputHeight: scaled(44),
                              textInputAction: TextInputAction.next,
                            ),
                            SizedBox(height: scaled(24)),
                            AppPasswordField(
                              key: _key('password'),
                              controller: _passwordController,
                              label: 'Kata sandi baru',
                              hintText: '••••••••',
                              validator: _validateNewPassword,
                              onChanged: (_) => setState(() {}),
                              inputHeight: scaled(44),
                              textInputAction: TextInputAction.next,
                            ),
                            SizedBox(height: scaled(6)),
                            _passwordHints(scale),
                            SizedBox(height: scaled(24)),
                            AppPasswordField(
                              key: _key('password-confirmation'),
                              controller: _confirmationController,
                              label: 'Konfirmasi kata sandi',
                              hintText: '••••••••',
                              validator: (value) =>
                                  validatePasswordConfirmation(
                                    value,
                                    _passwordController.text,
                                  ),
                              onChanged: (_) => setState(() {}),
                              inputHeight: scaled(44),
                              textInputAction: TextInputAction.done,
                            ),
                            SizedBox(height: scaled(6)),
                            _confirmationHint(scale),
                            SizedBox(height: scaled(24)),
                            SizedBox(
                              height: scaled(48),
                              child: AppSubmitButton(
                                key: _key('change-password'),
                                label: 'Ubah kata sandi',
                                onPressed: _changePassword,
                                isLoading: _changingPassword,
                                textStyle: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: scaled(16),
                                  fontWeight: FontWeight.w600,
                                  height: 24 / 16,
                                ),
                                buttonStyle: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.coral,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: scaled(20),
                                    vertical: scaled(12),
                                  ),
                                  elevation: 1,
                                  shadowColor: const Color(0x0D101828),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      scaled(8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String? _validateNewPassword(String? value) {
    final required = validatePassword(value);
    if (required != null) return required;
    if (_passwordRules.any((rule) => !rule.isMet(value!))) {
      return 'Kata sandi belum memenuhi semua aturan di bawah.';
    }
    return null;
  }

  Widget _passwordHints(double scale) {
    final password = _passwordController.text;
    return Column(
      key: _key('password-rules'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final rule in _passwordRules)
          Text(
            '${rule.isMet(password) ? '✓' : '•'} ${rule.label}',
            style: TextStyle(
              color: rule.isMet(password) ? _ruleMetColor : AppTheme.secondary,
              fontFamily: AppTheme.fontFamily,
              fontSize: 14 * scale,
              height: 20 / 14,
            ),
          ),
      ],
    );
  }

  Widget _confirmationHint(double scale) {
    final confirmation = _confirmationController.text;
    final matches =
        confirmation.isNotEmpty && confirmation == _passwordController.text;
    return Text(
      '${matches ? '✓' : '•'} Sama dengan kata sandi baru',
      key: _key('password-confirmation-hint'),
      style: TextStyle(
        color: matches ? _ruleMetColor : AppTheme.secondary,
        fontFamily: AppTheme.fontFamily,
        fontSize: 14 * scale,
        height: 20 / 14,
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (_savingProfile || !_profileFormKey.currentState!.validate()) return;
    if (ref.read(backendTokenProvider) == null) {
      _notify('Mode pratinjau: perubahan profil tidak disimpan.');
      return;
    }

    final name = _nameController.text.trim();
    setState(() => _savingProfile = true);
    try {
      final user = await ref
          .read(profileRepositoryProvider)
          .updateName(name: name);
      ref
          .read(authControllerProvider.notifier)
          .updateUserName(user.name ?? name);
      _notify('Profil berhasil disimpan.');
    } on Exception catch (error) {
      _notify(_messageFor(error));
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    if (_changingPassword || !_passwordFormKey.currentState!.validate()) {
      return;
    }
    if (ref.read(backendTokenProvider) == null) {
      _notify('Mode pratinjau: kata sandi tidak diubah.');
      return;
    }

    setState(() => _changingPassword = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .changePassword(
            currentPassword: _currentPasswordController.text,
            newPassword: _passwordController.text,
          );
      _notify(
        'Kata sandi diubah. Silakan masuk kembali dengan kata sandi baru.',
      );
      // Backend mencabut semua sesi, jadi token ini sudah tidak berlaku.
      await ref.read(authControllerProvider.notifier).logout();
    } on Exception catch (error) {
      _notify(_messageFor(error));
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  static String _messageFor(Object error) => switch (error) {
    BackendApiException(statusCode: 401) =>
      'Sesi login telah berakhir. Silakan masuk kembali.',
    BackendApiException(message: 'Current password is incorrect') =>
      'Kata sandi saat ini salah.',
    BackendApiException(
      message: 'New password must differ from the current one',
    ) =>
      'Kata sandi baru harus berbeda dari kata sandi saat ini.',
    BackendApiException(:final message) => message,
    ApiNetworkException(:final message) => message,
    ApiConfigurationException(:final message) => message,
    _ => 'Respons server tidak dapat dibaca. Coba lagi.',
  };

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PasswordRule {
  const _PasswordRule(this.label, this.isMet);

  final String label;
  final bool Function(String password) isMet;
}

/// Samakan dengan aturan kata sandi Supabase (Authentication → Email) dan backend.
final _passwordRules = <_PasswordRule>[
  _PasswordRule('8–72 karakter', (p) => p.length >= 8 && p.length <= 72),
  _PasswordRule('Huruf kecil (a–z)', (p) => p.contains(RegExp('[a-z]'))),
  _PasswordRule('Huruf besar (A–Z)', (p) => p.contains(RegExp('[A-Z]'))),
  _PasswordRule('Angka (0–9)', (p) => p.contains(RegExp('[0-9]'))),
  _PasswordRule(
    'Simbol (mis. ! @ # ?)',
    (p) => p.contains(RegExp(r'[^A-Za-z0-9]')),
  ),
];

/// Hijau yang sama dengan pilihan terpilih di dialog EPDS.
const _ruleMetColor = Color(0xFF12B76A);
