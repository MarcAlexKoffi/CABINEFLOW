import 'package:cabine_flow/app/app_routes.dart';
import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/features/auth/domain/models/auth_login_result.dart';
import 'package:cabine_flow/features/auth/domain/repositories/auth_repository.dart';
import 'package:cabine_flow/features/auth/presentation/view_models/login_view_model.dart';
import 'package:cabine_flow/shared/widgets/app_logo.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<LoginPage> createState() {
    return _LoginPageState();
  }
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _identifierController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  late final LoginViewModel _viewModel;

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();

    _viewModel = LoginViewModel(authRepository: widget.authRepository);
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _viewModel.dispose();

    super.dispose();
  }

  String? _validateIdentifier(String? value) {
    final String email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Saisis ton adresse e-mail.';
    }

    final int atIndex = email.indexOf('@');
    final int dotIndex = email.lastIndexOf('.');
    final bool isValidEmail =
        atIndex > 0 && dotIndex > atIndex + 1 && dotIndex < email.length - 1;

    if (!isValidEmail) {
      return 'Saisis une adresse e-mail valide.';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    final String password = value ?? '';

    if (password.isEmpty) {
      return 'Saisis ton mot de passe.';
    }

    if (password.length < 4) {
      return 'Le mot de passe doit contenir au moins 4 caractères.';
    }

    return null;
  }

  Future<void> _submitForm() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final bool isFormValid = _formKey.currentState?.validate() ?? false;

    if (!isFormValid) {
      return;
    }

    final AuthLoginResult? result = await _viewModel.login(
      identifier: _identifierController.text,
      password: _passwordController.text,
    );

    if (!mounted || result == null) {
      return;
    }

    if (result.isAuthenticated && result.user != null) {
      Navigator.of(
        context,
      ).pushReplacementNamed(AppRoutes.dashboard, arguments: result.user);
      return;
    }

    if (result.requiresAccessScreen) {
      Navigator.of(
        context,
      ).pushReplacementNamed(AppRoutes.pendingAccount, arguments: result);
    }
  }

  void _showForgotPasswordMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Demande à l’administrateur de réinitialiser ton mot de passe.',
          ),
        ),
      );
  }

  void _showSupportMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Le contact du support sera configuré ultérieurement.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(child: _LoginBackground()),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 32,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: AutofillGroup(
                        child: Form(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const AppLogo(
                                size: 64,
                                icon: Icons.water_drop_rounded,
                                titleFontSize: 30,
                                subtitle: 'Connexion à votre espace',
                              ),
                              const SizedBox(height: 32),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.outlineVariant.withAlpha(
                                      90,
                                    ),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x55000000),
                                      blurRadius: 24,
                                      offset: Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (_viewModel.errorMessage != null) ...[
                                      _LoginErrorBanner(
                                        message: _viewModel.errorMessage!,
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    const _FieldLabel(text: 'Adresse e-mail'),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _identifierController,
                                      style: const TextStyle(
                                        color: AppColors.inputText,
                                        fontSize: 15,
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [
                                        AutofillHints.email,
                                      ],
                                      decoration: const InputDecoration(
                                        hintText: 'ex: marc@cabineflow.app',
                                        prefixIcon: Icon(
                                          Icons.mail_outline_rounded,
                                        ),
                                      ),
                                      validator: _validateIdentifier,
                                      onChanged: (String value) {
                                        _viewModel.clearError();
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: _FieldLabel(
                                            text: 'Mot de passe',
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: _showForgotPasswordMessage,
                                          style: TextButton.styleFrom(
                                            minimumSize: Size.zero,
                                            padding: const EdgeInsets.all(4),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: const Text(
                                            'Mot de passe oublié ?',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _passwordController,
                                      style: const TextStyle(
                                        color: AppColors.inputText,
                                        fontSize: 15,
                                      ),
                                      obscureText: _obscurePassword,
                                      enableSuggestions: false,
                                      autocorrect: false,
                                      textInputAction: TextInputAction.done,
                                      autofillHints: const [
                                        AutofillHints.password,
                                      ],
                                      decoration: InputDecoration(
                                        hintText: '••••••••',
                                        prefixIcon: const Icon(
                                          Icons.lock_outline_rounded,
                                        ),
                                        suffixIcon: IconButton(
                                          tooltip: _obscurePassword
                                              ? 'Afficher le mot de passe'
                                              : 'Masquer le mot de passe',
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                          ),
                                        ),
                                      ),
                                      validator: _validatePassword,
                                      onChanged: (String value) {
                                        _viewModel.clearError();
                                      },
                                      onFieldSubmitted: (String value) {
                                        _submitForm();
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    FilledButton(
                                      onPressed: _viewModel.isLoading
                                          ? null
                                          : _submitForm,
                                      child: AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        child: _viewModel.isLoading
                                            ? const Row(
                                                key: ValueKey<String>(
                                                  'loading',
                                                ),
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2.2,
                                                          color: AppColors
                                                              .onPrimary,
                                                        ),
                                                  ),
                                                  SizedBox(width: 10),
                                                  Text('Connexion...'),
                                                ],
                                              )
                                            : const Row(
                                                key: ValueKey<String>('button'),
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text('Se connecter'),
                                                  SizedBox(width: 8),
                                                  Icon(
                                                    Icons.arrow_forward_rounded,
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          'Besoin d’aide ?',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                        TextButton(
                                          onPressed: _showSupportMessage,
                                          style: TextButton.styleFrom(
                                            minimumSize: Size.zero,
                                            padding: const EdgeInsets.only(
                                              left: 4,
                                            ),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: const Text(
                                            'Contacter le support',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.labelLarge);
  }
}

class _LoginErrorBanner extends StatelessWidget {
  const _LoginErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withAlpha(70),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withAlpha(120)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ColoredBox(color: AppColors.background),
        Positioned(
          top: -180,
          left: -150,
          child: Container(
            width: 420,
            height: 420,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [AppColors.primary.withAlpha(24), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          right: -150,
          bottom: -170,
          child: Container(
            width: 380,
            height: 380,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [AppColors.secondary.withAlpha(22), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
