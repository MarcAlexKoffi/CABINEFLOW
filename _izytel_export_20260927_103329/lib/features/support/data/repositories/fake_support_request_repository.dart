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
    yield _filter(<SupportRequestStatus>{SupportRequestStatus.newRequest});
    yield* _controller.stream.map(
      (_) => _filter(<SupportRequestStatus>{SupportRequestStatus.newRequest}),
    );
  }

  @override
  Stream<List<SupportRequest>> watchAllRequests() async* {
    yield _sorted(_requests);
    yield* _controller.stream.map((_) => _sorted(_requests));
  }

  @override
  Stream<List<SupportRequest>> watchForOrder({required String orderId}) async* {
    yield _forOrder(orderId);
    yield* _controller.stream.map((_) => _forOrder(orderId));
  }

  @override
  Future<void> takeInCharge({
    required String requestId,
    required String staffId,
    required String staffName,
  }) async {
    _replace(
      requestId,
      (SupportRequest value) => value.copyWith(
        status: SupportRequestStatus.inProgress,
        updatedAt: DateTime.now(),
        assignedTo: staffId,
        assignedToName: staffName,
        inProgressAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> resolve({
    required String requestId,
    required String staffId,
    required String staffName,
    required String resolutionNote,
  }) async {
    final String note = resolutionNote.trim();
    if (note.length < 3) {
      throw ArgumentError('Ajoutez une note de résolution.');
    }
    _replace(
      requestId,
      (SupportRequest value) => value.copyWith(
        status: SupportRequestStatus.resolved,
        updatedAt: DateTime.now(),
        resolutionNote: note,
        resolvedAt: DateTime.now(),
        resolvedBy: staffId,
        resolvedByName: staffName,
      ),
    );
  }

  @override
  Future<void> markCustomerNotified({
    required String requestId,
    required String staffId,
    required String staffName,
  }) async {
    _replace(
      requestId,
      (SupportRequest value) => value.copyWith(
        updatedAt: DateTime.now(),
        customerNotifiedAt: DateTime.now(),
        customerNotifiedBy: staffId,
        customerNotifiedByName: staffName,
        notificationChannel: 'whatsapp',
      ),
    );
  }

  @override
  Future<void> close({
    required String requestId,
    required String staffId,
    required String staffName,
  }) async {
    _replace(
      requestId,
      (SupportRequest value) => value.copyWith(
        status: SupportRequestStatus.closed,
        updatedAt: DateTime.now(),
        closedAt: DateTime.now(),
        closedBy: staffId,
        closedByName: staffName,
      ),
    );
  }

  List<SupportRequest> _filter(Set<SupportRequestStatus> statuses) {
    return _sorted(
      _requests.where(
        (SupportRequest request) => statuses.contains(request.status),
      ),
    );
  }

  List<SupportRequest> _forOrder(String orderId) {
    return _sorted(
      _requests.where((SupportRequest request) => request.orderId == orderId),
    );
  }

  List<SupportRequest> _sorted(Iterable<SupportRequest> source) {
    final List<SupportRequest> values = source.toList(growable: false);
    values.sort(
      (SupportRequest a, SupportRequest b) =>
          b.createdAt.compareTo(a.createdAt),
    );
    return values;
  }

  void _replace(
    String requestId,
    SupportRequest Function(SupportRequest value) update,
  ) {
    final int index = _requests.indexWhere(
      (SupportRequest request) => request.id == requestId,
    );
    if (index < 0) {
      throw StateError('Demande introuvable.');
    }
    _requests[index] = update(_requests[index]);
    _emit();
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
