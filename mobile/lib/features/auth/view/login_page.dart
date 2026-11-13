import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_brand_header.dart';
import '../../../core/widgets/app_error.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_password_field.dart';
import '../../../core/widgets/app_submit_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../controller/auth_controller.dart';
import '../models/login_models.dart';
import '../validation/auth_form_validators.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/roles');
      },
      child: Scaffold(
        body: auth.when(
          loading: () =>
              const AppLoading(message: 'Menyiapkan halaman masuk...'),
          error: (error, stackTrace) => AppError(
            message: 'Halaman masuk tidak dapat dimuat.',
            onRetry: () => ref.invalidate(authControllerProvider),
          ),
          data: (value) => _LoginContent(
            state: value,
            onClearError: ref.read(authControllerProvider.notifier).clearError,
            onLogin: (email, password) => ref
                .read(authControllerProvider.notifier)
                .login(email: email, password: password),
          ),
        ),
      ),
    );
  }
}

class _LoginContent extends StatefulWidget {
  const _LoginContent({
    required this.state,
    required this.onClearError,
    required this.onLogin,
  });

  final AuthState state;
  final VoidCallback onClearError;
  final Future<LoginResponse?> Function(String email, String password) onLogin;

  @override
  State<_LoginContent> createState() => _LoginContentState();
}

class _LoginContentState extends State<_LoginContent> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final response = await widget.onLogin(
      _emailController.text,
      _passwordController.text,
    );
    if (response != null && mounted) {
      final role = response.user.role;
      if (role != null) context.go(role.location);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final loginTheme = baseTheme.copyWith(
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
      data: loginTheme,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final frameWidth = math.min(constraints.maxWidth, 390.0);
          final panelHeight = widget.state.errorMessage == null ? 492.0 : 524.0;
          final contentHeight = math.max(constraints.maxHeight, panelHeight);

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
                        key: const Key('login-image-frame'),
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
                    top: contentHeight - panelHeight,
                    left: 0,
                    right: 0,
                    height: panelHeight,
                    child: Center(
                      child: SizedBox(
                        key: const Key('login-panel'),
                        width: math.max(0, frameWidth - 10),
                        height: panelHeight,
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
                              child: SingleChildScrollView(
                                child: _buildPanel(context),
                              ),
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
    );
  }

  Widget _buildPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          children: [
            const AppBrandMark(),
            const SizedBox(height: 10),
            SizedBox(
              width: 332,
              height: 24,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Halo, Senang melihatmu kembali!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: AppTheme.muted,
                    fontSize: 16,
                    height: 24 / 16,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                key: const Key('login-email'),
                controller: _emailController,
                label: 'Email',
                hintText: 'Masukan email anda',
                inputHeight: 44,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: !widget.state.isSubmitting,
                autofillHints: const [AutofillHints.username],
                autocorrect: false,
                validator: validateEmail,
                onChanged: (_) => widget.onClearError(),
                labelStyle: _fieldLabelStyle,
                textStyle: _fieldTextStyle,
              ),
              const SizedBox(height: 24),
              AppPasswordField(
                key: const Key('login-password'),
                controller: _passwordController,
                label: 'Kata sandi',
                hintText: '••••••••',
                inputHeight: 44,
                textInputAction: TextInputAction.done,
                enabled: !widget.state.isSubmitting,
                autofillHints: const [AutofillHints.password],
                validator: validatePassword,
                onFieldSubmitted: (_) => _submit(),
                onChanged: (_) => widget.onClearError(),
                labelStyle: _fieldLabelStyle,
                textStyle: _fieldTextStyle,
              ),
              const SizedBox(height: 24),
              Row(
                key: const Key('login-actions'),
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 91,
                    height: 18,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Semantics(
                        checked: _rememberMe,
                        label: 'Ingat saya',
                        child: InkWell(
                          key: const Key('login-remember-me'),
                          onTap: widget.state.isSubmitting
                              ? null
                              : () => setState(() {
                                  _rememberMe = !_rememberMe;
                                }),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: _rememberMe
                                      ? AppTheme.coral
                                      : Colors.white,
                                  border: Border.all(
                                    color: _rememberMe
                                        ? AppTheme.coral
                                        : AppTheme.border,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: _rememberMe
                                    ? const Icon(
                                        Icons.check,
                                        size: 12,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Ingat saya',
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  color: AppTheme.body,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  height: 20 / 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 117,
                    height: 18,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        key: const Key('login-reset-password'),
                        onPressed: widget.state.isSubmitting
                            ? null
                            : () => context.go('/reset-password'),
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
                        child: const Text('Lupa kata sandi?'),
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.state.errorMessage case final message?) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    key: const Key('login-error'),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: Color(0xFFD92D20),
                      fontSize: 14,
                      height: 20 / 14,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              AppSubmitButton(
                key: const Key('login-submit'),
                label: 'Masuk',
                isLoading: widget.state.isSubmitting,
                onPressed: _submit,
                textStyle: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 24 / 16,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                key: const Key('login-register-row'),
                height: 20,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
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
                      const SizedBox(width: 4),
                      TextButton(
                        key: const Key('login-register'),
                        onPressed: widget.state.isSubmitting
                            ? null
                            : () => context.go('/register'),
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
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
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
