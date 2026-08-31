import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/features/support/domain/models/support_request.dart';
import 'package:cabine_flow/features/support/domain/repositories/support_request_repository.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';

class CustomerSupportRequestButton extends StatefulWidget {
  const CustomerSupportRequestButton({
    super.key,
    required this.orderId,
    required this.orderReference,
    required this.repository,
  });

  final String orderId;
  final String orderReference;
  final SupportRequestRepository repository;

  @override
  State<CustomerSupportRequestButton> createState() =>
      _CustomerSupportRequestButtonState();
}

class _CustomerSupportRequestButtonState
    extends State<CustomerSupportRequestButton> {
  bool _isSubmitting = false;

  Future<void> _open() async {
    if (_isSubmitting) {
      return;
    }

    final SupportRequestDraft? draft =
        await showModalBottomSheet<SupportRequestDraft>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) {
            return const _SupportRequestSheet();
          },
        );

    if (!mounted || draft == null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.repository.create(
        orderId: widget.orderId,
        orderReference: widget.orderReference,
        type: draft.type,
        description: draft.description,
      );

      if (!mounted) {
        return;
      }

      IzyTelFeedback.success(
        context,
        'Votre demande concernant ${widget.orderReference} a été envoyée.',
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      debugPrint(
        '[SupportRequest][customer] order=${widget.orderReference} ERROR $error',
      );
      IzyTelFeedback.error(
        context,
        'Impossible d’envoyer la demande pour le moment. Réessayez.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _isSubmitting ? null : _open,
      icon: _isSubmitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.report_problem_outlined),
      label: Text(_isSubmitting ? 'Envoi…' : 'Signaler un problème'),
      style: OutlinedButton.styleFrom(
        foregroundColor: CustomerAppColors.error,
        side: BorderSide(color: CustomerAppColors.error.withAlpha(110)),
        minimumSize: const Size.fromHeight(48),
      ),
    );
  }
}

class _SupportRequestSheet extends StatefulWidget {
  const _SupportRequestSheet();

  @override
  State<_SupportRequestSheet> createState() => _SupportRequestSheetState();
}

class _SupportRequestSheetState extends State<_SupportRequestSheet> {
  final TextEditingController _descriptionController = TextEditingController();
  SupportRequestType _type = SupportRequestType.paymentNotRecognized;
  String? _errorText;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final String description = _descriptionController.text.trim();
    if (_type == SupportRequestType.other && description.length < 3) {
      setState(() {
        _errorText = 'Précisez le problème en quelques mots.';
      });
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(
      context,
    ).pop(SupportRequestDraft(type: _type, description: description));
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bool descriptionRequired = _type == SupportRequestType.other;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 690),
          decoration: const BoxDecoration(
            color: CustomerAppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Signaler un problème',
                            style: TextStyle(
                              color: CustomerAppColors.onSurface,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Choisissez le motif qui correspond le mieux à votre situation.',
                            style: TextStyle(
                              color: CustomerAppColors.onSurfaceVariant,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...SupportRequestType.values.map(
                        (SupportRequestType type) => _ReasonChoice(
                          type: type,
                          isSelected: _type == type,
                          onTap: () {
                            setState(() {
                              _type = type;
                              _errorText = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _descriptionController,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 1000,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: descriptionRequired
                              ? 'Description (obligatoire)'
                              : 'Description (facultatif)',
                          hintText:
                              'Ajoutez les informations utiles au service client…',
                          errorText: _errorText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Envoyer la demande'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReasonChoice extends StatelessWidget {
  const _ReasonChoice({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  final SupportRequestType type;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected
            ? CustomerAppColors.primary.withAlpha(16)
            : CustomerAppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? CustomerAppColors.primary
                    : CustomerAppColors.surfaceContainerHigh,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: isSelected
                      ? CustomerAppColors.primary
                      : CustomerAppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    type.label,
                    style: TextStyle(
                      color: CustomerAppColors.onSurface,
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
