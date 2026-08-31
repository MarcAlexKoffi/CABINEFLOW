import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum _AgentIssueTab { all, open, inProgress, resolved, cancelled }

class AgentIssueCenterPage extends StatefulWidget {
  const AgentIssueCenterPage({
    super.key,
    required this.user,
    required this.repository,
  });

  final AppUser user;
  final AgentRepository repository;

  @override
  State<AgentIssueCenterPage> createState() => _AgentIssueCenterPageState();
}

class _AgentIssueCenterPageState extends State<AgentIssueCenterPage> {
  final TextEditingController _searchController = TextEditingController();
  late final Stream<List<AgentDirectoryEntry>> _agentsStream;
  late final Stream<List<AgentIssue>> _issuesStream;
  _AgentIssueTab _selectedTab = _AgentIssueTab.open;
  String _query = '';
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _agentsStream = widget.repository.watchAgents();
    _issuesStream = widget.repository.watchAllAgentIssues();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(
        backgroundColor: IzyTelColors.background,
        title: const Text('Signalements agents'),
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<List<AgentDirectoryEntry>>(
          stream: _agentsStream,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<AgentDirectoryEntry>> agentsSnapshot,
              ) {
                return StreamBuilder<List<AgentIssue>>(
                  stream: _issuesStream,
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<List<AgentIssue>> issuesSnapshot,
                      ) {
                        if (!agentsSnapshot.hasData &&
                            agentsSnapshot.connectionState ==
                                ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (!issuesSnapshot.hasData &&
                            issuesSnapshot.connectionState ==
                                ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (issuesSnapshot.hasError) {
                          return _IssueErrorState(
                            message:
                                'Impossible de charger les signalements agents.',
                            onRetry: () => setState(() {}),
                          );
                        }

                        final List<AgentDirectoryEntry> agents =
                            agentsSnapshot.data ??
                            const <AgentDirectoryEntry>[];
                        final List<AgentIssue> allIssues =
                            issuesSnapshot.data ?? const <AgentIssue>[];
                        final Map<String, AgentDirectoryEntry> agentById =
                            <String, AgentDirectoryEntry>{
                              for (final AgentDirectoryEntry agent in agents)
                                agent.userId: agent,
                            };
                        final List<AgentIssue> visible = _filterIssues(
                          allIssues,
                          agentById,
                        );
                        final int openCount = allIssues
                            .where((AgentIssue issue) => issue.status == 'open')
                            .length;
                        final int inProgressCount = allIssues
                            .where(
                              (AgentIssue issue) =>
                                  issue.status == 'in_progress',
                            )
                            .length;
                        final int resolvedCount = allIssues
                            .where(
                              (AgentIssue issue) => issue.status == 'resolved',
                            )
                            .length;
                        final int cancelledCount = allIssues
                            .where(
                              (AgentIssue issue) => issue.status == 'cancelled',
                            )
                            .length;

                        return RefreshIndicator(
                          onRefresh: () async => setState(() {}),
                          color: IzyTelColors.primary,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                            children: [
                              const IzyTelPageHeader(
                                title: 'Centre de signalements',
                                subtitle:
                                    'Centralise les incidents remontés par les agents, puis prends une action de suivi.',
                              ),
                              const SizedBox(height: IzyTelSpacing.lg),
                              Row(
                                children: [
                                  Expanded(
                                    child: _IssueMetricCard(
                                      label: 'Ouverts',
                                      value: '$openCount',
                                      color: IzyTelColors.warning,
                                      softColor: IzyTelColors.warningSoft,
                                      icon: Symbols.warning_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _IssueMetricCard(
                                      label: 'En cours',
                                      value: '$inProgressCount',
                                      color: IzyTelColors.primary,
                                      softColor: IzyTelColors.primarySoft,
                                      icon: Symbols.autorenew_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _IssueMetricCard(
                                      label: 'Résolus',
                                      value: '$resolvedCount',
                                      color: IzyTelColors.success,
                                      softColor: IzyTelColors.successSoft,
                                      icon: Symbols.check_circle_rounded,
                                    ),
                                  ),
                                ],
                              ),
                              if (cancelledCount > 0) ...[
                                const SizedBox(height: IzyTelSpacing.sm),
                                IzyTelSurface(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: IzyTelSpacing.md,
                                    vertical: IzyTelSpacing.sm,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: IzyTelColors.errorSoft,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Symbols.cancel_rounded,
                                          color: IzyTelColors.error,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          '$cancelledCount signalement${cancelledCount > 1 ? 's' : ''} classé${cancelledCount > 1 ? 's' : ''} sans suite.',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: IzyTelColors.textPrimary,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: IzyTelSpacing.md),
                              IzyTelSearchField(
                                controller: _searchController,
                                hintText: 'Agent, réseau, type, description…',
                                onChanged: (String value) {
                                  setState(() => _query = value);
                                },
                              ),
                              const SizedBox(height: IzyTelSpacing.sm),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildTabPill(
                                      label: 'Tous',
                                      selected:
                                          _selectedTab == _AgentIssueTab.all,
                                      onTap: () => setState(
                                        () => _selectedTab = _AgentIssueTab.all,
                                      ),
                                      count: allIssues.length,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildTabPill(
                                      label: 'Ouverts',
                                      selected:
                                          _selectedTab == _AgentIssueTab.open,
                                      onTap: () => setState(
                                        () =>
                                            _selectedTab = _AgentIssueTab.open,
                                      ),
                                      count: openCount,
                                      color: IzyTelColors.warning,
                                      softColor: IzyTelColors.warningSoft,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildTabPill(
                                      label: 'En cours',
                                      selected:
                                          _selectedTab ==
                                          _AgentIssueTab.inProgress,
                                      onTap: () => setState(
                                        () => _selectedTab =
                                            _AgentIssueTab.inProgress,
                                      ),
                                      count: inProgressCount,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildTabPill(
                                      label: 'Résolus',
                                      selected:
                                          _selectedTab ==
                                          _AgentIssueTab.resolved,
                                      onTap: () => setState(
                                        () => _selectedTab =
                                            _AgentIssueTab.resolved,
                                      ),
                                      count: resolvedCount,
                                      color: IzyTelColors.success,
                                      softColor: IzyTelColors.successSoft,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildTabPill(
                                      label: 'Sans suite',
                                      selected:
                                          _selectedTab ==
                                          _AgentIssueTab.cancelled,
                                      onTap: () => setState(
                                        () => _selectedTab =
                                            _AgentIssueTab.cancelled,
                                      ),
                                      count: cancelledCount,
                                      color: IzyTelColors.error,
                                      softColor: IzyTelColors.errorSoft,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: IzyTelSpacing.lg),
                              if (visible.isEmpty)
                                const _IssueEmptyState()
                              else
                                ...visible.map(
                                  (AgentIssue issue) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _AgentIssueAdminCard(
                                      issue: issue,
                                      agentName:
                                          agentById[issue.agentId]?.name ??
                                          'Agent',
                                      onTap: () => _openIssueDetail(
                                        issue: issue,
                                        agent: agentById[issue.agentId],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                );
              },
        ),
      ),
    );
  }

  Widget _buildTabPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required int count,
    Color color = IzyTelColors.primary,
    Color softColor = IzyTelColors.primarySoft,
  }) {
    return IzyTelFilterPill(
      label: label,
      selected: selected,
      onTap: onTap,
      count: count,
      selectedColor: color,
      softColor: softColor,
      tintedWhenIdle: selected,
    );
  }

  List<AgentIssue> _filterIssues(
    List<AgentIssue> issues,
    Map<String, AgentDirectoryEntry> agentById,
  ) {
    Iterable<AgentIssue> filtered = issues.where((AgentIssue issue) {
      return switch (_selectedTab) {
        _AgentIssueTab.all => true,
        _AgentIssueTab.open => issue.status == 'open',
        _AgentIssueTab.inProgress => issue.status == 'in_progress',
        _AgentIssueTab.resolved => issue.status == 'resolved',
        _AgentIssueTab.cancelled => issue.status == 'cancelled',
      };
    });

    final String query = _query.trim().toLowerCase();
    if (query.isEmpty) return filtered.toList(growable: false);

    filtered = filtered.where((AgentIssue issue) {
      final AgentDirectoryEntry? agent = agentById[issue.agentId];
      final String searchable = <String>[
        agent?.name ?? '',
        agent?.phoneNumber ?? '',
        issue.network?.label ?? '',
        _issueTypeLabel(issue.type),
        _issueStatusLabel(issue.status),
        issue.description,
        issue.resolvedBy ?? '',
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    });

    return filtered.toList(growable: false);
  }

  Future<void> _openIssueDetail({
    required AgentIssue issue,
    required AgentDirectoryEntry? agent,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setModalState,
              ) {
                Future<void> updateStatus(String status) async {
                  setModalState(() => _isUpdating = true);
                  try {
                    await widget.repository.updateIssueStatus(
                      issueId: issue.id,
                      status: status,
                      resolvedBy: widget.user.name,
                    );
                    if (!mounted || !context.mounted) return;
                    Navigator.of(context).pop();
                    IzyTelFeedback.success(
                      this.context,
                      _successMessageForStatus(status),
                    );
                    return;
                  } catch (_) {
                    if (!mounted || !context.mounted) return;
                    setModalState(() => _isUpdating = false);
                    IzyTelFeedback.error(
                      this.context,
                      'Impossible de mettre à jour le signalement.',
                    );
                  }
                }

                return _IssueDetailSheet(
                  issue: issue,
                  agent: agent,
                  isUpdating: _isUpdating,
                  onMarkInProgress: issue.status == 'in_progress'
                      ? null
                      : () => updateStatus('in_progress'),
                  onResolve: issue.status == 'resolved'
                      ? null
                      : () => updateStatus('resolved'),
                  onCancel: issue.status == 'cancelled'
                      ? null
                      : () => updateStatus('cancelled'),
                );
              },
        );
      },
    );
  }

  String _successMessageForStatus(String status) {
    switch (status) {
      case 'in_progress':
        return 'Le signalement est passé en cours de traitement.';
      case 'resolved':
        return 'Le signalement a été marqué comme résolu.';
      case 'cancelled':
        return 'Le signalement a été classé sans suite.';
      default:
        return 'Signalement mis à jour.';
    }
  }
}

class _IssueMetricCard extends StatelessWidget {
  const _IssueMetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.softColor,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final Color softColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      radius: IzyTelRadii.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: IzyTelColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: IzyTelColors.textPrimary,
                  ),
                ),
              ),
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: softColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: 34,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentIssueAdminCard extends StatelessWidget {
  const _AgentIssueAdminCard({
    required this.issue,
    required this.agentName,
    required this.onTap,
  });

  final AgentIssue issue;
  final String agentName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = _issueStatusColor(issue.status);
    return IzyTelSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      radius: IzyTelRadii.card,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withAlpha(22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _issueStatusIcon(issue.status),
              color: accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$agentName · ${_issueTypeLabel(issue.type)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: IzyTelColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IzyTelStatusPill(
                      label: _issueStatusLabel(issue.status),
                      color: accent,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  issue.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IzyTelColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${issue.network?.label ?? 'Tous réseaux'} · ${_formatDate(issue.createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: IzyTelColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Symbols.chevron_right_rounded,
                      size: 18,
                      color: IzyTelColors.textMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IssueDetailSheet extends StatelessWidget {
  const _IssueDetailSheet({
    required this.issue,
    required this.agent,
    required this.isUpdating,
    required this.onMarkInProgress,
    required this.onResolve,
    required this.onCancel,
  });

  final AgentIssue issue;
  final AgentDirectoryEntry? agent;
  final bool isUpdating;
  final VoidCallback? onMarkInProgress;
  final VoidCallback? onResolve;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final Color accent = _issueStatusColor(issue.status);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 12, 12, bottomInset + 12),
        child: Container(
          decoration: const BoxDecoration(
            color: IzyTelColors.surface,
            borderRadius: BorderRadius.all(Radius.circular(IzyTelRadii.sheet)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(IzyTelSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Détail du signalement',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: IzyTelColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Symbols.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    IzyTelStatusPill(
                      label: _issueStatusLabel(issue.status),
                      color: accent,
                    ),
                    IzyTelStatusPill(
                      label: issue.network?.label ?? 'Tous réseaux',
                      color: IzyTelColors.primary,
                      icon: Symbols.sim_card_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: IzyTelSpacing.lg),
                _InfoBlock(
                  label: 'Agent',
                  value: agent?.name ?? 'Agent',
                  secondary: agent?.phoneNumber,
                ),
                const SizedBox(height: IzyTelSpacing.md),
                _InfoBlock(label: 'Type', value: _issueTypeLabel(issue.type)),
                const SizedBox(height: IzyTelSpacing.md),
                _InfoBlock(
                  label: 'Description',
                  value: issue.description,
                  valueMultiline: true,
                ),
                const SizedBox(height: IzyTelSpacing.md),
                _InfoBlock(
                  label: 'Créé le',
                  value: _formatDateTime(issue.createdAt),
                ),
                if (issue.updatedAt != null) ...[
                  const SizedBox(height: IzyTelSpacing.md),
                  _InfoBlock(
                    label: 'Dernière mise à jour',
                    value: _formatDateTime(issue.updatedAt!),
                  ),
                ],
                if (issue.resolvedAt != null) ...[
                  const SizedBox(height: IzyTelSpacing.md),
                  _InfoBlock(
                    label: 'Clôturé le',
                    value: _formatDateTime(issue.resolvedAt!),
                    secondary: issue.resolvedBy == null
                        ? null
                        : 'Par ${issue.resolvedBy}',
                  ),
                ],
                const SizedBox(height: IzyTelSpacing.xl),
                if (isUpdating)
                  const Padding(
                    padding: EdgeInsets.only(bottom: IzyTelSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isUpdating ? null : onMarkInProgress,
                        icon: const Icon(Symbols.autorenew_rounded, size: 18),
                        label: const Text('En cours'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isUpdating ? null : onResolve,
                        icon: const Icon(Symbols.check_rounded, size: 18),
                        label: const Text('Résoudre'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isUpdating ? null : onCancel,
                    icon: const Icon(Symbols.block_rounded, size: 18),
                    label: const Text('Classer sans suite'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: IzyTelColors.error,
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

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.label,
    required this.value,
    this.secondary,
    this.valueMultiline = false,
  });

  final String label;
  final String value;
  final String? secondary;
  final bool valueMultiline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: IzyTelColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: IzyTelColors.textPrimary,
            fontWeight: FontWeight.w600,
            height: valueMultiline ? 1.4 : 1.2,
          ),
        ),
        if (secondary != null) ...[
          const SizedBox(height: 3),
          Text(
            secondary!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: IzyTelColors.textMuted),
          ),
        ],
      ],
    );
  }
}

class _IssueEmptyState extends StatelessWidget {
  const _IssueEmptyState();

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: IzyTelColors.successSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Symbols.inventory_2_rounded,
              color: IzyTelColors.success,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Aucun signalement à afficher',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: IzyTelColors.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Les incidents remontés par les agents apparaîtront ici et pourront être traités depuis cette page.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: IzyTelColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _IssueErrorState extends StatelessWidget {
  const _IssueErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(IzyTelSpacing.lg),
        child: IzyTelSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Symbols.cloud_off_rounded,
                color: IzyTelColors.error,
                size: 34,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Symbols.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _issueTypeLabel(String value) {
  switch (value) {
    case 'network':
      return 'Réseau';
    case 'balance':
      return 'Solde';
    case 'technical':
      return 'Technique';
    case 'other':
      return 'Autre';
    default:
      return 'Incident';
  }
}

String _issueStatusLabel(String value) {
  switch (value) {
    case 'resolved':
      return 'Résolu';
    case 'cancelled':
      return 'Sans suite';
    case 'in_progress':
      return 'En cours';
    case 'open':
    default:
      return 'Ouvert';
  }
}

Color _issueStatusColor(String value) {
  switch (value) {
    case 'resolved':
      return IzyTelColors.success;
    case 'cancelled':
      return IzyTelColors.error;
    case 'in_progress':
      return IzyTelColors.primary;
    case 'open':
    default:
      return IzyTelColors.warning;
  }
}

IconData _issueStatusIcon(String value) {
  switch (value) {
    case 'resolved':
      return Symbols.check_circle_rounded;
    case 'cancelled':
      return Symbols.cancel_rounded;
    case 'in_progress':
      return Symbols.autorenew_rounded;
    case 'open':
    default:
      return Symbols.warning_rounded;
  }
}

String _formatDate(DateTime date) {
  const List<String> months = <String>[
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _formatDateTime(DateTime date) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${_formatDate(date)} à ${twoDigits(date.hour)}:${twoDigits(date.minute)}';
}
