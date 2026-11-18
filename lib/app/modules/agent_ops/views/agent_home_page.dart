import 'dart:async';

import 'package:cabine_flow/app/theme/izytel_colors.dart';
import 'package:cabine_flow/app/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/app/domain/entities/agents/agent_models.dart';
import 'package:cabine_flow/app/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/app/modules/agent_issues/views/agent_issues_page.dart';
import 'package:cabine_flow/app/domain/entities/auth/app_user.dart';
import 'package:cabine_flow/app/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/app/shared/widgets/izytel/izytel_ui.dart';
import 'package:cabine_flow/app/modules/agent_ops/controllers/agent_home_view_model.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class AgentHomePage extends StatefulWidget {
  const AgentHomePage({
    super.key,
    required this.user,
    required this.ordersRepository,
    required this.agentRepository,
    required this.onOpenOrders,
    required this.onOpenHistory,
    required this.onOpenProfile,
    required this.onOpenActivity,
    required this.onOpenCommissions,
  });
  final AppUser user;
  final OrdersRepository ordersRepository;
  final AgentRepository agentRepository;
  final VoidCallback onOpenOrders,
      onOpenHistory,
      onOpenProfile,
      onOpenActivity,
      onOpenCommissions;
  @override
  State<AgentHomePage> createState() => _AgentHomePageState();
}

class _AgentHomePageState extends State<AgentHomePage>
    with WidgetsBindingObserver {
  late AgentHomeViewModel _home;
  late Stream<AgentProfile?> _profile;
  late Stream<List<AgentIssue>> _issues;
  String get _firstName {
    final name = widget.user.name.trim();
    return name.isEmpty ? 'Agent' : name.split(RegExp(r'\s+')).first;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bind();
  }

  void _bind() {
    _profile = widget.agentRepository.watchAgentProfile(widget.user.id);
    _issues = widget.agentRepository.watchAgentIssues(widget.user.id);
    _home = AgentHomeViewModel(
      agentId: widget.user.id,
      repository: widget.ordersRepository,
    )..start();
  }

  @override
  void didUpdateWidget(covariant AgentHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.ordersRepository != widget.ordersRepository ||
        oldWidget.agentRepository != widget.agentRepository) {
      _home.dispose();
      _bind();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_home.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _home.dispose();
    super.dispose();
  }

  void _openIssues() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AgentIssuesPage(
          agentId: widget.user.id,
          repository: widget.agentRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: IzyTelColors.background,
    body: SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: _home,
        builder: (context, _) => StreamBuilder<AgentProfile?>(
          stream: _profile,
          builder: (context, profileSnapshot) => StreamBuilder<List<AgentIssue>>(
            stream: _issues,
            builder: (context, issueSnapshot) {
              final openIssues = (issueSnapshot.data ?? const <AgentIssue>[])
                  .where(
                    (i) => const {
                      'open',
                      'in_progress',
                      'acknowledged',
                    }.contains(i.status),
                  )
                  .length;
              return IzyTelRefreshIndicator(
                onRefresh: _home.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    IzyTelSpacing.lg,
                    IzyTelSpacing.md,
                    IzyTelSpacing.lg,
                    IzyTelSpacing.xxl,
                  ),
                  children: [
                    _HomeHeader(
                      agentId: widget.user.id,
                      firstName: _firstName,
                      userName: widget.user.name,
                      availability: profileSnapshot.data?.availability,
                      repository: widget.agentRepository,
                      onOpenProfile: widget.onOpenProfile,
                    ),
                    const SizedBox(height: IzyTelSpacing.xl),
                    _PriorityActionCard(
                      toAccept: _home.toAccept,
                      inProgress: _home.inProgress,
                      available: _home.availableCount,
                      assigned: _home.assignedToAccept,
                      sharedEnabled: _home.sharedEnabled,
                      loading: _home.loading,
                      hasData: _home.hasData,
                      error: _home.error,
                      onOpenOrders: widget.onOpenOrders,
                      onRetry: () => unawaited(_home.refresh()),
                    ),
                    const SizedBox(height: IzyTelSpacing.lg),
                    _OperationalSummary(
                      toAccept: _home.toAccept,
                      inProgress: _home.inProgress,
                      completed: _home.completed,
                      hasData: _home.hasData,
                      acceptLabel: _home.sharedEnabled
                          ? 'À prendre'
                          : 'À accepter',
                    ),
                    const SizedBox(height: IzyTelSpacing.xl),
                    const IzyTelSectionHeader(title: 'Mon suivi'),
                    const SizedBox(height: IzyTelSpacing.sm),
                    IzyTelSurface(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IzyTelMenuRow(
                            icon: Symbols.insights_rounded,
                            title: 'Mon activité détaillée',
                            subtitle:
                                'Performances, commandes, capacités et mouvements.',
                            iconColor: IzyTelColors.primary,
                            onTap: widget.onOpenActivity,
                          ),
                          const Divider(height: 1),
                          IzyTelMenuRow(
                            icon: Symbols.account_balance_wallet_rounded,
                            title: 'Mes commissions',
                            subtitle:
                                'Consulter mon solde, mes gains et mes versements.',
                            iconColor: IzyTelColors.success,
                            onTap: widget.onOpenCommissions,
                          ),
                        ],
                      ),
                    ),
                    if (openIssues > 0) ...[
                      const SizedBox(height: IzyTelSpacing.xl),
                      const IzyTelSectionHeader(title: 'À surveiller'),
                      const SizedBox(height: IzyTelSpacing.sm),
                      IzyTelSurface(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: IzyTelMenuRow(
                          icon: Symbols.support_agent_rounded,
                          title: 'Mes signalements',
                          subtitle:
                              'Suivre les incidents actuellement en cours de traitement.',
                          badge: '$openIssues',
                          iconColor: IzyTelColors.warning,
                          onTap: _openIssues,
                        ),
                      ),
                    ],
                    const SizedBox(height: IzyTelSpacing.xl),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: widget.onOpenHistory,
                            icon: const Icon(Symbols.history_rounded),
                            label: const Text('Historique'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: widget.onOpenProfile,
                            icon: const Icon(Symbols.person_rounded),
                            label: const Text('Profil'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.agentId,
    required this.firstName,
    required this.userName,
    required this.availability,
    required this.repository,
    required this.onOpenProfile,
  });

  final String agentId;
  final String firstName;
  final String userName;
  final AgentAvailability? availability;
  final AgentRepository repository;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final bool isAvailable = availability == AgentAvailability.available;
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Bonjour $firstName 👋',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: IzyTelColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: <Widget>[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isAvailable
                          ? IzyTelColors.success
                          : IzyTelColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      availability?.label ?? 'Statut en cours de chargement',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: IzyTelColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _AgentHomeAvatar(
          agentId: agentId,
          userName: userName,
          repository: repository,
          onTap: onOpenProfile,
        ),
      ],
    );
  }
}

