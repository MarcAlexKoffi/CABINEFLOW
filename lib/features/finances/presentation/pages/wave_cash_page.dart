import 'dart:async';

import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/commissions/domain/models/commission_models.dart';
import 'package:cabine_flow/features/commissions/domain/repositories/commission_repository.dart';
import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';
import 'package:cabine_flow/features/finances/domain/repositories/finance_operations_repository.dart';
import 'package:cabine_flow/features/finances/domain/services/finance_calculators.dart';
import 'package:cabine_flow/features/finances/presentation/widgets/financial_ui.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';
import 'package:cabine_flow/features/refunds/domain/repositories/refund_repository.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class WaveCashPage extends StatefulWidget {
  const WaveCashPage({
    super.key,
    required this.user,
    required this.ordersRepository,
    required this.refundRepository,
    required this.commissionRepository,
    required this.financeRepository,
  });

  final AppUser user;
  final OrdersRepository ordersRepository;
  final RefundRepository refundRepository;
  final CommissionRepository commissionRepository;
  final FinanceOperationsRepository financeRepository;

  @override
  State<WaveCashPage> createState() => _WaveCashPageState();
}

class _WaveCashPageState extends State<WaveCashPage> {
  late Future<_WavePageData> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Stream<List<QueueOrder>> get _ordersStream {
    final OrdersRepository repository = widget.ordersRepository;
    if (repository is OrderHistoryRepository) {
      return (repository as OrderHistoryRepository).watchOrderHistory();
    }
    return repository.watchPaymentTrackingOrders();
  }

