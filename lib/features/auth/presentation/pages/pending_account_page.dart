import 'package:cabine_flow/app/app_routes.dart';
import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/models/auth_login_result.dart';
import 'package:cabine_flow/features/auth/domain/repositories/auth_repository.dart';
import 'package:cabine_flow/features/auth/presentation/view_models/pending_account_view_model.dart';
import 'package:cabine_flow/shared/widgets/app_logo.dart';
import 'package:flutter/material.dart';

class PendingAccountPage extends StatefulWidget {
  const PendingAccountPage({
    super.key,
    required this.authRepository,
    required this.initialResult,
  });

  final AuthRepository authRepository;
  final AuthLoginResult initialResult;

  @override
  State<PendingAccountPage> createState() {
    return _PendingAccountPageState();
  }
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

    if (!mounted || user == null) {
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.dashboard,
      (Route<dynamic> route) => false,
      arguments: user,
    );
  }

  Future<void> _logout() async {
    final bool didLogout = await _viewModel.logout();

    if (!mounted || !didLogout) {
      return;
    }

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
        final Color statusColor = isInactive
            ? AppColors.error
            : AppColors.warning;

        return Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(
                child: ColoredBox(color: AppColors.background),
              ),
              Positioned(
                top: -180,
                right: -150,
                child: Container(
                  width: 420,
                  height: 420,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [statusColor.withAlpha(28), Colors.transparent],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 32,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AppLogo(
                            size: 58,
                            icon: Icons.water_drop_rounded,
                            titleFontSize: 27,
                            subtitle: 'Accès à l’espace opérateur',
                          ),
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: statusColor.withAlpha(100),
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
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                  alignment: Alignment.center,
                                  child: Container(
                                    width: 76,
                                    height: 76,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: statusColor.withAlpha(25),
                                      border: Border.all(
                                        color: statusColor.withAlpha(95),
                                      ),
                                    ),
                                    child: Icon(
                                      isInactive
                                          ? Icons.block_rounded
                                          : Icons.hourglass_top_rounded,
                                      size: 38,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  isInactive
                                      ? 'Compte inactif'
                                      : 'Compte en attente',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.onSurface,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 9),
                                Text(
                                  isInactive
                                      ? 'Ce compte a été désactivé. Contacte un administrateur avant de réessayer.'
                                      : 'Ton profil a bien été créé. Un administrateur doit maintenant lui attribuer un rôle et l’activer.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.onSurfaceVariant,
                                    fontSize: 14,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _ProfileInformationCard(
                                  name: _viewModel.profileName,
                                  email: _viewModel.email,
                                  statusLabel: isInactive
                                      ? 'Désactivé'
                                      : 'Activation requise',
                                  statusColor: statusColor,
                                ),
                                if (_viewModel.feedbackMessage != null) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.outlineVariant,
                                      ),
                                    ),
                                    child: Text(
                                      _viewModel.feedbackMessage!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: AppColors.onSurfaceVariant,
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
                                  icon: _viewModel.isRefreshing
                                      ? const SizedBox(
                                          width: 19,
                                          height: 19,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: AppColors.onPrimary,
                                          ),
                                        )
                                      : const Icon(Icons.refresh_rounded),
                                  label: Text(
                                    _viewModel.isRefreshing
                                        ? 'Vérification...'
                                        : 'Vérifier mon accès',
                                  ),
                                ),
                                const SizedBox(height: 9),
                                OutlinedButton.icon(
                                  onPressed: _viewModel.isBusy ? null : _logout,
                                  icon: _viewModel.isSigningOut
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.logout_rounded),
                                  label: Text(
                                    _viewModel.isSigningOut
                                        ? 'Déconnexion...'
                                        : 'Se déconnecter',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Aucune commande ni donnée interne n’est accessible tant que le compte n’est pas activé.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
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
}

class _ProfileInformationCard extends StatelessWidget {
  const _ProfileInformationCard({
    required this.name,
    required this.email,
    required this.statusLabel,
    required this.statusColor,
  });

  final String name;
  final String email;
  final String statusLabel;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          _InformationRow(
            icon: Icons.person_outline_rounded,
            label: 'Profil',
            value: name,
          ),
          const SizedBox(height: 11),
          const Divider(height: 1, color: AppColors.outlineVariant),
          const SizedBox(height: 11),
          _InformationRow(
            icon: Icons.mail_outline_rounded,
            label: 'E-mail',
            value: email.isEmpty ? 'Non disponible' : email,
          ),
          const SizedBox(height: 11),
          const Divider(height: 1, color: AppColors.outlineVariant),
          const SizedBox(height: 11),
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 19, color: statusColor),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Statut',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 1),
        Icon(icon, size: 19, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
