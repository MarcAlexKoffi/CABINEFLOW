import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/commissions/domain/repositories/commission_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CommissionPayoutSheet extends StatefulWidget {
  const CommissionPayoutSheet({
    super.key,
    required this.user,
    required this.repository,
    required this.agentId,
    required this.agentName,
    required this.availableBalance,
  });

  final AppUser user;
  final CommissionRepository repository;
  final String agentId;
  final String agentName;
  final int availableBalance;

  @override
  State<CommissionPayoutSheet> createState() => _CommissionPayoutSheetState();
}

class _CommissionPayoutSheetState extends State<CommissionPayoutSheet> {
  late final TextEditingController _amountController;
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: '${widget.availableBalance}',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int get _amount => int.tryParse(_amountController.text.trim()) ?? 0;

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final int amount = _amount;
    final String reference = _referenceController.text.trim();
    if (amount <= 0 || amount > widget.availableBalance) {
      setState(() {
        _errorText =
            'Le montant doit être compris entre 1 F et le solde disponible.';
      });
      return;
    }
    if (reference.length < 3 || reference.length > 120) {
      setState(() {
        _errorText = 'Saisis la référence du paiement Wave.';
      });
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await widget.repository.recordPayout(
        agentId: widget.agentId,
        agentName: widget.agentName,
        amount: amount,
        paymentReference: reference,
        staffId: widget.user.id,
        staffName: widget.user.name,
        note: _noteController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = _friendlyError(error);
      });
    }
  }

  String _friendlyError(Object error) {
    final String text = error.toString();
    if (text.startsWith('StateError: ')) return text.substring(12);
    if (text.startsWith('Invalid argument(s): ')) return text.substring(21);
    if (text.startsWith('ArgumentError: ')) return text.substring(15);
    return 'Impossible d’enregistrer le paiement pour le moment.';
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final int remaining = (widget.availableBalance - _amount)
        .clamp(0, widget.availableBalance)
        .toInt();

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: AppColors.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Payer une commission',
                        style: TextStyle(
                          color: AppColors.onBackground,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary.withAlpha(50),
                        child: Text(
                          _initials(widget.agentName),
                          style: const TextStyle(
                            color: AppColors.primaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Agent',
                              style: TextStyle(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              widget.agentName,
                              style: const TextStyle(
                                color: AppColors.onBackground,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Solde disponible',
                            style: TextStyle(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            formatCfaFull(widget.availableBalance),
                            style: const TextStyle(
                              color: AppColors.primaryContainer,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _Label('Montant à payer'),
                const SizedBox(height: 7),
                TextField(
                  controller: _amountController,
                  enabled: !_isSubmitting,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() => _errorText = null),
                  decoration: const InputDecoration(
                    hintText: '0',
                    suffixIconConstraints: BoxConstraints(minWidth: 72),
                    suffixIcon: Padding(
                      padding: EdgeInsets.only(right: 14),
                      child: Align(
                        alignment: Alignment.centerRight,
                        widthFactor: 1,
                        child: Text(
                          'F CFA',
                          style: TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _Label('Moyen de paiement'),
                const SizedBox(height: 7),
                const _ReadOnlyField(
                  value: 'Wave',
                  icon: Icons.account_balance_wallet_outlined,
                ),
                const SizedBox(height: 14),
                _Label('Référence du paiement Wave'),
                const SizedBox(height: 7),
                TextField(
                  controller: _referenceController,
                  enabled: !_isSubmitting,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    hintText: 'Ex. WAVE-29AUG-845921',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 14),
                _Label('Note interne', trailing: 'Facultatif'),
                const SizedBox(height: 7),
                TextField(
                  controller: _noteController,
                  enabled: !_isSubmitting,
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Ex. Paiement commissions août',
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorText!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      _SummaryRow(label: 'Agent', value: widget.agentName),
                      const Divider(height: 22),
                      const _SummaryRow(label: 'Moyen', value: 'Wave'),
                      const Divider(height: 22),
                      _SummaryRow(
                        label: 'Montant à déduire',
                        value: '- ${formatCfa(_amount)}',
                        valueColor: AppColors.error,
                      ),
                      const Divider(height: 22),
                      _SummaryRow(
                        label: 'Solde restant estimé',
                        value: formatCfa(remaining),
                        valueColor: AppColors.primaryContainer,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.primaryContainer,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Effectue d’abord réellement le paiement dans Wave. IzyTel enregistre ensuite la référence et conserve l’historique sans supprimer les commissions originales.',
                        style: TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Confirmer le paiement'),
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

class _Label extends StatelessWidget {
  const _Label(this.label, {this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
      ],
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.value, required this.icon});

  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryContainer),
          const SizedBox(width: 9),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.onBackground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? AppColors.onBackground,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

String _initials(String name) {
  final List<String> words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((String value) => value.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
  return '${words.first.substring(0, 1)}${words.last.substring(0, 1)}'
      .toUpperCase();
}
