import 'dart:async';

import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';
import 'package:cabine_flow/features/refunds/domain/repositories/refund_repository.dart';

class FakeRefundRepository implements RefundRepository {
  final Map<String, RefundCase> _refunds = <String, RefundCase>{};
  final StreamController<void> _controller = StreamController<void>.broadcast();

  List<RefundCase> get refunds => _sorted(_refunds.values);

  @override
  Stream<List<RefundCase>> watchAll() async* {
    yield refunds;
    yield* _controller.stream.map((_) => refunds);
  }

  @override
  Stream<RefundCase?> watchForOrder({required String orderId}) async* {
    yield _refunds[orderId.trim()];
    yield* _controller.stream.map((_) => _refunds[orderId.trim()]);
  }

  @override
  Future<RefundCase> create({
    required RefundCreationRequest request,
    required String staffId,
    required String staffName,
  }) async {
    final String orderId = request.orderId.trim();
    if (_refunds.containsKey(orderId)) {
      throw StateError('Un remboursement existe déjà pour cette commande.');
    }
    if (request.amount <= 0 || request.amount > request.originalAmount) {
      throw ArgumentError('Le montant à rembourser est invalide.');
    }
    final String reasonNote = request.reasonNote.trim();
    if (request.reason == RefundReason.other && reasonNote.length < 3) {
      throw ArgumentError('Précisez le motif du remboursement.');
    }

    final DateTime now = DateTime.now();
    final RefundCase value = RefundCase(
      id: orderId,
      orderId: orderId,
      orderReference: request.orderReference.trim().toUpperCase(),
      supportRequestId: request.supportRequestId.trim(),
      supportRequestType: request.supportRequestType.trim(),
      supportRequestDescription: request.supportRequestDescription.trim(),
      customerAuthUid: request.customerAuthUid,
      clientName: request.clientName.trim(),
      clientWhatsappPhone: request.clientWhatsappPhone.trim(),
      originalAmount: request.originalAmount,
      amount: request.amount,
      reason: request.reason,
      reasonNote: reasonNote,
      paymentChannel: 'wave',
      originalPaymentReference: request.originalPaymentReference,
      status: RefundStatus.pendingApproval,
      requestedAt: now,
      requestedBy: staffId.trim(),
      requestedByName: staffName.trim(),
      updatedAt: now,
    );
    _refunds[orderId] = value;
    _emit();
    return value;
  }

  @override
  Future<void> approve({
    required String orderId,
    required String staffId,
    required String staffName,
  }) async {
    _update(
      orderId,
      expected: RefundStatus.pendingApproval,
      update: (RefundCase value) => value.copyWith(
        status: RefundStatus.approved,
        approvedAt: DateTime.now(),
        approvedBy: staffId,
        approvedByName: staffName,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> reject({
    required String orderId,
    required String staffId,
    required String staffName,
    required String reason,
  }) async {
    final String cleanedReason = reason.trim();
    if (cleanedReason.length < 3) {
      throw ArgumentError('Précisez pourquoi le remboursement est rejeté.');
    }
    _update(
      orderId,
      expected: RefundStatus.pendingApproval,
      update: (RefundCase value) => value.copyWith(
        status: RefundStatus.rejected,
        rejectedAt: DateTime.now(),
        rejectedBy: staffId,
        rejectedByName: staffName,
        rejectionReason: cleanedReason,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> markRefunded({
    required String orderId,
    required String staffId,
    required String staffName,
    required String refundReference,
  }) async {
    final String cleanedReference = refundReference.trim();
    if (cleanedReference.length < 3) {
      throw ArgumentError('Saisissez la référence du remboursement Wave.');
    }
    _update(
      orderId,
      expected: RefundStatus.approved,
      update: (RefundCase value) => value.copyWith(
        status: RefundStatus.refunded,
        refundReference: cleanedReference,
        refundedAt: DateTime.now(),
        refundedBy: staffId,
        refundedByName: staffName,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> markCustomerNotified({
    required String orderId,
    required String staffId,
    required String staffName,
  }) async {
    final RefundCase value = _required(orderId);
    if (!value.isRefundCompleted) {
      throw StateError('Le remboursement n’est pas encore effectué.');
    }
    _refunds[orderId.trim()] = value.copyWith(
      customerNotifiedAt: DateTime.now(),
      customerNotifiedBy: staffId,
      customerNotifiedByName: staffName,
      notificationChannel: 'whatsapp',
      updatedAt: DateTime.now(),
    );
    _emit();
  }

  @override
  Future<void> reconcile({
    required String orderId,
    required String staffId,
    required String staffName,
  }) async {
    _update(
      orderId,
      expected: RefundStatus.refunded,
      update: (RefundCase value) => value.copyWith(
        status: RefundStatus.reconciled,
        reconciledAt: DateTime.now(),
        reconciledBy: staffId,
        reconciledByName: staffName,
        updatedAt: DateTime.now(),
      ),
    );
  }

  void _update(
    String orderId, {
    required RefundStatus expected,
    required RefundCase Function(RefundCase value) update,
  }) {
    final RefundCase value = _required(orderId);
    if (value.status != expected) {
      throw StateError('Transition de remboursement invalide.');
    }
    _refunds[orderId.trim()] = update(value);
    _emit();
  }

  RefundCase _required(String orderId) {
    final RefundCase? value = _refunds[orderId.trim()];
    if (value == null) {
      throw StateError('Remboursement introuvable.');
    }
    return value;
  }

  List<RefundCase> _sorted(Iterable<RefundCase> values) {
    final List<RefundCase> result = values.toList(growable: false);
    result.sort(
      (RefundCase a, RefundCase b) => b.requestedAt.compareTo(a.requestedAt),
    );
    return result;
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  Future<void> dispose() => _controller.close();
}
