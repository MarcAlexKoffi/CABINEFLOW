import 'dart:async';

import 'package:cabine_flow/backoffice/data/repositories/supabase_backoffice_case_pagination_repository.dart';
import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_modal.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_order_widgets.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_pagination.dart';
import 'package:cabine_flow/features/agents/data/repositories/supabase_agent_issue_center_repository.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_issue_center_models.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/shared/widgets/izytel_period_filter.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum _IssueScope { all, open, inProgress, resolved, cancelled }
enum _IssueNetworkScope { all, orange, mtn, moov, unspecified }
enum _IssueSort { recent, oldest, updated }

class BackofficeAgentIssuesPage extends StatefulWidget {
  const BackofficeAgentIssuesPage({
    super.key,
    required this.user,
    required this.repository,
  });

  final AppUser user;
  final AgentRepository repository;

  @override
  State<BackofficeAgentIssuesPage> createState() =>
      _BackofficeAgentIssuesPageState();
}

class _BackofficeAgentIssuesPageState extends State<BackofficeAgentIssuesPage> {
  late final Stream<List<AgentDirectoryEntry>> _agentsStream;
  late final SupabaseAgentIssueCenterRepository _centerRepository;
  late final SupabaseBackofficeCasePaginationRepository _pageRepository;
  late Future<BackofficeAgentIssuePageData> _pageFuture;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _busyIssueIds = <String>{};
  Timer? _searchDebounce;

  _IssueScope _scope = _IssueScope.open;
  _IssueNetworkScope _networkScope = _IssueNetworkScope.all;
  _IssueSort _sort = _IssueSort.recent;
  String _query = '';
  IzyTelPeriodFilterValue _period = const IzyTelPeriodFilterValue();
  int _page = 1;
  int _pageSize = 25;

