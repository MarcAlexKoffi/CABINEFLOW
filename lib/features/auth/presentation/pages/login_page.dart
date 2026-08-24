import 'package:cabine_flow/app/app_routes.dart';
import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/features/auth/domain/models/auth_login_result.dart';
import 'package:cabine_flow/features/auth/domain/repositories/auth_repository.dart';
import 'package:cabine_flow/features/auth/presentation/view_models/login_view_model.dart';
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
          backgroundColor: const Color(0xFF020713),
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
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _Header(),
                          const SizedBox(height: 32),
                          _buildFormCard(),
                        ],
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

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xD90A1128),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x3343B5FF), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Connexion à votre espace',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 24),
              if (_viewModel.errorMessage != null) ...[
                _LoginErrorBanner(message: _viewModel.errorMessage!),
                const SizedBox(height: 16),
              ],
              const _FieldLabel(text: 'Adresse e-mail'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _identifierController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: _inputDecoration(
                  hint: 'ex: marc@cabineflow.app',
                  icon: Icons.mail_outline_rounded,
                ),
                validator: _validateIdentifier,
                onChanged: (String value) => _viewModel.clearError(),
              ),
              const SizedBox(height: 20),
              const _FieldLabel(text: 'Mot de passe'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                obscureText: _obscurePassword,
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                decoration:
                    _inputDecoration(
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                    ).copyWith(
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Afficher le mot de passe'
                            : 'Masquer le mot de passe',
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                validator: _validatePassword,
                onChanged: (String value) => _viewModel.clearError(),
                onFieldSubmitted: (String value) => _submitForm(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: (bool? value) {
                        setState(() {
                          _rememberMe = value ?? false;
                        });
                      },
                      side: const BorderSide(color: Color(0xFF4B5563)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      activeColor: const Color(0xFF1677FF),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Se souvenir de moi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: _showForgotPasswordMessage,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Mot de passe oublié ?',
                      style: TextStyle(
                        color: Color(0xFF43B5FF),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF43B5FF), Color(0xFF1677FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x401677FF),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: FilledButton(
                  onPressed: _viewModel.isLoading ? null : _submitForm,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _viewModel.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Se connecter',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Besoin d’aide ?',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                  ),
                  TextButton(
                    onPressed: _showSupportMessage,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.only(left: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Contactez le support',
                      style: TextStyle(
                        color: Color(0xFF43B5FF),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF4B5563), fontSize: 15),
      prefixIcon: Icon(icon, color: const Color(0xFF6B7280), size: 22),
      filled: true,
      fillColor: const Color(0xFF050A1A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0x3343B5FF), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0x1A43B5FF), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF43B5FF), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Align(
          heightFactor:
              0.5, // Force le logo à ne prendre que 50% de sa hauteur dans le layout (coupe les marges transparentes)
          child: Image.asset(
            'assets/images/logo.png',
            height: 180, // Garde sa grande taille visuelle
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x4C43B5FF), width: 1),
                ),
                child: const Center(
                  child: Text(
                    'LOGO',
                    style: TextStyle(
                      color: Color(0xCC43B5FF),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.1,
            ),
            children: [
              TextSpan(
                text: 'Cabine',
                style: TextStyle(color: Colors.white),
              ),
              TextSpan(
                text: 'Flow',
                style: TextStyle(color: Color(0xFF1677FF)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Votre cabine. Votre performance.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xB38C909F),
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(
          0xFFD1D5DB,
        ), // Gris très clair pour contraster avec le fond sombre
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
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
        color: AppColors.errorContainer.withAlpha(51),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withAlpha(127)),
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
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.0, -0.4),
              radius: 1.2,
              colors: [Color(0xFF0C2B5E), Color(0xFF04122D), Color(0xFF020713)],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: SizedBox.expand(),
        ),
        // Future emplacement pour la vague bleue
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black],
                stops: [0.0, 0.4],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: Image.asset(
              'assets/images/login_wave.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // Si l'image de vague n'existe pas encore, on dessine un effet de lueur
                return Container(
                  height: 300,
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, 1.5),
                      radius: 2.0,
                      colors: [
                        Color(0x3343B5FF),
                        Color(0x111677FF),
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
