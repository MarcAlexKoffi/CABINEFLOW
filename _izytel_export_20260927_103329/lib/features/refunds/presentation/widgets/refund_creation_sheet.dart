import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';
import 'package:cabine_flow/features/support/domain/models/support_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RefundCreationSheet extends StatefulWidget {
  const RefundCreationSheet({
    super.key,
    required this.order,
    required this.supportRequest,
  });

  final QueueOrder order;
  final SupportRequest supportRequest;

  @override
  State<RefundCreationSheet> createState() => _RefundCreationSheetState();
}

class _RefundCreationSheetState extends State<RefundCreationSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late RefundReason _reason;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: '${widget.order.amount}');
    _noteController = TextEditingController();
    _reason = _defaultReason(widget.supportRequest.type);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: IzyTelColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(IzyTelRadii.sheet),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: IzyTelColors.outlineStrong.withAlpha(90),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Créer un remboursement',
                  style: TextStyle(
                    color: IzyTelColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Commande ${widget.order.reference} · ${_formatAmount(widget.order.amount)} F',
                  style: const TextStyle(
                    color: IzyTelColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 18),
                _LabelledField(
                  label: 'Montant à rembourser',
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: const TextStyle(color: IzyTelColors.textPrimary),
                    decoration: _inputDecoration('Ex. ${widget.order.amount}'),
                  ),
                ),
                const SizedBox(height: 14),
                _LabelledField(
                  label: 'Raison du remboursement',
                  child: DropdownButtonFormField<RefundReason>(
                    initialValue: _reason,
                    dropdownColor: IzyTelColors.surfaceMuted,
                    style: const TextStyle(color: IzyTelColors.textPrimary),
                    decoration: _inputDecoration('Choisir une raison'),
                    items: RefundReason.values
                        .map(
                          (RefundReason reason) =>
                              DropdownMenuItem<RefundReason>(
                                value: reason,
                                child: Text(reason.label),
                              ),
                        )
                        .toList(growable: false),
                    onChanged: (RefundReason? value) {
                      if (value == null) return;
                      setState(() {
                        _reason = value;
                        _errorMessage = null;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 14),
                _LabelledField(
                  label: _reason == RefundReason.other
                      ? 'Précision (obligatoire)'
                      : 'Note (facultative)',
                  child: TextField(
                    controller: _noteController,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 500,
                    style: const TextStyle(color: IzyTelColors.textPrimary),
                    decoration: _inputDecoration(
                      'Ajoutez une précision utile pour l’audit.',
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: IzyTelColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: IzyTelColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: IzyTelColors.primary.withAlpha(60),
                    ),
                  ),
                  child: const Text(
                    'Créer ce dossier ne rembourse pas automatiquement le client. Après approbation, le remboursement sera effectué manuellement via Wave puis sa référence sera enregistrée dans IzyTel.',
                    style: TextStyle(
                      color: IzyTelColors.textSecondary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('Créer'),
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

  void _submit() {
    final int? amount = int.tryParse(_amountController.text.trim());
    final String note = _noteController.text.trim();
    if (amount == null || amount <= 0 || amount > widget.order.amount) {
      setState(() {
        _errorMessage =
            'Le montant doit être compris entre 1 F et ${_formatAmount(widget.order.amount)} F.';
      });
      return;
    }
    if (_reason == RefundReason.other && note.length < 3) {
      setState(() {
        _errorMessage = 'Précisez le motif du remboursement.';
      });
      return;
    }
    Navigator.of(context).pop(
      RefundCreationDraft(amount: amount, reason: _reason, reasonNote: note),
    );
  }

  RefundReason _defaultReason(SupportRequestType type) {
    switch (type) {
      case SupportRequestType.completedButNotReceived:
        return RefundReason.serviceNotReceived;
      case SupportRequestType.wrongAmount:
        return RefundReason.wrongAmount;
      case SupportRequestType.wrongNumber:
        return RefundReason.wrongNumber;
      case SupportRequestType.transactionFailed:
        return RefundReason.transactionFailed;
      case SupportRequestType.paymentNotRecognized:
        return RefundReason.paymentIssue;
      case SupportRequestType.other:
        return RefundReason.other;
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: IzyTelColors.surfaceMuted,
      hintStyle: const TextStyle(color: IzyTelColors.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: IzyTelColors.outlineStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: IzyTelColors.primary, width: 1.4),
      ),
    );
  }
}

class _LabelledField extends StatelessWidget {
  const _LabelledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: IzyTelColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        child,
      ],
    );
  }
}

String _formatAmount(int amount) {
  final String value = amount.toString();
  final StringBuffer buffer = StringBuffer();
  for (int index = 0; index < value.length; index += 1) {
    if (index > 0 && (value.length - index) % 3 == 0) {
      buffer.write(' ');
    }
    buffer.write(value[index]);
  }
  return buffer.toString();
}