class _AgentHomeAvatar extends StatefulWidget {
  const _AgentHomeAvatar({
    required this.agentId,
    required this.userName,
    required this.repository,
    required this.onTap,
  });

  final String agentId;
  final String userName;
  final AgentRepository repository;
  final VoidCallback onTap;

  @override
  State<_AgentHomeAvatar> createState() => _AgentHomeAvatarState();
}

class _AgentHomeAvatarState extends State<_AgentHomeAvatar> {
  StreamSubscription<AgentPersonalProfile?>? _subscription;
  String? _avatarUrl;
  int _resolveGeneration = 0;

  @override
  void initState() {
    super.initState();
    _bindPersonalProfile();
  }

  @override
  void didUpdateWidget(covariant _AgentHomeAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.agentId != widget.agentId ||
        oldWidget.repository != widget.repository) {
      _bindPersonalProfile();
    }
  }

  void _bindPersonalProfile() {
    unawaited(_subscription?.cancel());
    _avatarUrl = null;
    _subscription = widget.repository
        .watchPersonalProfile(widget.agentId)
        .listen(
          (AgentPersonalProfile? profile) {
            final String? path = profile?.avatarStoragePath?.trim();
            if (path == null || path.isEmpty) {
              _resolveGeneration++;
              if (mounted && _avatarUrl != null) {
                setState(() => _avatarUrl = null);
              }
              return;
            }
            unawaited(_resolveAvatar(path));
          },
          onError: (_) {
            _resolveGeneration++;
            if (mounted && _avatarUrl != null) {
              setState(() => _avatarUrl = null);
            }
          },
        );
  }

  Future<void> _resolveAvatar(String path) async {
    final int generation = ++_resolveGeneration;
    final String? resolved = await widget.repository.resolvePersonalFileUrl(
      path,
    );
    if (!mounted || generation != _resolveGeneration) return;
    setState(() => _avatarUrl = resolved);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IzyTelAvatar(
      name: widget.userName,
      imageUrl: _avatarUrl,
      onTap: widget.onTap,
    );
  }
}

