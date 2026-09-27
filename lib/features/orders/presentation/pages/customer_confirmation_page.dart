import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';

/// Écran conservé uniquement pour compatibilité avec d'anciens parcours.
///
/// Le traitement WC5 ne permet plus à l'Agent de contacter directement le
/// client. La notification de fin de commande est gérée automatiquement par
/// la messagerie IzyTel et routée vers le territoire concerné.
class CustomerConfirmationPage extends StatefulWidget {
  const CustomerConfirmationPage({
    super.key,
    required this.order,
    required this.onComplete,
  });

  final QueueOrder order;
  final Future<bool> Function(bool messageSent) onComplete;

  @override
  State<CustomerConfirmationPage> createState() =>
      _CustomerConfirmationPageState();
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

  Future<void> _finish() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    // `true` signifie ici que la confirmation client est prise en charge par
    // le circuit IzyTel. Aucun envoi manuel par l'Agent n'est nécessaire.
    final bool isSuccessful = await widget.onComplete(true);

    if (!mounted) return;

    if (isSuccessful) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() => _isSubmitting = false);
    IzyTelFeedback.error(context, 'Impossible de clôturer la commande.');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      child: Scaffold(
        backgroundColor: IzyTelColors.background,
        appBar: AppBar(
          backgroundColor: IzyTelColors.background,
          surfaceTintColor: Colors.transparent,
          title: const Text('Commande terminée'),
        ),
        body: SafeArea(
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
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: IzyTelColors.outline),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.notifications_active_rounded,
                        color: IzyTelColors.primary,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Le client sera informé automatiquement dans IzyTel. '
                          'Aucune action de communication n’est requise de la '
                          'part de l’Agent.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _finish,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(
                    _isSubmitting ? 'Clôture en cours...' : 'Terminer',
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

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: IzyTelColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: IzyTelColors.primary,
            size: 30,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'La transaction a été réalisée avec succès.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: IzyTelColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                networkLogoAsset,
                width: 34,
                height: 34,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  networkLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SummaryLine(label: 'Référence', value: order.reference),
          _SummaryLine(label: 'Bénéficiaire', value: order.beneficiaryPhone),
          _SummaryLine(label: 'Offre', value: order.offerLabel),
          _SummaryLine(
            label: 'Montant',
            value: '${formatCfa(order.amount)} CFA',
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(color: IzyTelColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
