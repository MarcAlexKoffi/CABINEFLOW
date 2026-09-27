import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';
import 'package:cabine_flow/features/finances/domain/repositories/finance_operations_repository.dart';
import 'package:cabine_flow/features/finances/presentation/widgets/financial_ui.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class CustomerCreditsPage extends StatefulWidget {
  const CustomerCreditsPage({
    super.key,
    required this.user,
    required this.repository,
    required this.ordersRepository,
  });
  final AppUser user;
  final FinanceOperationsRepository repository;
  final OrdersRepository ordersRepository;

  @override
  State<CustomerCreditsPage> createState() => _CustomerCreditsPageState();
}

class _CustomerCreditsPageState extends State<CustomerCreditsPage> {
  bool _busy = false;

  Stream<List<QueueOrder>> get _ordersStream {
    final OrdersRepository repository = widget.ordersRepository;
    if (repository is OrderHistoryRepository) {
      return (repository as OrderHistoryRepository).watchOrderHistory();
    }
    return repository.watchPaymentTrackingOrders();
  }

  Future<void> _create(List<CustomerCredit> existing) async {
    final List<QueueOrder> orders = await _ordersStream.first;
    if (!mounted) return;
    final Set<String> used = existing
        .map((CustomerCredit item) => item.orderId)
        .toSet();
    final List<QueueOrder> eligible = orders
        .where((QueueOrder order) {
          final bool canAuthorize =
              order.status == QueueOrderStatus.awaitingPayment ||
              order.status == QueueOrderStatus.paymentToVerify ||
              order.status == QueueOrderStatus.expired;
          return canAuthorize &&
              !order.isFundedForProcessing &&
              !used.contains(order.id);
        })
        .take(100)
        .toList(growable: false);
    if (eligible.isEmpty) {
      _message('Aucune commande impayée disponible pour créer un crédit.');
      return;
    }
    QueueOrder selected = eligible.first;
    final TextEditingController note = TextEditingController();
    final bool? submit = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => AlertDialog(
          title: const Text('Créer un crédit client'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<QueueOrder>(
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Commande'),
                  items: eligible
                      .map(
                        (QueueOrder order) => DropdownMenuItem(
                          value: order,
                          child: Text(
                            '${order.reference} · ${order.clientName}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (QueueOrder? value) {
                    if (value == null) return;
                    setState(() => selected = value);
                  },
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Montant du crédit : ${formatCfaFull(selected.amount)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 6),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Cette action autorise le traitement de la commande avant son encaissement.',
                    style: TextStyle(fontSize: 12, color: IzyTelColors.warning),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: note,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note (facultatif)',
                  ),
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
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
    if (submit != true) return;
    await _run(() async {
      await widget.repository.createCustomerCredit(
        draft: CustomerCreditDraft(
          orderId: selected.id,
          orderReference: selected.reference,
          clientName: selected.clientName,
          clientWhatsappPhone: selected.clientWhatsappPhone,
          amount: selected.amount,
          note: note.text,
        ),
        staffId: widget.user.id,
        staffName: widget.user.name,
      );
      try {
        await widget.ordersRepository.tryAutomaticAssignment(
          orderId: selected.id,
        );
      } on Object {
        // Le crédit et la file 9E sont déjà enregistrés atomiquement.
        // L'affectation sera retentée par la synchronisation du backlog.
      }
      return selected.id;
    });
  }

  Future<void> _settle(CustomerCredit credit) async {
    final TextEditingController amount = TextEditingController(
      text: '${credit.outstanding}',
    );
    final TextEditingController reference = TextEditingController();
    final TextEditingController note = TextEditingController();
    FinancePaymentChannel channel = FinancePaymentChannel.wave;
    final bool? submit = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => AlertDialog(
          title: const Text('Règlement du crédit'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${credit.clientName} · reste ${formatCfaFull(credit.outstanding)}',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Montant reçu'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<FinancePaymentChannel>(
                  initialValue: channel,
                  decoration: const InputDecoration(labelText: 'Canal'),
                  items: FinancePaymentChannel.values
                      .map(
                        (FinancePaymentChannel item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (FinancePaymentChannel? value) =>
                      setState(() => channel = value ?? channel),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reference,
                  decoration: const InputDecoration(labelText: 'Référence'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: note,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note (facultatif)',
                  ),
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
      ),
    );
    if (submit != true) return;
    await _run(
      () => widget.repository.settleCustomerCredit(
        creditId: credit.id,
        amount: int.tryParse(amount.text.trim()) ?? 0,
        channel: channel,
        reference: reference.text,
        note: note.text,
        staffId: widget.user.id,
        staffName: widget.user.name,
      ),
    );
  }

  Future<void> _run(Future<Object?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        _message('Opération enregistrée.');
      }
    } catch (error) {
      if (mounted) {
        _message(
          error
              .toString()
              .replaceFirst('Bad state: ', '')
              .replaceFirst('Invalid argument(s): ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _message(String text) => IzyTelFeedback.show(context, text);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(
        title: const Text(
          'Crédits clients',
          style: TextStyle(
            fontSize: IzyTelTypeScale.title3,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<List<CustomerCredit>>(
        stream: widget.repository.watchCustomerCredits(),
        builder: (BuildContext context, AsyncSnapshot<List<CustomerCredit>> snapshot) {
          final List<CustomerCredit> credits =
              snapshot.data ?? const <CustomerCredit>[];
          final int outstanding = credits.fold<int>(
            0,
            (int total, CustomerCredit item) =>
                total + (item.outstanding > 0 ? item.outstanding : 0),
          );
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: FinancialMetricCard(
                      label: 'À récupérer',
                      value: formatCfa(outstanding),
                      icon: Symbols.request_quote_rounded,
                      accent: outstanding > 0
                          ? IzyTelColors.warning
                          : IzyTelColors.success,
                      caption:
                          '${credits.where((CustomerCredit item) => item.outstanding > 0).length} dossier(s)',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FinancialMetricCard(
                      label: 'Récupéré',
                      value: formatCfa(
                        credits.fold<int>(
                          0,
                          (int total, CustomerCredit item) =>
                              total + item.paidAmount,
                        ),
                      ),
                      icon: Symbols.savings_rounded,
                      accent: IzyTelColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _busy ? null : () => _create(credits),
                icon: const Icon(Symbols.add_rounded),
                label: const Text('Nouveau crédit'),
              ),
              const SizedBox(height: 18),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (credits.isEmpty)
                const FinanceEmptyState(
                  icon: Symbols.request_quote_rounded,
                  title: 'Aucun crédit client',
                  message:
                      'Les créances exceptionnelles liées aux commandes apparaîtront ici.',
                )
              else
                ...credits.map(
                  (CustomerCredit credit) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: IzyTelColors.surface,
                        borderRadius: BorderRadius.circular(IzyTelRadii.card),
                        border: Border.all(color: IzyTelColors.outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      credit.clientName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: IzyTelColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      credit.orderReference,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: IzyTelColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                credit.status.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: credit.outstanding > 0
                                      ? IzyTelColors.warning
                                      : IzyTelColors.success,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Dû ${formatCfaFull(credit.amount)} · payé ${formatCfaFull(credit.paidAmount)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: IzyTelColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Reste ${formatCfaFull(credit.outstanding)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: IzyTelColors.textPrimary,
                            ),
                          ),
                          if (credit.outstanding > 0) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _busy ? null : () => _settle(credit),
                                icon: const Icon(Symbols.payments_rounded),
                                label: const Text('Enregistrer un règlement'),
                              ),
                            ),
                          ],
                        ],
                      ),
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
