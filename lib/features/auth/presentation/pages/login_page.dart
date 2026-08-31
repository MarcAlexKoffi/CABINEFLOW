import 'package:cabine_flow/app/app_routes.dart';
import 'package:cabine_flow/core/services/session_preferences.dart';
import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/features/auth/domain/models/auth_login_result.dart';
import 'package:cabine_flow/features/auth/domain/repositories/auth_repository.dart';
import 'package:cabine_flow/features/auth/presentation/view_models/login_view_model.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_brand.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

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
    _restoreRememberedPreference();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _restoreRememberedPreference() async {
    final RememberedSessionPreference preference =
        await SessionPreferences.load();
    if (!mounted) return;
    setState(() {
      _rememberMe = preference.rememberMe;
      if (_identifierController.text.trim().isEmpty &&
          preference.email.isNotEmpty) {
        _identifierController.text = preference.email;
      }
    });
  }

  Future<void> _persistRememberedPreference() async {
    if (_rememberMe) {
      await SessionPreferences.save(
        rememberMe: true,
        email: _identifierController.text,
      );
    } else {
      await SessionPreferences.clear();
    }
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
      await _persistRememberedPreference();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacementNamed(AppRoutes.dashboard, arguments: result.user);
      return;
    }

    if (result.requiresAccessScreen) {
      await _persistRememberedPreference();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacementNamed(AppRoutes.pendingAccount, arguments: result);
    }
  }

  void _showForgotPasswordMessage() {
    IzyTelFeedback.show(
      context,
      'Demande à l’administrateur de réinitialiser ton mot de passe.',
    );
  }

  void _showGoogleMessage() {
    IzyTelFeedback.show(
      context,
      'La connexion Google sera activée prochainement.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          backgroundColor: IzyTelColors.surfaceMuted,
          body: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double availableHeight = constraints.maxHeight;
                final double availableWidth = constraints.maxWidth;
                final bool compactHeight = availableHeight < 720;
                final bool compactWidth = availableWidth < 360;
                final double contentHorizontal = compactWidth ? 22 : 28;
                final double heroHeight = (availableWidth * .80).clamp(
                  compactHeight ? 220.0 : 236.0,
                  292.0,
                );
                final double brandSize = compactWidth ? 78 : 86;

                // Structure volontairement robuste face au clavier :
                // ScrollView > ConstrainedBox > IntrinsicHeight. Sans Expanded
                // ni Spacer vertical, le formulaire garde ses dimensions et
                // devient simplement défilable lorsque le clavier réduit la vue.
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(
                            height: heroHeight,
                            width: double.infinity,
                            child: ClipPath(
                              clipper: const _LoginHeroClipper(),
                              child: Container(
                                color: IzyTelColors.surface,
                                padding: EdgeInsets.only(
                                  top: compactHeight ? 18 : 24,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IzyTelBrandMark(size: brandSize),
                                    const SizedBox(height: 6),
                                    const IzyTelWordmark(
                                      fontSize: 34,
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
                              contentHorizontal,
                              compactHeight ? 14 : 18,
                              contentHorizontal,
                              12,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 420,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Bienvenue',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            fontSize: IzyTelTypeScale.title2,
                                            height: 1.10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -.45,
                                            color: IzyTelColors.textPrimary,
                                          ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      'Connectez-vous à votre espace\npour continuer',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: IzyTelColors.textPrimary,
                                            fontSize: IzyTelTypeScale.label,
                                            height: 1.32,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    SizedBox(height: compactHeight ? 10 : 14),
                                    if (_viewModel.errorMessage != null) ...[
                                      _ErrorBanner(
                                        message: _viewModel.errorMessage!,
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    Form(
                                      key: _formKey,
                                      autovalidateMode:
                                          AutovalidateMode.onUnfocus,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          const _FieldLabel('Email'),
                                          const SizedBox(height: 6),
                                          TextFormField(
                                            controller: _identifierController,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            textInputAction:
                                                TextInputAction.next,
                                            autofillHints: const [
                                              AutofillHints.email,
                                            ],
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.copyWith(
                                                  color:
                                                      IzyTelColors.textPrimary,
                                                  fontSize:
                                                      IzyTelTypeScale.text,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                            decoration: const InputDecoration(
                                              hintText: 'exemple@email.com',
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 13,
                                                  ),
                                              prefixIcon: Icon(
                                                Symbols.mail_rounded,
                                                size: IzyTelIconSize.info,
                                              ),
                                            ),
                                            validator: _validateIdentifier,
                                            onChanged: (_) =>
                                                _viewModel.clearError(),
                                          ),
                                          const SizedBox(height: 10),
                                          const _FieldLabel('Mot de passe'),
                                          const SizedBox(height: 6),
                                          TextFormField(
                                            controller: _passwordController,
                                            obscureText: _obscurePassword,
                                            enableSuggestions: false,
                                            autocorrect: false,
                                            textInputAction:
                                                TextInputAction.done,
                                            autofillHints: const [
                                              AutofillHints.password,
                                            ],
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.copyWith(
                                                  color:
                                                      IzyTelColors.textPrimary,
                                                  fontSize:
                                                      IzyTelTypeScale.text,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                            decoration: InputDecoration(
                                              hintText: '••••••••',
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 13,
                                                  ),
                                              prefixIcon: const Icon(
                                                Symbols.lock_rounded,
                                                size: IzyTelIconSize.info,
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
                                                      ? Symbols
                                                            .visibility_off_rounded
                                                      : Symbols
                                                            .visibility_rounded,
                                                  size: IzyTelIconSize.info,
                                                ),
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
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Flexible(
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    SizedBox(
                                                      width: 22,
                                                      height: 22,
                                                      child: Checkbox(
                                                        value: _rememberMe,
                                                        onChanged:
                                                            (
                                                              bool? value,
                                                            ) => setState(
                                                              () =>
                                                                  _rememberMe =
                                                                      value ??
                                                                      false,
                                                            ),
                                                        materialTapTargetSize:
                                                            MaterialTapTargetSize
                                                                .shrinkWrap,
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    const Flexible(
                                                      child: FittedBox(
                                                        fit: BoxFit.scaleDown,
                                                        alignment: Alignment
                                                            .centerLeft,
                                                        child: Text(
                                                          'Se souvenir de moi',
                                                          maxLines: 1,
                                                          softWrap: false,
                                                          style: TextStyle(
                                                            color: IzyTelColors
                                                                .textPrimary,
                                                            fontSize:
                                                                IzyTelTypeScale
                                                                    .label,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Flexible(
                                                child: TextButton(
                                                  onPressed:
                                                      _showForgotPasswordMessage,
                                                  style: TextButton.styleFrom(
                                                    padding: EdgeInsets.zero,
                                                    minimumSize: Size.zero,
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                  ),
                                                  child: const FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    alignment:
                                                        Alignment.centerRight,
                                                    child: Text(
                                                      'Mot de passe oublié ?',
                                                      maxLines: 1,
                                                      softWrap: false,
                                                      style: TextStyle(
                                                        fontSize:
                                                            IzyTelTypeScale
                                                                .label,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
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
                                                            color: IzyTelColors
                                                                .surface,
                                                          ),
                                                    )
                                                  : const Text(
                                                      'Se connecter',
                                                      style: TextStyle(
                                                        fontSize:
                                                            IzyTelTypeScale
                                                                .label,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    const _OrDivider(),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      height: 46,
                                      child: OutlinedButton(
                                        onPressed: _showGoogleMessage,
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: IzyTelColors.surface,
                                          foregroundColor:
                                              IzyTelColors.textPrimary,
                                          side: const BorderSide(
                                            color: IzyTelColors.outlineStrong,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IzyTelGoogleMark(size: 18),
                                            SizedBox(width: 9),
                                            Flexible(
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  'Continuer avec Google',
                                                  maxLines: 1,
                                                  style: TextStyle(
                                                    fontSize:
                                                        IzyTelTypeScale.label,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              contentHorizontal,
                              compactHeight ? 8 : 12,
                              contentHorizontal,
                              12,
                            ),
                            child: Text(
                              '© 2025 IzyTel. Tous droits réservés.',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: IzyTelColors.textMuted,
                                    fontSize: IzyTelTypeScale.micro,
                                    fontWeight: FontWeight.w400,
                                  ),
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
        fontWeight: FontWeight.w600,
        fontSize: IzyTelTypeScale.label,
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
        const Flexible(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'ou continuer avec',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: IzyTelColors.textMuted,
              fontSize: IzyTelTypeScale.micro,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Flexible(child: Divider()),
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
            Symbols.error_rounded,
            color: IzyTelColors.error,
            size: IzyTelIconSize.info,
          ),
          const SizedBox(width: 8),
          Flexible(
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
      ..lineTo(0, size.height - 54)
      ..quadraticBezierTo(
        size.width * .50,
        size.height + 4,
        size.width,
        size.height - 54,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
