import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_order_widgets.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum _IssueScope { all, open, inProgress, resolved, cancelled }

class BackofficeAgentIssuesPage extends StatefulWidget {
  const BackofficeAgentIssuesPage({
    super.key,
    required this.user,
    required this.repository,
  });

  final AppUser user;
  final AgentRepository repository;

  @override
  State<BackofficeAgentIssuesPage> createState() => _BackofficeAgentIssuesPageState();
}

class _BackofficeAgentIssuesPageState extends State<BackofficeAgentIssuesPage> {
  late final Stream<List<AgentIssue>> _issuesStream;
  late final Stream<List<AgentDirectoryEntry>> _agentsStream;
  final TextEditingController _searchController = TextEditingController();
  _IssueScope _scope = _IssueScope.open;
  String _query = '';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _issuesStream = widget.repository.watchAllAgentIssues();
    _agentsStream = widget.repository.watchAgents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AgentIssue>>(
      stream: _issuesStream,
      builder: (BuildContext context, AsyncSnapshot<List<AgentIssue>> issuesSnapshot) {
        if (issuesSnapshot.hasError) {
          return const BackofficeEmptyState(
            icon: Symbols.report_problem_rounded,
            title: 'Signalements indisponibles',
            message: 'Impossible de charger les signalements Agents pour le moment.',
          );
        }
        if (!issuesSnapshot.hasData) return const Center(child: CircularProgressIndicator());
        return StreamBuilder<List<AgentDirectoryEntry>>(
          stream: _agentsStream,
          builder: (BuildContext context, AsyncSnapshot<List<AgentDirectoryEntry>> agentsSnapshot) {
            final List<AgentIssue> all = issuesSnapshot.data!;
            final List<AgentDirectoryEntry> agents = agentsSnapshot.data ?? const <AgentDirectoryEntry>[];
            final Map<String, AgentDirectoryEntry> agentById = <String, AgentDirectoryEntry>{for (final AgentDirectoryEntry agent in agents) agent.userId: agent};
            final int open = all.where((AgentIssue issue) => issue.status == 'open').length;
            final int progress = all.where((AgentIssue issue) => issue.status == 'in_progress').length;
            final int resolved = all.where((AgentIssue issue) => issue.status == 'resolved').length;
            final int cancelled = all.where((AgentIssue issue) => issue.status == 'cancelled').length;
            final List<AgentIssue> visible = _filtered(all, agentById);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const BackofficePageIntro(
                  eyebrow: 'Équipe / Signalements',
                  title: 'Centre de signalements Agents',
                  description: 'Priorise les incidents remontés par les Agents, suis leur prise en charge et conserve l’identité du staff qui les résout.',
                  icon: Symbols.report_problem_rounded,
                ),
                const SizedBox(height: 18),
                _metrics(open: open, progress: progress, resolved: resolved, cancelled: cancelled),
                const SizedBox(height: 14),
                _filters(all: all, open: open, progress: progress, resolved: resolved, cancelled: cancelled),
                const SizedBox(height: 14),
                if (visible.isEmpty)
                  const BackofficeEmptyState(
                    icon: Symbols.task_alt_rounded,
                    title: 'Aucun signalement dans cette vue',
                    message: 'Les signalements correspondant aux filtres actifs apparaîtront ici.',
                  )
                else
                  LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      if (constraints.maxWidth >= 920) return _desktopTable(visible, agentById);
                      return Column(
                        children: visible.map((AgentIssue issue) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _mobileCard(issue, agentById[issue.agentId]),
                        )).toList(growable: false),
                      );
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _metrics({required int open, required int progress, required int resolved, required int cancelled}) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 920 ? 4 : 2;
        const double gap = 10;
        final double width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        final List<Widget> cards = <Widget>[
          BackofficeMetricCard(label: 'Ouverts', value: '$open', caption: 'à prendre en charge', icon: Symbols.warning_rounded, emphasis: BackofficePalette.warning),
          BackofficeMetricCard(label: 'En cours', value: '$progress', caption: 'incidents suivis', icon: Symbols.fact_check_rounded),
          BackofficeMetricCard(label: 'Résolus', value: '$resolved', caption: 'traitements finalisés', icon: Symbols.task_alt_rounded, emphasis: BackofficePalette.success),
          BackofficeMetricCard(label: 'Sans suite', value: '$cancelled', caption: 'dossiers classés', icon: Symbols.cancel_rounded, emphasis: BackofficePalette.danger),
        ];
        return Wrap(spacing: gap, runSpacing: gap, children: cards.map((Widget card) => SizedBox(width: width, child: card)).toList());
      },
    );
  }

