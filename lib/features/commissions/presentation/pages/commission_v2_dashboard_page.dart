import 'package:cabine_flow/features/commissions/data/repositories/firestore_commission_v2_repository.dart';
import 'package:cabine_flow/features/commissions/domain/models/commission_v2_models.dart';
import 'package:cabine_flow/features/commissions/domain/repositories/commission_v2_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum CommissionV2Scope { agentSelf, adminAll, adminAgent }

class AgentCommissionsV2Page extends StatelessWidget {
  const AgentCommissionsV2Page({super.key, this.agentId, this.agentName});

  final String? agentId;
  final String? agentName;

  @override
  Widget build(BuildContext context) {
    final String? resolvedId = agentId ?? FirebaseAuth.instance.currentUser?.uid;
    if (resolvedId == null || resolvedId.trim().isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Aucune session Agent active.')),
      );
    }
    return CommissionV2DashboardPage(
      scope: CommissionV2Scope.agentSelf,
      agentId: resolvedId,
      agentName: agentName,
    );
  }
}

class AdminCommissionsV2Page extends StatelessWidget {
  const AdminCommissionsV2Page({super.key});

  @override
  Widget build(BuildContext context) {
    return const CommissionV2DashboardPage(scope: CommissionV2Scope.adminAll);
  }
}

class AdminAgentCommissionsV2Page extends StatelessWidget {
  const AdminAgentCommissionsV2Page({
    super.key,
    required this.agentId,
    this.agentName,
  });

  final String agentId;
  final String? agentName;

  @override
  Widget build(BuildContext context) {
    return CommissionV2DashboardPage(
      scope: CommissionV2Scope.adminAgent,
      agentId: agentId,
      agentName: agentName,
    );
  }
}

class CommissionV2DashboardPage extends StatefulWidget {
  const CommissionV2DashboardPage({
    super.key,
    required this.scope,
    this.agentId,
    this.agentName,
    this.repository,
  });

  final CommissionV2Scope scope;
  final String? agentId;
  final String? agentName;
  final CommissionV2Repository? repository;

  @override
  State<CommissionV2DashboardPage> createState() =>
      _CommissionV2DashboardPageState();
}

class _CommissionV2DashboardPageState extends State<CommissionV2DashboardPage> {
  late final CommissionV2Repository _repository;
  late Stream<CommissionV2Snapshot> _stream;
  late final TextEditingController _searchController;
  CommissionV2Filter _filter = const CommissionV2Filter();

