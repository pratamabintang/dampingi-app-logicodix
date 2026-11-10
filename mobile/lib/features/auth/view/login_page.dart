import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_error.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_password_field.dart';
import '../../../core/widgets/app_submit_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../models/app_role.dart';
import '../controller/auth_controller.dart';
import '../models/login_models.dart';
import '../validation/auth_form_validators.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: auth.when(
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
    final role = widget.state.selectedRole;
    final minimumHeight = MediaQuery.sizeOf(context).height;

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentHeight = minimumHeight > constraints.maxHeight
            ? minimumHeight
            : constraints.maxHeight;
        return SingleChildScrollView(
          child: SizedBox(
            height: contentHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 490,
                  child: Image.asset(
                    'assets/images/login_hero.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 16,
                  child: IconButton.filledTonal(
                    tooltip: 'Kembali ke pilihan peran',
                    onPressed: () => context.go('/roles'),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                Positioned(
                  top: 352,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(28, 26, 28, 32),
                        children: [
                          Text(
                            'Masuk',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            role == null
                                ? 'Masuk ke akun Dampingi Anda.'
                                : 'Masuk sebagai ${_roleLabel(role)}.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 24),
                          AppTextField(
                            key: const Key('login-email'),
                            controller: _emailController,
                            label: 'Email',
                            hintText: 'Masukkan email',
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            enabled: !widget.state.isSubmitting,
                            autofillHints: const [AutofillHints.username],
                            autocorrect: false,
                            validator: validateEmail,
                            onChanged: (_) => widget.onClearError(),
                          ),
                          const SizedBox(height: 16),
                          AppPasswordField(
                            key: const Key('login-password'),
                            controller: _passwordController,
                            label: 'Kata sandi',
                            hintText: 'Masukkan kata sandi',
                            textInputAction: TextInputAction.done,
                            enabled: !widget.state.isSubmitting,
                            autofillHints: const [AutofillHints.password],
                            validator: validatePassword,
                            onFieldSubmitted: (_) => _submit(),
                            onChanged: (_) => widget.onClearError(),
                          ),
                          if (widget.state.errorMessage
                              case final message?) ...[
                            const SizedBox(height: 12),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                message,
                                key: const Key('login-error'),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: const Color(0xFFD92D20)),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          AppSubmitButton(
                            key: const Key('login-submit'),
                            label: 'Masuk',
                            isLoading: widget.state.isSubmitting,
                            onPressed: _submit,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Demo: demo.${_accountRoleSuffix(role)}@dampingi.test '
                            'dengan kata sandi demo1234',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.secondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _roleLabel(AppRole role) => switch (role) {
  AppRole.mother => 'Ibu',
  AppRole.companion => 'Pendamping',
  AppRole.professional => 'Tenaga kesehatan',
};

String _accountRoleSuffix(AppRole? role) => switch (role) {
  AppRole.mother => 'mother',
  AppRole.companion => 'companion',
  AppRole.professional => 'doctor',
  null => 'mother',
};
