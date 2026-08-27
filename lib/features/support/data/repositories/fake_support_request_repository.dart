import 'dart:async';

import 'package:cabine_flow/features/support/domain/models/support_request.dart';
import 'package:cabine_flow/features/support/domain/repositories/support_request_repository.dart';

class FakeSupportRequestRepository implements SupportRequestRepository {
  final List<SupportRequest> _requests = <SupportRequest>[];
  final StreamController<List<SupportRequest>> _controller =
      StreamController<List<SupportRequest>>.broadcast();
  int _counter = 0;

  List<SupportRequest> get requests =>
      List<SupportRequest>.unmodifiable(_requests);

  @override
  Future<SupportRequest> create({
    required String orderId,
    required String orderReference,
    required SupportRequestType type,
    required String description,
  }) async {
    final String cleanedOrderId = orderId.trim();
    final String cleanedReference = orderReference.trim().toUpperCase();
    final String cleanedDescription = description.trim();

    if (cleanedOrderId.isEmpty || cleanedReference.length < 8) {
      throw ArgumentError('La commande associée est invalide.');
    }
    if (cleanedDescription.length > 1000) {
      throw ArgumentError('La description est trop longue.');
    }
    if (type == SupportRequestType.other && cleanedDescription.length < 3) {
      throw ArgumentError('Précisez le problème en quelques mots.');
    }

    final DateTime now = DateTime.now();
    final SupportRequest request = SupportRequest(
      id: 'support-${++_counter}',
      orderId: cleanedOrderId,
      orderReference: cleanedReference,
      customerAuthUid: 'fake-customer',
      type: type,
      description: cleanedDescription,
      status: SupportRequestStatus.newRequest,
      createdAt: now,
      updatedAt: now,
    );
    _requests.add(request);
    _emit();
    return request;
  }

  @override
  Stream<List<SupportRequest>> watchNewRequests() async* {
    List<SupportRequest> current() =>
        _requests
            .where(
              (SupportRequest request) =>
                  request.status == SupportRequestStatus.newRequest,
            )
            .toList(growable: false)
          ..sort(
            (SupportRequest a, SupportRequest b) =>
                b.createdAt.compareTo(a.createdAt),
          );

    yield current();
    yield* _controller.stream.map((_) => current());
  }

  @override
  Stream<List<SupportRequest>> watchForOrder({required String orderId}) async* {
    yield _forOrder(orderId);
    yield* _controller.stream.map((_) => _forOrder(orderId));
  }

  List<SupportRequest> _forOrder(String orderId) {
    final List<SupportRequest> values =
        _requests
            .where((SupportRequest request) => request.orderId == orderId)
            .toList(growable: false)
          ..sort(
            (SupportRequest a, SupportRequest b) =>
                b.createdAt.compareTo(a.createdAt),
          );
    return values;
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(List<SupportRequest>.unmodifiable(_requests));
    }
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
