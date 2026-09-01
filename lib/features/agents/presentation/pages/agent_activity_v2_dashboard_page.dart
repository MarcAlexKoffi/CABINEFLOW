import 'package:cabine_flow/features/agents/data/repositories/firestore_agent_activity_v2_repository.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_activity_v2_models.dart';
import 'package:flutter/material.dart';

class AgentActivityV2DashboardPage extends StatefulWidget {
  AgentActivityV2DashboardPage({
    super.key,
    required this.agentId,
    this.agentName,
    this.adminMode = false,
    FirestoreAgentActivityV2Repository? repository,
  }) : repository = repository ?? FirestoreAgentActivityV2Repository();

  final String agentId;
  final String? agentName;
  final bool adminMode;
  final FirestoreAgentActivityV2Repository repository;

  @override
  State<AgentActivityV2DashboardPage> createState() =>
      _AgentActivityV2DashboardPageState();
}

class _AgentActivityV2DashboardPageState
    extends State<AgentActivityV2DashboardPage> {
  late Stream<AgentActivityV2Snapshot> _activityStream;

  @override
  void initState() {
    super.initState();
    _activityStream = widget.repository.watchAgentActivity(widget.agentId);
  }

  @override
  void didUpdateWidget(covariant AgentActivityV2DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.agentId != widget.agentId ||
        oldWidget.repository != widget.repository) {
      _activityStream = widget.repository.watchAgentActivity(widget.agentId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.adminMode ? 'Activité de l’Agent' : 'Mon activité détaillée',
        ),
      ),
      body: StreamBuilder<AgentActivityV2Snapshot>(
        stream: _activityStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(message: '${snapshot.error}');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final AgentActivityV2Snapshot data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: <Widget>[
              _Header(
                name: widget.agentName,
                adminMode: widget.adminMode,
                profile: data.operationalProfile,
              ),
              const SizedBox(height: 16),
              const _SectionTitle(
                title: 'Performance',
                trailing: 'Données réelles',
              ),
              const SizedBox(height: 8),
              _PerformanceGrid(data: data),
              const SizedBox(height: 20),
              const _SectionTitle(
                title: 'Capacités actuelles',
                trailing: 'Profil 9E',
              ),
              const SizedBox(height: 8),
              _CapacityCard(profile: data.operationalProfile),
              const SizedBox(height: 20),
              _SectionTitle(
                title: 'Commissions',
                trailing: '${data.commissionTransactionCount} transaction(s)',
              ),
              const SizedBox(height: 8),
              _CommissionSummary(data: data),
              const SizedBox(height: 10),
              if (data.commissions.isEmpty)
                const _EmptyCard(text: 'Aucune commission enregistrée.')
              else
                ...data.commissions.take(8).map(_CommissionCard.new),
              const SizedBox(height: 20),
              _SectionTitle(
                title: 'Versements de commissions',
                trailing: _formatCfa(data.commissionPaid),
              ),
              const SizedBox(height: 8),
              if (data.payouts.isEmpty)
                const _EmptyCard(text: 'Aucun versement enregistré.')
              else
                ...data.payouts.take(8).map(_PayoutCard.new),
              const SizedBox(height: 20),
              _SectionTitle(
                title: 'Mouvements & recharges',
                trailing: 'Recharges ${_formatCfa(data.rechargeAmount)}',
              ),
              const SizedBox(height: 8),
              if (data.movements.isEmpty)
                const _EmptyCard(text: 'Aucun mouvement réseau disponible.')
              else
                ...data.movements.take(12).map(_MovementCard.new),
              const SizedBox(height: 20),
              _SectionTitle(
                title: 'Signalements',
                trailing: '${data.openIssueCount} en cours',
              ),
              const SizedBox(height: 8),
              if (data.issues.isEmpty)
                const _EmptyCard(text: 'Aucun signalement pour cet Agent.')
              else
                ...data.issues.take(10).map(_IssueCard.new),
              const SizedBox(height: 20),
              _SectionTitle(
                title: 'Dernières commandes',
                trailing: '${data.orders.length} au total',
              ),
              const SizedBox(height: 8),
              if (data.orders.isEmpty)
                const _EmptyCard(text: 'Aucune commande affectée à cet Agent.')
              else
                ...data.orders.take(12).map(_OrderCard.new),
              if (data.orders.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _AgentOrderHistoryV2Page(
                          orders: data.orders,
                          agentName: widget.agentName,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('Voir l’historique complet'),
                ),
              ],
              const SizedBox(height: 20),
              _SectionTitle(
                title: 'Affectations refusées',
                trailing: '${data.refusedCount}',
              ),
              const SizedBox(height: 8),
              if (data.assignments.where((item) => item.isRefused).isEmpty)
                const _EmptyCard(text: 'Aucun refus enregistré.')
              else
                ...data.assignments
                    .where((item) => item.isRefused)
                    .take(10)
                    .map(_RefusalCard.new),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.adminMode,
    required this.profile,
  });

  final String? name;
  final bool adminMode;
  final AgentOperationalSnapshotV2? profile;

  @override
  Widget build(BuildContext context) {
    final String cleanName = (name ?? '').trim();
    final String code = profile?.agentCode ?? '';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (cleanName.isNotEmpty)
              Text(
                cleanName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (cleanName.isNotEmpty) const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                if (code.isNotEmpty) _ChipLabel(text: code),
                _ChipLabel(
                  text: _availabilityLabel(profile?.availability ?? ''),
                ),
                if (adminMode) const _ChipLabel(text: 'Vue Admin'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Synthèse en lecture seule construite depuis les commandes, '
              'affectations, capacités, commissions, versements, mouvements '
              'et signalements déjà enregistrés.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(text, style: Theme.of(context).textTheme.labelMedium),
      ),
    );
  }
}

