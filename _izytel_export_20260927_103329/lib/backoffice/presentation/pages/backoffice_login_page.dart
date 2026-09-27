import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/models/auth_login_result.dart';
import 'package:cabine_flow/features/auth/domain/repositories/auth_repository.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_brand.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class BackofficeLoginPage extends StatefulWidget {
  const BackofficeLoginPage({
    super.key,
    required this.authRepository,
    required this.onAuthenticated,
  });

  final AuthRepository authRepository;
  final ValueChanged<AppUser> onAuthenticated;

  @override
  State<BackofficeLoginPage> createState() => _BackofficeLoginPageState();
}

class _BackofficeLoginPageState extends State<BackofficeLoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _canAccessBackoffice(AppUser user) {
    return user.role == UserRole.administrator ||
        user.role == UserRole.manager ||
        user.role == UserRole.supervisor;
  }

  Future<void> _submit() async {
    if (_loading || _formKey.currentState?.validate() != true) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final AuthLoginResult result = await widget.authRepository.login(
      identifier: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;

    final AppUser? user = result.user;
    if (result.isAuthenticated && user != null) {
      if (!_canAccessBackoffice(user)) {
        await widget.authRepository.logout();
        if (!mounted) return;
        setState(() {
          _loading = false;
          _errorMessage =
              'Ce compte n’a pas accès au back-office. Utilise un compte Administrateur ou Manager.';
        });
        return;
      }
      setState(() => _loading = false);
      widget.onAuthenticated(user);
      return;
    }

    setState(() {
      _loading = false;
      _errorMessage = _messageFor(result);
    });
  }

  String _messageFor(AuthLoginResult result) {
    final String? explicit = result.message?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    switch (result.status) {
      case AuthLoginStatus.pendingActivation:
        return 'Ce compte attend encore son activation par un administrateur.';
      case AuthLoginStatus.inactive:
        return 'Ce compte IzyTel est actuellement désactivé.';
      case AuthLoginStatus.invalidCredentials:
        return 'Adresse e-mail ou mot de passe incorrect.';
      case AuthLoginStatus.unavailable:
        return 'Connexion momentanément indisponible.';
      case AuthLoginStatus.authenticated:
        return 'Connexion impossible.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final bool wide = size.width >= 980;

    return Scaffold(
      backgroundColor: BackofficePalette.canvas,
      body: wide
          ? Row(
              children: <Widget>[
                const Expanded(flex: 11, child: _DesktopHero()),
                Expanded(
                  flex: 9,
                  child: _LoginPane(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 485),
                      child: _buildFormCard(context),
                    ),
                  ),
                ),
              ],
            )
          : _CompactLoginLayout(form: _buildFormCard(context)),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BackofficePalette.line),
        borderRadius: BorderRadius.circular(26),
        boxShadow: BackofficeShadows.elevated,
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: BackofficeGradients.brand,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: BackofficeShadows.glow,
                    ),
                    child: const Icon(
                      Symbols.shield_rounded,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Accès staff sécurisé',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: BackofficePalette.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Administrateur & Manager',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Bienvenue sur IzyTel',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Connecte-toi pour accéder au centre de pilotage et reprendre tes opérations là où tu les as laissées.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 26),
              TextFormField(
                controller: _emailController,
                enabled: !_loading,
                autofillHints: const <String>[
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Adresse e-mail',
                  hintText: 'nom@izytel.ci',
                  prefixIcon: Icon(Symbols.mail_rounded),
                ),
                validator: (String? value) {
                  final String input = value?.trim() ?? '';
                  if (input.isEmpty || !input.contains('@')) {
                    return 'Renseigne une adresse e-mail valide.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: IzyTelSpacing.md),
              TextFormField(
                controller: _passwordController,
                enabled: !_loading,
                obscureText: _obscurePassword,
                autofillHints: const <String>[AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  hintText: '••••••••',
                  prefixIcon: const Icon(Symbols.lock_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Afficher le mot de passe'
                        : 'Masquer le mot de passe',
                    onPressed: _loading
                        ? null
                        : () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                    icon: Icon(
                      _obscurePassword
                          ? Symbols.visibility_rounded
                          : Symbols.visibility_off_rounded,
                    ),
                  ),
                ),
                validator: (String? value) {
                  if ((value ?? '').isEmpty) {
                    return 'Renseigne ton mot de passe.';
                  }
                  return null;
                },
              ),
              if (_errorMessage != null) ...<Widget>[
                const SizedBox(height: IzyTelSpacing.md),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    border: Border.all(color: const Color(0xFFFFD7DB)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(
                        Symbols.error_rounded,
                        size: 20,
                        color: BackofficePalette.danger,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: BackofficePalette.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Symbols.arrow_forward_rounded),
                label: Text(_loading ? 'Connexion…' : 'Se connecter'),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(
                    Symbols.lock_rounded,
                    size: 15,
                    color: BackofficePalette.faint,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Authentification protégée par Firebase Auth',
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: BackofficePalette.faint,
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
}

class _LoginPane extends StatelessWidget {
  const _LoginPane({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BackofficePalette.canvas,
      child: Stack(
        children: <Widget>[
          const Positioned(
            top: -140,
            right: -100,
            child: _SoftOrb(size: 330, color: Color(0x142F6BFF)),
          ),
          const Positioned(
            bottom: -170,
            left: -120,
            child: _SoftOrb(size: 360, color: Color(0x1055D5FF)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 54, vertical: 36),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopHero extends StatelessWidget {
  const _DesktopHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: BackofficeGradients.hero),
      child: Stack(
        children: <Widget>[
          const Positioned(
            top: -120,
            right: -80,
            child: _SoftOrb(size: 360, color: Color(0x2455D5FF)),
          ),
          const Positioned(
            bottom: -160,
            left: -100,
            child: _SoftOrb(size: 430, color: Color(0x1F7C62FF)),
          ),
          Positioned(
            top: 80,
            right: 46,
            child: Transform.rotate(
              angle: -.08,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withValues(alpha: .08)),
                  borderRadius: BorderRadius.circular(34),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _HeroBrand(),
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 650),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const _HeroBadge(),
                        const SizedBox(height: 24),
                        Text(
                          'Le centre de commande de votre activité IzyTel.',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontSize: 44,
                            height: 1.08,
                            letterSpacing: -1.45,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Une interface pensée pour piloter les opérations, les accès et la finance avec la même précision que sur mobile, mais avec la puissance du grand écran.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: .86),
                            height: 1.62,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 34),
                        const Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: <Widget>[
                            _HeroFeature(
                              icon: Symbols.verified_user_rounded,
                              label: 'Accès staff sécurisé',
                            ),
                            _HeroFeature(
                              icon: Symbols.devices_rounded,
                              label: 'Mobile + Web',
                            ),
                            _HeroFeature(
                              icon: Symbols.hub_rounded,
                              label: 'Firebase + Supabase',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4ADE80),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Admin mobile conservé · Back-office complémentaire',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white.withValues(alpha: .78),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBrand extends StatelessWidget {
  const _HeroBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 54,
          height: 54,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .96),
            borderRadius: BorderRadius.circular(17),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 26,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: const IzyTelBrandMark(size: 38),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'IzyTel',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -.45,
              ),
            ),
            Text(
              'Back-office',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white.withValues(alpha: .82),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .95),
        border: Border.all(color: Colors.white),
        borderRadius: BorderRadius.circular(999),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF0D47C7).withValues(alpha: .14),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Symbols.space_dashboard_rounded,
            size: 16,
            color: BackofficePalette.primaryStrong,
            fill: 1,
            weight: 650,
          ),
          const SizedBox(width: 7),
          Text(
            'CENTRE DE PILOTAGE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: BackofficePalette.primaryStrong,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFeature extends StatelessWidget {
  const _HeroFeature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        border: Border.all(color: Colors.white.withValues(alpha: .20)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: 18,
            color: Colors.white,
            fill: 1,
            weight: 600,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white.withValues(alpha: .94),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactLoginLayout extends StatelessWidget {
  const _CompactLoginLayout({required this.form});

  final Widget form;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool tablet = width >= 700;

    return Stack(
      children: <Widget>[
        const Positioned.fill(
          child: ColoredBox(color: BackofficePalette.canvas),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            height: tablet ? 360 : 315,
            decoration: const BoxDecoration(gradient: BackofficeGradients.hero),
          ),
        ),
        const Positioned(
          top: -90,
          right: -80,
          child: _SoftOrb(size: 260, color: Color(0x2255D5FF)),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              tablet ? 42 : 20,
              tablet ? 44 : 28,
              tablet ? 42 : 20,
              34,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  children: <Widget>[
                    const _CompactBrand(),
                    SizedBox(height: tablet ? 34 : 24),
                    form,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactBrand extends StatelessWidget {
  const _CompactBrand();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 64,
          height: 64,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 25,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: const IzyTelBrandMark(size: 46),
        ),
        const SizedBox(height: 14),
        Text(
          'IzyTel Back-office',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Pilote tes opérations depuis un espace Web dédié.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: .66),
          ),
        ),
      ],
    );
  }
}

class _SoftOrb extends StatelessWidget {
  const _SoftOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