  Widget _filters({required List<AgentIssue> all, required int open, required int progress, required int resolved, required int cancelled}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: backofficePanelDecoration(),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget search = TextField(
            controller: _searchController,
            onChanged: (String value) => setState(() => _query = value),
            decoration: const InputDecoration(hintText: 'Agent, réseau, type ou description', prefixIcon: Icon(Symbols.search_rounded)),
          );
          final Widget scope = DropdownButtonFormField<_IssueScope>(
            initialValue: _scope,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Vue'),
            items: <DropdownMenuItem<_IssueScope>>[
              DropdownMenuItem(value: _IssueScope.all, child: Text('Tous (${all.length})')),
              DropdownMenuItem(value: _IssueScope.open, child: Text('Ouverts ($open)')),
              DropdownMenuItem(value: _IssueScope.inProgress, child: Text('En cours ($progress)')),
              DropdownMenuItem(value: _IssueScope.resolved, child: Text('Résolus ($resolved)')),
              DropdownMenuItem(value: _IssueScope.cancelled, child: Text('Sans suite ($cancelled)')),
            ],
            onChanged: (_IssueScope? value) {
              if (value != null) setState(() => _scope = value);
            },
          );
          if (constraints.maxWidth < 760) return Column(children: <Widget>[search, const SizedBox(height: 10), scope]);
          return Row(children: <Widget>[Expanded(flex: 3, child: search), const SizedBox(width: 10), SizedBox(width: 250, child: scope)]);
        },
      ),
    );
  }

  List<AgentIssue> _filtered(List<AgentIssue> all, Map<String, AgentDirectoryEntry> agentById) {
    final String query = _query.trim().toLowerCase();
    final List<AgentIssue> result = all.where((AgentIssue issue) {
      final bool inScope = switch (_scope) {
        _IssueScope.all => true,
        _IssueScope.open => issue.status == 'open',
        _IssueScope.inProgress => issue.status == 'in_progress',
        _IssueScope.resolved => issue.status == 'resolved',
        _IssueScope.cancelled => issue.status == 'cancelled',
      };
      if (!inScope) return false;
      if (query.isEmpty) return true;
      return <String>[
        agentById[issue.agentId]?.name ?? issue.agentId,
        issue.type,
        issue.description,
        issue.network?.label ?? '',
        issue.status,
      ].join(' ').toLowerCase().contains(query);
    }).toList(growable: false);
    result.sort((AgentIssue a, AgentIssue b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Widget _desktopTable(List<AgentIssue> issues, Map<String, AgentDirectoryEntry> agentById) {
    return BackofficeDesktopTable(
      columns: const <BackofficeTableColumnSpec>[
        BackofficeTableColumnSpec(label: 'STATUT', flex: 2),
        BackofficeTableColumnSpec(label: 'AGENT', flex: 3),
        BackofficeTableColumnSpec(label: 'SIGNALEMENT', flex: 4),
        BackofficeTableColumnSpec(label: 'RÉSEAU / DATE', flex: 3),
        BackofficeTableColumnSpec(label: 'ACTION', flex: 2, alignment: Alignment.centerRight),
      ],
      rows: issues.map((AgentIssue issue) {
        final AgentDirectoryEntry? agent = agentById[issue.agentId];
        final Color color = _statusColor(issue.status);
        return BackofficeDesktopTableRow(
          accentColor: issue.status == 'open' ? BackofficePalette.warning : issue.status == 'in_progress' ? BackofficePalette.primary : null,
          backgroundColor: issue.status == 'open' ? BackofficePalette.warning.withValues(alpha: .025) : null,
          onTap: () => _openDetails(issue, agent),
          cells: <BackofficeTableCellSpec>[
            BackofficeTableCellSpec(flex: 2, child: BackofficeStatusBadge(label: _statusLabel(issue.status), color: color)),
            BackofficeTableCellSpec(flex: 3, child: _twoLines(agent?.name ?? 'Agent', agent?.agentCode ?? issue.agentId)),
            BackofficeTableCellSpec(flex: 4, child: _twoLines(issue.type, issue.description)),
            BackofficeTableCellSpec(flex: 3, child: _twoLines(issue.network?.label ?? 'Tous réseaux', _formatDate(issue.createdAt))),
            BackofficeTableCellSpec(flex: 2, alignment: Alignment.centerRight, child: _primaryAction(issue, agent)),
          ],
        );
      }).toList(growable: false),
    );
  }

  Widget _mobileCard(AgentIssue issue, AgentDirectoryEntry? agent) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openDetails(issue, agent),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: backofficePanelDecoration(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Row(children: <Widget>[Expanded(child: BackofficeStatusBadge(label: _statusLabel(issue.status), color: _statusColor(issue.status))), const SizedBox(width: 8), Text(_formatDate(issue.createdAt), style: Theme.of(context).textTheme.bodySmall)]),
            const SizedBox(height: 10),
            Text(agent?.name ?? 'Agent', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('${issue.type}${issue.network == null ? '' : ' • ${issue.network!.label}'}', style: Theme.of(context).textTheme.bodySmall),
            if (issue.description.trim().isNotEmpty) ...<Widget>[const SizedBox(height: 8), Text(issue.description, maxLines: 2, overflow: TextOverflow.ellipsis)],
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: _primaryAction(issue, agent)),
          ]),
        ),
      ),
    );
  }

  Widget _twoLines(String title, String subtitle) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: <Widget>[
      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 3),
      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }

  Widget _primaryAction(AgentIssue issue, AgentDirectoryEntry? agent) {
    if (issue.status == 'open') {
      return FilledButton(onPressed: _submitting ? null : () => _update(issue, 'in_progress'), child: const Text('Prendre'));
    }
    if (issue.status == 'in_progress') {
      return FilledButton(onPressed: _submitting ? null : () => _update(issue, 'resolved'), child: const Text('Résoudre'));
    }
    return OutlinedButton(onPressed: () => _openDetails(issue, agent), child: const Text('Voir'));
  }

  Future<void> _update(AgentIssue issue, String status) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.repository.updateIssueStatus(issueId: issue.id, status: status, resolvedBy: status == 'resolved' ? widget.user.id : null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signalement mis à jour.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancel(AgentIssue issue) async {
    await _update(issue, 'cancelled');
  }

  Future<void> _openDetails(AgentIssue issue, AgentDirectoryEntry? agent) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Row(children: <Widget>[Expanded(child: Text(agent?.name ?? 'Signalement Agent')), BackofficeStatusBadge(label: _statusLabel(issue.status), color: _statusColor(issue.status))]),
        content: SizedBox(
          width: 620,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            _detail('Type', issue.type),
            _detail('Réseau', issue.network?.label ?? 'Non précisé'),
            _detail('Description', issue.description),
            _detail('Créé le', _formatDate(issue.createdAt)),
            if (issue.resolvedAt != null) _detail('Résolu le', _formatDate(issue.resolvedAt!)),
            if ((issue.resolvedBy ?? '').trim().isNotEmpty) _detail('Résolu par', issue.resolvedBy!),
          ]),
        ),
        actions: <Widget>[
          if ((issue.status == 'open' || issue.status == 'in_progress'))
            TextButton(onPressed: _submitting ? null : () { Navigator.pop(dialogContext); _cancel(issue); }, style: TextButton.styleFrom(foregroundColor: BackofficePalette.danger), child: const Text('Classer sans suite')),
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fermer')),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: BackofficePalette.faint, fontWeight: FontWeight.w800, letterSpacing: .6)),
        const SizedBox(height: 3),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ]),
    );
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

  String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} • ${two(value.hour)}:${two(value.minute)}';
  }
}
