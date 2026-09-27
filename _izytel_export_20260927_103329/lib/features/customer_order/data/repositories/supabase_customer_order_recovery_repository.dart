import 'dart:async';

import 'package:cabine_flow/core/resilience/backend_failure_policy.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_draft.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_recovery_key.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Registre de recuperation WC2.
///
/// Supabase porte le secret de recuperation et l'autorisation publique.
/// Firestore conserve uniquement son role legacy/pre-sync deja valide et ne
/// recoit aucun nouveau champ ni aucune nouvelle regle pour WC2.
class SupabaseCustomerOrderRecoveryRepository {
  SupabaseCustomerOrderRecoveryRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const Duration pollInterval = Duration(seconds: 3);

  final SupabaseClient _client;

  Future<void> register({
    required CustomerOrderReceipt order,
    required String recoveryCode,
  }) async {
    final CustomerOrderDraft draft = order.draft;
    final String normalizedReference =
        CustomerOrderRecoveryKey.normalizeReference(order.reference);
    final String normalizedCode = CustomerOrderRecoveryKey.normalizeCode(
      recoveryCode,
    );

    if (CustomerOrderRecoveryKey.validateReference(normalizedReference) !=
            null ||
        CustomerOrderRecoveryKey.validateCode(normalizedCode) != null) {
      throw const FormatException('Informations de recuperation invalides.');
    }

    final Object? result = await _client.rpc(
      'izytel_wc2_register_customer_recovery',
      params: <String, dynamic>{
        'p_payload': <String, dynamic>{
          'order_id': order.id.trim(),
          'order_reference': normalizedReference,
          'service': draft.service!.name,
          'network': draft.network!.name,
          'operation_type': _operationTypeValue(draft),
          'offer_id': draft.offer?.id,
          'offer_label': draft.selectedOfferLabel,
          'is_custom_offer': draft.usesCustomOffer,
          'amount': draft.amount,
          'beneficiary_phone': draft.beneficiaryNumber!.normalized,
          'created_at': order.createdAt.toUtc().toIso8601String(),
          'expires_at': order.expiresAt.toUtc().toIso8601String(),
          'order_status': order.status.name,
          'payment_status': order.paymentStatus.name,
          'payment_declared_at': order.paymentDeclaredAt?.toUtc().toIso8601String(),
          'payment_confirmed_at': order.paymentConfirmedAt?.toUtc().toIso8601String(),
          'expired_at': order.expiredAt?.toUtc().toIso8601String(),
        },
        'p_recovery_code': normalizedCode,
      },
    );

    if (result == null) {
      throw StateError('Enregistrement du code de recuperation impossible.');
    }
  }

  Future<Map<String, dynamic>?> recover({
    required String reference,
    required String recoveryCode,
  }) async {
    final String normalizedReference =
        CustomerOrderRecoveryKey.normalizeReference(reference);
    final String normalizedCode = CustomerOrderRecoveryKey.normalizeCode(
      recoveryCode,
    );

    if (CustomerOrderRecoveryKey.validateReference(normalizedReference) !=
            null ||
        CustomerOrderRecoveryKey.validateCode(normalizedCode) != null) {
      return null;
    }

    final Object? raw = await _client.rpc(
      'izytel_wc2_recover_customer_order',
      params: <String, dynamic>{
        'p_reference': normalizedReference,
        'p_recovery_code': normalizedCode,
      },
    );

    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw StateError('Reponse de recuperation Supabase invalide.');
  }

  Stream<Map<String, dynamic>> watch({
    required String reference,
    required String recoveryCode,
  }) async* {
    Map<String, dynamic>? lastKnown;
    int failures = 0;

    while (true) {
      try {
        final Map<String, dynamic>? current = await recover(
          reference: reference,
          recoveryCode: recoveryCode,
        );
        if (current == null) {
          throw StateError('Commande recuperee introuvable.');
        }
        lastKnown = current;
        failures = 0;
        yield current;
        await Future<void>.delayed(pollInterval);
      } catch (error) {
        if (!BackendFailurePolicy.canRetryRead(error) || lastKnown == null) {
          rethrow;
        }
        yield lastKnown;
        await Future<void>.delayed(
          BackendFailurePolicy.retryDelay(
            baseDelay: pollInterval,
            consecutiveFailures: failures++,
          ),
        );
      }
    }
  }

  String _operationTypeValue(CustomerOrderDraft draft) {
    switch (draft.service!) {
      case CustomerService.unitTransfer:
        return OrderOperationType.unitTransfer.name;
      case CustomerService.internetSubscription:
        return OrderOperationType.internetSubscription.name;
      case CustomerService.calls:
        final bool isMixedOffer =
            draft.offer?.badgeLabel?.toLowerCase() == 'mixte';
        return isMixedOffer
            ? OrderOperationType.mixedBundle.name
            : OrderOperationType.callBundle.name;
    }
  }
}
