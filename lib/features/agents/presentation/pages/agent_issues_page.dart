import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class AgentIssuesPage extends StatelessWidget {
  const AgentIssuesPage({
    super.key,
    required this.agentId,
    required this.repository,
  });

  final String agentId;
  final AgentRepository repository;

  Future<void> _report(BuildContext context) async {
    final AgentIssueDraft? draft = await showModalBottomSheet<AgentIssueDraft>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AgentIssueEditorSheet(),
    );
    if (draft == null || !context.mounted) return;

    try {
      await repository.createIssue(agentId: agentId, issue: draft);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Signalement transmis à l’administration.'),
          ),
        );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Impossible d’envoyer le signalement.')),
        );
    }
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
        stream: repository.watchAgentIssues(agentId),
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
          final int openCount = issues
              .where((AgentIssue issue) => issue.status != 'resolved')
              .length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              IzyTelSpacing.lg,
              IzyTelSpacing.sm,
              IzyTelSpacing.lg,
              100,
            ),
            children: <Widget>[
              _IssueOverview(total: issues.length, open: openCount),
              const SizedBox(height: IzyTelSpacing.xl),
              const IzyTelSectionHeader(title: 'Historique'),
              const SizedBox(height: IzyTelSpacing.sm),
              if (issues.isEmpty)
                IzyTelSurface(
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
                        'Aucun signalement',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: IzyTelColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tu peux signaler ici un problème réseau, de solde ou un incident technique.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: IzyTelColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                )
              else
                IzyTelSurface(
                  padding: EdgeInsets.zero,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (int index = 0; index < issues.length; index++) ...[
                        _IssueRow(issue: issues[index]),
                        if (index < issues.length - 1) const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _report(context),
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

class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.issue});

  final AgentIssue issue;

  @override
  Widget build(BuildContext context) {
    final bool resolved = issue.status == 'resolved';
    final Color color = resolved ? IzyTelColors.success : IzyTelColors.warning;
    return Padding(
      padding: const EdgeInsets.all(IzyTelSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: resolved
                  ? IzyTelColors.successSoft
                  : IzyTelColors.warningSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              resolved ? Symbols.check_circle_rounded : Symbols.warning_rounded,
              color: color,
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
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        _issueTypeLabel(issue.type),
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
                      label: resolved ? 'Résolu' : 'En cours',
                      color: color,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  issue.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IzyTelColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${issue.network?.label ?? 'Tous réseaux'} • ${_formatDate(issue.createdAt)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: IzyTelColors.textMuted,
                    fontWeight: FontWeight.w500,
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

Color _networkColor(AgentNetwork network) => switch (network) {
  AgentNetwork.orange => IzyTelColors.orange,
  AgentNetwork.mtn => IzyTelColors.mtnText,
  AgentNetwork.moov => IzyTelColors.moov,
};

String _issueTypeLabel(String type) => switch (type) {
  'network' => 'Problème réseau',
  'balance' => 'Solde insuffisant',
  'technical' => 'Problème technique',
  _ => 'Autre incident',
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
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} à $time';
}
