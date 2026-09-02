import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum _AgentIssueFilter { all, active, resolved, cancelled }

class AgentIssuesPage extends StatefulWidget {
  const AgentIssuesPage({
    super.key,
    required this.agentId,
    required this.repository,
  });

  final String agentId;
  final AgentRepository repository;

  @override
  State<AgentIssuesPage> createState() => _AgentIssuesPageState();
}

class _AgentIssuesPageState extends State<AgentIssuesPage> {
  final TextEditingController _searchController = TextEditingController();
  _AgentIssueFilter _filter = _AgentIssueFilter.all;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _report() async {
    final AgentIssueDraft? draft = await showModalBottomSheet<AgentIssueDraft>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AgentIssueEditorSheet(),
    );
    if (draft == null || !mounted) return;

    try {
      await widget.repository.createIssue(agentId: widget.agentId, issue: draft);
      if (!mounted) return;
      IzyTelFeedback.success(
        context,
        'Signalement transmis à l’administration.',
      );
    } catch (_) {
      if (!mounted) return;
      IzyTelFeedback.error(context, 'Impossible d’envoyer le signalement.');
    }
  }

  List<AgentIssue> _filteredIssues(List<AgentIssue> issues) {
    Iterable<AgentIssue> filtered = issues.where((AgentIssue issue) {
      return switch (_filter) {
        _AgentIssueFilter.all => true,
        _AgentIssueFilter.active => _isIssueActive(issue.status),
        _AgentIssueFilter.resolved => issue.status == 'resolved',
        _AgentIssueFilter.cancelled => issue.status == 'cancelled',
      };
    });

    final String query = _query.trim().toLowerCase();
    if (query.isEmpty) return filtered.toList(growable: false);

    return filtered.where((AgentIssue issue) {
      final String searchable = <String>[
        issue.id,
        _issueTypeLabel(issue.type),
        issue.network?.label ?? 'Tous réseaux',
        _issueStatusLabel(issue.status),
        issue.description,
        issue.resolvedBy ?? '',
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList(growable: false);
  }

  Future<void> _openIssueDetail(AgentIssue issue) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _AgentIssueDetailSheet(issue: issue),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(
        backgroundColor: IzyTelColors.background,
        foregroundColor: IzyTelColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Mes signalements',
          style: TextStyle(
            fontSize: IzyTelTypeScale.title3,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<List<AgentIssue>>(
        stream: widget.repository.watchAgentIssues(widget.agentId),
        builder: (BuildContext context, AsyncSnapshot<List<AgentIssue>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(IzyTelSpacing.xl),
                child: Text('Impossible de charger les signalements.'),
              ),
            );
          }

          final List<AgentIssue> issues = snapshot.data ?? const <AgentIssue>[];
          final int activeCount = issues
              .where((AgentIssue issue) => _isIssueActive(issue.status))
              .length;
          final List<AgentIssue> filtered = _filteredIssues(issues);

          return ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              IzyTelSpacing.lg,
              IzyTelSpacing.sm,
              IzyTelSpacing.lg,
              110,
            ),
            children: <Widget>[
              _IssueOverview(total: issues.length, open: activeCount),
              const SizedBox(height: IzyTelSpacing.lg),
              TextField(
                controller: _searchController,
                onChanged: (String value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Rechercher un signalement…',
                  prefixIcon: const Icon(Symbols.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Effacer',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Symbols.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: IzyTelSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    _IssueFilterChip(
                      label: 'Tous',
                      selected: _filter == _AgentIssueFilter.all,
                      onTap: () => setState(() => _filter = _AgentIssueFilter.all),
                    ),
                    _IssueFilterChip(
                      label: 'En cours',
                      selected: _filter == _AgentIssueFilter.active,
                      onTap: () => setState(() => _filter = _AgentIssueFilter.active),
                    ),
                    _IssueFilterChip(
                      label: 'Résolus',
                      selected: _filter == _AgentIssueFilter.resolved,
                      onTap: () => setState(() => _filter = _AgentIssueFilter.resolved),
                    ),
                    _IssueFilterChip(
                      label: 'Classés',
                      selected: _filter == _AgentIssueFilter.cancelled,
                      onTap: () => setState(() => _filter = _AgentIssueFilter.cancelled),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: IzyTelSpacing.xl),
              IzyTelSectionHeader(
                title: 'Historique',
                actionLabel: filtered.isEmpty ? null : '${filtered.length}',
              ),
              const SizedBox(height: IzyTelSpacing.sm),
              if (issues.isEmpty)
                const _IssueEmptyState(
                  title: 'Aucun signalement',
                  message:
                      'Tu peux signaler ici un problème réseau, de solde ou un incident technique.',
                )
              else if (filtered.isEmpty)
                const _IssueEmptyState(
                  title: 'Aucun résultat',
                  message:
                      'Aucun signalement ne correspond à cette recherche ou à ce filtre.',
                )
              else
                ...filtered.map(
                  (AgentIssue issue) => Padding(
                    padding: const EdgeInsets.only(bottom: IzyTelSpacing.sm),
                    child: _IssueRow(
                      issue: issue,
                      onTap: () => _openIssueDetail(issue),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _report,
        backgroundColor: IzyTelColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Symbols.add_rounded),
        label: const Text(
          'Signaler un problème',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _IssueOverview extends StatelessWidget {
  const _IssueOverview({required this.total, required this.open});

  final int total;
  final int open;

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      padding: const EdgeInsets.all(IzyTelSpacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: open > 0
                  ? IzyTelColors.warningSoft
                  : IzyTelColors.successSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              open > 0 ? Symbols.warning_rounded : Symbols.check_circle_rounded,
              color: open > 0 ? IzyTelColors.warning : IzyTelColors.success,
              size: IzyTelIconSize.state,
            ),
          ),
          const SizedBox(width: IzyTelSpacing.sm),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  open > 0
                      ? '$open signalement${open > 1 ? 's' : ''} en cours'
                      : 'Aucun incident en cours',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: IzyTelColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$total signalement${total > 1 ? 's' : ''} enregistré${total > 1 ? 's' : ''} au total',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IzyTelColors.textSecondary,
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

class _IssueFilterChip extends StatelessWidget {
  const _IssueFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _IssueEmptyState extends StatelessWidget {
  const _IssueEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Symbols.support_agent_rounded,
            size: 34,
            color: IzyTelColors.textMuted,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: IzyTelColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
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

class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.issue, required this.onTap});

  final AgentIssue issue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = _issueStatusColor(issue.status);
    final bool resolved = issue.status == 'resolved';
    final bool cancelled = issue.status == 'cancelled';
    final IconData icon = resolved
        ? Symbols.check_circle_rounded
        : cancelled
        ? Symbols.block_rounded
        : Symbols.warning_rounded;

    return IzyTelSurface(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(IzyTelRadii.card),
        child: Padding(
          padding: const EdgeInsets.all(IzyTelSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withAlpha(22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: IzyTelIconSize.action),
              ),
              const SizedBox(width: IzyTelSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            _issueTypeLabel(issue.type),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: IzyTelColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IzyTelStatusPill(
                          label: _issueStatusLabel(issue.status),
                          color: color,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      issue.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: IzyTelColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '${issue.network?.label ?? 'Tous réseaux'} • ${_formatDate(issue.createdAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: IzyTelColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Symbols.chevron_right_rounded,
                          size: 20,
                          color: IzyTelColors.textMuted,
                        ),
                      ],
                    ),
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

class _AgentIssueDetailSheet extends StatelessWidget {
  const _AgentIssueDetailSheet({required this.issue});

  final AgentIssue issue;

  @override
  Widget build(BuildContext context) {
    final bool resolved = issue.status == 'resolved';
    final bool cancelled = issue.status == 'cancelled';
    final Color statusColor = _issueStatusColor(issue.status);
    final DateTime? closingDate = issue.resolvedAt;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        decoration: const BoxDecoration(
          color: IzyTelColors.surface,
          borderRadius: BorderRadius.all(Radius.circular(IzyTelRadii.sheet)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(IzyTelSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Détail du signalement',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: IzyTelColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Symbols.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  IzyTelStatusPill(
                    label: _issueStatusLabel(issue.status),
                    color: statusColor,
                  ),
                  IzyTelStatusPill(
                    label: issue.network?.label ?? 'Tous réseaux',
                    color: IzyTelColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: IzyTelSpacing.lg),
              _DetailLine(label: 'Référence', value: issue.id),
              _DetailLine(label: 'Type', value: _issueTypeLabel(issue.type)),
              _DetailLine(
                label: 'Réseau',
                value: issue.network?.label ?? 'Tous réseaux',
              ),
              _DetailLine(
                label: 'Créé le',
                value: _formatDateTime(issue.createdAt),
              ),
              _DetailLine(
                label: 'Dernière mise à jour',
                value: _formatDateTime(issue.updatedAt ?? issue.createdAt),
              ),
              if (closingDate != null)
                _DetailLine(
                  label: resolved ? 'Résolu le' : 'Clôturé le',
                  value: _formatDateTime(closingDate),
                ),
              if ((resolved || cancelled) && issue.resolvedBy != null)
                _DetailLine(
                  label: resolved ? 'Résolu par' : 'Classé par',
                  value: issue.resolvedBy!,
                ),
              const SizedBox(height: 4),
              Text(
                'Description',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: IzyTelColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(IzyTelSpacing.md),
                decoration: BoxDecoration(
                  color: IzyTelColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: IzyTelColors.outline),
                ),
                child: Text(
                  issue.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: IzyTelColors.textPrimary,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: IzyTelSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: IzyTelSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: IzyTelColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          SelectableText(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: IzyTelColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentIssueEditorSheet extends StatefulWidget {
  const _AgentIssueEditorSheet();

  @override
  State<_AgentIssueEditorSheet> createState() => _AgentIssueEditorSheetState();
}

class _AgentIssueEditorSheetState extends State<_AgentIssueEditorSheet> {
  final TextEditingController _descriptionController = TextEditingController();
  String _type = 'network';
  AgentNetwork? _network;
  String? _errorText;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final String description = _descriptionController.text.trim();
    if (description.length < 3) {
      setState(() => _errorText = 'Décris le problème en quelques mots.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(
      AgentIssueDraft(type: _type, network: _network, description: description),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      fit: FlexFit.tight,
                      child: Text(
                        'Signaler un problème',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: IzyTelColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Symbols.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Choisis le type d’incident et décris la situation.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IzyTelColors.textSecondary,
                  ),
                ),
                const SizedBox(height: IzyTelSpacing.lg),
                const _FieldLabel('Type de problème'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _ChoiceChip(
                      label: 'Réseau',
                      selected: _type == 'network',
                      onTap: () => setState(() => _type = 'network'),
                    ),
                    _ChoiceChip(
                      label: 'Solde',
                      selected: _type == 'balance',
                      onTap: () => setState(() => _type = 'balance'),
                    ),
                    _ChoiceChip(
                      label: 'Technique',
                      selected: _type == 'technical',
                      onTap: () => setState(() => _type = 'technical'),
                    ),
                    _ChoiceChip(
                      label: 'Autre',
                      selected: _type == 'other',
                      onTap: () => setState(() => _type = 'other'),
                    ),
                  ],
                ),
                const SizedBox(height: IzyTelSpacing.md),
                const _FieldLabel('Réseau concerné'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _ChoiceChip(
                      label: 'Tous',
                      selected: _network == null,
                      onTap: () => setState(() => _network = null),
                    ),
                    for (final AgentNetwork network in AgentNetwork.values)
                      _ChoiceChip(
                        label: network.label,
                        selected: _network == network,
                        accent: _networkColor(network),
                        onTap: () => setState(() => _network = network),
                      ),
                  ],
                ),
                const SizedBox(height: IzyTelSpacing.md),
                const _FieldLabel('Description'),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  minLines: 4,
                  maxLines: 6,
                  onChanged: (_) {
                    if (_errorText != null) setState(() => _errorText = null);
                  },
                  decoration: InputDecoration(
                    hintText: 'Explique brièvement le problème rencontré…',
                    errorText: _errorText,
                  ),
                ),
                const SizedBox(height: IzyTelSpacing.lg),
                Row(
                  children: <Widget>[
                    Flexible(
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Annuler'),
                        ),
                      ),
                    ),
                    const SizedBox(width: IzyTelSpacing.sm),
                    Flexible(
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _submit,
                          child: const Text('Envoyer'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final Color color = accent ?? IzyTelColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(24) : IzyTelColors.surfaceMuted,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? color : IzyTelColors.outline),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? color : IzyTelColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

bool _isIssueActive(String status) =>
    status == 'open' || status == 'in_progress' || status == 'acknowledged';

Color _networkColor(AgentNetwork network) => switch (network) {
  AgentNetwork.orange => IzyTelColors.orange,
  AgentNetwork.mtn => IzyTelColors.mtnText,
  AgentNetwork.moov => IzyTelColors.moov,
};

Color _issueStatusColor(String status) => switch (status) {
  'resolved' => IzyTelColors.success,
  'cancelled' => IzyTelColors.error,
  'in_progress' || 'acknowledged' => IzyTelColors.primary,
  _ => IzyTelColors.warning,
};

String _issueTypeLabel(String type) => switch (type) {
  'network' => 'Problème réseau',
  'balance' => 'Solde insuffisant',
  'technical' => 'Problème technique',
  _ => 'Autre incident',
};

String _issueStatusLabel(String status) => switch (status) {
  'open' => 'Ouvert',
  'in_progress' => 'En cours',
  'acknowledged' => 'Pris en charge',
  'resolved' => 'Résolu',
  'cancelled' => 'Classé',
  _ => 'En cours',
};

String _formatDate(DateTime value) {
  final DateTime now = DateTime.now();
  final String time =
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  if (value.year == now.year &&
      value.month == now.month &&
      value.day == now.day) {
    return 'Aujourd’hui à $time';
  }
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} à $time';
}

String _formatDateTime(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year} à '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
