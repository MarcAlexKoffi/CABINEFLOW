import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';
import 'package:cabine_flow/features/finances/domain/repositories/finance_operations_repository.dart';
import 'package:cabine_flow/features/finances/presentation/widgets/financial_ui.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class FinanceExpensesPage extends StatefulWidget {
  const FinanceExpensesPage({
    super.key,
    required this.user,
    required this.repository,
  });
  final AppUser user;
  final FinanceOperationsRepository repository;
  @override
  State<FinanceExpensesPage> createState() => _FinanceExpensesPageState();
}

class _FinanceExpensesPageState extends State<FinanceExpensesPage> {
  bool _busy = false;

  Future<void> _add() async {
    FinanceExpenseCategory category = FinanceExpenseCategory.transport;
    FinancePaymentChannel channel = FinancePaymentChannel.wave;
    final TextEditingController amount = TextEditingController();
    final TextEditingController description = TextEditingController();
    final TextEditingController reference = TextEditingController();
    final bool? submit = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => AlertDialog(
          title: const Text('Nouvelle dépense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<FinanceExpenseCategory>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: FinanceExpenseCategory.values
                      .map(
                        (FinanceExpenseCategory item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (FinanceExpenseCategory? value) =>
                      setState(() => category = value ?? category),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Montant'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: description,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description'),
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
                  decoration: InputDecoration(
                    labelText: channel == FinancePaymentChannel.wave
                        ? 'Référence Wave (obligatoire)'
                        : 'Référence (facultatif)',
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
    setState(() => _busy = true);
    try {
      await widget.repository.recordExpense(
        draft: FinanceExpenseDraft(
          category: category,
          amount: int.tryParse(amount.text.trim()) ?? 0,
          description: description.text,
          channel: channel,
          reference: reference.text,
        ),
        staffId: widget.user.id,
        staffName: widget.user.name,
      );
      if (mounted) {
        _message('Dépense enregistrée.');
      }
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Invalid argument(s): ', ''));
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
          'Dépenses',
          style: TextStyle(
            fontSize: IzyTelTypeScale.title3,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _busy ? null : _add,
            icon: const Icon(Symbols.add_rounded),
          ),
        ],
      ),
      body: StreamBuilder<List<FinanceExpense>>(
        stream: widget.repository.watchExpenses(),
        builder: (BuildContext context, AsyncSnapshot<List<FinanceExpense>> snapshot) {
          final List<FinanceExpense> expenses =
              snapshot.data ?? const <FinanceExpense>[];
          final DateTime now = DateTime.now();
          final int monthTotal = expenses
              .where(
                (FinanceExpense item) =>
                    item.spentAt.year == now.year &&
                    item.spentAt.month == now.month,
              )
              .fold<int>(
                0,
                (int total, FinanceExpense item) => total + item.amount,
              );
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              FinancialMetricCard(
                label: 'Dépenses du mois',
                value: formatCfa(monthTotal),
                icon: Symbols.receipt_long_rounded,
                accent: IzyTelColors.warning,
                caption: '${expenses.length} mouvement(s) enregistrés',
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _busy ? null : _add,
                icon: const Icon(Symbols.add_rounded),
                label: const Text('Ajouter une dépense'),
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
              else if (expenses.isEmpty)
                const FinanceEmptyState(
                  icon: Symbols.receipt_long_rounded,
                  title: 'Aucune dépense',
                  message:
                      'Les charges de transport, internet et fonctionnement apparaîtront ici.',
                )
              else
                ...expenses.map(
                  (FinanceExpense item) => Container(
                    margin: const EdgeInsets.only(bottom: 9),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: IzyTelColors.surface,
                      borderRadius: BorderRadius.circular(IzyTelRadii.card),
                      border: Border.all(color: IzyTelColors.outline),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: IzyTelColors.warning.withAlpha(18),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Symbols.receipt_long_rounded,
                            color: IzyTelColors.warning,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${item.category.label} · ${item.channel.label} · ${financeDateTime(item.spentAt)}',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: IzyTelColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '-${formatCfa(item.amount)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: IzyTelColors.warning,
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