  bool get _isAdmin => widget.scope != CommissionV2Scope.agentSelf;
  bool get _isGlobalAdmin => widget.scope == CommissionV2Scope.adminAll;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirestoreCommissionV2Repository();
    _searchController = TextEditingController();
    _stream = _resolveStream();
  }

  @override
  void didUpdateWidget(covariant CommissionV2DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope || oldWidget.agentId != widget.agentId) {
      _stream = _resolveStream();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<CommissionV2Snapshot> _resolveStream() {
    switch (widget.scope) {
      case CommissionV2Scope.agentSelf:
        return _repository.watchAgent(widget.agentId ?? '');
      case CommissionV2Scope.adminAll:
        return _repository.watchAdmin();
      case CommissionV2Scope.adminAgent:
        return _repository.watchAdminAgent(widget.agentId ?? '');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: Text(_pageTitle),
        backgroundColor: const Color(0xFFF6F8FC),
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<CommissionV2Snapshot>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(message: '${snapshot.error}');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final CommissionV2View view = snapshot.data!.apply(_filter);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: <Widget>[
              _HeaderCard(
                isAdmin: _isAdmin,
                isGlobalAdmin: _isGlobalAdmin,
                agentName: widget.agentName,
              ),
              const SizedBox(height: 14),
              _SearchField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _filter = _filter.copyWith(query: value);
                  });
                },
                onClear: () {
                  _searchController.clear();
                  setState(() {
                    _filter = _filter.copyWith(query: '');
                  });
                },
              ),
              const SizedBox(height: 12),
              _Filters(
                filter: _filter,
                showSettlement: _isAdmin,
                onChanged: (filter) => setState(() => _filter = filter),
                onReset: _resetFilters,
              ),
              const SizedBox(height: 18),
              _SectionHeader(
                title: 'Synthèse',
                trailing: _periodLabel(_filter.period),
              ),
              const SizedBox(height: 8),
              _MetricGrid(stats: view.stats),
              if (_filter.network != null) ...<Widget>[
                const SizedBox(height: 8),
                const _InfoBanner(
                  text:
                      'Les versements Wave actuels sont enregistrés au niveau du compte Agent, '
                      'sans ventilation par réseau. IzyTel n’invente donc pas de montant versé '
                      'Orange, MTN ou Moov.',
                ),
              ],
              const SizedBox(height: 18),
              const _SectionHeader(title: 'Répartition par réseau'),
              const SizedBox(height: 8),
              _NetworkBreakdown(stats: view.stats.networks),
              if (_isAdmin) ...<Widget>[
                const SizedBox(height: 18),
                _SectionHeader(
                  title: _isGlobalAdmin ? 'Comptes Agents' : 'Compte Agent',
                  trailing: '${view.accounts.length}',
                ),
                const SizedBox(height: 8),
                if (view.accounts.isEmpty)
                  const _EmptyCard(
                    message: 'Aucun compte de commission ne correspond aux filtres.',
                  )
                else
                  ...view.accounts.map(
                    (account) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _AccountCard(
                        account: account,
                        allowOpen: _isGlobalAdmin,
                        adminPerspective: true,
                        onOpen: _isGlobalAdmin
                            ? () => _openAgentAccount(account)
                            : null,
                      ),
                    ),
                  ),
              ] else ...<Widget>[
                const SizedBox(height: 18),
                const _SectionHeader(title: 'Mon compte'),
                const SizedBox(height: 8),
                if (view.accounts.isEmpty)
                  const _EmptyCard(
                    message:
                        'Aucun compte de commission n’existe encore. Il sera créé lors de la '
                        'première transaction réussie éligible.',
                  )
                else
                  _AccountCard(
                    account: view.accounts.first,
                    adminPerspective: false,
                  ),
              ],
              const SizedBox(height: 18),
              _SectionHeader(
                title: 'Historique complet',
                trailing: '${view.timeline.length} ligne(s)',
              ),
              const SizedBox(height: 8),
              if (_isAdmin)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: _InfoBanner(
                    text:
                        'D est une vue de contrôle et d’historique. Les nouveaux règlements '
                        'continuent d’être enregistrés depuis le flux de paiement de commissions '
                        'Admin déjà validé.',
                  ),
                ),
              if (view.timeline.isEmpty)
                const _EmptyCard(
                  message: 'Aucune commission ou versement ne correspond aux filtres.',
                )
              else
                ...view.timeline.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _HistoryCard(item: item, showAgent: _isAdmin),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String get _pageTitle {
    switch (widget.scope) {
      case CommissionV2Scope.agentSelf:
        return 'Mes commissions';
      case CommissionV2Scope.adminAll:
        return 'Commissions V2';
      case CommissionV2Scope.adminAgent:
        final String name = (widget.agentName ?? '').trim();
        return name.isEmpty ? 'Commissions Agent' : 'Commissions • $name';
    }
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _filter = const CommissionV2Filter();
    });
  }

  void _openAgentAccount(CommissionAccountV2 account) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminAgentCommissionsV2Page(
          agentId: account.agentId,
          agentName: account.agentName,
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.isAdmin,
    required this.isGlobalAdmin,
    this.agentName,
  });

  final bool isAdmin;
  final bool isGlobalAdmin;
  final String? agentName;

  @override
  Widget build(BuildContext context) {
    final String cleanName = (agentName ?? '').trim();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7EAF0)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Symbols.account_balance_wallet,
              color: Color(0xFF1565D8),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  isGlobalAdmin
                      ? 'Vue financière de toutes les commissions'
                      : cleanName.isNotEmpty
                      ? cleanName
                      : isAdmin
                      ? 'Vue de l’Agent'
                      : 'Mon historique financier',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF172033),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Données Firestore existantes : commissions, comptes et versements. '
                  'Aucune nouvelle comptabilité parallèle.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF687386),
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

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Référence, Agent, commande, montant…',
        prefixIcon: const Icon(Symbols.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Effacer',
                onPressed: onClear,
                icon: const Icon(Symbols.close),
              ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE4E8EF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE4E8EF)),
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.filter,
    required this.showSettlement,
    required this.onChanged,
    required this.onReset,
  });

  final CommissionV2Filter filter;
  final bool showSettlement;
  final ValueChanged<CommissionV2Filter> onChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _FilterRow(
          label: 'Période',
          children: CommissionV2Period.values.map((period) {
            return ChoiceChip(
              label: Text(_periodLabel(period)),
              selected: filter.period == period,
              onSelected: (_) => onChanged(filter.copyWith(period: period)),
            );
          }).toList(growable: false),
        ),
        const SizedBox(height: 8),
        _FilterRow(
          label: 'Réseau',
          children: <Widget>[
            ChoiceChip(
              label: const Text('Tous'),
              selected: filter.network == null,
              onSelected: (_) => onChanged(filter.copyWith(clearNetwork: true)),
            ),
            for (final String network in <String>['orange', 'mtn', 'moov'])
              ChoiceChip(
                label: Text(_networkLabel(network)),
                selected: filter.network == network,
                onSelected: (_) => onChanged(filter.copyWith(network: network)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _FilterRow(
          label: 'Historique',
          children: CommissionHistoryKind.values.map((kind) {
            return ChoiceChip(
              label: Text(_historyKindLabel(kind)),
              selected: filter.historyKind == kind,
              onSelected: (_) => onChanged(filter.copyWith(historyKind: kind)),
            );
          }).toList(growable: false),
        ),
        if (showSettlement) ...<Widget>[
          const SizedBox(height: 8),
          _FilterRow(
            label: 'Règlement Agent',
            children: CommissionSettlementState.values.map((state) {
              return ChoiceChip(
                label: Text(_settlementLabel(state)),
                selected: filter.settlementState == state,
                onSelected: (_) =>
                    onChanged(filter.copyWith(settlementState: state)),
              );
            }).toList(growable: false),
          ),
        ],
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onReset,
            icon: const Icon(Symbols.restart_alt, size: 18),
            label: const Text('Réinitialiser les filtres'),
          ),
        ),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xFF687386),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: children
                .map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: child,
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Flexible(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF172033),
            ),
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: 8),
          Text(
            trailing!,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF7B8494),
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.stats});

  final CommissionV2Stats stats;

  @override
  Widget build(BuildContext context) {
    final List<_MetricData> metrics = <_MetricData>[
      _MetricData(
        label: 'Généré',
        value: _formatCfa(stats.generatedAmount),
        icon: Symbols.add_card,
      ),
      _MetricData(
        label: 'Versé',
        value: stats.paidAmount == null ? '—' : _formatCfa(stats.paidAmount!),
        icon: Symbols.payments,
      ),
      _MetricData(
        label: 'Solde actuel',
        value: stats.currentOutstanding == null
            ? '—'
            : _formatCfa(stats.currentOutstanding!),
        icon: Symbols.account_balance_wallet,
      ),
      _MetricData(
        label: 'Transactions',
        value: '${stats.commissionCount}',
        icon: Symbols.receipt_long,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double gap = 10;
        final int columns = constraints.maxWidth >= 720 ? 4 : 2;
        final double width =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: width,
                  child: _MetricCard(data: metric),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(data.icon, size: 20, color: const Color(0xFF1565D8)),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              data.value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF172033),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF7B8494),
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkBreakdown extends StatelessWidget {
  const _NetworkBreakdown({required this.stats});

  final List<CommissionNetworkStatV2> stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int columns = constraints.maxWidth >= 660 ? 3 : 1;
        const double gap = 8;
        final double width =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: stats
              .map(
                (entry) => SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: const Color(0xFFE7EAF0)),
                    ),
                    child: Row(
                      children: <Widget>[
                        _NetworkDot(network: entry.network),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                _networkLabel(entry.network),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF172033),
                                ),
                              ),
                              Text(
                                '${entry.transactions} transaction(s)',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: const Color(0xFF7B8494)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatCfa(entry.amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF172033),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _NetworkDot extends StatelessWidget {
  const _NetworkDot({required this.network});

  final String network;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (network.toLowerCase()) {
      'orange' => const Color(0xFFF57C00),
      'mtn' => const Color(0xFFF3C900),
      'moov' => const Color(0xFF00A86B),
      _ => const Color(0xFF1565D8),
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.adminPerspective,
    this.allowOpen = false,
    this.onOpen,
  });

  final CommissionAccountV2 account;
  final bool adminPerspective;
  final bool allowOpen;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final Widget content = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Symbols.person, color: Color(0xFF1565D8), size: 21),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  account.agentName.trim().isEmpty
                      ? account.agentId
                      : account.agentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF172033),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SettlementPill(
                state: account.settlementState,
                adminPerspective: adminPerspective,
              ),
              if (allowOpen) ...<Widget>[
                const SizedBox(width: 4),
                const Icon(Symbols.chevron_right, size: 20),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: <Widget>[
              _InlineMetric(label: 'Acquis', value: _formatCfa(account.earnedTotal)),
              _InlineMetric(label: 'Versé', value: _formatCfa(account.paidTotal)),
              _InlineMetric(
                label: adminPerspective ? 'À payer' : 'À recevoir',
                value: _formatCfa(account.outstanding),
              ),
              _InlineMetric(
                label: 'Transactions',
                value: '${account.earnedTransactions}',
              ),
            ],
          ),
        ],
      ),
    );

    if (!allowOpen || onOpen == null) return content;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
      child: content,
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 104),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF172033),
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF7B8494),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettlementPill extends StatelessWidget {
  const _SettlementPill({
    required this.state,
    required this.adminPerspective,
  });

  final CommissionSettlementState state;
  final bool adminPerspective;

  @override
  Widget build(BuildContext context) {
    final (String label, Color background, Color foreground) = switch (state) {
      CommissionSettlementState.unpaid => (
        adminPerspective ? 'À payer' : 'À recevoir',
        const Color(0xFFFFF2E0),
        const Color(0xFF9A5700),
      ),
      CommissionSettlementState.partial => (
        'Partiel',
        const Color(0xFFFFF7D6),
        const Color(0xFF7D6200),
      ),
      CommissionSettlementState.paid => (
        'Payé',
        const Color(0xFFE8F7EE),
        const Color(0xFF167245),
      ),
      CommissionSettlementState.empty => (
        'Aucun gain',
        const Color(0xFFF0F2F5),
        const Color(0xFF687386),
      ),
      CommissionSettlementState.all => (
        'Tous',
        const Color(0xFFEAF2FF),
        const Color(0xFF1565D8),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item, required this.showAgent});

  final CommissionHistoryItemV2 item;
  final bool showAgent;

  @override
  Widget build(BuildContext context) {
    final bool isCommission = item.kind == CommissionHistoryKind.commissions;
    final Color accent = isCommission
        ? const Color(0xFF167245)
        : const Color(0xFF1565D8);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7EAF0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withAlpha(23),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCommission ? Symbols.add_card : Symbols.payments,
              size: 20,
              color: accent,
            ),
          ),
          const SizedBox(width: 11),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF172033),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${isCommission ? '+' : '-'}${_formatCfa(item.amount)}',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.reference.isEmpty ? 'Sans référence' : item.reference,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (showAgent && item.agentName.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    item.agentName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF687386),
                    ),
                  ),
                ],
                if ((item.network ?? '').isNotEmpty ||
                    (item.subtitle ?? '').isNotEmpty) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    <String>[
                      if ((item.network ?? '').isNotEmpty)
                        _networkLabel(item.network!),
                      if ((item.subtitle ?? '').isNotEmpty) item.subtitle!,
                    ].join(' • '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF7B8494),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  _formatDateTime(item.date),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF8A93A2),
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

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Symbols.info, color: Color(0xFF1565D8), size: 19),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF3E5E8C),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7EAF0)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF7B8494),
        ),
      ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Symbols.error, size: 38, color: Color(0xFFC43D3D)),
            const SizedBox(height: 10),
            const Text(
              'Impossible de charger les commissions.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

String _periodLabel(CommissionV2Period period) {
  return switch (period) {
    CommissionV2Period.all => 'Tout',
    CommissionV2Period.today => 'Aujourd’hui',
    CommissionV2Period.last7Days => '7 jours',
    CommissionV2Period.thisMonth => 'Ce mois',
  };
}

String _historyKindLabel(CommissionHistoryKind kind) {
  return switch (kind) {
    CommissionHistoryKind.all => 'Tout',
    CommissionHistoryKind.commissions => 'Commissions',
    CommissionHistoryKind.payouts => 'Versements',
  };
}

String _settlementLabel(CommissionSettlementState state) {
  return switch (state) {
    CommissionSettlementState.all => 'Tous',
    CommissionSettlementState.unpaid => 'À payer',
    CommissionSettlementState.partial => 'Partiels',
    CommissionSettlementState.paid => 'Payés',
    CommissionSettlementState.empty => 'Sans gain',
  };
}

String _networkLabel(String network) {
  return switch (network.toLowerCase()) {
    'orange' => 'Orange',
    'mtn' => 'MTN',
    'moov' => 'Moov',
    _ => network,
  };
}

String _formatCfa(int value) {
  final String digits = value.abs().toString();
  final StringBuffer buffer = StringBuffer();
  for (int index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(' ');
    }
    buffer.write(digits[index]);
  }
  final String sign = value < 0 ? '-' : '';
  return '$sign${buffer.toString()} F';
}

String _formatDateTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} à '
      '${two(value.hour)}:${two(value.minute)}';
}
