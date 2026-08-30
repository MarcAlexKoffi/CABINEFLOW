import 'package:cabine_flow/app/app_routes.dart';
import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/features/auth/domain/models/auth_login_result.dart';
import 'package:cabine_flow/features/auth/domain/repositories/auth_repository.dart';
import 'package:cabine_flow/features/auth/presentation/view_models/login_view_model.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_brand.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late final LoginViewModel _viewModel;
  bool _obscurePassword = true;
  bool _rememberMe = false;

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
    if (email.isEmpty) return 'Saisis ton adresse e-mail.';
    final int atIndex = email.indexOf('@');
    final int dotIndex = email.lastIndexOf('.');
    final bool valid =
        atIndex > 0 && dotIndex > atIndex + 1 && dotIndex < email.length - 1;
    return valid ? null : 'Saisis une adresse e-mail valide.';
  }

  String? _validatePassword(String? value) {
    final String password = value ?? '';
    if (password.isEmpty) return 'Saisis ton mot de passe.';
    if (password.length < 4) {
      return 'Le mot de passe doit contenir au moins 4 caractères.';
    }
    return null;
  }

  Future<void> _submitForm() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final AuthLoginResult? result = await _viewModel.login(
      identifier: _identifierController.text,
      password: _passwordController.text,
    );

    if (!mounted || result == null) return;

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

  void _showGoogleMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('La connexion Google sera activée prochainement.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF4F8FF),
          body: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compact = constraints.maxHeight < 760;
                final double heroHeight = compact ? 238 : 270;

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: heroHeight,
                          width: double.infinity,
                          child: ClipPath(
                            clipper: const _LoginHeroClipper(),
                            child: Container(
                              color: Colors.white,
                              padding: EdgeInsets.only(top: compact ? 34 : 48),
                              child: const Column(
                                children: [
                                  IzyTelBrandMark(size: 88),
                                  SizedBox(height: 12),
                                  IzyTelWordmark(
                                    fontSize: 38,
                                    showTagline: true,
                                    centered: true,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            24,
                            compact ? 8 : 14,
                            24,
                            22,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Connexion à votre espace',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'Connectez-vous à votre espace\npour continuer',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: IzyTelColors.textSecondary,
                                          height: 1.35,
                                        ),
                                  ),
                                  const SizedBox(height: 18),
                                  if (_viewModel.errorMessage != null) ...[
                                    _ErrorBanner(
                                      message: _viewModel.errorMessage!,
                                    ),
                                    const SizedBox(height: 14),
                                  ],
                                  Form(
                                    key: _formKey,
                                    autovalidateMode:
                                        AutovalidateMode.onUserInteraction,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const _FieldLabel('Email'),
                                        const SizedBox(height: 7),
                                        TextFormField(
                                          controller: _identifierController,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          textInputAction: TextInputAction.next,
                                          autofillHints: const [
                                            AutofillHints.email,
                                          ],
                                          decoration: const InputDecoration(
                                            hintText: 'exemple@email.com',
                                            prefixIcon: Icon(
                                              Icons.mail_outline_rounded,
                                              size: 19,
                                            ),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 13,
                                                  vertical: 12,
                                                ),
                                          ),
                                          validator: _validateIdentifier,
                                          onChanged: (_) =>
                                              _viewModel.clearError(),
                                        ),
                                        const SizedBox(height: 13),
                                        const _FieldLabel('Mot de passe'),
                                        const SizedBox(height: 7),
                                        TextFormField(
                                          controller: _passwordController,
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
                                              size: 19,
                                            ),
                                            suffixIcon: IconButton(
                                              tooltip: _obscurePassword
                                                  ? 'Afficher le mot de passe'
                                                  : 'Masquer le mot de passe',
                                              onPressed: () => setState(
                                                () => _obscurePassword =
                                                    !_obscurePassword,
                                              ),
                                              icon: Icon(
                                                _obscurePassword
                                                    ? Icons
                                                          .visibility_off_outlined
                                                    : Icons.visibility_outlined,
                                                size: 19,
                                              ),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 13,
                                                  vertical: 12,
                                                ),
                                          ),
                                          validator: _validatePassword,
                                          onChanged: (_) =>
                                              _viewModel.clearError(),
                                          onFieldSubmitted: (_) =>
                                              _submitForm(),
                                        ),
                                        const SizedBox(height: 7),
                                        Row(
                                          children: [
                                            SizedBox(
                                              width: 30,
                                              height: 30,
                                              child: Checkbox(
                                                value: _rememberMe,
                                                onChanged: (bool? value) =>
                                                    setState(
                                                      () => _rememberMe =
                                                          value ?? false,
                                                    ),
                                                materialTapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                            ),
                                            const SizedBox(width: 3),
                                            Expanded(
                                              child: Text(
                                                'Se souvenir de moi',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelMedium
                                                    ?.copyWith(
                                                      color: IzyTelColors
                                                          .textSecondary,
                                                    ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed:
                                                  _showForgotPasswordMessage,
                                              style: TextButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                    ),
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              child: const Text(
                                                'Mot de passe oublié ?',
                                                style: TextStyle(fontSize: 11),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        SizedBox(
                                          height: 48,
                                          child: FilledButton(
                                            onPressed: _viewModel.isLoading
                                                ? null
                                                : _submitForm,
                                            child: _viewModel.isLoading
                                                ? const SizedBox.square(
                                                    dimension: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                  )
                                                : const Text('Se connecter'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const _OrDivider(),
                                  const SizedBox(height: 13),
                                  SizedBox(
                                    height: 46,
                                    child: OutlinedButton(
                                      onPressed: _showGoogleMessage,
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        side: const BorderSide(
                                          color: IzyTelColors.outline,
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'G',
                                            style: TextStyle(
                                              color: Color(0xFF4285F4),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 17,
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          Text('Continuer avec Google'),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: compact ? 22 : 34),
                                  Text(
                                    '© 2025 IzyTel. Tous droits réservés.',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: IzyTelColors.textMuted,
                                          fontSize: 10,
                                        ),
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
            ),
          ),
        );
      },
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: IzyTelColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 11,
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'ou continuer avec',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: IzyTelColors.textMuted,
              fontSize: 10,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IzyTelColors.errorSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: IzyTelColors.error,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: IzyTelColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginHeroClipper extends CustomClipper<Path> {
  const _LoginHeroClipper();

  @override
  Path getClip(Size size) {
    final Path path = Path()
      ..lineTo(0, size.height - 46)
      ..quadraticBezierTo(
        size.width * .50,
        size.height + 4,
        size.width,
        size.height - 46,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