  Future<_WavePageData> _load({WaveOpeningBalance? openingOverride}) async {
    final List<QueueOrder> orders = await _ordersStream.first;
    final List<RefundCase> refunds = await widget.refundRepository
        .watchAll()
        .first;
    final List<CommissionPayout> payouts = await widget.commissionRepository
        .watchPayouts()
        .first;
    final List<SupplierPayment> supplierPayments = await widget
        .financeRepository
        .watchSupplierPayments()
        .first;
    final List<CustomerCreditSettlement> settlements = await widget
        .financeRepository
        .watchCustomerCreditSettlements()
        .first;
    final List<FinanceExpense> expenses = await widget.financeRepository
        .watchExpenses()
        .first;
    final WaveOpeningBalance? opening =
        openingOverride ??
        await widget.financeRepository.watchWaveOpeningBalance().first;
    final List<WaveBalanceAdjustment> adjustments = await widget
        .financeRepository
        .watchWaveBalanceAdjustments()
        .first;
    return _WavePageData(
      opening: opening,
      adjustments: adjustments,
      snapshot: WaveFinanceCalculator.calculate(
        opening: opening,
        orders: orders,
        refunds: refunds,
        commissionPayouts: payouts,
        supplierPayments: supplierPayments,
        creditSettlements: settlements,
        expenses: expenses,
      ),
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _setOpening(_WavePageData data) async {
    final TextEditingController amount = TextEditingController(
      text: '${data.snapshot.theoreticalBalance.clamp(0, 1000000000)}',
    );
    final TextEditingController note = TextEditingController(
      text: data.opening == null
          ? 'Initialisation de la caisse Wave'
          : 'Recalage du solde Wave réel',
    );
    final bool? submit = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(data.opening == null ? 'Initialiser Wave' : 'Recaler Wave'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Saisis le solde réellement visible dans ta caisse Wave. Les mouvements futurs seront calculés à partir de ce point.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Solde Wave réel'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (submit != true) return;

    final int? newAmount = int.tryParse(amount.text.trim());
    if (newAmount == null || newAmount < 0) {
      _message('Saisis un solde Wave valide.');
      return;
    }

    setState(() => _busy = true);
    try {
      final WaveOpeningBalance? previousOpening = data.opening;

      await widget.financeRepository.setWaveOpeningBalance(
        amount: newAmount,
        note: note.text,
        staffId: widget.user.id,
        staffName: widget.user.name,
      );

      // Ne pas relire simplement snapshots().first ici : Firestore peut
      // émettre d'abord l'ancienne valeur en cache juste après la transaction.
      // On attend explicitement le nouveau point de départ confirmé.
      WaveOpeningBalance? confirmedOpening;
      try {
        confirmedOpening = await widget.financeRepository
            .watchWaveOpeningBalance()
            .firstWhere((WaveOpeningBalance? opening) {
              if (opening == null || opening.amount != newAmount) return false;
              if (previousOpening == null) return true;
              return opening.effectiveAt.isAfter(previousOpening.effectiveAt) ||
                  opening.updatedAt.isAfter(previousOpening.updatedAt);
            })
            .timeout(const Duration(seconds: 8));
      } on TimeoutException {
        // L'écriture a déjà été confirmée par setWaveOpeningBalance().
        // On affiche donc immédiatement le nouveau point réel, puis les
        // prochains rafraîchissements récupéreront le timestamp serveur exact.
        final DateTime now = DateTime.now();
        confirmedOpening = WaveOpeningBalance(
          amount: newAmount,
          effectiveAt: now,
          note: note.text.trim().isEmpty ? null : note.text.trim(),
          updatedAt: now,
          updatedBy: widget.user.id,
          updatedByName: widget.user.name,
        );
      }

      if (mounted) {
        setState(() {
          _future = _load(openingOverride: confirmedOpening);
        });
        _message('Nouveau point de départ Wave enregistré.');
      }
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Invalid argument(s): ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) => IzyTelFeedback.show(context, text);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(
        title: const Text(
          'Caisse Wave',
          style: TextStyle(
            fontSize: IzyTelTypeScale.title3,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _busy ? null : _reload,
            tooltip: 'Actualiser',
            icon: const Icon(Symbols.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_WavePageData>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<_WavePageData> snapshot) {
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Impossible de calculer la caisse Wave : ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final _WavePageData data = snapshot.data!;
          final WaveCashSnapshot cash = data.snapshot;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: IzyTelColors.primary,
                  borderRadius: BorderRadius.circular(IzyTelRadii.largeCard),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Solde théorique Wave',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      formatCfaFull(cash.theoreticalBalance),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      cash.hasOpeningBalance
                          ? 'Calculé depuis ${financeDateTime(cash.effectiveAt)}'
                          : 'Aucun solde d’ouverture : calcul depuis l’historique disponible',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _setOpening(data),
                  icon: const Icon(Symbols.tune_rounded),
                  label: Text(
                    cash.hasOpeningBalance
                        ? 'Recaler avec le solde réel'
                        : 'Initialiser le solde Wave',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Entrées Wave',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: IzyTelColors.textPrimary,
                ),
              ),
              const SizedBox(height: 9),
              _FlowRow(
                label: 'Solde d’ouverture',
                amount: cash.openingBalance,
                icon: Symbols.flag_rounded,
              ),
              _FlowRow(
                label: 'Paiements clients',
                amount: cash.clientPayments,
                icon: Symbols.call_received_rounded,
                positive: true,
              ),
              _FlowRow(
                label: 'Règlements de crédits',
                amount: cash.creditSettlements,
                icon: Symbols.savings_rounded,
                positive: true,
              ),
              const SizedBox(height: 18),
              const Text(
                'Sorties Wave',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: IzyTelColors.textPrimary,
                ),
              ),
              const SizedBox(height: 9),
              _FlowRow(
                label: 'Paiements fournisseurs',
                amount: cash.supplierPayments,
                icon: Symbols.inventory_2_rounded,
                outgoing: true,
              ),
              _FlowRow(
                label: 'Remboursements clients',
                amount: cash.refunds,
                icon: Symbols.currency_exchange_rounded,
                outgoing: true,
              ),
              _FlowRow(
                label: 'Dépenses',
                amount: cash.expenses,
                icon: Symbols.receipt_long_rounded,
                outgoing: true,
              ),
              _FlowRow(
                label: 'Commissions Agents',
                amount: cash.commissionPayouts,
                icon: Symbols.payments_rounded,
                outgoing: true,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: IzyTelColors.surface,
                  borderRadius: BorderRadius.circular(IzyTelRadii.card),
                  border: Border.all(color: IzyTelColors.outline),
                ),
                child: Text(
                  'Formule : ouverture + paiements clients + règlements crédits - fournisseurs - remboursements - dépenses - commissions. Les paiements en espèces/banque ne modifient pas Wave.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IzyTelColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Historique des recalages',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: IzyTelColors.textPrimary,
                ),
              ),
              const SizedBox(height: 9),
              if (data.adjustments.isEmpty)
                const FinanceEmptyState(
                  icon: Symbols.history_rounded,
                  title: 'Aucun recalage',
                  message:
                      'Chaque initialisation ou recalage du solde Wave sera conservé ici.',
                )
              else
                ...data.adjustments
                    .take(30)
                    .map(
                      (WaveBalanceAdjustment adjustment) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: IzyTelColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: IzyTelColors.outline),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Symbols.tune_rounded,
                              color: IzyTelColors.wave,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${formatCfa(adjustment.previousOpeningBalance)} → ${formatCfa(adjustment.openingBalance)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: IzyTelColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${financeDateTime(adjustment.effectiveAt)} · ${adjustment.createdByName}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: IzyTelColors.textMuted,
                                    ),
                                  ),
                                  if (adjustment.note?.trim().isNotEmpty ==
                                      true) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      adjustment.note!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: IzyTelColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Text(
                              '${adjustment.difference >= 0 ? '+' : ''}${formatCfa(adjustment.difference)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: adjustment.difference == 0
                                    ? IzyTelColors.textMuted
                                    : IzyTelColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }
}

class _WavePageData {
  const _WavePageData({
    required this.opening,
    required this.adjustments,
    required this.snapshot,
  });
  final WaveOpeningBalance? opening;
  final List<WaveBalanceAdjustment> adjustments;
  final WaveCashSnapshot snapshot;
}

class _FlowRow extends StatelessWidget {
  const _FlowRow({
    required this.label,
    required this.amount,
    required this.icon,
    this.positive = false,
    this.outgoing = false,
  });
  final String label;
  final int amount;
  final IconData icon;
  final bool positive;
  final bool outgoing;
  @override
  Widget build(BuildContext context) {
    final Color accent = outgoing
        ? IzyTelColors.warning
        : (positive ? IzyTelColors.success : IzyTelColors.primary);
    final String prefix = outgoing ? '-' : (positive ? '+' : '');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IzyTelColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IzyTelColors.outline),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: IzyTelColors.textSecondary,
              ),
            ),
          ),
          Text(
            '$prefix${formatCfa(amount)}',
            style: TextStyle(fontWeight: FontWeight.w800, color: accent),
          ),
        ],
      ),
    );
  }
}
