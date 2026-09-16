import 'dart:async';

import 'package:cabine_flow/backoffice/domain/models/backoffice_finance_snapshot.dart';
import 'package:cabine_flow/backoffice/domain/repositories/backoffice_finance_repository.dart';
import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_order_widgets.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/permissions/user_permissions.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Les dix sous-modules officiels du bloc BO-5.
enum BackofficeFinanceModule {
  overview,
  waveCash,
  commissions,
  suppliers,
  customerCredits,
  expenses,
  workingCapital,
  reconciliations,
  movements,
  closings,
}

extension BackofficeFinanceModuleX on BackofficeFinanceModule {
  String get title {
    switch (this) {
      case BackofficeFinanceModule.overview:
        return 'Vue financière';
      case BackofficeFinanceModule.waveCash:
        return 'Caisse Wave';
      case BackofficeFinanceModule.commissions:
        return 'Commissions';
      case BackofficeFinanceModule.suppliers:
        return 'Fournisseurs';
      case BackofficeFinanceModule.customerCredits:
        return 'Crédits clients';
      case BackofficeFinanceModule.expenses:
        return 'Dépenses';
      case BackofficeFinanceModule.workingCapital:
        return 'Fonds de roulement';
      case BackofficeFinanceModule.reconciliations:
        return 'Rapprochements';
      case BackofficeFinanceModule.movements:
        return 'Mouvements';
      case BackofficeFinanceModule.closings:
        return 'Clôtures';
    }
  }

  String get description {
    switch (this) {
      case BackofficeFinanceModule.overview:
        return 'Position financière opérationnelle IzyTel en temps réel : encaissements, dettes, capacités et sorties.';
      case BackofficeFinanceModule.waveCash:
        return 'Contrôle de la caisse Wave, du solde d’ouverture et des flux théoriques de la journée.';
      case BackofficeFinanceModule.commissions:
        return 'Suivi des commissions acquises, déjà payées et restant dues à chaque Agent.';
      case BackofficeFinanceModule.suppliers:
        return 'Registre fournisseurs, approvisionnements Agent et règlements fournisseurs.';
      case BackofficeFinanceModule.customerCredits:
        return 'Suivi des ventes à crédit et des remboursements partiels ou complets des clients.';
      case BackofficeFinanceModule.expenses:
        return 'Charges opérationnelles IzyTel avec canal de paiement, référence et traçabilité.';
      case BackofficeFinanceModule.workingCapital:
        return 'Capacités Orange, MTN et Moov disponibles chez les Agents et engagements financiers associés.';
      case BackofficeFinanceModule.reconciliations:
        return 'Contrôles croisés entre commandes, paiements, remboursements, fournisseurs, commissions et clôtures.';
      case BackofficeFinanceModule.movements:
        return 'Journal financier consolidé des mouvements de capacités et des flux monétaires.';
      case BackofficeFinanceModule.closings:
        return 'Photographie quotidienne immuable des soldes, flux, dettes, capacités et écarts Wave.';
    }
  }

  IconData get icon {
    switch (this) {
      case BackofficeFinanceModule.overview:
        return Symbols.account_balance_wallet_rounded;
      case BackofficeFinanceModule.waveCash:
        return Symbols.account_balance_rounded;
      case BackofficeFinanceModule.commissions:
        return Symbols.savings_rounded;
      case BackofficeFinanceModule.suppliers:
        return Symbols.storefront_rounded;
      case BackofficeFinanceModule.customerCredits:
        return Symbols.request_quote_rounded;
      case BackofficeFinanceModule.expenses:
        return Symbols.receipt_rounded;
      case BackofficeFinanceModule.workingCapital:
        return Symbols.toll_rounded;
      case BackofficeFinanceModule.reconciliations:
        return Symbols.rule_rounded;
      case BackofficeFinanceModule.movements:
        return Symbols.swap_horiz_rounded;
      case BackofficeFinanceModule.closings:
        return Symbols.event_available_rounded;
    }
  }
}

class BackofficeFinancePage extends StatefulWidget {
  const BackofficeFinancePage({
    super.key,
    required this.user,
    required this.repository,
    required this.ordersRepository,
    required this.module,
  });

  final AppUser user;
  final BackofficeFinanceRepository repository;
  final OrdersRepository ordersRepository;
  final BackofficeFinanceModule module;

  @override
  State<BackofficeFinancePage> createState() => _BackofficeFinancePageState();
}

class _BackofficeFinancePageState extends State<BackofficeFinancePage> {
  late Stream<BackofficeFinanceSnapshot> _stream;
  bool _busy = false;

  bool get _canManage => widget.user.permissions.canManageFinanceSettings;

  @override
  void initState() {
    super.initState();
    _stream = widget.repository.watchSnapshot();
  }

