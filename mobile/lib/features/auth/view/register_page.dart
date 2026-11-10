import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_error.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_password_field.dart';
import '../../../core/widgets/app_submit_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../controller/auth_controller.dart';
import '../models/login_models.dart';
import '../validation/auth_form_validators.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

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
    final auth = ref.watch(authControllerProvider);
    return auth.when(
      loading: () => const Scaffold(
        body: AppLoading(message: 'Menyiapkan halaman pendaftaran...'),
      ),
      error: (error, stackTrace) => Scaffold(
        body: AppError(
          message: 'Halaman pendaftaran tidak dapat dimuat.',
          onRetry: () => ref.invalidate(authControllerProvider),
        ),
      ),
      data: (state) => _buildPage(context, state),
    );
  }

  Widget _buildPage(BuildContext context, AuthState state) {
    final baseTheme = Theme.of(context);
    final registrationTheme = baseTheme.copyWith(
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        hintStyle: GoogleFonts.dmSans(
          color: AppTheme.secondary,
          fontSize: 16,
          height: 24 / 16,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        constraints: const BoxConstraints(minHeight: 44),
      ),
    );

    return Theme(
      data: registrationTheme,
      child: Scaffold(
        backgroundColor: AppTheme.cream,
        resizeToAvoidBottomInset: true,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final frameWidth = constraints.maxWidth < 390
                ? constraints.maxWidth
                : 390.0;

            return Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppTheme.cream, Colors.white],
                      stops: [0.5, 1],
                    ),
                  ),
                ),
                Positioned(
                  top: -110,
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
                        alignment: Alignment.center,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: SingleChildScrollView(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 202),
                        child: SizedBox(
                          width: frameWidth - 10,
                          child: _RegisterPanel(
                            state: state,
                            formKey: _formKey,
                            nameController: _nameController,
                            emailController: _emailController,
                            passwordController: _passwordController,
                            confirmationController: _confirmationController,
                            onChanged: _clearError,
                            onSubmit: _submit,
                            onLogin: () => context.go('/login'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _clearError(String _) {
    ref.read(authControllerProvider.notifier).clearError();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final registered = await ref
        .read(authControllerProvider.notifier)
        .register(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
    if (registered && mounted) context.go('/login');
  }
}

class _RegisterPanel extends StatelessWidget {
  const _RegisterPanel({
    required this.state,
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmationController,
    required this.onChanged,
    required this.onSubmit,
    required this.onLogin,
  });

  final AuthState state;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmationController;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 56),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Text(
                'Dampingi',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color: AppTheme.coral,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  height: 32 / 24,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Halo, Silahkan buat akun Anda',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color: AppTheme.muted,
                  fontSize: 16,
                  height: 24 / 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Form(
            key: formKey,
            child: Column(
              children: [
                AppTextField(
                  key: const Key('register-name'),
                  controller: nameController,
                  label: 'Nama',
                  hintText: 'Masukan nama anda',
                  validator: validateName,
                  inputHeight: 44,
                  enabled: !state.isSubmitting,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  onChanged: onChanged,
                  labelStyle: _fieldLabelStyle,
                  textStyle: _fieldTextStyle,
                ),
                const SizedBox(height: 24),
                AppTextField(
                  key: const Key('register-email'),
                  controller: emailController,
                  label: 'Email',
                  hintText: 'Masukan email anda',
                  validator: validateEmail,
                  inputHeight: 44,
                  enabled: !state.isSubmitting,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  onChanged: onChanged,
                  labelStyle: _fieldLabelStyle,
                  textStyle: _fieldTextStyle,
                ),
                const SizedBox(height: 24),
                AppPasswordField(
                  key: const Key('register-password'),
                  controller: passwordController,
                  label: 'Kata sandi',
                  hintText: '••••••••',
                  validator: validatePassword,
                  inputHeight: 44,
                  showVisibilityToggle: false,
                  enabled: !state.isSubmitting,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: onChanged,
                  labelStyle: _fieldLabelStyle,
                  textStyle: _fieldTextStyle,
                ),
                const SizedBox(height: 24),
                AppPasswordField(
                  key: const Key('register-confirm-password'),
                  controller: confirmationController,
                  label: 'Konfirmasi kata sandi',
                  hintText: '••••••••',
                  validator: (value) => validatePasswordConfirmation(
                    value,
                    passwordController.text,
                  ),
                  inputHeight: 44,
                  showVisibilityToggle: false,
                  enabled: !state.isSubmitting,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onFieldSubmitted: (_) => onSubmit(),
                  onChanged: onChanged,
                  labelStyle: _fieldLabelStyle,
                  textStyle: _fieldTextStyle,
                ),
                if (state.errorMessage case final message?) ...[
                  const SizedBox(height: 12),
                  Text(
                    message,
                    key: const Key('register-error'),
                    style: GoogleFonts.dmSans(
                      color: const Color(0xFFD92D20),
                      fontSize: 14,
                      height: 20 / 14,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                AppSubmitButton(
                  key: const Key('register-submit'),
                  label: 'Buat akun',
                  isLoading: state.isSubmitting,
                  onPressed: onSubmit,
                  textStyle: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 24 / 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Sudah punya akun?',
                style: GoogleFonts.dmSans(
                  color: AppTheme.secondary,
                  fontSize: 14,
                  height: 20 / 14,
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                key: const Key('register-login'),
                onPressed: onLogin,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.coral,
                  minimumSize: Size.zero,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 20 / 14,
                  ),
                ),
                child: const Text('Masuk'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final _fieldLabelStyle = GoogleFonts.dmSans(
  color: AppTheme.body,
  fontSize: 14,
  fontWeight: FontWeight.w500,
  height: 20 / 14,
);

final _fieldTextStyle = GoogleFonts.dmSans(
  color: AppTheme.body,
  fontSize: 16,
  height: 24 / 16,
);
