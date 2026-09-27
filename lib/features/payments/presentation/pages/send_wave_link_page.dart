import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/messaging/data/services/customer_messaging_delivery_service.dart';
import 'package:cabine_flow/features/payments/domain/repositories/payment_link_repository.dart';
import 'package:cabine_flow/features/payments/presentation/view_models/payment_request_view_model.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SendWaveLinkPage extends StatefulWidget {
  const SendWaveLinkPage({
    super.key,
    required this.order,
    required this.ordersRepository,
    required this.paymentLinkRepository,
  });

  final QueueOrder order;
  final OrdersRepository ordersRepository;
  final PaymentLinkRepository paymentLinkRepository;

  @override
  State<SendWaveLinkPage> createState() {
    return _SendWaveLinkPageState();
  }
}

class _SendWaveLinkPageState extends State<SendWaveLinkPage> {
  late final PaymentRequestViewModel _viewModel;

  @override
  void initState() {
    super.initState();

    _viewModel = PaymentRequestViewModel(
      order: widget.order,
      paymentLinkRepository: widget.paymentLinkRepository,
      ordersRepository: widget.ordersRepository,
    );

    _viewModel.initialize();
  }

  @override
  void dispose() {
    _viewModel.dispose();

    super.dispose();
  }


  Future<void> _copyPaymentLink() async {
    final String? paymentLink = _viewModel.paymentLinkData?.url;

    if (paymentLink == null) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: paymentLink));

    if (!mounted) {
      return;
    }

    _showMessage('Lien Wave copié.');
  }

  Future<void> _copyPaymentMessage() async {
    await Clipboard.setData(ClipboardData(text: _viewModel.paymentMessage));

    if (!mounted) {
      return;
    }

    _showMessage('Message de paiement copié.');
  }

  Future<void> _sendPaymentMessage() async {
    try {
      await CustomerMessagingDeliveryService().notifyOrder(
        orderId: widget.order.id,
        orderReference: widget.order.reference,
        message: _viewModel.paymentMessage,
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('Impossible d’envoyer le lien dans la messagerie IzyTel : $error');
      return;
    }

    final bool successful = await _viewModel.markPaymentRequestAsSent();
    if (!mounted) return;
    if (!successful) {
      _showMessage(
        _viewModel.errorMessage ?? 'Le message est parti, mais son enregistrement a échoué.',
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  void _showMessage(String message) {
    IzyTelFeedback.show(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          backgroundColor: IzyTelColors.background,
          body: SafeArea(
            child: Column(
              children: [
                _WaveTopBar(
                  onBackPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                Divider(
                  height: 1,
                  color: IzyTelColors.outline,
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.errorMessage != null && _viewModel.paymentLinkData == null) {
      return _WaveErrorState(
        message: _viewModel.errorMessage!,
        onRetry: _viewModel.initialize,
      );
    }

    final String paymentLink = _viewModel.paymentLinkData?.url ?? '';


    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'COMMANDE #${widget.order.reference}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: IzyTelColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${formatCfa(widget.order.amount)} CFA',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: IzyTelColors.primary,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 18,
                color: IzyTelColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.order.clientName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: IzyTelColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'APERÇU DU MESSAGE',
            style: TextStyle(
              color: IzyTelColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: IzyTelColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border(
                left: const BorderSide(color: IzyTelColors.primary, width: 4),
                top: BorderSide(color: IzyTelColors.outline),
                right: BorderSide(
                  color: IzyTelColors.outline,
                ),
                bottom: BorderSide(
                  color: IzyTelColors.outline,
                ),
              ),
            ),
            child: Text(
              _viewModel.paymentMessage.trim().isEmpty
                  ? 'Le message de paiement n’a pas pu être généré.'
                  : _viewModel.paymentMessage,
              softWrap: true,
              overflow: TextOverflow.visible,
              style: const TextStyle(
                color: IzyTelColors.textPrimary,
                fontSize: 14,
                height: 1.55,
              ),
            ),
          ),
          const SizedBox(height: 22),
          _WaveLinkCard(
            paymentLink: paymentLink,
            onCopyPressed: _copyPaymentLink,
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _viewModel.isSubmitting ? null : _sendPaymentMessage,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            icon: _viewModel.isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.forum_rounded),
            label: Text(
              _viewModel.isSubmitting
                  ? 'Envoi en cours...'
                  : 'Envoyer dans la messagerie IzyTel',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _viewModel.isSubmitting ? null : _copyPaymentMessage,
            icon: const Icon(Icons.content_copy_rounded, size: 18),
            label: const Text('Copier le message'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _viewModel.isSubmitting
                ? null
                : () {
                    Navigator.of(context).pop(false);
                  },
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }
}

class _WaveTopBar extends StatelessWidget {
  const _WaveTopBar({required this.onBackPressed});

  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: IzyTelColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Retour',
            onPressed: onBackPressed,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: IzyTelColors.primary,
            ),
          ),
          Expanded(
            child: Text(
              'Envoi du lien Wave',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: IzyTelColors.textPrimary,
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

class _WaveLinkCard extends StatelessWidget {
  const _WaveLinkCard({required this.paymentLink, required this.onCopyPressed});

  final String paymentLink;
  final VoidCallback onCopyPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: IzyTelColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IzyTelColors.outline),
        boxShadow: const [
          BoxShadow(
            color: IzyTelColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: Color(0x2216BDF0),
                child: Icon(
                  Icons.link_rounded,
                  color: Color(0xFF16BDF0),
                  size: 19,
                ),
              ),
              SizedBox(width: 10),
              Text(
                'Lien de paiement',
                style: TextStyle(
                  color: IzyTelColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(
              left: 12,
              top: 5,
              bottom: 5,
              right: 4,
            ),
            decoration: BoxDecoration(
              color: IzyTelColors.surface,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: IzyTelColors.outline),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    paymentLink,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: IzyTelColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copier le lien',
                  onPressed: onCopyPressed,
                  icon: const Icon(
                    Icons.content_copy_rounded,
                    color: IzyTelColors.primary,
                    size: 19,
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

class _WaveErrorState extends StatelessWidget {
  const _WaveErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.link_off_rounded,
              size: 48,
              color: IzyTelColors.error,
            ),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
