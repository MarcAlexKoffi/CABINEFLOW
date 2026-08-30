import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/agents/presentation/pages/agent_issues_page.dart';
import 'package:cabine_flow/features/agents/presentation/view_models/agent_activity_view_model.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/commissions/domain/repositories/commission_repository.dart';
import 'package:cabine_flow/features/commissions/presentation/pages/agent_commissions_page.dart';
import 'package:cabine_flow/features/commissions/presentation/pages/agent_performance_page.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class AgentActivityPage extends StatefulWidget {
  const AgentActivityPage({
    super.key,
    required this.user,
    required this.repository,
    required this.commissionRepository,
    required this.isLoggingOut,
    required this.onLogout,
    this.onOpenHistory,
  });

  final AppUser user;
  final AgentRepository repository;
  final CommissionRepository commissionRepository;
  final bool isLoggingOut;
  final Future<void> Function() onLogout;
  final VoidCallback? onOpenHistory;

  @override
  State<AgentActivityPage> createState() => _AgentActivityPageState();
}

class _AgentActivityPageState extends State<AgentActivityPage> {
  late final AgentActivityViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AgentActivityViewModel(
      agentId: widget.user.id,
      repository: widget.repository,
    );
    _viewModel.start();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  AgentProfile _fallbackProfile() {
    return AgentProfile(
      userId: widget.user.id,
      agentCode:
          'AG-${widget.user.id.replaceAll(RegExp(r'[^0-9]'), '').padLeft(4, '0')}',
      availability: AgentAvailability.available,
      authorizedNetworks: const <AgentNetwork>[
        AgentNetwork.orange,
        AgentNetwork.mtn,
        AgentNetwork.moov,
      ],
      activeNetworks: const <AgentNetwork>[
        AgentNetwork.orange,
        AgentNetwork.mtn,
        AgentNetwork.moov,
      ],
      orangeCapacity: 0,
      mtnCapacity: 0,
      moovCapacity: 0,
      zoneIds: const <String>[],
      maxTransactionsPerDay: 0,
      dailyTransactionLimit: 0,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _editCapacity(AgentNetwork network) async {
    final AgentProfile? profile = _viewModel.profile;
    if (profile == null) return;

    final int? amount = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CapacityEditorSheet(
        network: network,
        initialAmount: profile.capacityFor(network),
      ),
    );
    if (amount == null || !mounted) return;

    final bool success = await _viewModel.updateCapacity(network, amount);
    if (!mounted) return;
    _showMessage(
      success
          ? 'Capacité ${network.label} mise à jour.'
          : _viewModel.errorMessage ?? 'Modification impossible.',
    );
  }

  void _openPerformance() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AgentPerformancePage(
          user: widget.user,
          repository: widget.commissionRepository,
        ),
      ),
    );
  }

  void _openCommissions() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AgentCommissionsPage(
          user: widget.user,
          repository: widget.commissionRepository,
        ),
      ),
    );
  }

  void _openIssues() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AgentIssuesPage(
          agentId: widget.user.id,
          repository: widget.repository,
        ),
      ),
    );
  }

  void _openAccountMenu(AgentProfile profile) {
    final int openIssues = _viewModel.issues
        .where((AgentIssue issue) => issue.status != 'resolved')
        .length;
    showIzyTelAccountSheet(
      context: context,
      name: widget.user.name,
      role: 'Agent • ${profile.availability.label}',
      actions: <IzyTelAccountAction>[
        IzyTelAccountAction(
          icon: Symbols.insights_rounded,
          label: 'Mes performances',
          onTap: _openPerformance,
        ),
        IzyTelAccountAction(
          icon: Symbols.account_balance_wallet_rounded,
          label: 'Mes commissions',
          onTap: _openCommissions,
        ),
        IzyTelAccountAction(
          icon: Symbols.support_agent_rounded,
          label: openIssues > 0
              ? 'Mes signalements ($openIssues)'
              : 'Mes signalements',
          onTap: _openIssues,
        ),
        IzyTelAccountAction(
          icon: Symbols.logout_rounded,
          label: 'Se déconnecter',
          destructive: true,
          onTap: () {
            widget.onLogout();
          },
        ),
      ],
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (BuildContext context, Widget? child) {
            if (_viewModel.errorMessage != null &&
                _viewModel.profile == null &&
                !_viewModel.isLoading) {
              return _ProfileUnavailable(
                message: _viewModel.errorMessage!,
                isLoggingOut: widget.isLoggingOut,
                onRetry: _viewModel.start,
                onLogout: widget.onLogout,
              );
            }

            final AgentProfile profile =
                _viewModel.profile ?? _fallbackProfile();
            final int openIssues = _viewModel.issues
                .where((AgentIssue issue) => issue.status != 'resolved')
                .length;

            return RefreshIndicator(
              onRefresh: _viewModel.start,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  IzyTelSpacing.lg,
                  IzyTelSpacing.md,
                  IzyTelSpacing.lg,
                  IzyTelSpacing.xxl,
                ),
                children: <Widget>[
                  IzyTelPageHeader(
                    title: 'Profil',
                    subtitle: 'Ton activité et tes réglages opérationnels.',
                    actions: <Widget>[
                      IzyTelAvatar(
                        name: widget.user.name,
                        size: 42,
                        onTap: () => _openAccountMenu(profile),
                      ),
                    ],
                  ),
                  const SizedBox(height: IzyTelSpacing.lg),
                  _AgentIdentityHero(user: widget.user, profile: profile),
                  const SizedBox(height: IzyTelSpacing.md),
                  _AvailabilityCard(
                    profile: profile,
                    isSaving: _viewModel.isSaving,
                    onChanged: (bool enabled) async {
                      final bool success = await _viewModel.setAvailability(
                        enabled
                            ? AgentAvailability.available
                            : AgentAvailability.unavailable,
                      );
                      if (!mounted || success) return;
                      _showMessage(
                        _viewModel.errorMessage ?? 'Modification impossible.',
                      );
                    },
                  ),
                  const SizedBox(height: IzyTelSpacing.xl),
                  const _SectionLabel('Mon activité'),
                  const SizedBox(height: 6),
                  IzyTelSurface(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IzyTelMenuRow(
                          icon: Symbols.insights_rounded,
                          title: 'Mes performances',
                          subtitle:
                              'Volume traité, réussite, refus, échecs et temps moyen.',
                          iconColor: IzyTelColors.primary,
                          onTap: _openPerformance,
                        ),
                        const Divider(height: 1),
                        IzyTelMenuRow(
                          icon: Symbols.account_balance_wallet_rounded,
                          title: 'Mes commissions',
                          subtitle:
                              'Solde, commissions acquises et versements reçus.',
                          iconColor: IzyTelColors.success,
                          onTap: _openCommissions,
                        ),
                        if (widget.onOpenHistory != null) ...<Widget>[
                          const Divider(height: 1),
                          IzyTelMenuRow(
                            icon: Symbols.history_rounded,
                            title: 'Historique',
                            subtitle:
                                'Retrouver tes commandes en cours et terminées.',
                            iconColor: IzyTelColors.moov,
                            onTap: widget.onOpenHistory!,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: IzyTelSpacing.xl),
                  const _SectionLabel('Disponibilité'),
                  const SizedBox(height: 6),
                  IzyTelSurface(
                    padding: EdgeInsets.zero,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (
                          int index = 0;
                          index < AgentNetwork.values.length;
                          index++
                        ) ...<Widget>[
                          _NetworkAvailabilityRow(
                            network: AgentNetwork.values[index],
                            profile: profile,
                            isSaving: _viewModel.isSaving,
                            onToggle: (bool enabled) async {
                              final AgentNetwork network =
                                  AgentNetwork.values[index];
                              final bool success = await _viewModel
                                  .toggleNetwork(network, enabled);
                              if (!mounted || success) return;
                              _showMessage(
                                _viewModel.errorMessage ??
                                    'Modification impossible.',
                              );
                            },
                            onEditCapacity:
                                profile.authorizedNetworks.contains(
                                  AgentNetwork.values[index],
                                )
                                ? () =>
                                      _editCapacity(AgentNetwork.values[index])
                                : null,
                          ),
                          if (index < AgentNetwork.values.length - 1)
                            const Divider(height: 1),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: IzyTelSpacing.xl),
                  const _SectionLabel('Affectation'),
                  const SizedBox(height: 6),
                  _AssignmentCard(
                    zones: _viewModel.assignedZones,
                    profile: profile,
                  ),
                  const SizedBox(height: IzyTelSpacing.xl),
                  const _SectionLabel('Assistance'),
                  const SizedBox(height: 6),
                  IzyTelSurface(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: IzyTelMenuRow(
                      icon: Symbols.support_agent_rounded,
                      title: 'Mes signalements',
                      subtitle: 'Signaler un incident et suivre sa résolution.',
                      badge: openIssues > 0 ? '$openIssues' : null,
                      iconColor: openIssues > 0
                          ? IzyTelColors.warning
                          : IzyTelColors.success,
                      onTap: _openIssues,
                    ),
                  ),
                  const SizedBox(height: IzyTelSpacing.xl),
                  const _SectionLabel('Compte'),
                  const SizedBox(height: 6),
                  IzyTelSurface(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: IzyTelMenuRow(
                      icon: Symbols.logout_rounded,
                      title: widget.isLoggingOut
                          ? 'Déconnexion...'
                          : 'Se déconnecter',
                      subtitle: 'Fermer ta session Agent sur cet appareil.',
                      destructive: true,
                      onTap: widget.isLoggingOut
                          ? () {}
                          : () {
                              widget.onLogout();
                            },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AgentIdentityHero extends StatelessWidget {
  const _AgentIdentityHero({required this.user, required this.profile});

  final AppUser user;
  final AgentProfile profile;

  @override
  Widget build(BuildContext context) {
    final bool available = profile.availability == AgentAvailability.available;
    return Container(
      padding: const EdgeInsets.all(IzyTelSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[IzyTelColors.primary, IzyTelColors.primaryStrong],
        ),
        borderRadius: BorderRadius.circular(IzyTelRadii.largeCard),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x282E63EB),
            blurRadius: 22,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withAlpha(90)),
            ),
            child: Text(
              _initials(user.name),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: IzyTelSpacing.md),
          Flexible(
            fit: FlexFit.tight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.25,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${profile.agentCode} • Agent IzyTel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withAlpha(220),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 9),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(28),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: available
                              ? const Color(0xFF86EFAC)
                              : const Color(0xFFFCD34D),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        profile.availability.label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({
    required this.profile,
    required this.isSaving,
    required this.onChanged,
  });

  final AgentProfile profile;
  final bool isSaving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool available = profile.availability == AgentAvailability.available;
    return IzyTelSurface(
      padding: const EdgeInsets.all(IzyTelSpacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: available
                  ? IzyTelColors.successSoft
                  : IzyTelColors.warningSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              available
                  ? Symbols.wifi_tethering_rounded
                  : Symbols.pause_rounded,
              color: available ? IzyTelColors.success : IzyTelColors.warning,
              size: IzyTelIconSize.action,
            ),
          ),
          const SizedBox(width: IzyTelSpacing.sm),
          Flexible(
            fit: FlexFit.tight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  available ? 'Disponible' : 'Indisponible',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: IzyTelColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  available
                      ? 'Tu peux recevoir de nouvelles commandes.'
                      : 'Les nouvelles affectations sont suspendues.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IzyTelColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(value: available, onChanged: isSaving ? null : onChanged),
        ],
      ),
    );
  }
}

class _NetworkAvailabilityRow extends StatelessWidget {
  const _NetworkAvailabilityRow({
    required this.network,
    required this.profile,
    required this.isSaving,
    required this.onToggle,
    required this.onEditCapacity,
  });

  final AgentNetwork network;
  final AgentProfile profile;
  final bool isSaving;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onEditCapacity;

  @override
  Widget build(BuildContext context) {
    final bool authorized = profile.authorizedNetworks.contains(network);
    final bool active = authorized && profile.activeNetworks.contains(network);
    final Color accent = _networkColor(network);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: IzyTelSpacing.md,
        vertical: IzyTelSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          _NetworkLogo(network: network),
          const SizedBox(width: IzyTelSpacing.sm),
          Flexible(
            fit: FlexFit.tight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      network.label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: IzyTelColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: authorized && active
                            ? accent
                            : IzyTelColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                GestureDetector(
                  onTap: onEditCapacity,
                  child: Text(
                    authorized
                        ? '${formatCfa(profile.capacityFor(network))} disponibles • Modifier'
                        : 'Réseau non autorisé par l’administration',
                    maxLines: 2,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: authorized
                          ? IzyTelColors.textSecondary
                          : IzyTelColors.textMuted,
                      fontWeight: authorized
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Switch(
            value: active,
            onChanged: !authorized || isSaving ? null : onToggle,
          ),
        ],
      ),
    );
  }
}

class _NetworkLogo extends StatelessWidget {
  const _NetworkLogo({required this.network});

  final AgentNetwork network;

  @override
  Widget build(BuildContext context) {
    final String asset = switch (network) {
      AgentNetwork.orange => 'assets/brands/operators/orange_ci.png',
      AgentNetwork.mtn => 'assets/brands/operators/mtn_ci.png',
      AgentNetwork.moov => 'assets/brands/operators/moov_africa_ci.png',
    };
    final Color background = switch (network) {
      AgentNetwork.orange => IzyTelColors.orangeSoft,
      AgentNetwork.mtn => IzyTelColors.mtnSoft,
      AgentNetwork.moov => IzyTelColors.moovSoft,
    };
    return Container(
      width: 42,
      height: 42,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Image.asset(asset, fit: BoxFit.contain),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.zones, required this.profile});

  final List<AgentZone> zones;
  final AgentProfile profile;

  @override
  Widget build(BuildContext context) {
    final String zonesLabel = zones.isEmpty
        ? 'Aucune zone assignée'
        : zones.map((AgentZone zone) => zone.displayLabel).join(' • ');
    return IzyTelSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _InfoLine(
            icon: Symbols.location_on_rounded,
            title: 'Zones',
            value: zonesLabel,
          ),
          const Divider(height: 1),
          _InfoLine(
            icon: Symbols.receipt_long_rounded,
            title: 'Quota quotidien',
            value: profile.maxTransactionsPerDay > 0
                ? '${profile.maxTransactionsPerDay} transactions maximum'
                : 'Pas de plafond défini',
          ),
          const Divider(height: 1),
          _InfoLine(
            icon: Symbols.payments_rounded,
            title: 'Limite quotidienne',
            value: profile.dailyTransactionLimit > 0
                ? formatCfaFull(profile.dailyTransactionLimit)
                : 'Pas de limite définie',
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: IzyTelColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: IzyTelColors.primary,
              size: IzyTelIconSize.action,
            ),
          ),
          const SizedBox(width: IzyTelSpacing.sm),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: IzyTelColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IzyTelColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CapacityEditorSheet extends StatefulWidget {
  const _CapacityEditorSheet({
    required this.network,
    required this.initialAmount,
  });

  final AgentNetwork network;
  final int initialAmount;

  @override
  State<_CapacityEditorSheet> createState() => _CapacityEditorSheetState();
}

class _CapacityEditorSheetState extends State<_CapacityEditorSheet> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initialAmount}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String raw = _controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    final int? value = int.tryParse(raw);
    if (value == null || value < 0) {
      setState(() => _errorText = 'Saisis un montant valide.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 12, 12, bottomInset + 12),
        child: Container(
          padding: const EdgeInsets.all(IzyTelSpacing.lg),
          decoration: const BoxDecoration(
            color: IzyTelColors.surface,
            borderRadius: BorderRadius.all(Radius.circular(IzyTelRadii.sheet)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _NetworkLogo(network: widget.network),
                    const SizedBox(width: IzyTelSpacing.sm),
                    Flexible(
                      fit: FlexFit.tight,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Capacité ${widget.network.label}',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: IzyTelColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Text(
                            'Montant actuellement disponible pour traiter les commandes.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: IzyTelColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Symbols.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: IzyTelSpacing.lg),
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  onChanged: (_) {
                    if (_errorText != null) setState(() => _errorText = null);
                  },
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Montant disponible',
                    suffixText: 'F CFA',
                    errorText: _errorText,
                  ),
                ),
                const SizedBox(height: IzyTelSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text(
                      'Enregistrer la capacité',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: IzyTelColors.textMuted,
        fontSize: IzyTelTypeScale.micro,
        fontWeight: FontWeight.w700,
        letterSpacing: .7,
      ),
    );
  }
}

class _ProfileUnavailable extends StatelessWidget {
  const _ProfileUnavailable({
    required this.message,
    required this.isLoggingOut,
    required this.onRetry,
    required this.onLogout,
  });

  final String message;
  final bool isLoggingOut;
  final Future<void> Function() onRetry;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(IzyTelSpacing.xl),
        child: IzyTelSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Symbols.cloud_off_rounded,
                size: 38,
                color: IzyTelColors.warning,
              ),
              const SizedBox(height: IzyTelSpacing.sm),
              Text(
                'Profil indisponible',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: IzyTelColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: IzyTelColors.textSecondary,
                ),
              ),
              const SizedBox(height: IzyTelSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Symbols.refresh_rounded),
                  label: const Text('Réessayer'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: isLoggingOut
                      ? null
                      : () {
                          onLogout();
                        },
                  icon: const Icon(Symbols.logout_rounded),
                  label: Text(
                    isLoggingOut ? 'Déconnexion...' : 'Se déconnecter',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _networkColor(AgentNetwork network) => switch (network) {
  AgentNetwork.orange => IzyTelColors.orange,
  AgentNetwork.mtn => IzyTelColors.mtnText,
  AgentNetwork.moov => IzyTelColors.moov,
};

String _initials(String name) {
  final List<String> parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((String part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