  @override
  void initState() {
    super.initState();
    _agentsStream = widget.repository.watchAgents();
    _centerRepository = SupabaseAgentIssueCenterRepository();
    _pageRepository = SupabaseBackofficeCasePaginationRepository();
    _pageFuture = _fetchPage();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<BackofficeAgentIssuePageData> _fetchPage() {
    final DateTimeRange? range = _period.resolvedRange();
    return _pageRepository.fetchAgentIssuePage(
      start: range?.start,
      end: range?.end,
      scope: switch (_scope) {
        _IssueScope.all => 'all',
        _IssueScope.open => 'open',
        _IssueScope.inProgress => 'in_progress',
        _IssueScope.resolved => 'resolved',
        _IssueScope.cancelled => 'cancelled',
      },
      network: switch (_networkScope) {
        _IssueNetworkScope.all => null,
        _IssueNetworkScope.orange => 'orange',
        _IssueNetworkScope.mtn => 'mtn',
        _IssueNetworkScope.moov => 'moov',
        _IssueNetworkScope.unspecified => '__none__',
      },
      query: _query,
      sort: switch (_sort) {
        _IssueSort.recent => 'recent',
        _IssueSort.oldest => 'oldest',
        _IssueSort.updated => 'updated',
      },
      page: _page,
      pageSize: _pageSize,
    );
  }

  void _reload({bool resetPage = false}) {
    if (resetPage) _page = 1;
    setState(() => _pageFuture = _fetchPage());
  }

  void _onSearchChanged(String value) {
    _query = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _reload(resetPage: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BackofficeAgentIssuePageData>(
      future: _pageFuture,
      builder: (BuildContext context, AsyncSnapshot<BackofficeAgentIssuePageData> centerSnapshot) {
        if (centerSnapshot.hasError) {
          return BackofficeEmptyState(
            icon: Symbols.report_problem_rounded,
            title: 'Signalements indisponibles',
            message: 'Impossible de charger le centre de signalements Agents pour le moment.',
            action: OutlinedButton.icon(
              onPressed: () => _reload(),
              icon: const Icon(Symbols.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          );
        }
        if (!centerSnapshot.hasData) return const Center(child: CircularProgressIndicator());

        return StreamBuilder<List<AgentDirectoryEntry>>(
          stream: _agentsStream,
          builder: (BuildContext context, AsyncSnapshot<List<AgentDirectoryEntry>> agentsSnapshot) {
            final BackofficeAgentIssuePageData data = centerSnapshot.data!;
            final List<AgentDirectoryEntry> agents = agentsSnapshot.data ?? const <AgentDirectoryEntry>[];
            final Map<String, AgentDirectoryEntry> agentById = <String, AgentDirectoryEntry>{
              for (final AgentDirectoryEntry agent in agents) agent.userId: agent,
            };
            final List<AgentIssueCenterItem> visible = data.items;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const BackofficePageIntro(
                  eyebrow: 'Équipe / Signalements',
                  title: 'Centre de signalements Agents',
                  description: 'Centralise les incidents terrain, priorise leur traitement et conserve un historique lisible de chaque prise en charge.',
                  icon: Symbols.report_problem_rounded,
                ),
                const SizedBox(height: 14),
                _scopeBanner(data),
                const SizedBox(height: 14),
                _metrics(
                  open: data.openCount,
                  progress: data.inProgressCount,
                  resolved: data.resolvedCount,
                  cancelled: data.cancelledCount,
                ),
                const SizedBox(height: 14),
                _filters(data: data),
                const SizedBox(height: 14),
                _resultsHeader(visible.length, data.total),
                const SizedBox(height: 10),
                if (visible.isEmpty)
                  const BackofficeEmptyState(
                    icon: Symbols.task_alt_rounded,
                    title: 'Aucun signalement dans cette vue',
                    message: 'Les signalements correspondant aux filtres actifs apparaîtront ici.',
                  )
                else
                  LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      if (constraints.maxWidth >= 980) return _desktopTable(visible, agentById);
                      return Column(
                        children: visible
                            .map((AgentIssueCenterItem issue) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _mobileCard(issue, agentById[issue.agentId]),
                                ))
                            .toList(growable: false),
                      );
                    },
                  ),
                if (data.total > 0) ...<Widget>[
                  const SizedBox(height: 14),
                  BackofficePaginationBar(
                    page: _page,
                    pageSize: _pageSize,
                    total: data.total,
                    loading: centerSnapshot.connectionState == ConnectionState.waiting,
                    onPrevious: _page > 1 ? () { _page -= 1; _reload(); } : null,
                    onNext: _page * _pageSize < data.total ? () { _page += 1; _reload(); } : null,
                    onPageSizeChanged: (int value) { _pageSize = value; _reload(resetPage: true); },
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _scopeBanner(BackofficeAgentIssuePageData snapshot) {
    final bool managerScope = snapshot.scopeType == 'manager_territory';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: managerScope
            ? BackofficePalette.primarySoft.withValues(alpha: .72)
            : const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: managerScope
              ? BackofficePalette.primary.withValues(alpha: .14)
              : BackofficePalette.line,
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            managerScope
                ? Symbols.location_on_rounded
                : Symbols.admin_panel_settings_rounded,
            size: 20,
            color: managerScope
                ? BackofficePalette.primary
                : BackofficePalette.muted,
            fill: 1,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              managerScope
                  ? 'Périmètre Manager : uniquement les signalements des Agents rattachés à vos zones.'
                  : 'Périmètre Administrateur : tous les signalements Agents sont visibles.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: BackofficePalette.ink,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (snapshot.generatedAt != null) ...<Widget>[
            const SizedBox(width: 10),
            Text(
              'Actualisé ${_formatTime(snapshot.generatedAt!)}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: BackofficePalette.faint,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => _reload(),
            icon: const Icon(Symbols.refresh_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _metrics({
    required int open,
    required int progress,
    required int resolved,
    required int cancelled,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 920 ? 4 : 2;
        const double gap = 10;
        final double width =
            (constraints.maxWidth - (columns - 1) * gap) / columns;
        final List<Widget> cards = <Widget>[
          BackofficeMetricCard(
            label: 'Ouverts',
            value: '$open',
            caption: 'à prendre en charge',
            icon: Symbols.warning_rounded,
            emphasis: BackofficePalette.warning,
          ),
          BackofficeMetricCard(
            label: 'En cours',
            value: '$progress',
            caption: 'incidents suivis',
            icon: Symbols.fact_check_rounded,
          ),
          BackofficeMetricCard(
            label: 'Résolus',
            value: '$resolved',
            caption: 'traitements finalisés',
            icon: Symbols.task_alt_rounded,
            emphasis: BackofficePalette.success,
          ),
          BackofficeMetricCard(
            label: 'Sans suite',
            value: '$cancelled',
            caption: 'dossiers classés',
            icon: Symbols.cancel_rounded,
            emphasis: BackofficePalette.danger,
          ),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards
              .map((Widget card) => SizedBox(width: width, child: card))
              .toList(growable: false),
        );
      },
    );
  }

  Widget _filters({required BackofficeAgentIssuePageData data}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: backofficePanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget search = TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Agent, type, réseau, description ou intervenant',
                  prefixIcon: Icon(Symbols.search_rounded),
                ),
              );
              final Widget scope = DropdownButtonFormField<_IssueScope>(
                initialValue: _scope,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'État'),
                items: <DropdownMenuItem<_IssueScope>>[
                  DropdownMenuItem(value: _IssueScope.all, child: Text('Tous (${data.allCount})')),
                  DropdownMenuItem(value: _IssueScope.open, child: Text('Ouverts (${data.openCount})')),
                  DropdownMenuItem(value: _IssueScope.inProgress, child: Text('En cours (${data.inProgressCount})')),
                  DropdownMenuItem(value: _IssueScope.resolved, child: Text('Résolus (${data.resolvedCount})')),
                  DropdownMenuItem(value: _IssueScope.cancelled, child: Text('Sans suite (${data.cancelledCount})')),
                ],
                onChanged: (_IssueScope? value) {
                  if (value != null) { _scope = value; _reload(resetPage: true); }
                },
              );
              final Widget network = DropdownButtonFormField<_IssueNetworkScope>(
                initialValue: _networkScope,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Réseau'),
                items: const <DropdownMenuItem<_IssueNetworkScope>>[
                  DropdownMenuItem(value: _IssueNetworkScope.all, child: Text('Tous les réseaux')),
                  DropdownMenuItem(value: _IssueNetworkScope.orange, child: Text('Orange')),
                  DropdownMenuItem(value: _IssueNetworkScope.mtn, child: Text('MTN')),
                  DropdownMenuItem(value: _IssueNetworkScope.moov, child: Text('Moov Africa')),
                  DropdownMenuItem(value: _IssueNetworkScope.unspecified, child: Text('Non précisé')),
                ],
                onChanged: (_IssueNetworkScope? value) {
                  if (value != null) { _networkScope = value; _reload(resetPage: true); }
                },
              );
              final Widget sort = DropdownButtonFormField<_IssueSort>(
                initialValue: _sort,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tri'),
                items: const <DropdownMenuItem<_IssueSort>>[
                  DropdownMenuItem(value: _IssueSort.recent, child: Text('Plus récents')),
                  DropdownMenuItem(value: _IssueSort.oldest, child: Text('Plus anciens')),
                  DropdownMenuItem(value: _IssueSort.updated, child: Text('Dernière activité')),
                ],
                onChanged: (_IssueSort? value) {
                  if (value != null) { _sort = value; _reload(resetPage: true); }
                },
              );
              if (constraints.maxWidth < 820) {
                return Column(children: <Widget>[search, const SizedBox(height: 10), scope, const SizedBox(height: 10), network, const SizedBox(height: 10), sort]);
              }
              return Row(children: <Widget>[Expanded(flex: 4, child: search), const SizedBox(width: 10), SizedBox(width: 190, child: scope), const SizedBox(width: 10), SizedBox(width: 190, child: network), const SizedBox(width: 10), SizedBox(width: 180, child: sort)]);
            },
          ),
          const SizedBox(height: 12),
          IzyTelPeriodFilterBar(
            value: _period,
            onChanged: (IzyTelPeriodFilterValue value) { _period = value; _reload(resetPage: true); },
            compact: MediaQuery.sizeOf(context).width < 760,
            calendarHelpText: 'Retrouver d’anciens signalements Agents',
          ),
        ],
      ),
    );
  }


  Widget _resultsHeader(int visible, int all) {
    return Row(
      children: <Widget>[
        Text(
          '$visible signalement${visible > 1 ? 's' : ''}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: BackofficePalette.ink,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(width: 8),
        Text(
          'sur $all dans votre périmètre',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: BackofficePalette.muted,
              ),
        ),
      ],
    );
  }

  Widget _desktopTable(
    List<AgentIssueCenterItem> issues,
    Map<String, AgentDirectoryEntry> agentById,
  ) {
    return BackofficeDesktopTable(
      maxBodyHeight: 660,
      columns: const <BackofficeTableColumnSpec>[
        BackofficeTableColumnSpec(label: 'STATUT', flex: 2),
        BackofficeTableColumnSpec(label: 'AGENT', flex: 3),
        BackofficeTableColumnSpec(label: 'SIGNALEMENT', flex: 4),
        BackofficeTableColumnSpec(label: 'RÉSEAU', flex: 2),
        BackofficeTableColumnSpec(label: 'OUVERT DEPUIS', flex: 2),
        BackofficeTableColumnSpec(
          label: 'ACTION',
          flex: 2,
          alignment: Alignment.centerRight,
        ),
      ],
      rows: issues.map((AgentIssueCenterItem issue) {
        final AgentDirectoryEntry? agent = agentById[issue.agentId];
        final Color color = _statusColor(issue.status);
        return BackofficeDesktopTableRow(
          accentColor: issue.status == 'open'
              ? BackofficePalette.warning
              : issue.status == 'in_progress'
                  ? BackofficePalette.primary
                  : null,
          backgroundColor: issue.status == 'open'
              ? BackofficePalette.warning.withValues(alpha: .025)
              : null,
          onTap: () => _openDetails(issue, agent),
          cells: <BackofficeTableCellSpec>[
            BackofficeTableCellSpec(
              flex: 2,
              child: BackofficeStatusBadge(
                label: _statusLabel(issue.status),
                color: color,
                icon: _statusIcon(issue.status),
              ),
            ),
            BackofficeTableCellSpec(
              flex: 3,
              child: _twoLines(
                agent?.name ?? 'Agent',
                agent?.agentCode ?? issue.agentId,
              ),
            ),
            BackofficeTableCellSpec(
              flex: 4,
              child: _twoLines(
                _typeLabel(issue.type),
                issue.description,
              ),
            ),
            BackofficeTableCellSpec(
              flex: 2,
              child: issue.network == null
                  ? Text(
                      'Non précisé',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  : BackofficeNetworkBadge(
                      network: _mobileNetwork(issue.network!),
                      compact: true,
                    ),
            ),
            BackofficeTableCellSpec(
              flex: 2,
              child: _twoLines(
                _ageLabel(issue.createdAt),
                issue.createdAt == null
                    ? 'Date inconnue'
                    : _formatDate(issue.createdAt!),
              ),
            ),
            BackofficeTableCellSpec(
              flex: 2,
              alignment: Alignment.centerRight,
              child: _primaryAction(issue, agent),
            ),
          ],
        );
      }).toList(growable: false),
    );
  }

  Widget _mobileCard(
    AgentIssueCenterItem issue,
    AgentDirectoryEntry? agent,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openDetails(issue, agent),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: backofficePanelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  BackofficeStatusBadge(
                    label: _statusLabel(issue.status),
                    color: _statusColor(issue.status),
                    icon: _statusIcon(issue.status),
                  ),
                  const Spacer(),
                  Text(
                    _ageLabel(issue.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: BackofficePalette.muted,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                agent?.name ?? 'Agent',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    _typeLabel(issue.type),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (issue.network != null)
                    BackofficeNetworkBadge(
                      network: _mobileNetwork(issue.network!),
                      compact: true,
                    ),
                ],
              ),
              if (issue.description.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 9),
                Text(
                  issue.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: _primaryAction(issue, agent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _twoLines(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _primaryAction(
    AgentIssueCenterItem issue,
    AgentDirectoryEntry? agent,
  ) {
    final bool busy = _busyIssueIds.contains(issue.id);
    if (issue.status == 'open') {
      return FilledButton.icon(
        onPressed: busy ? null : () => _takeIssue(issue),
        icon: const Icon(Symbols.play_arrow_rounded, size: 18),
        label: Text(busy ? '...' : 'Prendre'),
      );
    }
    if (issue.status == 'in_progress') {
      return FilledButton.icon(
        onPressed: busy ? null : () => _resolveIssue(issue),
        icon: const Icon(Symbols.task_alt_rounded, size: 18),
        label: Text(busy ? '...' : 'Résoudre'),
      );
    }
    return OutlinedButton.icon(
      onPressed: () => _openDetails(issue, agent),
      icon: const Icon(Symbols.visibility_rounded, size: 18),
      label: const Text('Voir'),
    );
  }

  Future<void> _openDetails(
    AgentIssueCenterItem issue,
    AgentDirectoryEntry? agent,
  ) async {
    await showBackofficeModal<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final bool busy = _busyIssueIds.contains(issue.id);
        return BackofficeModalShell(
          title: agent?.name ?? 'Signalement Agent',
          subtitle:
              '${_typeLabel(issue.type)} • ${issue.createdAt == null ? 'date inconnue' : _formatDate(issue.createdAt!)}',
          icon: Symbols.report_problem_rounded,
          iconColor: _statusColor(issue.status),
          maxWidth: 880,
          chips: <Widget>[
            BackofficeStatusBadge(
              label: _statusLabel(issue.status),
              color: _statusColor(issue.status),
              icon: _statusIcon(issue.status),
            ),
            if (issue.network != null)
              BackofficeNetworkBadge(
                network: _mobileNetwork(issue.network!),
                compact: true,
              ),
          ],
          actions: <Widget>[
            if (issue.status == 'open')
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop();
                        _takeIssue(issue);
                      },
                icon: const Icon(Symbols.play_arrow_rounded),
                label: const Text('Prendre en charge'),
              ),
            if (issue.status == 'in_progress')
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop();
                        _resolveIssue(issue);
                      },
                icon: const Icon(Symbols.task_alt_rounded),
                label: const Text('Résoudre'),
              ),
            if (issue.status == 'open' || issue.status == 'in_progress')
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop();
                        _cancelIssue(issue);
                      },
                style: TextButton.styleFrom(
                  foregroundColor: BackofficePalette.danger,
                ),
                icon: const Icon(Symbols.cancel_rounded),
                label: const Text('Classer sans suite'),
              ),
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fermer'),
            ),
          ],
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              BackofficeModalHero(
                leading: _agentAvatar(agent?.name ?? 'Agent'),
                eyebrow: 'Signalement Agent',
                value: _typeLabel(issue.type),
                caption: issue.description,
                trailing: BackofficeStatusBadge(
                  label: _statusLabel(issue.status),
                  color: _statusColor(issue.status),
                  icon: _statusIcon(issue.status),
                ),
              ),
              const SizedBox(height: 14),
              BackofficeModalSection(
                title: 'Incident',
                subtitle: 'Informations déclarées par l’Agent',
                icon: Symbols.info_rounded,
                child: BackofficeInfoGrid(
                  items: <BackofficeInfoItem>[
                    BackofficeInfoItem(
                      label: 'Agent',
                      value: agent?.name ?? issue.agentId,
                      icon: Symbols.badge_rounded,
                      emphasis: true,
                    ),
                    BackofficeInfoItem(
                      label: 'Code Agent',
                      value: agent?.agentCode ?? issue.agentId,
                      icon: Symbols.tag_rounded,
                      selectable: true,
                    ),
                    BackofficeInfoItem(
                      label: 'Réseau',
                      value: issue.network?.label ?? 'Non précisé',
                      icon: Symbols.cell_tower_rounded,
                    ),
                    BackofficeInfoItem(
                      label: 'Créé le',
                      value: issue.createdAt == null
                          ? 'Non renseigné'
                          : _formatDate(issue.createdAt!),
                      icon: Symbols.schedule_rounded,
                    ),
                    BackofficeInfoItem(
                      label: 'Dernière activité',
                      value: issue.updatedAt == null
                          ? 'Non renseignée'
                          : _formatDate(issue.updatedAt!),
                      icon: Symbols.update_rounded,
                    ),
                    BackofficeInfoItem(
                      label: 'Ancienneté',
                      value: _ageLabel(issue.createdAt),
                      icon: Symbols.timelapse_rounded,
                    ),
                  ],
                ),
              ),
              if (issue.status == 'resolved' ||
                  issue.status == 'cancelled') ...<Widget>[
                const SizedBox(height: 14),
                BackofficeModalSection(
                  title: 'Clôture',
                  subtitle: 'Traçabilité de la décision finale',
                  icon: issue.status == 'resolved'
                      ? Symbols.verified_rounded
                      : Symbols.cancel_rounded,
                  tone: issue.status == 'resolved'
                      ? BackofficePalette.success
                      : BackofficePalette.danger,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      BackofficeInfoGrid(
                        items: <BackofficeInfoItem>[
                          BackofficeInfoItem(
                            label: 'Intervenant',
                            value: issue.resolvedBy.isEmpty
                                ? 'Non renseigné'
                                : issue.resolvedBy,
                            icon: Symbols.person_check_rounded,
                          ),
                          BackofficeInfoItem(
                            label: 'Clôturé le',
                            value: issue.resolvedAt == null
                                ? 'Non renseigné'
                                : _formatDate(issue.resolvedAt!),
                            icon: Symbols.event_available_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _noteCard(
                        issue.resolutionNote.isEmpty
                            ? 'Aucune note de clôture enregistrée pour ce signalement historique.'
                            : issue.resolutionNote,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              BackofficeModalSection(
                title: 'Historique du traitement',
                subtitle:
                    'Création, prise en charge et clôture dans l’ordre chronologique',
                icon: Symbols.history_rounded,
                child: _timeline(issue, agent),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _agentAvatar(String name) {
    final String initial = name.trim().isEmpty ? 'A' : name.trim()[0].toUpperCase();
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: BackofficePalette.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        initial,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: BackofficePalette.primary,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }

  Widget _noteCard(String note) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: BackofficePalette.line),
      ),
      child: Text(
        note,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
      ),
    );
  }

  Widget _timeline(
    AgentIssueCenterItem issue,
    AgentDirectoryEntry? agent,
  ) {
    if (issue.events.isEmpty) {
      return Text(
        'Aucun événement historique disponible.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Column(
      children: issue.events.asMap().entries.map((entry) {
        final int index = entry.key;
        final AgentIssueCenterEvent event = entry.value;
        final bool last = index == issue.events.length - 1;
        final String actor = event.kind == 'created'
            ? (agent?.name ?? 'Agent')
            : event.actorName.isNotEmpty
                ? event.actorName
                : 'Staff IzyTel';
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 30,
              child: Column(
                children: <Widget>[
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _eventColor(event.kind).withValues(alpha: .10),
                      border: Border.all(
                        color: _eventColor(event.kind).withValues(alpha: .28),
                      ),
                    ),
                    child: Icon(
                      _eventIcon(event.kind),
                      size: 15,
                      color: _eventColor(event.kind),
                      fill: 1,
                    ),
                  ),
                  if (!last)
                    Container(
                      width: 2,
                      height: event.note.isEmpty ? 38 : 58,
                      color: BackofficePalette.line,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: last ? 0 : 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            _eventLabel(event.kind),
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        if (event.occurredAt != null)
                          Text(
                            _formatDate(event.occurredAt!),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: BackofficePalette.faint,
                                ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      actor,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: BackofficePalette.muted,
                          ),
                    ),
                    if (event.note.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 5),
                      Text(
                        event.note,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: BackofficePalette.ink,
                              height: 1.4,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      }).toList(growable: false),
    );
  }

  Future<void> _takeIssue(AgentIssueCenterItem issue) async {
    await _transition(issue, status: 'in_progress');
  }

  Future<void> _resolveIssue(AgentIssueCenterItem issue) async {
    final String? note = await _requestClosingNote(
      title: 'Résoudre le signalement',
      subtitle:
          'Décris brièvement la solution appliquée. Cette note restera dans l’historique.',
      confirmLabel: 'Confirmer la résolution',
      tone: BackofficePalette.success,
    );
    if (note == null) return;
    await _transition(issue, status: 'resolved', note: note);
  }

  Future<void> _cancelIssue(AgentIssueCenterItem issue) async {
    final String? note = await _requestClosingNote(
      title: 'Classer sans suite',
      subtitle:
          'Indique pourquoi ce signalement est classé sans suite. Cette décision restera traçable.',
      confirmLabel: 'Classer le signalement',
      tone: BackofficePalette.danger,
    );
    if (note == null) return;
    await _transition(issue, status: 'cancelled', note: note);
  }

  Future<String?> _requestClosingNote({
    required String title,
    required String subtitle,
    required String confirmLabel,
    required Color tone,
  }) async {
    final TextEditingController controller = TextEditingController();
    final String? result = await showBackofficeModal<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final String value = controller.text.trim();
            final bool valid = value.length >= 3 && value.length <= 1000;
            return BackofficeModalShell(
              title: title,
              subtitle: subtitle,
              icon: Symbols.edit_note_rounded,
              iconColor: tone,
              maxWidth: 620,
              actions: <Widget>[
                OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton.icon(
                  onPressed: valid
                      ? () => Navigator.of(dialogContext).pop(value)
                      : null,
                  icon: const Icon(Symbols.check_rounded),
                  label: Text(confirmLabel),
                ),
              ],
              body: BackofficeModalSection(
                title: 'Note de clôture',
                subtitle: 'Entre 3 et 1000 caractères',
                icon: Symbols.notes_rounded,
                tone: tone,
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  minLines: 4,
                  maxLines: 7,
                  maxLength: 1000,
                  onChanged: (_) => setModalState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Ex. incident réseau vérifié, ligne rétablie après…',
                    alignLabelWithHint: true,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _transition(
    AgentIssueCenterItem issue, {
    required String status,
    String? note,
  }) async {
    if (_busyIssueIds.contains(issue.id)) return;
    setState(() => _busyIssueIds.add(issue.id));
    try {
      await _centerRepository.transitionIssue(
        issueId: issue.id,
        status: status,
        note: note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'in_progress'
                ? 'Signalement pris en charge.'
                : status == 'resolved'
                    ? 'Signalement résolu et historisé.'
                    : 'Signalement classé sans suite.',
          ),
        ),
      );
      _reload(resetPage: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _busyIssueIds.remove(issue.id));
      }
    }
  }



  String _friendlyError(Object error) {
    final String raw = error.toString();
    if (raw.contains('ISSUE_OUT_OF_SCOPE')) {
      return 'Ce signalement ne fait pas partie de votre périmètre Manager.';
    }
    if (raw.contains('ISSUE_ALREADY_CLOSED')) {
      return 'Ce signalement a déjà été clôturé.';
    }
    if (raw.contains('INVALID_TRANSITION')) {
      return 'Le statut du signalement a changé. Actualise la liste puis réessaie.';
    }
    if (raw.contains('RESOLUTION_NOTE_REQUIRED')) {
      return 'Une note de clôture de 3 caractères minimum est requise.';
    }
    if (raw.contains('STAFF_REQUIRED')) {
      return 'Ce compte n’est pas autorisé à traiter les signalements Agents.';
    }
    return 'Impossible de mettre à jour ce signalement pour le moment.';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return BackofficePalette.warning;
      case 'in_progress':
        return BackofficePalette.primary;
      case 'resolved':
        return BackofficePalette.success;
      case 'cancelled':
        return BackofficePalette.danger;
      default:
        return BackofficePalette.muted;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'open':
        return Symbols.warning_rounded;
      case 'in_progress':
        return Symbols.autorenew_rounded;
      case 'resolved':
        return Symbols.task_alt_rounded;
      case 'cancelled':
        return Symbols.cancel_rounded;
      default:
        return Symbols.info_rounded;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'open':
        return 'Ouvert';
      case 'in_progress':
        return 'En cours';
      case 'resolved':
        return 'Résolu';
      case 'cancelled':
        return 'Sans suite';
      default:
        return status;
    }
  }

  String _typeLabel(String type) {
    switch (type.trim().toLowerCase()) {
      case 'network':
        return 'Incident réseau';
      case 'technical':
        return 'Incident technique';
      case 'other':
        return 'Autre signalement';
      default:
        final String clean = type.trim();
        if (clean.isEmpty) return 'Signalement';
        return '${clean[0].toUpperCase()}${clean.substring(1)}';
    }
  }

  String _eventLabel(String kind) {
    switch (kind) {
      case 'created':
        return 'Signalement créé';
      case 'in_progress':
        return 'Pris en charge';
      case 'resolved':
        return 'Résolu';
      case 'cancelled':
        return 'Classé sans suite';
      default:
        return kind;
    }
  }

  IconData _eventIcon(String kind) {
    switch (kind) {
      case 'created':
        return Symbols.flag_rounded;
      case 'in_progress':
        return Symbols.play_arrow_rounded;
      case 'resolved':
        return Symbols.task_alt_rounded;
      case 'cancelled':
        return Symbols.cancel_rounded;
      default:
        return Symbols.circle;
    }
  }

  Color _eventColor(String kind) {
    switch (kind) {
      case 'created':
        return BackofficePalette.warning;
      case 'in_progress':
        return BackofficePalette.primary;
      case 'resolved':
        return BackofficePalette.success;
      case 'cancelled':
        return BackofficePalette.danger;
      default:
        return BackofficePalette.muted;
    }
  }

  MobileNetwork _mobileNetwork(AgentNetwork network) {
    switch (network) {
      case AgentNetwork.orange:
        return MobileNetwork.orange;
      case AgentNetwork.mtn:
        return MobileNetwork.mtn;
      case AgentNetwork.moov:
        return MobileNetwork.moov;
    }
  }

  String _ageLabel(DateTime? value) {
    if (value == null) return 'Inconnue';
    final Duration duration = DateTime.now().difference(value);
    if (duration.isNegative) return 'À l’instant';
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes.clamp(1, 59)} min';
    }
    if (duration.inHours < 24) return '${duration.inHours} h';
    if (duration.inDays < 30) return '${duration.inDays} j';
    final int months = (duration.inDays / 30).floor();
    return '$months mois';
  }

  String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} • ${two(value.hour)}:${two(value.minute)}';
  }

  String _formatTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.hour)}:${two(value.minute)}';
  }
}
