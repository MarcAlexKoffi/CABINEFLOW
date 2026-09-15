import 'dart:async';

import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/features/offers/domain/models/admin_offer.dart';
import 'package:cabine_flow/features/offers/domain/repositories/admin_offer_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Source canonique BO-4 pour les offres IzyTel.
///
/// Les écritures passent exclusivement par les RPC Admin Supabase. Le flux de
/// lecture émet d'abord un snapshot REST puis se branche sur Realtime afin de
/// ne pas rendre le module dépendant de l'ouverture du WebSocket.
class SupabaseAdminOfferRepository implements AdminOfferRepository {
  SupabaseAdminOfferRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static const String tableName = 'catalog_offers';

  final SupabaseClient _client;

  @override
  Stream<List<AdminOffer>> watchOffers() async* {
    yield await _fetchOffers();

    try {
      final String? token = await FirebaseAuth.instance.currentUser?.getIdToken();
      await _client.realtime.setAuth(token);

      final Stream<List<Map<String, dynamic>>> rowsStream = _client
          .from(tableName)
          .stream(primaryKey: const <String>['id']);

      await for (final List<Map<String, dynamic>> rows in rowsStream) {
        yield _mapRows(rows);
      }
    } catch (error, stackTrace) {
      // Une indisponibilité Realtime ne doit pas supprimer le snapshot REST
      // déjà affiché. Les actions du BO recréent le stream après mutation.
      IzyTelLog.backendError(
        'SupabaseAdminOfferRepository.Realtime',
        error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<String> createOffer(AdminOfferDraft draft) async {
    final dynamic response = await _client.rpc(
      'izytel_create_catalog_offer',
      params: <String, dynamic>{'p_payload': _payload(draft)},
    );
    return _readReturnedId(response);
  }

  @override
  Future<void> updateOffer({
    required String offerId,
    required AdminOfferDraft draft,
  }) async {
    await _client.rpc(
      'izytel_update_catalog_offer',
      params: <String, dynamic>{
        'p_offer_id': offerId,
        'p_payload': _payload(draft),
      },
    );
  }

  @override
  Future<void> setOfferActive({
    required String offerId,
    required bool isActive,
  }) async {
    await _client.rpc(
      'izytel_set_catalog_offer_active',
      params: <String, dynamic>{
        'p_offer_id': offerId,
        'p_is_active': isActive,
      },
    );
  }

  Future<List<AdminOffer>> _fetchOffers() async {
    final dynamic response = await _client.from(tableName).select();
    final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[
      if (response is List)
        for (final dynamic row in response)
          if (row is Map<String, dynamic>) row,
    ];
    return _mapRows(rows);
  }

  List<AdminOffer> _mapRows(List<Map<String, dynamic>> rows) {
    final List<AdminOffer> offers = rows
        .map(_fromRow)
        .whereType<AdminOffer>()
        .toList(growable: true)
      ..sort(_compareOffers);
    return List<AdminOffer>.unmodifiable(offers);
  }

  AdminOffer? _fromRow(Map<String, dynamic> row) {
    final String id = _string(row['id']);
    final MobileNetwork? network = _network(_string(row['network']));
    final OfferService? service = _service(_string(row['service']));
    final OrderOperationType? operationType = _operationType(
      _string(row['operation_type']),
    );
    final String title = _string(row['title']);
    final String catalogLabel = _string(row['catalog_label']);
    final int? sellingPrice = _int(row['selling_price']);

    if (id.isEmpty ||
        network == null ||
        service == null ||
        operationType == null ||
        title.isEmpty ||
        catalogLabel.isEmpty ||
        sellingPrice == null ||
        sellingPrice <= 0) {
      return null;
    }

    return AdminOffer(
      id: id,
      network: network,
      service: service,
      operationType: operationType,
      title: title,
      catalogLabel: catalogLabel,
      sellingPrice: sellingPrice,
      details: _stringList(row['details']),
      category: _string(row['category']).isEmpty
          ? _categoryFor(operationType, service)
          : _string(row['category']),
      isActive: row['is_active'] == true,
      displayOrder: _int(row['display_order']) ?? 9999,
      description: _optionalString(row['description']),
      badgeLabel: _optionalString(row['badge_label']),
      validity: _optionalString(row['validity']),
      volume: _optionalString(row['volume']),
      minutes: _optionalString(row['minutes']),
      sms: _optionalString(row['sms']),
      eligibility: _optionalString(row['eligibility']),
      createdAt: _dateTime(row['created_at']),
      updatedAt: _dateTime(row['updated_at']),
    );
  }

  Map<String, dynamic> _payload(AdminOfferDraft draft) {
    return <String, dynamic>{
      'network': draft.network.name,
      'service': draft.service.firestoreValue,
      'operationType': draft.operationType.name,
      'title': draft.title.trim(),
      'catalogLabel': draft.catalogLabel.trim(),
      'sellingPrice': draft.sellingPrice,
      'details': draft.details
          .map((String item) => item.trim())
          .where((String item) => item.isNotEmpty)
          .toList(growable: false),
      'category': draft.category.trim(),
      'isActive': draft.isActive,
      'displayOrder': draft.displayOrder,
      'description': _nullable(draft.description),
      'badgeLabel': _nullable(draft.badgeLabel),
      'validity': _nullable(draft.validity),
      'volume': _nullable(draft.volume),
      'minutes': _nullable(draft.minutes),
      'sms': _nullable(draft.sms),
      'eligibility': _nullable(draft.eligibility),
    };
  }

  String _readReturnedId(dynamic response) {
    if (response is Map<String, dynamic>) {
      final String id = _string(response['id']);
      if (id.isNotEmpty) {
        return id;
      }
    }
    if (response is List && response.isNotEmpty) {
      final dynamic first = response.first;
      if (first is Map<String, dynamic>) {
        final String id = _string(first['id']);
        if (id.isNotEmpty) {
          return id;
        }
      }
    }
    throw StateError('L’offre a été créée sans identifiant exploitable.');
  }

  int _compareOffers(AdminOffer a, AdminOffer b) {
    final int network = a.network.index.compareTo(b.network.index);
    if (network != 0) {
      return network;
    }
    final int service = a.service.index.compareTo(b.service.index);
    if (service != 0) {
      return service;
    }
    final int order = a.displayOrder.compareTo(b.displayOrder);
    if (order != 0) {
      return order;
    }
    return a.sellingPrice.compareTo(b.sellingPrice);
  }

  MobileNetwork? _network(String value) {
    for (final MobileNetwork item in MobileNetwork.values) {
      if (item.name == value) {
        return item;
      }
    }
    return null;
  }

  OfferService? _service(String value) {
    if (value == 'internetSubscription') {
      return OfferService.internet;
    }
    if (value == 'calls') {
      return OfferService.calls;
    }
    return null;
  }

  OrderOperationType? _operationType(String value) {
    for (final OrderOperationType item in OrderOperationType.values) {
      if (item.name == value) {
        return item;
      }
    }
    return null;
  }

  String _categoryFor(OrderOperationType type, OfferService service) {
    if (type == OrderOperationType.mixedBundle) {
      return 'mixed';
    }
    if (service == OfferService.calls) {
      return 'calls';
    }
    return 'internet';
  }

  String _string(Object? value) => value?.toString().trim() ?? '';

  String? _optionalString(Object? value) {
    final String cleaned = _string(value);
    return cleaned.isEmpty ? null : cleaned;
  }

  String? _nullable(String? value) {
    final String cleaned = value?.trim() ?? '';
    return cleaned.isEmpty ? null : cleaned;
  }

  int? _int(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  List<String> _stringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map((dynamic item) => item?.toString().trim() ?? '')
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }

  DateTime? _dateTime(Object? value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