class _PriorityActionCard extends StatelessWidget {
  const _PriorityActionCard({
    required this.toAccept,
    required this.inProgress,
    required this.available,
    required this.assigned,
    required this.sharedEnabled,
    required this.loading,
    required this.hasData,
    required this.error,
    required this.onOpenOrders,
    required this.onRetry,
  });
  final int toAccept, inProgress, available, assigned;
  final bool sharedEnabled, loading, hasData;
  final String? error;
  final VoidCallback onOpenOrders, onRetry;
  @override
  Widget build(BuildContext context) {
    final pending = toAccept > 0;
    final title = !hasData
        ? (loading ? 'Synchronisation de ta file' : 'Commandes indisponibles')
        : pending
        ? '$toAccept commande${toAccept > 1 ? 's' : ''} ${sharedEnabled ? 'à prendre' : 'à accepter'}'
        : inProgress > 0
        ? '$inProgress commande${inProgress > 1 ? 's' : ''} en cours'
        : 'Aucune commande urgente';
    final subtitle = !hasData
        ? (loading
              ? 'Tes commandes réelles sont en cours de chargement.'
              : 'Actualise pour retrouver ta file de commandes.')
        : pending
        ? (available > 0
              ? '$available dans la file partagée${assigned > 0 ? ' · $assigned affectée${assigned > 1 ? 's' : ''} à toi' : ''}.'
              : 'De nouvelles affectations attendent ta réponse.')
        : inProgress > 0
        ? 'Poursuis le traitement de tes commandes acceptées.'
        : 'Ta file est à jour. Tu peux consulter le détail de tes commandes.';
    return Container(
      key: const ValueKey('agent-priority-card'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: IzyTelColors.primary.withAlpha(40),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF132E68), Color(0xFF1D4ED8), Color(0xFF2E63EB)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -65,
                right: -45,
                child: IgnorePointer(
                  child: Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(7),
                      border: Border.all(color: Colors.white.withAlpha(15)),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(25),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withAlpha(30),
                            ),
                          ),
                          child: Icon(
                            pending
                                ? Symbols.bolt_rounded
                                : Symbols.task_alt_rounded,
                            color: Colors.white,
                            size: 23,
                          ),
                        ),
                        const Text(
                          'TA PRIORITÉ',
                          style: TextStyle(
                            color: Color(0xFFF0F5FF),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF132E68).withAlpha(70),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            loading && !hasData
                                ? 'Chargement'
                                : error != null
                                ? 'À actualiser'
                                : 'En direct',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        height: 1.18,
                        letterSpacing: -.5,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFF0F5FF),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF173B88),
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: !hasData && error != null
                            ? onRetry
                            : onOpenOrders,
                        icon: Icon(
                          !hasData && error != null
                              ? Symbols.refresh_rounded
                              : Symbols.receipt_long_rounded,
                          size: 20,
                        ),
                        label: Text(
                          !hasData && error != null
                              ? 'Réessayer'
                              : pending
                              ? 'Voir les commandes'
                              : 'Ouvrir mes commandes',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    if (error != null && hasData) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Actualisation interrompue. Dernières données affichées.',
                        style: TextStyle(
                          color: Color(0xFFF0F5FF),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Symbols.refresh_rounded, size: 18),
                        label: const Text('Réessayer'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperationalSummary extends StatelessWidget {
  const _OperationalSummary({
    required this.toAccept,
    required this.inProgress,
    required this.completed,
    required this.hasData,
    required this.acceptLabel,
  });

  final int toAccept;
  final int inProgress;
  final int completed;
  final bool hasData;
  final String acceptLabel;

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _SummaryItem(
              value: hasData ? '$toAccept' : '—',
              label: acceptLabel,
              valueColor: IzyTelColors.warning,
            ),
          ),
          const SizedBox(height: 42, child: VerticalDivider(width: 1)),
          Expanded(
            child: _SummaryItem(
              value: hasData ? '$inProgress' : '—',
              label: 'En cours',
              valueColor: IzyTelColors.primary,
            ),
          ),
          const SizedBox(height: 42, child: VerticalDivider(width: 1)),
          Expanded(
            child: _SummaryItem(
              value: hasData ? '$completed' : '—',
              label: 'Terminées',
              valueColor: IzyTelColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: IzyTelColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
