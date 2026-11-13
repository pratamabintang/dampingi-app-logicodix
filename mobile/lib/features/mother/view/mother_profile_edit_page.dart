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
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _profileInitialized = false;

  Key _key(String suffix) => Key('${widget.keyPrefix}-$suffix');

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
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
                              onPressed: () => _showUnavailableNotice(
                                'Fitur ubah foto belum tersedia.',
                              ),
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
                              key: _key('password'),
                              controller: _passwordController,
                              label: 'Kata sandi',
                              hintText: '••••••••',
                              validator: validatePassword,
                              inputHeight: scaled(44),
                              textInputAction: TextInputAction.next,
                            ),
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
                              inputHeight: scaled(44),
                              textInputAction: TextInputAction.done,
                            ),
                            SizedBox(height: scaled(24)),
                            SizedBox(
                              height: scaled(48),
                              child: AppSubmitButton(
                                key: _key('change-password'),
                                label: 'Ubah kata sandi',
                                onPressed: _changePassword,
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

  void _saveProfile() {
    if (!_profileFormKey.currentState!.validate()) return;
    _showUnavailableNotice(
      'Perubahan profil belum dapat disimpan dari aplikasi ini.',
    );
  }

  void _changePassword() {
    if (!_passwordFormKey.currentState!.validate()) return;
    _showUnavailableNotice(
      'Fitur ubah kata sandi belum tersedia dari aplikasi ini.',
    );
  }

  void _showUnavailableNotice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