  @override
  void didUpdateWidget(covariant BackofficeFinancePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _stream = widget.repository.watchSnapshot();
    }
  }

  void _reload() {
    setState(() => _stream = widget.repository.watchSnapshot());
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    required String success,
  }) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) {
        return;
      }
      IzyTelFeedback.success(context, success);
      _reload();
    } catch (error) {
      if (!mounted) {
        return;
      }
      IzyTelFeedback.error(context, _financeError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BackofficeFinanceSnapshot>(
      stream: _stream,
      builder: (BuildContext context, AsyncSnapshot<BackofficeFinanceSnapshot> async) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
            BackofficePageIntro(
              eyebrow: 'BO-5 · FINANCES',
              title: widget.module.title,
              description: widget.module.description,
              icon: widget.module.icon,
              trailing: OutlinedButton.icon(
                onPressed: _busy ? null : _reload,
                icon: const Icon(Symbols.refresh_rounded),
                label: const Text('Actualiser'),
              ),
            ),
            const SizedBox(height: 18),
            if (!_canManage)
              _readOnlyBanner()
            else
              _canonicalBanner(),
            const SizedBox(height: 16),
            if (async.connectionState == ConnectionState.waiting && !async.hasData)
              const _FinanceLoading()
            else if (async.hasError && !async.hasData)
              _FinanceErrorState(onRetry: _reload)
            else if (async.data case final BackofficeFinanceSnapshot snapshot)
              _moduleBody(snapshot)
            else
              _FinanceErrorState(onRetry: _reload),
            ],
          ),
        );
      },
    );
  }

  Widget _canonicalBanner() {
    return _InfoBanner(
      icon: Symbols.database_rounded,
      color: BackofficePalette.success,
      text:
          'Supabase est la source canonique BO-5. Les actions financières sont journalisées et les autres écrans se rafraîchissent via finance_change_feed.',
    );
  }

  Widget _readOnlyBanner() {
    return const _InfoBanner(
      icon: Symbols.visibility_rounded,
      color: BackofficePalette.warning,
      text:
          'Mode consultation Manager : les soldes et mouvements sont visibles, mais les écritures financières restent réservées à l’Administrateur.',
    );
  }

  Widget _moduleBody(BackofficeFinanceSnapshot snapshot) {
    switch (widget.module) {
      case BackofficeFinanceModule.overview:
        return _overview(snapshot);
      case BackofficeFinanceModule.waveCash:
        return _wave(snapshot);
      case BackofficeFinanceModule.commissions:
        return _commissions(snapshot);
      case BackofficeFinanceModule.suppliers:
        return _suppliers(snapshot);
      case BackofficeFinanceModule.customerCredits:
        return _credits(snapshot);
      case BackofficeFinanceModule.expenses:
        return _expenses(snapshot);
      case BackofficeFinanceModule.workingCapital:
        return _workingCapital(snapshot);
      case BackofficeFinanceModule.reconciliations:
        return _reconciliations(snapshot);
      case BackofficeFinanceModule.movements:
        return _movements(snapshot);
      case BackofficeFinanceModule.closings:
        return _closings(snapshot);
    }
  }

  Widget _overview(BackofficeFinanceSnapshot s) {
    final DateTime today = DateTime.now();
    final int receipts = s.confirmedReceiptsOn(today) + s.creditSettlementsOn(today);
    final int theoreticalWave = s.waveTheoreticalBalanceOn(today);
    final int expenses = s.expensesOn(today);
    final int refunds = s.refundsOn(today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _metricGrid(<Widget>[
          BackofficeMetricCard(
            label: 'Encaissements jour',
            value: formatCfa(receipts),
            caption: 'paiements + remboursements crédits',
            icon: Symbols.payments_rounded,
            emphasis: BackofficePalette.success,
          ),
          BackofficeMetricCard(
            label: 'Wave théorique',
            value: formatCfa(theoreticalWave),
            caption: 'solde après flux Wave du jour',
            icon: Symbols.account_balance_rounded,
            emphasis: BackofficePalette.primary,
          ),
          BackofficeMetricCard(
            label: 'Créances clients',
            value: formatCfa(s.customerReceivables),
            caption: 'crédits restant à encaisser',
            icon: Symbols.request_quote_rounded,
            emphasis: s.customerReceivables > 0 ? BackofficePalette.warning : BackofficePalette.success,
          ),
          BackofficeMetricCard(
            label: 'Dette fournisseurs',
            value: formatCfa(s.supplierDebt),
            caption: 'reste à régler',
            icon: Symbols.storefront_rounded,
            emphasis: s.supplierDebt > 0 ? BackofficePalette.warning : BackofficePalette.success,
          ),
          BackofficeMetricCard(
            label: 'Commissions dues',
            value: formatCfa(s.commissionDebt),
            caption: 'Agents à payer',
            icon: Symbols.savings_rounded,
            emphasis: s.commissionDebt > 0 ? BackofficePalette.warning : BackofficePalette.success,
          ),
          BackofficeMetricCard(
            label: 'Capacité disponible',
            value: formatCfa(s.totalAvailableCapacity),
            caption: 'Orange + MTN + Moov',
            icon: Symbols.toll_rounded,
            emphasis: BackofficePalette.cyan,
          ),
          BackofficeMetricCard(
            label: 'Dépenses jour',
            value: formatCfa(expenses),
            caption: 'charges enregistrées',
            icon: Symbols.receipt_rounded,
            emphasis: BackofficePalette.danger,
          ),
          BackofficeMetricCard(
            label: 'Remboursements jour',
            value: formatCfa(refunds),
            caption: 'remboursements clients exécutés',
            icon: Symbols.currency_exchange_rounded,
            emphasis: refunds > 0 ? BackofficePalette.warning : BackofficePalette.success,
          ),
        ]),
        const SizedBox(height: 18),
        _section(
          title: 'Synthèse réseau',
          subtitle: 'Capacité télécom disponible chez les Agents.',
          child: _networkCapacityCards(s),
        ),
        const SizedBox(height: 18),
        _section(
          title: 'État de contrôle',
          subtitle: 'Points qui doivent attirer l’attention avant une clôture.',
          child: _reconciliationSummary(s),
        ),
      ],
    );
  }

  Widget _wave(BackofficeFinanceSnapshot s) {
    final int incoming = s.waveIncomingSinceOpening;
    final int outgoing = s.waveOutgoingSinceOpening;
    final int theoretical = s.waveTheoreticalBalance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _metricGrid(<Widget>[
          BackofficeMetricCard(
            label: 'Solde ouverture',
            value: formatCfa(s.openingWaveBalance),
            caption: 'base actuelle de caisse',
            icon: Symbols.account_balance_wallet_rounded,
          ),
          BackofficeMetricCard(
            label: 'Entrées Wave',
            value: formatCfa(incoming),
            caption: 'depuis le solde d’ouverture',
            icon: Symbols.south_west_rounded,
            emphasis: BackofficePalette.success,
          ),
          BackofficeMetricCard(
            label: 'Sorties Wave',
            value: formatCfa(outgoing),
            caption: 'depuis le solde d’ouverture',
            icon: Symbols.north_east_rounded,
            emphasis: BackofficePalette.danger,
          ),
          BackofficeMetricCard(
            label: 'Solde théorique',
            value: formatCfa(theoretical),
            caption: 'ouverture + entrées - sorties',
            icon: Symbols.calculate_rounded,
            emphasis: BackofficePalette.cyan,
          ),
        ]),
        const SizedBox(height: 16),
        if (!s.hasWaveOpening) ...<Widget>[
          const _InfoBanner(
            icon: Symbols.warning_rounded,
            color: BackofficePalette.warning,
            text:
                'Initialise le solde Wave avant toute clôture. Le solde théorique ne peut être fiable sans point de départ réel.',
          ),
          const SizedBox(height: 14),
        ],
        if (_canManage)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _showWaveOpeningDialog(s),
              icon: const Icon(Symbols.edit_rounded),
              label: const Text('Définir le solde d’ouverture'),
            ),
          ),
        const SizedBox(height: 18),
        _section(
          title: 'Historique des ajustements',
          subtitle: 'Chaque changement de solde d’ouverture est conservé.',
          child: _simpleRows(
            s.waveAdjustments,
            emptyTitle: 'Aucun ajustement Wave',
            emptyMessage: 'Le premier ajustement apparaîtra ici.',
            builder: (Map<String, dynamic> row) => _FinanceListTile(
              icon: Symbols.account_balance_rounded,
              title: '${formatCfa(financeInt(row['previous_opening_balance']))} → ${formatCfa(financeInt(row['opening_balance']))}',
              subtitle: financeString(row['note']).isEmpty ? 'Aucune note' : financeString(row['note']),
              trailing: _dateLabel(financeDate(row['effective_at'])),
            ),
          ),
        ),
      ],
    );
  }

  Widget _commissions(BackofficeFinanceSnapshot s) {
    final int earned = s.commissionAccounts.fold<int>(0, (int t, Map<String, dynamic> r) => t + financeInt(r['earned_total']));
    final int paid = s.commissionAccounts.fold<int>(0, (int t, Map<String, dynamic> r) => t + financeInt(r['paid_total']));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _metricGrid(<Widget>[
          BackofficeMetricCard(label: 'Acquises', value: formatCfa(earned), caption: 'commissions cumulées', icon: Symbols.trending_up_rounded, emphasis: BackofficePalette.success),
          BackofficeMetricCard(label: 'Payées', value: formatCfa(paid), caption: 'règlements cumulés', icon: Symbols.payments_rounded),
          BackofficeMetricCard(label: 'À payer', value: formatCfa(s.commissionDebt), caption: 'solde Agents', icon: Symbols.savings_rounded, emphasis: s.commissionDebt > 0 ? BackofficePalette.warning : BackofficePalette.success),
          BackofficeMetricCard(label: 'Transactions', value: '${s.commissionAccounts.fold<int>(0, (int t, Map<String, dynamic> r) => t + financeInt(r['earned_transactions']))}', caption: 'ayant généré une commission', icon: Symbols.receipt_long_rounded, emphasis: BackofficePalette.cyan),
        ]),
        const SizedBox(height: 18),
        _section(
          title: 'Comptes Agents',
          subtitle: 'Solde calculé depuis le ledger Phase 5.',
          child: _simpleRows(
            s.commissionAccounts,
            emptyTitle: 'Aucun compte commission',
            emptyMessage: 'Les commissions apparaîtront après les transactions éligibles.',
            builder: (Map<String, dynamic> row) {
              final int balance = financeInt(row['earned_total']) - financeInt(row['paid_total']);
              return _FinanceListTile(
                icon: Symbols.badge_rounded,
                title: financeString(row['agent_name']).isEmpty ? 'Agent' : financeString(row['agent_name']),
                subtitle: '${financeInt(row['earned_transactions'])} transaction(s) · acquis ${formatCfa(financeInt(row['earned_total']))} · payé ${formatCfa(financeInt(row['paid_total']))}',
                trailing: formatCfa(balance),
                action: _canManage && balance > 0
                    ? TextButton(
                        onPressed: _busy ? null : () => _showCommissionPayoutDialog(row, balance),
                        child: const Text('Payer'),
                      )
                    : null,
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        _section(
          title: 'Derniers paiements',
          subtitle: 'Historique des versements de commissions.',
          child: _simpleRows(
            s.commissionPayouts,
            emptyTitle: 'Aucun paiement de commission',
            emptyMessage: 'Les règlements Agents seront listés ici.',
            builder: (Map<String, dynamic> row) => _FinanceListTile(
              icon: Symbols.payments_rounded,
              title: '${financeString(row['agent_name'])} · ${formatCfa(financeInt(row['amount']))}',
              subtitle: 'Réf. ${financeString(row['payment_reference'])}',
              trailing: _dateLabel(financeDate(row['paid_at'])),
            ),
          ),
        ),
      ],
    );
  }

  Widget _suppliers(BackofficeFinanceSnapshot s) {
    final Map<String, Map<String, dynamic>> accounts = <String, Map<String, dynamic>>{
      for (final Map<String, dynamic> row in s.supplierAccounts) financeString(row['supplier_id']): row,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _metricGrid(<Widget>[
          BackofficeMetricCard(label: 'Fournisseurs', value: '${s.suppliers.length}', caption: 'registre actif + suspendu', icon: Symbols.storefront_rounded),
          BackofficeMetricCard(label: 'Dette totale', value: formatCfa(s.supplierDebt), caption: 'reste à régler', icon: Symbols.account_balance_wallet_rounded, emphasis: s.supplierDebt > 0 ? BackofficePalette.warning : BackofficePalette.success),
          BackofficeMetricCard(label: 'Approvisionnements', value: '${s.supplierRecharges.length}', caption: 'recharges enregistrées', icon: Symbols.add_card_rounded, emphasis: BackofficePalette.cyan),
        ]),
        const SizedBox(height: 14),
        if (_canManage)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.icon(onPressed: _busy ? null : () => _showSupplierDialog(), icon: const Icon(Symbols.add_rounded), label: const Text('Nouveau fournisseur')),
              OutlinedButton.icon(onPressed: _busy || s.suppliers.where((Map<String, dynamic> r) => r['is_active'] == true).isEmpty ? null : () => _showSupplierRechargeDialog(s), icon: const Icon(Symbols.add_card_rounded), label: const Text('Approvisionner un Agent')),
              OutlinedButton.icon(onPressed: _busy || s.suppliers.isEmpty ? null : () => _showSupplierPaymentDialog(s), icon: const Icon(Symbols.payments_rounded), label: const Text('Régler un fournisseur')),
            ],
          ),
        const SizedBox(height: 18),
        _section(
          title: 'Registre fournisseurs',
          subtitle: 'La suppression est logique : tout fournisseur ayant un historique financier reste auditable.',
          child: _simpleRows(
            s.suppliers,
            emptyTitle: 'Aucun fournisseur',
            emptyMessage: 'Ajoute le premier fournisseur pour enregistrer les approvisionnements.',
            builder: (Map<String, dynamic> row) {
              final String id = financeString(row['id']);
              final Map<String, dynamic>? account = accounts[id];
              final int debt = account == null ? 0 : financeInt(account['total_owed']) - financeInt(account['total_paid']);
              final bool active = row['is_active'] == true;
              return _FinanceListTile(
                icon: Symbols.storefront_rounded,
                title: financeString(row['name']),
                subtitle: '${financeString(row['phone_number']).isEmpty ? 'Sans téléphone' : financeString(row['phone_number'])} · dette ${formatCfa(debt)} · ${active ? 'actif' : 'suspendu'}',
                trailing: active ? 'Actif' : 'Suspendu',
                action: _canManage
                    ? PopupMenuButton<String>(
                        tooltip: 'Actions fournisseur',
                        onSelected: (String value) async {
                          if (value == 'edit') {
                            await _showSupplierDialog(row: row);
                          } else if (value == 'toggle') {
                            await _runAction(
                              () => widget.repository.setSupplierActive(supplierId: id, isActive: !active),
                              success: active ? 'Fournisseur suspendu.' : 'Fournisseur réactivé.',
                            );
                          } else if (value == 'delete') {
                            await _confirmDeleteSupplier(id, financeString(row['name']));
                          }
                        },
                        itemBuilder: (_) => <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(value: 'edit', child: Text('Modifier')),
                          PopupMenuItem<String>(value: 'toggle', child: Text(active ? 'Suspendre' : 'Réactiver')),
                          const PopupMenuItem<String>(value: 'delete', child: Text('Retirer du registre')),
                        ],
                      )
                    : null,
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        _section(
          title: 'Approvisionnements récents',
          subtitle: 'Principal, bonus reçu et montant dû au fournisseur.',
          child: _simpleRows(
            s.supplierRecharges.take(20).toList(growable: false),
            emptyTitle: 'Aucun approvisionnement',
            emptyMessage: 'Les approvisionnements Agents apparaîtront ici.',
            builder: (Map<String, dynamic> row) => _FinanceListTile(
              icon: Symbols.add_card_rounded,
              title: '${financeString(row['agent_name'])} · ${_networkLabel(financeString(row['network']))}',
              subtitle: '${financeString(row['supplier_name'])} · principal ${formatCfa(financeInt(row['principal_amount']))} · bonus ${formatCfa(financeInt(row['bonus_amount']))}',
              trailing: _dateLabel(financeDate(row['occurred_at'])),
            ),
          ),
        ),
      ],
    );
  }

  Widget _credits(BackofficeFinanceSnapshot s) {
    final int openCount = s.credits.where((Map<String, dynamic> row) => financeString(row['status']) != 'settled').length;
    final int paid = s.credits.fold<int>(0, (int t, Map<String, dynamic> r) => t + financeInt(r['paid_amount']));
    final int granted = s.credits.fold<int>(0, (int t, Map<String, dynamic> r) => t + financeInt(r['amount']));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _metricGrid(<Widget>[
          BackofficeMetricCard(label: 'Crédits accordés', value: formatCfa(granted), caption: '${s.credits.length} dossier(s)', icon: Symbols.request_quote_rounded),
          BackofficeMetricCard(label: 'Remboursé', value: formatCfa(paid), caption: 'encaissements sur crédits', icon: Symbols.payments_rounded, emphasis: BackofficePalette.success),
          BackofficeMetricCard(label: 'Reste à payer', value: formatCfa(s.customerReceivables), caption: '$openCount dossier(s) ouvert(s)', icon: Symbols.pending_actions_rounded, emphasis: s.customerReceivables > 0 ? BackofficePalette.warning : BackofficePalette.success),
        ]),
        const SizedBox(height: 14),
        if (_canManage)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _showCreateCreditDialog(s),
              icon: const Icon(Symbols.add_rounded),
              label: const Text('Autoriser un crédit'),
            ),
          ),
        const SizedBox(height: 18),
        _section(
          title: 'Dossiers de crédit',
          subtitle: 'Le reste à payer est recalculé après chaque remboursement.',
          child: _simpleRows(
            s.credits,
            emptyTitle: 'Aucun crédit client',
            emptyMessage: 'Aucune commande n’est actuellement enregistrée à crédit.',
            builder: (Map<String, dynamic> row) {
              final int amount = financeInt(row['amount']);
              final int paidAmount = financeInt(row['paid_amount']);
              final int balance = amount - paidAmount;
              final String status = financeString(row['status']);
              return _FinanceListTile(
                icon: Symbols.person_rounded,
                title: '${financeString(row['client_name'])} · ${formatCfa(balance)} restant',
                subtitle: '${financeString(row['order_reference'])} · accordé ${formatCfa(amount)} · remboursé ${formatCfa(paidAmount)} · ${_creditStatusLabel(status)}',
                trailing: _dateLabel(financeDate(row['updated_at'])),
                action: _canManage && balance > 0
                    ? TextButton(
                        onPressed: _busy ? null : () => _showCreditSettlementDialog(row, balance),
                        child: const Text('Encaisser'),
                      )
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _expenses(BackofficeFinanceSnapshot s) {
    final DateTime today = DateTime.now();
    final int todayTotal = s.expensesOn(today);
    final int total = s.expenses.fold<int>(0, (int t, Map<String, dynamic> r) => t + financeInt(r['amount']));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _metricGrid(<Widget>[
          BackofficeMetricCard(label: 'Dépenses du jour', value: formatCfa(todayTotal), caption: 'tous canaux', icon: Symbols.receipt_rounded, emphasis: BackofficePalette.danger),
          BackofficeMetricCard(label: 'Historique chargé', value: formatCfa(total), caption: '${s.expenses.length} dépense(s)', icon: Symbols.history_rounded),
          BackofficeMetricCard(label: 'Sorties Wave jour', value: formatCfa(s.expensesOn(today, channel: 'wave')), caption: 'charges payées via Wave', icon: Symbols.account_balance_rounded, emphasis: BackofficePalette.warning),
        ]),
        const SizedBox(height: 14),
        if (_canManage)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(onPressed: _busy ? null : _showExpenseDialog, icon: const Icon(Symbols.add_rounded), label: const Text('Enregistrer une dépense')),
          ),
        const SizedBox(height: 18),
        _section(
          title: 'Journal des dépenses',
          subtitle: 'Les dépenses ne sont jamais écrasées : chaque saisie reste traçable.',
          child: _simpleRows(
            s.expenses,
            emptyTitle: 'Aucune dépense enregistrée',
            emptyMessage: 'Les charges IzyTel seront affichées ici.',
            builder: (Map<String, dynamic> row) => _FinanceListTile(
              icon: Symbols.receipt_rounded,
              title: '${_expenseCategoryLabel(financeString(row['category']))} · ${formatCfa(financeInt(row['amount']))}',
              subtitle: '${financeString(row['description'])} · ${_channelLabel(financeString(row['payment_channel']))}${financeString(row['payment_reference']).isEmpty ? '' : ' · réf. ${financeString(row['payment_reference'])}'}',
              trailing: _dateLabel(financeDate(row['spent_at'])),
            ),
          ),
        ),
      ],
    );
  }

  Widget _workingCapital(BackofficeFinanceSnapshot s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _networkCapacityCards(s),
        const SizedBox(height: 18),
        _metricGrid(<Widget>[
          BackofficeMetricCard(
            label: 'Wave théorique',
            value: formatCfa(s.waveTheoreticalBalance),
            caption: s.hasWaveOpening
                ? 'trésorerie Wave calculée'
                : 'solde d’ouverture à initialiser',
            icon: Symbols.account_balance_wallet_rounded,
            emphasis: s.hasWaveOpening
                ? BackofficePalette.success
                : BackofficePalette.warning,
          ),
          BackofficeMetricCard(
            label: 'Capacité disponible',
            value: formatCfa(s.totalAvailableCapacity),
            caption: 'stock télécom chez les Agents',
            icon: Symbols.toll_rounded,
            emphasis: BackofficePalette.cyan,
          ),
          BackofficeMetricCard(
            label: 'Capacité engagée',
            value: formatCfa(s.totalCommittedCapacity),
            caption: 'commandes financées affectées',
            icon: Symbols.lock_clock_rounded,
            emphasis: s.totalCommittedCapacity > 0
                ? BackofficePalette.warning
                : BackofficePalette.success,
          ),
          BackofficeMetricCard(
            label: 'Capacité libre',
            value: formatCfa(s.totalFreeCapacity),
            caption: 'disponible après engagements',
            icon: Symbols.inventory_2_rounded,
            emphasis: BackofficePalette.cyan,
          ),
          BackofficeMetricCard(
            label: 'Liquidité opérationnelle',
            value: formatCfa(s.operatingLiquidity),
            caption: 'Wave théorique + capacité libre',
            icon: Symbols.account_balance_rounded,
          ),
          BackofficeMetricCard(
            label: 'Créances clients',
            value: formatCfa(s.customerReceivables),
            caption: 'crédits restant à encaisser',
            icon: Symbols.request_quote_rounded,
            emphasis: s.customerReceivables > 0
                ? BackofficePalette.warning
                : BackofficePalette.success,
          ),
          BackofficeMetricCard(
            label: 'Dette fournisseurs',
            value: formatCfa(s.supplierDebt),
            caption: 'approvisionnements à régler',
            icon: Symbols.storefront_rounded,
            emphasis: s.supplierDebt > 0
                ? BackofficePalette.warning
                : BackofficePalette.success,
          ),
          BackofficeMetricCard(
            label: 'Commissions dues',
            value: formatCfa(s.commissionDebt),
            caption: 'passif Agents',
            icon: Symbols.savings_rounded,
          ),
          BackofficeMetricCard(
            label: 'Fonds net estimé',
            value: formatCfa(s.netWorkingCapital),
            caption: 'liquidité + créances - dettes',
            icon: Symbols.monitoring_rounded,
            emphasis: s.netWorkingCapital >= 0
                ? BackofficePalette.success
                : BackofficePalette.danger,
          ),
        ]),
        const SizedBox(height: 18),
        _section(
          title: 'Capacité par Agent',
          subtitle:
              'Disponibilités réellement suivies par Supabase Phase 5. Les engagements sont consolidés au niveau réseau.',
          child: _simpleRows(
            s.agentCapacities,
            emptyTitle: 'Aucune capacité Agent',
            emptyMessage:
                'Les capacités apparaîtront après initialisation des Agents.',
            builder: (Map<String, dynamic> row) => _FinanceListTile(
              icon: Symbols.badge_rounded,
              title: financeString(row['agent_name']),
              subtitle:
                  'Orange ${formatCfa(financeInt(row['orange_capacity']))} · MTN ${formatCfa(financeInt(row['mtn_capacity']))} · Moov ${formatCfa(financeInt(row['moov_capacity']))}',
              trailing: formatCfa(
                financeInt(row['orange_capacity']) +
                    financeInt(row['mtn_capacity']) +
                    financeInt(row['moov_capacity']),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _reconciliations(BackofficeFinanceSnapshot s) {
    final List<_FinanceCheck> checks = _financeChecks(s);
    final int anomalies = checks.where((_FinanceCheck item) => !item.ok).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _metricGrid(<Widget>[
          BackofficeMetricCard(label: 'Contrôles', value: '${checks.length}', caption: 'règles de cohérence', icon: Symbols.rule_rounded),
          BackofficeMetricCard(label: 'Anomalies', value: '$anomalies', caption: anomalies == 0 ? 'aucun écart détecté' : 'à examiner', icon: anomalies == 0 ? Symbols.check_circle_rounded : Symbols.warning_rounded, emphasis: anomalies == 0 ? BackofficePalette.success : BackofficePalette.danger),
          BackofficeMetricCard(label: 'Paiements Phase 5', value: '${s.orderPayments.length}', caption: 'lignes rapprochées', icon: Symbols.payments_rounded, emphasis: BackofficePalette.cyan),
          BackofficeMetricCard(label: 'Remboursements', value: '${s.refunds.length}', caption: 'dossiers financiers', icon: Symbols.currency_exchange_rounded),
        ]),
        const SizedBox(height: 18),
        _section(
          title: 'Matrice de contrôle',
          subtitle: 'Les contrôles sont calculés à partir du snapshot canonique Supabase.',
          child: Column(
            children: <Widget>[
              for (int index = 0; index < checks.length; index++) ...<Widget>[
                _FinanceCheckTile(check: checks[index]),
                if (index < checks.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        _section(
          title: 'Clôtures avec écart Wave',
          subtitle: 'Toute différence de caisse doit rester justifiée.',
          child: _simpleRows(
            s.closings.where((Map<String, dynamic> row) => financeInt(row['wave_difference']) != 0).toList(growable: false),
            emptyTitle: 'Aucun écart de clôture',
            emptyMessage: 'Les clôtures enregistrées ne présentent actuellement aucun écart Wave.',
            builder: (Map<String, dynamic> row) => _FinanceListTile(
              icon: Symbols.warning_rounded,
              title: '${financeString(row['date_key'])} · écart ${formatCfa(financeInt(row['wave_difference']))}',
              subtitle: financeString(row['wave_difference_note']).isEmpty ? 'Justification absente' : financeString(row['wave_difference_note']),
              trailing: financeString(row['closed_by_name']),
            ),
          ),
        ),
      ],
    );
  }

  Widget _movements(BackofficeFinanceSnapshot s) {
    final List<_FinanceMovement> movements = _buildMovements(s);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _metricGrid(<Widget>[
          BackofficeMetricCard(label: 'Mouvements', value: '${movements.length}', caption: 'snapshot consolidé', icon: Symbols.swap_horiz_rounded),
          BackofficeMetricCard(label: 'Capacité réseau', value: '${s.networkMovements.length}', caption: 'entrées / sorties télécom', icon: Symbols.toll_rounded, emphasis: BackofficePalette.cyan),
          BackofficeMetricCard(label: 'Événements ledger', value: '${s.ledgerEvents.length}', caption: 'journal Phase 5', icon: Symbols.receipt_long_rounded),
        ]),
        const SizedBox(height: 18),
        _section(
          title: 'Journal consolidé',
          subtitle: 'Les 150 mouvements les plus récents, toutes sources financières confondues.',
          child: movements.isEmpty
              ? const BackofficeEmptyState(icon: Symbols.history_rounded, title: 'Aucun mouvement', message: 'Les mouvements financiers apparaîtront ici.')
              : Column(
                  children: <Widget>[
                    for (int index = 0; index < movements.length && index < 150; index++) ...<Widget>[
                      _FinanceListTile(
                        icon: movements[index].icon,
                        title: movements[index].title,
                        subtitle: movements[index].subtitle,
                        trailing: _dateLabel(movements[index].at),
                      ),
                      if (index < movements.length - 1 && index < 149) const Divider(height: 1),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _closings(BackofficeFinanceSnapshot s) {
    final DateTime today = DateTime.now();
    final String key = _dateKey(today);
    final bool alreadyClosed = s.closings.any((Map<String, dynamic> row) => financeString(row['date_key']) == key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _metricGrid(<Widget>[
          BackofficeMetricCard(label: 'Clôtures', value: '${s.closings.length}', caption: 'journées figées', icon: Symbols.event_available_rounded),
          BackofficeMetricCard(label: 'Aujourd’hui', value: alreadyClosed ? 'Clôturé' : 'Ouvert', caption: key, icon: alreadyClosed ? Symbols.lock_rounded : Symbols.lock_open_rounded, emphasis: alreadyClosed ? BackofficePalette.success : BackofficePalette.warning),
          BackofficeMetricCard(label: 'Wave théorique', value: formatCfa(s.waveTheoreticalBalanceOn(today)), caption: 'avant clôture', icon: Symbols.account_balance_rounded, emphasis: BackofficePalette.cyan),
          BackofficeMetricCard(label: 'Résultat indicatif', value: formatCfa(s.estimatedOperationalResultOn(today)), caption: 'marge stock estimée - charges - commissions', icon: Symbols.monitoring_rounded),
        ]),
        const SizedBox(height: 14),
        if (_canManage && !alreadyClosed)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(onPressed: _busy ? null : () => _showClosingDialog(s), icon: const Icon(Symbols.lock_rounded), label: const Text('Clôturer la journée')),
          ),
        const SizedBox(height: 18),
        _section(
          title: 'Historique des clôtures',
          subtitle: 'Une journée clôturée devient un snapshot d’audit et n’est pas modifiée par les écrans BO-5.',
          child: _simpleRows(
            s.closings,
            emptyTitle: 'Aucune clôture',
            emptyMessage: 'La première clôture journalière apparaîtra ici.',
            builder: (Map<String, dynamic> row) {
              final int difference = financeInt(row['wave_difference']);
              return _FinanceListTile(
                icon: difference == 0 ? Symbols.check_circle_rounded : Symbols.warning_rounded,
                title: '${financeString(row['date_key'])} · Wave réel ${formatCfa(financeInt(row['wave_actual_balance']))}',
                subtitle: 'théorique ${formatCfa(financeInt(row['wave_theoretical_balance']))} · écart ${formatCfa(difference)} · résultat indicatif ${formatCfa(financeInt(row['estimated_profit']))}',
                trailing: financeString(row['closed_by_name']),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _networkCapacityCards(BackofficeFinanceSnapshot s) {
    Widget card(String network, String label, Color color) {
      final int available = s.capacityFor(network);
      final int committed = s.committedFor(network);
      final int free = s.freeCapacityFor(network);
      return BackofficeMetricCard(
        label: label,
        value: formatCfa(free),
        caption:
            'libre · stock ${formatCfa(available)} · engagé ${formatCfa(committed)}',
        icon: Symbols.signal_cellular_alt_rounded,
        emphasis: color,
      );
    }

    return _metricGrid(<Widget>[
      card('orange', 'Orange', const Color(0xFFF97316)),
      card('mtn', 'MTN', const Color(0xFFD4A000)),
      card('moov', 'Moov', const Color(0xFF2563EB)),
    ]);
  }

  Widget _metricGrid(List<Widget> cards) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 1180 ? 4 : constraints.maxWidth >= 760 ? 2 : 1;
        const double gap = 10;
        final double width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards.map((Widget card) => SizedBox(width: width, child: card)).toList(growable: false),
        );
      },
    );
  }

  Widget _section({required String title, required String subtitle, required Widget child}) {
    return Container(
      decoration: backofficePanelDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 3),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }

  Widget _simpleRows(
    List<Map<String, dynamic>> rows, {
    required String emptyTitle,
    required String emptyMessage,
    required Widget Function(Map<String, dynamic> row) builder,
  }) {
    if (rows.isEmpty) {
      return BackofficeEmptyState(icon: Symbols.inbox_rounded, title: emptyTitle, message: emptyMessage);
    }
    return Column(
      children: <Widget>[
        for (int index = 0; index < rows.length; index++) ...<Widget>[
          builder(rows[index]),
          if (index < rows.length - 1) const Divider(height: 1),
        ],
      ],
    );
  }

  Widget _reconciliationSummary(BackofficeFinanceSnapshot s) {
    final List<_FinanceCheck> checks = _financeChecks(s);
    return Column(
      children: <Widget>[
        for (int index = 0; index < checks.length; index++) ...<Widget>[
          _FinanceCheckTile(check: checks[index]),
          if (index < checks.length - 1) const Divider(height: 1),
        ],
      ],
    );
  }

  List<_FinanceCheck> _financeChecks(BackofficeFinanceSnapshot s) {
    final Set<String> orderIds = s.orders
        .map((Map<String, dynamic> row) => financeString(row['order_id']))
        .where((String id) => id.isNotEmpty)
        .toSet();
    final Set<String> paymentIds = s.orderPayments
        .map((Map<String, dynamic> row) => financeString(row['order_id']))
        .where((String id) => id.isNotEmpty)
        .toSet();
    final DateTime? canonicalOrderCutoff = s.orders
        .map((Map<String, dynamic> row) => financeDate(row['created_at']))
        .whereType<DateTime>()
        .fold<DateTime?>(
          null,
          (DateTime? earliest, DateTime value) =>
              earliest == null || value.isBefore(earliest) ? value : earliest,
        );
    final List<Map<String, dynamic>> unmatchedPayments = s.orderPayments
        .where((Map<String, dynamic> row) =>
            !orderIds.contains(financeString(row['order_id'])))
        .toList(growable: false);
    final int legacyPayments = unmatchedPayments.where((Map<String, dynamic> row) {
      final DateTime? createdAt = financeDate(row['created_at']);
      return canonicalOrderCutoff != null &&
          createdAt != null &&
          createdAt.isBefore(canonicalOrderCutoff);
    }).length;
    final int orphanPayments = unmatchedPayments.length - legacyPayments;
    final int confirmedWithoutLedger = s.orders.where((Map<String, dynamic> row) {
      return financeString(row['payment_status']) == 'confirmed' &&
          !paymentIds.contains(financeString(row['order_id']));
    }).length;
    final Map<String, Map<String, dynamic>> orderById =
        <String, Map<String, dynamic>>{
          for (final Map<String, dynamic> row in s.orders)
            financeString(row['order_id']): row,
        };
    final int creditMismatch = s.credits.where((Map<String, dynamic> row) {
      final Map<String, dynamic>? order =
          orderById[financeString(row['order_id'])];
      return order == null ||
          financeString(order['payment_status']) != 'credit' ||
          financeInt(order['amount']) != financeInt(row['amount']) ||
          financeString(order['order_reference']).toUpperCase() !=
              financeString(row['order_reference']).toUpperCase();
    }).length;
    final List<Map<String, dynamic>> completedRefunds = s.refunds.where((Map<String, dynamic> row) {
      final String status = financeString(row['status']);
      return status == 'refunded' || status == 'reconciled';
    }).toList(growable: false);
    final int legacyRefundsWithoutCanonicalOrder = completedRefunds.where((Map<String, dynamic> row) {
      final String orderId = financeString(row['order_id']);
      return !orderById.containsKey(orderId) &&
          financeString(row['legacy_firestore_id']).isNotEmpty;
    }).length;
    final int refundedMismatch = completedRefunds.where((Map<String, dynamic> row) {
      final String orderId = financeString(row['order_id']);
      final Map<String, dynamic>? order = orderById[orderId];
      if (order == null) {
        return financeString(row['legacy_firestore_id']).isEmpty;
      }
      return financeString(order['order_status']) != 'refunded';
    }).length;
    final Set<String> supplierIds = s.suppliers
        .map((Map<String, dynamic> row) => financeString(row['id']))
        .where((String id) => id.isNotEmpty)
        .toSet();
    final int orphanSupplierAccounts = s.supplierAccounts.where((Map<String, dynamic> row) {
      return !supplierIds.contains(financeString(row['supplier_id']));
    }).length;
    final int supplierNegative = s.supplierAccounts.where((Map<String, dynamic> row) {
      return financeInt(row['total_paid']) > financeInt(row['total_owed']);
    }).length;
    final int commissionNegative = s.commissionAccounts.where((Map<String, dynamic> row) {
      return financeInt(row['paid_total']) > financeInt(row['earned_total']);
    }).length;
    final int negativeCapacity = s.agentCapacities.where((Map<String, dynamic> row) {
      return financeInt(row['orange_capacity']) < 0 ||
          financeInt(row['mtn_capacity']) < 0 ||
          financeInt(row['moov_capacity']) < 0;
    }).length;
    final int closingDifferences = s.closings.where((Map<String, dynamic> row) {
      return financeInt(row['wave_difference']) != 0;
    }).length;
    final int unjustifiedClosingDifferences = s.closings.where((Map<String, dynamic> row) {
      return financeInt(row['wave_difference']) != 0 &&
          financeString(row['wave_difference_note']).length < 3;
    }).length;

    return <_FinanceCheck>[
      _FinanceCheck(
        ok: s.hasWaveOpening,
        title: 'Point de départ de caisse Wave',
        detail: s.hasWaveOpening
            ? 'Solde d’ouverture défini au ${_dateLabel(s.waveOpeningEffectiveAt)}'
            : 'Aucun solde d’ouverture : la caisse théorique et les clôtures ne doivent pas être validées.',
      ),
      _FinanceCheck(
        ok: orphanPayments == 0,
        title: 'Paiements rattachés aux commandes',
        detail: orphanPayments == 0
            ? legacyPayments == 0
                ? '${s.orderPayments.length} paiement(s) rattaché(s)'
                : '${s.orderPayments.length - legacyPayments} paiement(s) courant(s) rattaché(s) · $legacyPayments historique(s) pré-Phase 4 conservé(s)'
            : '$orphanPayments paiement(s) courant(s) sans commande canonique · $legacyPayments historique(s) pré-Phase 4 ignoré(s)',
      ),
      _FinanceCheck(
        ok: confirmedWithoutLedger == 0,
        title: 'Commandes confirmées présentes au ledger paiement',
        detail: confirmedWithoutLedger == 0
            ? 'Aucune commande confirmée manquante'
            : '$confirmedWithoutLedger commande(s) à rapprocher',
      ),
      _FinanceCheck(
        ok: creditMismatch == 0,
        title: 'Crédits reliés à la commande canonique',
        detail: creditMismatch == 0
            ? '${s.credits.length} dossier(s) cohérent(s)'
            : '$creditMismatch crédit(s) avec commande, montant ou statut incohérent',
      ),
      _FinanceCheck(
        ok: refundedMismatch == 0,
        title: 'Remboursements cohérents avec les commandes',
        detail: refundedMismatch == 0
            ? legacyRefundsWithoutCanonicalOrder == 0
                ? 'Statuts commande / remboursement cohérents'
                : 'Statuts courants cohérents · $legacyRefundsWithoutCanonicalOrder remboursement(s) legacy sans commande Phase 4 conservé(s)'
            : '$refundedMismatch remboursement(s) courant(s) avec commande ou statut incohérent · $legacyRefundsWithoutCanonicalOrder legacy ignoré(s)',
      ),
      _FinanceCheck(
        ok: orphanSupplierAccounts == 0,
        title: 'Comptes rattachés aux fournisseurs',
        detail: orphanSupplierAccounts == 0
            ? '${s.supplierAccounts.length} compte(s) fournisseur rattaché(s)'
            : '$orphanSupplierAccounts compte(s) sans fournisseur dans le registre BO-5',
      ),
      _FinanceCheck(
        ok: supplierNegative == 0,
        title: 'Soldes fournisseurs',
        detail: supplierNegative == 0
            ? 'Aucun surpaiement fournisseur détecté'
            : '$supplierNegative compte(s) avec paiement supérieur au dû',
      ),
      _FinanceCheck(
        ok: commissionNegative == 0,
        title: 'Soldes commissions',
        detail: commissionNegative == 0
            ? 'Aucun surpaiement Agent détecté'
            : '$commissionNegative compte(s) Agent incohérent(s)',
      ),
      _FinanceCheck(
        ok: negativeCapacity == 0,
        title: 'Capacités réseau',
        detail: negativeCapacity == 0
            ? 'Aucune capacité Agent négative'
            : '$negativeCapacity ligne(s) de capacité négative à examiner',
      ),
      _FinanceCheck(
        ok: unjustifiedClosingDifferences == 0,
        title: 'Écarts Wave historiques',
        detail: unjustifiedClosingDifferences == 0
            ? closingDifferences == 0
                ? 'Toutes les clôtures sont équilibrées'
                : '$closingDifferences clôture(s) avec écart, toutes justifiées'
            : '$unjustifiedClosingDifferences clôture(s) avec écart sans justification suffisante',
      ),
    ];
  }

  List<_FinanceMovement> _buildMovements(BackofficeFinanceSnapshot s) {
    final List<_FinanceMovement> values = <_FinanceMovement>[];
    for (final Map<String, dynamic> row in s.networkMovements) {
      final bool incoming = financeString(row['direction']) == 'incoming';
      values.add(_FinanceMovement(
        at: financeDate(row['occurred_at']),
        icon: incoming ? Symbols.south_west_rounded : Symbols.north_east_rounded,
        title: '${incoming ? 'Entrée' : 'Sortie'} capacité ${_networkLabel(financeString(row['network']))} · ${formatCfa(financeInt(row['amount']))}',
        subtitle: '${financeString(row['agent_name'])} · ${_movementTypeLabel(financeString(row['movement_type']))}',
      ));
    }
    for (final Map<String, dynamic> row in s.supplierPayments) {
      values.add(_FinanceMovement(at: financeDate(row['paid_at']), icon: Symbols.storefront_rounded, title: 'Paiement fournisseur · ${formatCfa(financeInt(row['amount']))}', subtitle: '${financeString(row['supplier_name'])} · ${_channelLabel(financeString(row['payment_channel']))}'));
    }
    for (final Map<String, dynamic> row in s.commissionPayouts) {
      values.add(_FinanceMovement(at: financeDate(row['paid_at']), icon: Symbols.savings_rounded, title: 'Commission Agent · ${formatCfa(financeInt(row['amount']))}', subtitle: '${financeString(row['agent_name'])} · réf. ${financeString(row['payment_reference'])}'));
    }
    for (final Map<String, dynamic> row in s.creditSettlements) {
      values.add(_FinanceMovement(at: financeDate(row['paid_at']), icon: Symbols.request_quote_rounded, title: 'Remboursement crédit · ${formatCfa(financeInt(row['amount']))}', subtitle: '${financeString(row['client_name'])} · ${_channelLabel(financeString(row['payment_channel']))}'));
    }
    for (final Map<String, dynamic> row in s.expenses) {
      values.add(_FinanceMovement(at: financeDate(row['spent_at']), icon: Symbols.receipt_rounded, title: 'Dépense · ${formatCfa(financeInt(row['amount']))}', subtitle: '${_expenseCategoryLabel(financeString(row['category']))} · ${financeString(row['description'])}'));
    }
    for (final Map<String, dynamic> row in s.refunds) {
      final DateTime? at = financeDate(row['refunded_at']);
      if (at == null) {
        continue;
      }
      values.add(_FinanceMovement(at: at, icon: Symbols.currency_exchange_rounded, title: 'Remboursement client · ${formatCfa(financeInt(row['amount']))}', subtitle: financeString(row['order_reference'])));
    }
    for (final Map<String, dynamic> row in s.waveAdjustments) {
      values.add(_FinanceMovement(at: financeDate(row['effective_at']), icon: Symbols.account_balance_rounded, title: 'Ajustement solde Wave · ${formatCfa(financeInt(row['opening_balance']))}', subtitle: financeString(row['note']).isEmpty ? 'Solde d’ouverture' : financeString(row['note'])));
    }
    values.sort((_FinanceMovement a, _FinanceMovement b) => (b.at ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(a.at ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return values;
  }

  Future<void> _showWaveOpeningDialog(BackofficeFinanceSnapshot s) async {
    final TextEditingController amount = TextEditingController(text: s.openingWaveBalance.toString());
    final TextEditingController note = TextEditingController();
    final bool? ok = await _showFormDialog(
      title: 'Solde Wave d’ouverture',
      description: 'Ce montant devient la base de calcul de la caisse théorique. L’ancien solde reste dans l’historique.',
      fields: <Widget>[
        TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montant (FCFA)')),
        const SizedBox(height: 12),
        TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Justification / note')),
      ],
    );
    if (ok != true) {
      return;
    }
    final int? value = int.tryParse(amount.text.trim());
    if (value == null || value < 0) {
      _showInputError('Saisis un montant Wave valide.');
      return;
    }
    await _runAction(() => widget.repository.setWaveOpening(amount: value, note: note.text), success: 'Solde Wave d’ouverture mis à jour.');
  }

  Future<void> _showSupplierDialog({Map<String, dynamic>? row}) async {
    final TextEditingController name = TextEditingController(text: financeString(row?['name']));
    final TextEditingController phone = TextEditingController(text: financeString(row?['phone_number']));
    final TextEditingController note = TextEditingController(text: financeString(row?['note']));
    final bool? ok = await _showFormDialog(
      title: row == null ? 'Nouveau fournisseur' : 'Modifier le fournisseur',
      description: 'Le fournisseur sera utilisé pour les approvisionnements et les règlements Phase 5.',
      fields: <Widget>[
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom du fournisseur')),
        const SizedBox(height: 12),
        TextField(controller: phone, decoration: const InputDecoration(labelText: 'Téléphone')),
        const SizedBox(height: 12),
        TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Note')),
      ],
    );
    if (ok != true) {
      return;
    }
    if (name.text.trim().length < 2) {
      _showInputError('Le nom du fournisseur est obligatoire.');
      return;
    }
    await _runAction(
      () async {
        await widget.repository.saveSupplier(supplierId: row == null ? null : financeString(row['id']), name: name.text, phoneNumber: phone.text, note: note.text);
      },
      success: row == null ? 'Fournisseur créé.' : 'Fournisseur mis à jour.',
    );
  }

  Future<void> _showSupplierRechargeDialog(BackofficeFinanceSnapshot s) async {
    final List<Map<String, dynamic>> suppliers = s.suppliers.where((Map<String, dynamic> row) => row['is_active'] == true).toList(growable: false);
    if (suppliers.isEmpty || s.agentCapacities.isEmpty) {
      _showInputError('Un fournisseur actif et un Agent sont nécessaires.');
      return;
    }
    String supplierId = financeString(suppliers.first['id']);
    String agentId = financeString(s.agentCapacities.first['agent_id']);
    String network = 'orange';
    final TextEditingController principal = TextEditingController();
    final TextEditingController bonus = TextEditingController(text: '0');
    final TextEditingController note = TextEditingController();
    final bool? ok = await _showStatefulFormDialog(
      title: 'Approvisionner un Agent',
      description: 'Le montant reçu augmente immédiatement la capacité réseau de l’Agent et met à jour le compte fournisseur.',
      builder: (StateSetter setDialogState) => <Widget>[
        DropdownButtonFormField<String>(initialValue: supplierId, decoration: const InputDecoration(labelText: 'Fournisseur'), items: suppliers.map((Map<String, dynamic> row) => DropdownMenuItem<String>(value: financeString(row['id']), child: Text(financeString(row['name'])))).toList(growable: false), onChanged: (String? value) {
          if (value != null) {
            setDialogState(() => supplierId = value);
          }
        }),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: agentId, decoration: const InputDecoration(labelText: 'Agent'), items: s.agentCapacities.map((Map<String, dynamic> row) => DropdownMenuItem<String>(value: financeString(row['agent_id']), child: Text(financeString(row['agent_name'])))).toList(growable: false), onChanged: (String? value) {
          if (value != null) {
            setDialogState(() => agentId = value);
          }
        }),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: network, decoration: const InputDecoration(labelText: 'Réseau'), items: const <DropdownMenuItem<String>>[DropdownMenuItem(value: 'orange', child: Text('Orange')), DropdownMenuItem(value: 'mtn', child: Text('MTN')), DropdownMenuItem(value: 'moov', child: Text('Moov'))], onChanged: (String? value) {
          if (value != null) {
            setDialogState(() => network = value);
          }
        }),
        const SizedBox(height: 12),
        TextField(controller: principal, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Principal payé / acheté')),
        const SizedBox(height: 12),
        TextField(controller: bonus, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bonus fournisseur')),
        const SizedBox(height: 8),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'La dette fournisseur créée correspond au principal. Le bonus augmente uniquement la capacité reçue.',
            style: TextStyle(fontSize: 12, color: BackofficePalette.muted),
          ),
        ),
        const SizedBox(height: 12),
        TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note')),
      ],
    );
    if (ok != true) {
      return;
    }
    final int? principalValue = int.tryParse(principal.text.trim());
    final int bonusValue = int.tryParse(bonus.text.trim()) ?? 0;
    if (principalValue == null ||
        principalValue <= 0 ||
        bonusValue < 0) {
      _showInputError('Vérifie les montants de l’approvisionnement.');
      return;
    }
    final Map<String, dynamic> agent = s.agentCapacities.firstWhere((Map<String, dynamic> row) => financeString(row['agent_id']) == agentId);
    await _runAction(
      () async {
        await widget.repository.recordSupplierRecharge(supplierId: supplierId, agentId: agentId, agentName: financeString(agent['agent_name']), network: network, principal: principalValue, bonus: bonusValue, amountOwed: principalValue, note: note.text, staffName: widget.user.name);
      },
      success: 'Approvisionnement enregistré et capacité mise à jour.',
    );
  }

  Future<void> _showSupplierPaymentDialog(BackofficeFinanceSnapshot s) async {
    if (s.suppliers.isEmpty) {
      _showInputError('Aucun fournisseur disponible.');
      return;
    }
    String supplierId = financeString(s.suppliers.first['id']);
    String channel = 'wave';
    final TextEditingController amount = TextEditingController();
    final TextEditingController reference = TextEditingController();
    final TextEditingController note = TextEditingController();
    final bool? ok = await _showStatefulFormDialog(
      title: 'Régler un fournisseur',
      description: 'Le règlement réduit automatiquement le solde dû au fournisseur.',
      builder: (StateSetter setDialogState) => <Widget>[
        DropdownButtonFormField<String>(initialValue: supplierId, decoration: const InputDecoration(labelText: 'Fournisseur'), items: s.suppliers.map((Map<String, dynamic> row) => DropdownMenuItem<String>(value: financeString(row['id']), child: Text(financeString(row['name'])))).toList(growable: false), onChanged: (String? value) {
          if (value != null) {
            setDialogState(() => supplierId = value);
          }
        }),
        const SizedBox(height: 12),
        TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montant')),
        const SizedBox(height: 12),
        _channelDropdown(channel, (String value) => setDialogState(() => channel = value)),
        const SizedBox(height: 12),
        TextField(controller: reference, decoration: const InputDecoration(labelText: 'Référence paiement')),
        const SizedBox(height: 12),
        TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note')),
      ],
    );
    if (ok != true) {
      return;
    }
    final int? value = int.tryParse(amount.text.trim());
    if (value == null || value <= 0 || reference.text.trim().length < 3) {
      _showInputError('Montant et référence valides obligatoires.');
      return;
    }
    await _runAction(
      () async {
        await widget.repository.recordSupplierPayment(supplierId: supplierId, amount: value, channel: channel, reference: reference.text, note: note.text, staffName: widget.user.name);
      },
      success: 'Paiement fournisseur enregistré.',
    );
  }

  Future<void> _showCommissionPayoutDialog(Map<String, dynamic> row, int balance) async {
    final TextEditingController amount = TextEditingController(text: balance.toString());
    final TextEditingController reference = TextEditingController();
    final TextEditingController note = TextEditingController();
    final bool? ok = await _showFormDialog(
      title: 'Payer une commission',
      description: '${financeString(row['agent_name'])} · solde maximum ${formatCfa(balance)}',
      fields: <Widget>[
        TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montant')),
        const SizedBox(height: 12),
        TextField(controller: reference, decoration: const InputDecoration(labelText: 'Référence Wave / paiement')),
        const SizedBox(height: 12),
        TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note')),
      ],
    );
    if (ok != true) {
      return;
    }
    final int? value = int.tryParse(amount.text.trim());
    if (value == null ||
        value <= 0 ||
        value > balance ||
        reference.text.trim().length < 3) {
      _showInputError(
        'Le montant doit être compris dans le solde dû et une référence est obligatoire.',
      );
      return;
    }
    await _runAction(
      () async {
        await widget.repository.recordCommissionPayout(agentId: financeString(row['agent_id']), agentName: financeString(row['agent_name']), amount: value, reference: reference.text, note: note.text, staffName: widget.user.name);
      },
      success: 'Commission Agent enregistrée.',
    );
  }

  Future<void> _showCreateCreditDialog(BackofficeFinanceSnapshot s) async {
    final Set<String> creditedOrders = s.credits
        .map((Map<String, dynamic> row) => financeString(row['order_id']))
        .toSet();

    List<QueueOrder> source;
    try {
      source = await widget.ordersRepository.fetchPaymentTrackingOrders();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showInputError(
        'Impossible de charger les commandes impayées pour le moment : ${_financeError(error)}',
      );
      return;
    }
    if (!mounted) {
      return;
    }

    final List<QueueOrder> candidates = source.where((QueueOrder order) {
      final bool eligibleStatus =
          order.status == QueueOrderStatus.awaitingPayment ||
          order.status == QueueOrderStatus.paymentToVerify ||
          order.status == QueueOrderStatus.expired;
      final bool paymentSafe =
          order.paymentStatus != OrderPaymentStatus.confirmed &&
          order.paymentStatus != OrderPaymentStatus.credit &&
          order.paymentStatus != OrderPaymentStatus.declared &&
          (order.paymentReference?.trim().isEmpty ?? true);
      return eligibleStatus &&
          paymentSafe &&
          !order.isFundedForProcessing &&
          !creditedOrders.contains(order.id);
    }).take(100).toList(growable: false);

    if (candidates.isEmpty) {
      _showInputError(
        'Aucune commande réellement impayée n’est éligible. Une déclaration Wave en attente de vérification doit être traitée avant toute autorisation de crédit.',
      );
      return;
    }

    QueueOrder selected = candidates.first;
    final TextEditingController note = TextEditingController();
    final bool? ok = await _showStatefulFormDialog(
      title: 'Autoriser un crédit client',
      description:
          'La commande sera financée comme crédit directement dans Supabase puis envoyée dans la file d’affectation. Aucun paiement Wave n’est créé.',
      builder: (StateSetter setDialogState) => <Widget>[
        DropdownButtonFormField<QueueOrder>(
          initialValue: selected,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Commande impayée'),
          items: candidates
              .map(
                (QueueOrder order) => DropdownMenuItem<QueueOrder>(
                  value: order,
                  child: Text(
                    '${order.reference} · ${order.clientName} · ${formatCfa(order.amount)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: (QueueOrder? value) {
            if (value != null) {
              setDialogState(() => selected = value);
            }
          },
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Montant du crédit : ${formatCfa(selected.amount)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 7),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Une commande avec paiement Wave déclaré n’est jamais convertie en crédit automatiquement.',
            style: TextStyle(
              fontSize: 12,
              color: BackofficePalette.warning,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: note,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Note / conditions'),
        ),
      ],
    );
    if (ok != true) {
      return;
    }

    await _runAction(
      () async {
        await widget.repository.authorizeCreditOrder(
          order: selected,
          note: note.text,
        );
        try {
          await widget.ordersRepository.tryAutomaticAssignment(
            orderId: selected.id,
          );
        } on Object {
          // Le crédit et l'entrée Phase 4 sont déjà atomiques dans Supabase.
          // Le moteur 9E retentera l'affectation via son backlog si nécessaire.
        }
      },
      success: 'Crédit client autorisé et commande envoyée au traitement.',
    );
  }

  Future<void> _showCreditSettlementDialog(Map<String, dynamic> row, int balance) async {
    final TextEditingController amount = TextEditingController(text: balance.toString());
    final TextEditingController reference = TextEditingController();
    final TextEditingController note = TextEditingController();
    String channel = 'wave';
    final bool? ok = await _showStatefulFormDialog(
      title: 'Encaisser un crédit',
      description: '${financeString(row['client_name'])} · reste ${formatCfa(balance)}',
      builder: (StateSetter setDialogState) => <Widget>[
        TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montant reçu')),
        const SizedBox(height: 12),
        _channelDropdown(channel, (String value) => setDialogState(() => channel = value)),
        const SizedBox(height: 12),
        TextField(controller: reference, decoration: const InputDecoration(labelText: 'Référence du règlement')),
        const SizedBox(height: 12),
        TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note')),
      ],
    );
    if (ok != true) {
      return;
    }
    final int? value = int.tryParse(amount.text.trim());
    if (value == null ||
        value <= 0 ||
        value > balance ||
        reference.text.trim().length < 3) {
      _showInputError('Montant et référence de règlement invalides.');
      return;
    }
    await _runAction(
      () async {
        await widget.repository.settleCredit(creditId: financeString(row['id']), amount: value, channel: channel, reference: reference.text, note: note.text);
      },
      success: value == balance ? 'Crédit soldé.' : 'Remboursement partiel enregistré.',
    );
  }

  Future<void> _showExpenseDialog() async {
    String category = 'fees';
    String channel = 'wave';
    final TextEditingController amount = TextEditingController();
    final TextEditingController description = TextEditingController();
    final TextEditingController reference = TextEditingController();
    final bool? ok = await _showStatefulFormDialog(
      title: 'Enregistrer une dépense',
      description: 'Toute dépense est conservée dans le journal financier et impacte la caisse théorique lorsqu’elle est payée via Wave.',
      builder: (StateSetter setDialogState) => <Widget>[
        DropdownButtonFormField<String>(initialValue: category, decoration: const InputDecoration(labelText: 'Catégorie'), items: _expenseCategories.map((String value) => DropdownMenuItem<String>(value: value, child: Text(_expenseCategoryLabel(value)))).toList(growable: false), onChanged: (String? value) {
          if (value != null) {
            setDialogState(() => category = value);
          }
        }),
        const SizedBox(height: 12),
        TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montant')),
        const SizedBox(height: 12),
        TextField(controller: description, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
        const SizedBox(height: 12),
        _channelDropdown(channel, (String value) => setDialogState(() => channel = value)),
        const SizedBox(height: 12),
        TextField(controller: reference, decoration: InputDecoration(labelText: channel == 'wave' ? 'Référence Wave (obligatoire)' : 'Référence (facultative)')),
      ],
    );
    if (ok != true) {
      return;
    }
    final int? value = int.tryParse(amount.text.trim());
    if (value == null || value <= 0 || description.text.trim().length < 3) {
      _showInputError('Montant et description valides obligatoires.');
      return;
    }
    if (channel == 'wave' && reference.text.trim().length < 3) {
      _showInputError('La référence Wave est obligatoire.');
      return;
    }
    await _runAction(
      () async {
        await widget.repository.recordExpense(category: category, amount: value, description: description.text, channel: channel, reference: reference.text);
      },
      success: 'Dépense enregistrée.',
    );
  }

  Future<void> _showClosingDialog(BackofficeFinanceSnapshot s) async {
    if (!s.hasWaveOpening) {
      _showInputError(
        'Définis d’abord le solde d’ouverture Wave. Une clôture sans point de départ de caisse serait trompeuse.',
      );
      return;
    }
    final DateTime today = DateTime.now();
    final int theoretical = s.waveTheoreticalBalanceOn(today);
    final TextEditingController actual = TextEditingController(text: theoretical.toString());
    final TextEditingController note = TextEditingController();
    final bool? ok = await _showFormDialog(
      title: 'Clôturer ${_dateKey(today)}',
      description: 'Solde Wave théorique affiché : ${formatCfa(theoretical)}. Saisis le solde réellement constaté. Supabase recalculera les totaux canoniques au moment de la clôture ; un écart non nul exige une justification.',
      fields: <Widget>[
        TextField(controller: actual, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Solde Wave réel')),
        const SizedBox(height: 12),
        TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Justification / commentaire')),
      ],
      confirmLabel: 'Clôturer',
    );
    if (ok != true) {
      return;
    }
    final int? actualValue = int.tryParse(actual.text.trim());
    if (actualValue == null || actualValue < 0) {
      _showInputError('Solde Wave réel invalide.');
      return;
    }
    if (actualValue != theoretical && note.text.trim().length < 3) {
      _showInputError('Justifie l’écart Wave avant la clôture.');
      return;
    }
    // Les totaux financiers ne sont pas envoyes comme autorite : Supabase
    // les recalcule atomiquement au moment de la cloture. Le navigateur ne
    // fournit que la date, le solde Wave constate et l'explication d'un ecart.
    final Map<String, dynamic> payload = <String, dynamic>{
      'date_key': _dateKey(today),
      'wave_actual_balance': actualValue,
      'wave_difference_note': note.text.trim(),
    };
    await _runAction(
      () async {
        await widget.repository.createClosing(payload);
      },
      success: 'Clôture journalière enregistrée.',
    );
  }

  Future<void> _confirmDeleteSupplier(String id, String name) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Retirer le fournisseur ?'),
        content: Text('$name sera retiré du registre actif. S’il possède un historique financier, Supabase refusera la suppression et proposera de le suspendre.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Retirer')),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _runAction(() => widget.repository.deleteSupplier(id), success: 'Fournisseur retiré du registre.');
  }

  Widget _channelDropdown(String value, ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Canal'),
      items: const <DropdownMenuItem<String>>[
        DropdownMenuItem(value: 'wave', child: Text('Wave')),
        DropdownMenuItem(value: 'cash', child: Text('Espèces')),
        DropdownMenuItem(value: 'bank', child: Text('Banque')),
        DropdownMenuItem(value: 'other', child: Text('Autre')),
      ],
      onChanged: (String? next) {
        if (next != null) {
          onChanged(next);
        }
      },
    );
  }

  Future<bool?> _showFormDialog({
    required String title,
    required String description,
    required List<Widget> fields,
    String confirmLabel = 'Enregistrer',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(description),
              const SizedBox(height: 18),
              ...fields,
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(confirmLabel)),
        ],
      ),
    );
  }

  Future<bool?> _showStatefulFormDialog({
    required String title,
    required String description,
    required List<Widget> Function(StateSetter setDialogState) builder,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
          scrollable: true,
          title: Text(title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(description),
                const SizedBox(height: 18),
                ...builder(setDialogState),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
  }

  void _showInputError(String message) {
    IzyTelFeedback.error(context, message);
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: .07), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withValues(alpha: .20))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Icon(icon, color: color, fill: 1),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: BackofficePalette.ink))),
      ]),
    );
  }
}

class _FinanceListTile extends StatelessWidget {
  const _FinanceListTile({required this.icon, required this.title, required this.subtitle, required this.trailing, this.action});
  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
        Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: BackofficePalette.primarySoft, borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 20, color: BackofficePalette.primary, fill: 1)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 3),
          Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
        ])),
        const SizedBox(width: 10),
        if (action != null) ...<Widget>[action!, const SizedBox(width: 8)],
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 150), child: Text(trailing, textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800, color: BackofficePalette.ink))),
      ]),
    );
  }
}

