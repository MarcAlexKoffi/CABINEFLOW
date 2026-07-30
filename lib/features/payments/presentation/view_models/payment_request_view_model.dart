import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/payments/domain/models/payment_link_data.dart';
import 'package:cabine_flow/features/payments/domain/repositories/payment_link_repository.dart';
import 'package:flutter/foundation.dart';

class PaymentRequestViewModel extends ChangeNotifier {
  PaymentRequestViewModel({
    required this.order,
    required PaymentLinkRepository paymentLinkRepository,
    required OrdersRepository ordersRepository,
  })  : _paymentLinkRepository = paymentLinkRepository,
        _ordersRepository = ordersRepository;

  final QueueOrder order;

  final PaymentLinkRepository _paymentLinkRepository;
  final OrdersRepository _ordersRepository;

  PaymentLinkData? _paymentLinkData;

  bool _isLoading = false;
  bool _isSubmitting = false;

  String? _errorMessage;

  PaymentLinkData? get paymentLinkData {
    return _paymentLinkData;
  }

  bool get isLoading {
    return _isLoading;
  }

  bool get isSubmitting {
    return _isSubmitting;
  }

  String? get errorMessage {
    return _errorMessage;
  }

  String get networkLabel {
    switch (order.network) {
      case MobileNetwork.orange:
        return 'Orange';

      case MobileNetwork.mtn:
        return 'MTN';

      case MobileNetwork.moov:
        return 'Moov';
    }
  }

  String get paymentMessage {
    final PaymentLinkData? linkData = _paymentLinkData;

    if (linkData == null || linkData.url.trim().isEmpty) {
      return 'Le lien de paiement est en cours de préparation.';
    }

    return 'Votre commande #${order.reference} '
        'a été enregistrée.\n\n'
        'Réseau : $networkLabel\n'
        'Numéro bénéficiaire : ${order.beneficiaryPhone}\n'
        'Offre : ${order.offerLabel}\n'
        'Montant : ${formatCfa(order.amount)} F CFA\n\n'
        'Veuillez payer ${linkData.merchantDisplayName} '
        '${formatCfa(order.amount)} F avec Wave '
        'en cliquant sur ce lien :\n'
        '${linkData.url}\n\n'
        'Ajoutez cet expéditeur à vos contacts '
        'pour rendre le lien cliquable.';
  }

  Future<void> initialize() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      _paymentLinkData = await _paymentLinkRepository.preparePaymentLink(
        order: order,
      );
    } catch (_) {
      _errorMessage = 'Impossible de préparer le lien Wave.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> markPaymentRequestAsSent() async {
    if (_isSubmitting) {
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;

    notifyListeners();

    try {
      await _ordersRepository.markPaymentRequestSent(
        orderId: order.id,
      );

      return true;
    } catch (error) {
      _errorMessage = error is StateError
          ? error.message.toString()
          : 'Impossible d’enregistrer l’envoi du lien.';

      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}