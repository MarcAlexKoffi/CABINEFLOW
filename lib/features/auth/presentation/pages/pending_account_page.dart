import 'package:cabine_flow/app/app_routes.dart';
import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/models/auth_login_result.dart';
import 'package:cabine_flow/features/auth/domain/repositories/auth_repository.dart';
import 'package:cabine_flow/features/auth/presentation/view_models/pending_account_view_model.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class PendingAccountPage extends StatefulWidget {
  const PendingAccountPage({
    super.key,
    required this.authRepository,
    required this.initialResult,
  });

  final AuthRepository authRepository;
  final AuthLoginResult initialResult;

  @override
  State<PendingAccountPage> createState() => _PendingAccountPageState();
}

class _PendingAccountPageState extends State<PendingAccountPage> {
  late final PendingAccountViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = PendingAccountViewModel(
      authRepository: widget.authRepository,
      initialResult: widget.initialResult,
    );
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _refreshAccess() async {
    final AppUser? user = await _viewModel.refreshAccess();
    if (!mounted || user == null) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.dashboard,
      (Route<dynamic> route) => false,
      arguments: user,
    );
  }

  Future<void> _logout() async {
    final bool didLogout = await _viewModel.logout();
    if (!mounted || !didLogout) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (Route<dynamic> route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (BuildContext context, Widget? child) {
        final bool isInactive = _viewModel.isInactive;
        final Color accent = isInactive
            ? IzyTelColors.error
            : IzyTelColors.warning;
        final Color soft = isInactive
            ? IzyTelColors.errorSoft
            : IzyTelColors.warningSoft;

        return Scaffold(
          backgroundColor: IzyTelColors.background,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Center(
                        child: Image.asset(
                          'assets/images/izyTel_logo.png',
                          width: 76,
                          height: 76,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'IzyTel',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: IzyTelColors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Accès à votre espace professionnel',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: IzyTelColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                        decoration: BoxDecoration(
                          color: IzyTelColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: IzyTelColors.outline),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: IzyTelColors.shadow,
                              blurRadius: 24,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Center(
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: soft,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Icon(
                                  isInactive
                                      ? Symbols.person_cancel_rounded
                                      : Symbols.hourglass_top_rounded,
                                  color: accent,
                                  size: 36,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              isInactive
                                  ? 'Compte suspendu'
                                  : 'Compte en attente',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: IzyTelColors.textPrimary,
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isInactive
                                  ? 'Votre accès IzyTel a été suspendu par un administrateur. Aucune donnée interne n’est accessible tant que le compte n’est pas réactivé.'
                                  : 'Votre profil est enregistré. Un administrateur doit encore attribuer votre rôle et activer votre accès.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: IzyTelColors.textSecondary,
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: IzyTelColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: <Widget>[
                                  _InfoLine(
                                    icon: Symbols.person_rounded,
                                    label: 'Profil',
                                    value: _viewModel.profileName,
                                  ),
                                  const Divider(
                                    color: IzyTelColors.outline,
                                    height: 22,
                                  ),
                                  _InfoLine(
                                    icon: Symbols.mail_rounded,
                                    label: 'E-mail',
                                    value: _viewModel.email,
                                  ),
                                  const Divider(
                                    color: IzyTelColors.outline,
                                    height: 22,
                                  ),
                                  _InfoLine(
                                    icon: Symbols.shield_rounded,
                                    label: 'Statut',
                                    value: isInactive
                                        ? 'Suspendu'
                                        : 'Activation requise',
                                    valueColor: accent,
                                  ),
                                ],
                              ),
                            ),
                            if (_viewModel.feedbackMessage != null) ...<Widget>[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: IzyTelColors.primarySoft,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _viewModel.feedbackMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: IzyTelColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: _viewModel.isBusy
                                  ? null
                                  : _refreshAccess,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                backgroundColor: IzyTelColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: _viewModel.isRefreshing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Symbols.refresh_rounded),
                              label: Text(
                                _viewModel.isRefreshing
                                    ? 'Vérification...'
                                    : 'Vérifier mon accès',
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _viewModel.isBusy ? null : _logout,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                foregroundColor: IzyTelColors.primary,
                                side: const BorderSide(
                                  color: IzyTelColors.outlineStrong,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: _viewModel.isSigningOut
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Symbols.logout_rounded),
                              label: Text(
                                _viewModel.isSigningOut
                                    ? 'Déconnexion...'
                                    : 'Se déconnecter',
                              ),
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
        );
      },
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 20, color: IzyTelColors.primary),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  color: IzyTelColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? IzyTelColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
