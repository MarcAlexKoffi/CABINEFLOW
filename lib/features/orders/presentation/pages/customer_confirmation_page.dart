import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerConfirmationPage extends StatefulWidget {
  const CustomerConfirmationPage({
    super.key,
    required this.order,
    required this.onComplete,
  });

  final QueueOrder order;

  // true  = message envoyé
  // false = parcours terminé sans envoi
  final Future<bool> Function(bool messageSent) onComplete;

  @override
  State<CustomerConfirmationPage> createState() {
    return _CustomerConfirmationPageState();
  }
}

class _CustomerConfirmationPageState extends State<CustomerConfirmationPage> {
  bool _isSubmitting = false;

  String get _networkLabel {
    switch (widget.order.network) {
      case MobileNetwork.orange:
        return 'Orange';

      case MobileNetwork.mtn:
        return 'MTN';

      case MobileNetwork.moov:
        return 'Moov';
    }
  }

  String get _networkLogoAsset {
    switch (widget.order.network) {
      case MobileNetwork.orange:
        return 'assets/images/orange_logo.png';
      case MobileNetwork.mtn:
        return 'assets/images/mtn_logo.png';
      case MobileNetwork.moov:
        return 'assets/images/moov_logo.png';
    }
  }

  String get _message {
    return 'Votre commande ${widget.order.reference} '
        'a été réalisée avec succès.\n\n'
        'Réseau : $_networkLabel\n'
        'Numéro : ${widget.order.beneficiaryPhone}\n'
        'Offre : ${widget.order.offerLabel}\n'
        'Montant : ${formatCfa(widget.order.amount)} CFA\n\n'
        'Merci pour votre confiance.';
  }

  String get _normalizedWhatsappPhone {
    String digits = widget.order.clientWhatsappPhone.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    if (digits.startsWith('225')) {
      return digits;
    }

    if (digits.startsWith('0')) {
      return '225$digits';
    }

    return digits;
  }

  Future<void> _copyMessage() async {
    await Clipboard.setData(ClipboardData(text: _message));

    if (!mounted) {
      return;
    }

    IzyTelFeedback.success(context, 'Message copié.');
  }

  Future<bool> _openWhatsapp() async {
    final Uri whatsappUri = Uri.https(
      'wa.me',
      '/$_normalizedWhatsappPhone',
      <String, String>{'text': _message},
    );

    final bool wasOpened = await launchUrl(
      whatsappUri,
      mode: LaunchMode.externalApplication,
    );

    if (!mounted) {
      return wasOpened;
    }

    if (!wasOpened) {
      IzyTelFeedback.error(context, 'Impossible d’ouvrir WhatsApp.');
    }

    return wasOpened;
  }

  Future<void> _confirmMessageSent() async {
    final bool? isConfirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Message envoyé'),
          content: Text(
            'Confirme que le message de la commande '
            '${widget.order.reference} a bien été envoyé au client.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Confirmer'),
            ),
          ],
        );
      },
    );

    if (isConfirmed == true) {
      await _finish(messageSent: true);
    }
  }

  Future<void> _confirmFinishWithoutSending() async {
    final bool? isConfirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Terminer sans envoyer'),
          content: const Text(
            'La commande sera clôturée sans confirmation '
            'envoyée au client. Continuer ?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Terminer'),
            ),
          ],
        );
      },
    );

    if (isConfirmed == true) {
      await _finish(messageSent: false);
    }
  }

  Future<void> _finish({required bool messageSent}) async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final bool isSuccessful = await widget.onComplete(messageSent);

    if (!mounted) {
      return;
    }

    if (isSuccessful) {
      Navigator.of(context).pop(messageSent);
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    IzyTelFeedback.error(context, 'Impossible de clôturer la commande.');
  }

  Future<void> _handleBackButton() async {
    if (_isSubmitting) {
      return;
    }

    await _confirmFinishWithoutSending();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (!didPop) {
          await _handleBackButton();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _ConfirmationTopBar(onBackPressed: _handleBackButton),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _SuccessBanner(),
                      const SizedBox(height: 20),
                      _OrderSummaryCard(
                        order: widget.order,
                        networkLabel: _networkLabel,
                        networkLogoAsset: _networkLogoAsset,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'APERÇU DU MESSAGE',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.outline,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _MessagePreview(message: _message),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isSubmitting ? null : _copyMessage,
                              icon: const Icon(
                                Icons.content_copy_rounded,
                                size: 18,
                              ),
                              label: const Text('Copier'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isSubmitting ? null : _openWhatsapp,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF25D366),
                                side: const BorderSide(
                                  color: Color(0x5525D366),
                                ),
                              ),
                              icon: const Icon(Icons.chat_rounded, size: 18),
                              label: const Text('WhatsApp'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _isSubmitting ? null : _confirmMessageSent,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 19,
                                height: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.onPrimary,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(
                          _isSubmitting
                              ? 'Clôture en cours...'
                              : 'Envoyer au client',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : _confirmFinishWithoutSending,
                        child: const Text(
                          'Terminer sans envoyer',
                          style: TextStyle(color: AppColors.outline),
                        ),
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

class _ConfirmationTopBar extends StatelessWidget {
  const _ConfirmationTopBar({required this.onBackPressed});

  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Retour',
            onPressed: onBackPressed,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.primary,
            ),
          ),
          Expanded(
            child: Text(
              'Confirmation Client',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(50)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0x2200A85A),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 34,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Transaction Réussie',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 5),
          Text(
            'L’opération a été enregistrée avec succès.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.outline),
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({
    required this.order,
    required this.networkLabel,
    required this.networkLogoAsset,
  });

  final QueueOrder order;
  final String networkLabel;
  final String networkLogoAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(100)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: AppColors.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'RÉFÉRENCE',
                    style: TextStyle(
                      color: AppColors.outline,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '#${order.reference}',
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _SummaryRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Client',
                  value: order.clientName,
                ),
                _SummaryDivider(),
                _SummaryRow(
                  icon: Icons.cell_tower_rounded,
                  label: 'Réseau',
                  valueWidget: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Image.asset(networkLogoAsset, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        networkLabel,
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _SummaryDivider(),
                _SummaryRow(
                  icon: Icons.phone_android_rounded,
                  label: 'Destinataire',
                  value: order.beneficiaryPhone,
                ),
                _SummaryDivider(),
                _SummaryRow(
                  icon: Icons.inventory_2_outlined,
                  label: 'Offre',
                  value: order.offerLabel,
                ),
                _SummaryDivider(),
                _SummaryRow(
                  icon: Icons.payments_outlined,
                  label: 'Montant',
                  value: '${formatCfa(order.amount)} CFA',
                  emphasizeValue: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    this.value,
    this.valueWidget,
    this.emphasizeValue = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final Widget? valueWidget;
  final bool emphasizeValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.onSurfaceVariant),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
        Flexible(
          child:
              valueWidget ??
              Text(
                value ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: emphasizeValue
                      ? AppColors.primary
                      : AppColors.onSurface,
                  fontSize: emphasizeValue ? 18 : 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
        ),
      ],
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 25, color: AppColors.surfaceContainerHighest);
  }
}

class _MessagePreview extends StatelessWidget {
  const _MessagePreview({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: SelectableText(
        message,
        style: const TextStyle(
          color: AppColors.onSurface,
          height: 1.55,
          fontSize: 13,
        ),
      ),
    );
  }
}