class _FinanceCheck {
  const _FinanceCheck({required this.ok, required this.title, required this.detail});
  final bool ok;
  final String title;
  final String detail;
}

class _FinanceCheckTile extends StatelessWidget {
  const _FinanceCheckTile({required this.check});
  final _FinanceCheck check;
  @override
  Widget build(BuildContext context) {
    final Color color = check.ok ? BackofficePalette.success : BackofficePalette.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: <Widget>[
        Icon(check.ok ? Symbols.check_circle_rounded : Symbols.warning_rounded, color: color, fill: 1),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(check.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(check.detail, style: Theme.of(context).textTheme.bodySmall),
        ])),
        BackofficeStatusBadge(label: check.ok ? 'OK' : 'À contrôler', color: color),
      ]),
    );
  }
}

class _FinanceMovement {
  const _FinanceMovement({required this.at, required this.icon, required this.title, required this.subtitle});
  final DateTime? at;
  final IconData icon;
  final String title;
  final String subtitle;
}

class _FinanceLoading extends StatelessWidget {
  const _FinanceLoading();
  @override
  Widget build(BuildContext context) => const Padding(padding: EdgeInsets.symmetric(vertical: 80), child: Center(child: CircularProgressIndicator()));
}

class _FinanceErrorState extends StatelessWidget {
  const _FinanceErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return BackofficeEmptyState(
      icon: Symbols.cloud_off_rounded,
      title: 'Données financières indisponibles',
      message: 'Le snapshot BO-5 ne peut pas être chargé pour le moment. Les autres modules IzyTel restent disponibles.',
      action: OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Symbols.refresh_rounded), label: const Text('Réessayer')),
    );
  }
}

