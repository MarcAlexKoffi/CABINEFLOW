import 'package:cabine_flow/features/offers/domain/models/admin_offer.dart';
import 'package:cabine_flow/features/offers/domain/repositories/admin_offer_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreAdminOfferRepository implements AdminOfferRepository {
  FirestoreAdminOfferRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _offers =>
      _firestore.collection('offers');

  @override
  Stream<List<AdminOffer>> watchOffers() {
    return _offers.snapshots().map((QuerySnapshot<Map<String, dynamic>> snap) {
      final List<AdminOffer> offers =
          snap.docs.map(_fromDocument).whereType<AdminOffer>().toList()
            ..sort(_compareOffers);

      return List<AdminOffer>.unmodifiable(offers);
    });
  }

  @override
  Future<String> createOffer(AdminOfferDraft draft) async {
    final DocumentReference<Map<String, dynamic>> ref = _offers.doc();
    await ref.set(_toFirestore(draft, isCreation: true));
    return ref.id;
  }

  @override
  Future<void> updateOffer({
    required String offerId,
    required AdminOfferDraft draft,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref = _offers.doc(offerId);
    final DocumentSnapshot<Map<String, dynamic>> current = await ref.get();

    if (!current.exists || current.data() == null) {
      throw StateError('Cette offre n’existe plus.');
    }

    final Object? createdAt = current.data()!['createdAt'];
    await ref.set(<String, dynamic>{
      ..._toFirestore(draft, isCreation: false),
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> setOfferActive({
    required String offerId,
    required bool isActive,
  }) {
    return _offers.doc(offerId).update(<String, dynamic>{
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Map<String, dynamic> _toFirestore(
    AdminOfferDraft draft, {
    required bool isCreation,
  }) {
    return <String, dynamic>{
      'schemaVersion': 1,
      'network': draft.network.name,
      'service': draft.service.firestoreValue,
      'operationType': draft.operationType.name,
      'title': draft.title.trim(),
      'catalogLabel': draft.catalogLabel.trim(),
      'description': _nullable(draft.description),
      'sellingPrice': draft.sellingPrice,
      'details': draft.details,
      'badgeLabel': _nullable(draft.badgeLabel),
      'category': draft.category,
      'validity': _nullable(draft.validity),
      'volume': _nullable(draft.volume),
      'minutes': _nullable(draft.minutes),
      'sms': _nullable(draft.sms),
      'eligibility': _nullable(draft.eligibility),
      'isActive': draft.isActive,
      'displayOrder': draft.displayOrder,
      if (isCreation) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  AdminOffer? _fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data();
    final MobileNetwork? network = _networkFrom(data['network']);
    final OfferService? service = _serviceFrom(data['service']);
    final OrderOperationType? operationType = _operationTypeFrom(
      data['operationType'],
    );
    final String? title = _requiredString(data['title']);
    final String? catalogLabel = _requiredString(data['catalogLabel']);
    final int? sellingPrice = _positiveInt(data['sellingPrice']);
    final bool? isActive = data['isActive'] is bool
        ? data['isActive'] as bool
        : null;

    if (network == null ||
        service == null ||
        operationType == null ||
        title == null ||
        catalogLabel == null ||
        sellingPrice == null ||
        isActive == null) {
      return null;
    }

    return AdminOffer(
      id: document.id,
      network: network,
      service: service,
      operationType: operationType,
      title: title,
      catalogLabel: catalogLabel,
      sellingPrice: sellingPrice,
      details: _stringList(data['details']),
      category:
          _requiredString(data['category']) ?? _categoryFor(operationType),
      isActive: isActive,
      displayOrder: _nonNegativeInt(data['displayOrder']) ?? 9999,
      description: _optionalString(data['description']),
      badgeLabel: _optionalString(data['badgeLabel']),
      validity: _optionalString(data['validity']),
      volume: _optionalString(data['volume']),
      minutes: _optionalString(data['minutes']),
      sms: _optionalString(data['sms']),
      eligibility: _optionalString(data['eligibility']),
      createdAt: _dateTime(data['createdAt']),
      updatedAt: _dateTime(data['updatedAt']),
    );
  }

  int _compareOffers(AdminOffer a, AdminOffer b) {
    final int network = a.network.index.compareTo(b.network.index);
    if (network != 0) return network;

    final int service = a.service.index.compareTo(b.service.index);
    if (service != 0) return service;

    final int order = a.displayOrder.compareTo(b.displayOrder);
    if (order != 0) return order;

    return a.sellingPrice.compareTo(b.sellingPrice);
  }

  MobileNetwork? _networkFrom(Object? value) {
    if (value is! String) return null;
    for (final MobileNetwork item in MobileNetwork.values) {
      if (item.name == value) return item;
    }
    return null;
  }

  OfferService? _serviceFrom(Object? value) {
    if (value == 'internetSubscription') return OfferService.internet;
    if (value == 'calls') return OfferService.calls;
    return null;
  }

  OrderOperationType? _operationTypeFrom(Object? value) {
    if (value is! String) return null;
    for (final OrderOperationType item in OrderOperationType.values) {
      if (item.name == value) return item;
    }
    return null;
  }

  String _categoryFor(OrderOperationType type) {
    return type == OrderOperationType.mixedBundle
        ? 'mixed'
        : type == OrderOperationType.callBundle
        ? 'calls'
        : 'internet';
  }

  String? _requiredString(Object? value) {
    final String? result = _optionalString(value);
    return result == null || result.isEmpty ? null : result;
  }

  String? _optionalString(Object? value) {
    if (value is! String) return null;
    final String cleaned = value.trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  Object? _nullable(String? value) {
    final String cleaned = value?.trim() ?? '';
    return cleaned.isEmpty ? null : cleaned;
  }

  int? _positiveInt(Object? value) {
    if (value is num && value > 0) return value.toInt();
    return null;
  }

  int? _nonNegativeInt(Object? value) {
    if (value is num && value >= 0) return value.toInt();
    return null;
  }

  List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];
    return value
        .whereType<String>()
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }

  DateTime? _dateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
