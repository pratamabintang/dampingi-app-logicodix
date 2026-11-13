import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_brand_header.dart';
import '../../../core/widgets/app_password_field.dart';
import '../../../core/widgets/app_submit_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../models/password_reset_flow.dart';
import '../validation/auth_form_validators.dart';

enum PasswordResetStage { email, code, newPassword }

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({required this.stage, this.flow, super.key});

  final PasswordResetStage stage;
  final PasswordResetFlow? flow;

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    switch (widget.stage) {
      case PasswordResetStage.email:
        final flow = PasswordResetFlow(email: _emailController.text.trim());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kode demo: ${PasswordResetFlow.demoCode}'),
          ),
        );
        context.go('/verify-reset-code', extra: flow);
      case PasswordResetStage.code:
        final flow = widget.flow;
        if (flow == null) {
          context.go('/reset-password');
          return;
        }
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        context.go('/new-password', extra: flow);
      case PasswordResetStage.newPassword:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Mode demo: kata sandi belum diubah pada akun server.',
              ),
            ),
          );
        context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final pageTheme = baseTheme.copyWith(
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        hintStyle: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          color: AppTheme.secondary,
          fontSize: 16,
          height: 24 / 16,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        constraints: const BoxConstraints(minHeight: 44),
      ),
    );

    return Theme(
      data: pageTheme,
      child: Scaffold(
        key: Key('reset-${widget.stage.name}-page'),
        backgroundColor: AppTheme.cream,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final frameWidth = math.min(constraints.maxWidth, 390.0);
            final contentHeight = math.max(constraints.maxHeight, 492.0);
            final panelWidth = math.max(0.0, frameWidth - 10);

            return SingleChildScrollView(
              child: SizedBox(
                height: contentHeight,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [AppTheme.cream, Colors.white],
                            stops: [0.5, 1],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 489,
                      child: Center(
                        child: SizedBox(
                          width: frameWidth,
                          height: 489,
                          child: Image.asset(
                            'assets/images/login_hero.png',
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: contentHeight - 492,
                      left: 0,
                      right: 0,
                      height: 492,
                      child: Center(
                        child: SizedBox(
                          width: panelWidth,
                          height: 492,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(32),
                            ),
                            child: ColoredBox(
                              color: Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  24,
                                  24,
                                  56,
                                ),
                                child: _buildPanel(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final (subtitle, field, buttonLabel) = switch (widget.stage) {
      PasswordResetStage.email => (
        'Masukan email untuk mengirim kode',
        _buildEmailField(),
        'Kirim kode',
      ),
      PasswordResetStage.code => (
        'Masukan kode lorem ipsum dolor sit amet',
        _buildCodeField(),
        'Verifikasi kode',
      ),
      PasswordResetStage.newPassword => (
        'Masukan kata sandi baru anda',
        _buildPasswordField(),
        'Ubah kata sandi',
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          children: [
            const AppBrandMark(),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: AppTheme.muted,
                fontSize: 16,
                height: 24 / 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Form(
          key: _formKey,
          child: Column(
            children: [
              field,
              const SizedBox(height: 24),
              AppSubmitButton(
                key: Key('reset-submit-${widget.stage.name}'),
                label: buttonLabel,
                onPressed: _submit,
                textStyle: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 24 / 16,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                children: [
                  Text(
                    'Belum punya akun?',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: AppTheme.secondary,
                      fontSize: 14,
                      height: 20 / 14,
                    ),
                  ),
                  TextButton(
                    key: Key('reset-register-${widget.stage.name}'),
                    onPressed: () => context.go('/register'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.coral,
                      minimumSize: Size.zero,
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 20 / 14,
                      ),
                    ),
                    child: const Text('Daftar sekarang'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() => AppTextField(
    key: const Key('reset-email'),
    controller: _emailController,
    label: 'Email',
    hintText: 'Masukan email anda',
    validator: validateEmail,
    keyboardType: TextInputType.emailAddress,
    textInputAction: TextInputAction.done,
    autofillHints: const [AutofillHints.email],
    onFieldSubmitted: (_) => _submit(),
    labelStyle: _fieldLabelStyle,
    textStyle: _fieldTextStyle,
  );

  Widget _buildCodeField() => AppTextField(
    key: const Key('reset-code'),
    controller: _codeController,
    label: 'Kode',
    hintText: PasswordResetFlow.demoCode,
    validator: _validateDemoCode,
    keyboardType: TextInputType.number,
    textInputAction: TextInputAction.done,
    onFieldSubmitted: (_) => _submit(),
    labelStyle: _fieldLabelStyle,
    textStyle: _fieldTextStyle,
  );

  Widget _buildPasswordField() => AppPasswordField(
    key: const Key('reset-new-password'),
    controller: _passwordController,
    label: 'Kata sandi baru',
    hintText: '••••••••',
    validator: validatePassword,
    showVisibilityToggle: false,
    textInputAction: TextInputAction.done,
    autofillHints: const [AutofillHints.newPassword],
    onFieldSubmitted: (_) => _submit(),
    labelStyle: _fieldLabelStyle,
    textStyle: _fieldTextStyle,
  );
}

String? _validateDemoCode(String? value) {
  final code = value?.trim() ?? '';
  if (code.isEmpty) return 'Kode wajib diisi.';
  if (code != PasswordResetFlow.demoCode) {
    return 'Kode demo tidak valid. Gunakan 123456.';
  }
  return null;
}

const _fieldLabelStyle = TextStyle(
  fontFamily: AppTheme.fontFamily,
  color: AppTheme.body,
  fontSize: 14,
  fontWeight: FontWeight.w500,
  height: 20 / 14,
);

const _fieldTextStyle = TextStyle(
  fontFamily: AppTheme.fontFamily,
  color: AppTheme.body,
  fontSize: 16,
  height: 24 / 16,
);