const List<String> _expenseCategories = <String>['transport', 'internet', 'electricity', 'maintenance', 'salary', 'communication', 'fees', 'marketing', 'office', 'other'];

String _expenseCategoryLabel(String value) {
  switch (value) {
    case 'transport': return 'Transport';
    case 'internet': return 'Internet';
    case 'electricity': return 'Électricité';
    case 'maintenance': return 'Maintenance';
    case 'salary': return 'Salaire';
    case 'communication': return 'Communication';
    case 'fees': return 'Frais';
    case 'marketing': return 'Marketing';
    case 'office': return 'Bureau';
    default: return 'Autre';
  }
}

String _channelLabel(String value) {
  switch (value) {
    case 'wave': return 'Wave';
    case 'cash': return 'Espèces';
    case 'bank': return 'Banque';
    default: return 'Autre';
  }
}

String _creditStatusLabel(String value) {
  switch (value) {
    case 'partial': return 'Partiellement remboursé';
    case 'settled': return 'Soldé';
    default: return 'En cours';
  }
}

String _networkLabel(String value) {
  switch (value) {
    case 'orange': return 'Orange';
    case 'mtn': return 'MTN';
    case 'moov': return 'Moov Africa';
    default: return value.isEmpty ? 'Réseau' : value;
  }
}