class _PerformanceGrid extends StatelessWidget {
  const _PerformanceGrid({required this.data});

  final AgentActivityV2Snapshot data;

  @override
  Widget build(BuildContext context) {
    final Duration? average = data.averageProcessingDuration;
    final List<(String, String, IconData)> items = <(String, String, IconData)>[
      ('Réussies', '${data.successfulCount}', Icons.check_circle_outline),
      ('Échouées', '${data.failedCount}', Icons.error_outline),
      ('En cours', '${data.activeCount}', Icons.timelapse),
      ('Refusées', '${data.refusedCount}', Icons.undo_rounded),
      (
        'Montant traité',
        _formatCfa(data.successfulAmount),
        Icons.payments_outlined,
      ),
      ('Temps moyen', _formatDuration(average), Icons.schedule),
    ];
    return _ResponsiveCards(
      children: items
          .map(
            (item) =>
                _MetricCard(label: item.$1, value: item.$2, icon: item.$3),
          )
          .toList(growable: false),
    );
  }
}

class _CapacityCard extends StatelessWidget {
  const _CapacityCard({required this.profile});

  final AgentOperationalSnapshotV2? profile;

  @override
  Widget build(BuildContext context) {
    final AgentOperationalSnapshotV2? value = profile;
    if (value == null) {
      return const _EmptyCard(text: 'Profil opérationnel Agent indisponible.');
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _ResponsiveCards(
              preferredColumns: 3,
              children: <Widget>[
                _NetworkCapacity(
                  network: 'Orange',
                  capacity: value.orangeCapacity,
                  active: value.isNetworkActive('orange'),
                ),
                _NetworkCapacity(
                  network: 'MTN',
                  capacity: value.mtnCapacity,
                  active: value.isNetworkActive('mtn'),
                ),
                _NetworkCapacity(
                  network: 'Moov Africa',
                  capacity: value.moovCapacity,
                  active: value.isNetworkActive('moov'),
                ),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: <Widget>[
                Text(
                  'Limite jour : ${_formatCfa(value.dailyTransactionLimit)}',
                ),
                Text('Max transactions/jour : ${value.maxTransactionsPerDay}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkCapacity extends StatelessWidget {
  const _NetworkCapacity({
    required this.network,
    required this.capacity,
    required this.active,
  });

  final String network;
  final int capacity;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                active
                    ? Icons.check_circle_outline
                    : Icons.pause_circle_outline,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  network,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(_formatCfa(capacity)),
          Text(
            active ? 'Actif' : 'Inactif',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CommissionSummary extends StatelessWidget {
  const _CommissionSummary({required this.data});

  final AgentActivityV2Snapshot data;

  @override
  Widget build(BuildContext context) {
    return _ResponsiveCards(
      children: <Widget>[
        _MetricCard(
          label: 'Total acquis',
          value: _formatCfa(data.commissionEarned),
          icon: Icons.savings_outlined,
        ),
        _MetricCard(
          label: 'Déjà versé',
          value: _formatCfa(data.commissionPaid),
          icon: Icons.account_balance_wallet_outlined,
        ),
        _MetricCard(
          label: 'Solde à verser',
          value: _formatCfa(data.commissionOutstanding),
          icon: Icons.payments_outlined,
        ),
      ],
    );
  }
}

class _ResponsiveCards extends StatelessWidget {
  const _ResponsiveCards({required this.children, this.preferredColumns});

  final List<Widget> children;
  final int? preferredColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns;
        if (constraints.maxWidth >= 760) {
          columns = preferredColumns ?? 3;
        } else if (constraints.maxWidth >= 430) {
          columns = 2;
        } else {
          columns = 1;
        }
        if (columns < 1) columns = 1;
        final double width =
            (constraints.maxWidth - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(growable: false),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 22),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommissionCard extends StatelessWidget {
  const _CommissionCard(this.commission);

  final AgentCommissionV2 commission;

  @override
  Widget build(BuildContext context) {
    final String reference = commission.orderReference.isEmpty
        ? commission.orderId
        : commission.orderReference;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.add_circle_outline),
        title: Text(
          reference,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${_networkLabel(commission.network)} • commande ${_formatCfa(commission.orderAmount)}'
          '${_dateSuffix(commission.earnedAt)}',
        ),
        trailing: Text(
          '+${_formatCfa(commission.commissionAmount)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _PayoutCard extends StatelessWidget {
  const _PayoutCard(this.payout);

  final AgentCommissionPayoutV2 payout;

  @override
  Widget build(BuildContext context) {
    final String reference = payout.paymentReference.isEmpty
        ? 'Référence non renseignée'
        : payout.paymentReference;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.account_balance_wallet_outlined),
        title: Text(
          _formatCfa(payout.amount),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${payout.paymentChannel.toUpperCase()} • $reference'
          '${_dateSuffix(payout.paidAt)}'
          '${payout.note == null ? '' : '\n${payout.note}'}',
        ),
      ),
    );
  }
}

class _MovementCard extends StatelessWidget {
  const _MovementCard(this.movement);

  final AgentNetworkMovementV2 movement;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(movement.isRecharge ? Icons.add_card : Icons.swap_horiz),
        title: Text(
          movement.isRecharge
              ? 'Recharge ${_networkLabel(movement.network)}'
              : _movementLabel(movement.type),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${_formatCfa(movement.signedAmount)} • '
          'capacité ${_formatCfa(movement.capacityBefore)} → '
          '${_formatCfa(movement.capacityAfter)}${_dateSuffix(movement.createdAt)}',
        ),
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard(this.issue);

  final AgentIssueSnapshotV2 issue;

  @override
  Widget build(BuildContext context) {
    final String network = issue.network == null
        ? 'Tous réseaux'
        : _networkLabel(issue.network!);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          issue.isOpen ? Icons.report_problem_outlined : Icons.task_alt,
        ),
        title: Text(
          _issueTypeLabel(issue.type),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${issue.description}\n$network • ${_issueStatusLabel(issue.status)}'
          '${_dateSuffix(issue.createdAt)}',
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _AgentOrderHistoryV2Page extends StatelessWidget {
  const _AgentOrderHistoryV2Page({
    required this.orders,
    required this.agentName,
  });

  final List<AgentActivityOrderV2> orders;
  final String? agentName;

  @override
  Widget build(BuildContext context) {
    final String cleanName = (agentName ?? '').trim();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          cleanName.isEmpty
              ? 'Historique des commandes'
              : 'Historique • $cleanName',
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        itemCount: orders.length,
        itemBuilder: (context, index) => _OrderCard(orders[index]),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard(this.order);

  final AgentActivityOrderV2 order;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        isThreeLine: true,
        leading: Icon(_orderIcon(order)),
        title: Text(
          order.reference,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${_networkLabel(order.network)} • ${_formatCfa(order.amount)}\n'
          '${_statusLabel(order.status)}'
          '${_dateSuffix(order.completedAt ?? order.assignedAt)}',
        ),
      ),
    );
  }
}

class _RefusalCard extends StatelessWidget {
  const _RefusalCard(this.assignment);

  final AgentActivityAssignmentV2 assignment;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.undo_rounded),
        title: Text(
          assignment.orderReference.isEmpty
              ? assignment.orderId
              : assignment.orderReference,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${assignment.refusalReason ?? 'Motif non renseigné'}'
          '${_dateSuffix(assignment.refusedAt)}',
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final Text titleWidget = Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        );
        final Text trailingWidget = Text(
          trailing,
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.bodySmall,
        );
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              titleWidget,
              const SizedBox(height: 2),
              trailingWidget,
            ],
          );
        }
        return Row(
          children: <Widget>[
            Flexible(flex: 3, child: titleWidget),
            const SizedBox(width: 8),
            Flexible(flex: 2, child: trailingWidget),
          ],
        );
      },
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(padding: const EdgeInsets.all(16), child: Text(text)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Impossible de charger l’activité.\n$message',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

IconData _orderIcon(AgentActivityOrderV2 order) {
  if (order.isSuccessful) return Icons.check_circle_outline;
  if (order.isFailed) return Icons.error_outline;
  return Icons.timelapse;
}

String _availabilityLabel(String value) => switch (value) {
  'available' => 'Disponible',
  'unavailable' => 'Indisponible',
  _ => 'Disponibilité inconnue',
};

String _networkLabel(String value) => switch (value.toLowerCase()) {
  'orange' => 'Orange',
  'mtn' => 'MTN',
  'moov' => 'Moov Africa',
  _ => value.isEmpty ? 'Réseau' : value,
};

String _statusLabel(String value) => switch (value) {
  'completed' || 'awaitingCustomerConfirmation' => 'Réussie',
  'failed' => 'Échouée',
  'inProgress' => 'En cours',
  'onHold' => 'En attente',
  'paidReady' => 'À traiter',
  _ => value,
};

String _movementLabel(String value) => switch (value) {
  'orderSuccess' => 'Débit transaction',
  'supplierRecharge' => 'Recharge fournisseur',
  'manualAdjustment' => 'Ajustement manuel',
  _ => value.isEmpty ? 'Mouvement réseau' : value,
};

String _issueTypeLabel(String value) => switch (value) {
  'network' => 'Incident réseau',
  'balance' => 'Solde / capacité',
  'technical' => 'Incident technique',
  'other' => 'Autre signalement',
  _ => 'Signalement',
};

String _issueStatusLabel(String value) => switch (value) {
  'open' => 'Ouvert',
  'acknowledged' => 'Pris en compte',
  'resolved' => 'Résolu',
  'cancelled' => 'Annulé',
  _ => value.isEmpty ? 'Statut inconnu' : value,
};

String _formatCfa(int value) {
  final String raw = value.abs().toString();
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(raw[i]);
  }
  return '${value < 0 ? '-' : ''}${buffer.toString()} F';
}

String _formatDuration(Duration? duration) {
  if (duration == null) return '—';
  if (duration.inHours > 0) {
    return '${duration.inHours} h ${duration.inMinutes.remainder(60)} min';
  }
  if (duration.inMinutes > 0) {
    return '${duration.inMinutes} min ${duration.inSeconds.remainder(60)} s';
  }
  return '${duration.inSeconds} s';
}

String _dateSuffix(DateTime? date) {
  if (date == null) return '';
  String two(int value) => value.toString().padLeft(2, '0');
  return '\n${two(date.day)}/${two(date.month)}/${date.year} '
      '${two(date.hour)}:${two(date.minute)}';
}