String _movementTypeLabel(String value) {
  switch (value) {
    case 'orderSuccess': return 'Commande réussie';
    case 'supplierRecharge': return 'Approvisionnement';
    case 'manualAdjustment': return 'Ajustement manuel';
    default: return value;
  }
}

String _dateLabel(DateTime? value) {
  if (value == null) {
    return '—';
  }
  final DateTime local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _dateKey(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _financeError(Object error) {
  final String raw = error.toString();
  const Map<String, String> messages = <String, String>{
    'ADMIN_REQUIRED': 'Cette écriture financière est réservée à l’Administrateur.',
    'INVALID_AMOUNT': 'Le montant saisi est invalide.',
    'DUPLICATE_REFERENCE': 'Cette référence de paiement a déjà été utilisée.',
    'PAYMENT_EXCEEDS_BALANCE': 'Le montant dépasse le reste à payer.',
    'CREDIT_ALREADY_SETTLED': 'Ce crédit est déjà soldé.',
    'CREDIT_ALREADY_EXISTS': 'Cette commande possède déjà un dossier de crédit.',
    'CONFIRMED_PAYMENT_ALREADY_EXISTS': 'Cette commande possède déjà un paiement confirmé et ne peut pas être convertie en crédit.',
    'ORDER_CREDIT_STATE_INVALID': 'L’état actuel de la commande ne permet pas une vente à crédit.',
    'SUPPLIER_HAS_HISTORY': 'Ce fournisseur possède un historique financier. Suspends-le au lieu de le supprimer.',
    'CLOSING_ALREADY_EXISTS': 'La journée est déjà clôturée.',
    'WAVE_OPENING_REQUIRED':
        'Définis le solde d’ouverture Wave avant de clôturer la journée.',
    'WAVE_DIFFERENCE_NOTE_REQUIRED':
        'Un écart Wave doit être justifié avant la clôture.',
    'INVALID_WAVE_BALANCE': 'Le solde Wave saisi est invalide.',
    'WAVE_REFERENCE_REQUIRED': 'Une dépense Wave doit avoir une référence.',
  };
  for (final MapEntry<String, String> entry in messages.entries) {
    if (raw.contains(entry.key)) return entry.value;
  }
  return 'L’opération financière n’a pas pu être enregistrée. Réessaie ou consulte le journal technique.';
}
