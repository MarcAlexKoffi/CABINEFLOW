import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/features/orders/domain/models/offer_catalog_item.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/offer_catalog_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Catalogue opérationnel mobile Staff basé sur la même table BO-4 que le Web.
class SupabaseOfferCatalogRepository implements OfferCatalogRepository {
  SupabaseOfferCatalogRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client {
    _changeFeedStream = _client
        .from(_changeFeedTable)
        .stream(primaryKey: const <String>['id'])
        .eq('id', 1)
        .asBroadcastStream();
  }

  static const String _offersTable = 'catalog_offers';
  static const String _changeFeedTable = 'catalog_change_feed';

  final SupabaseClient _client;
  late final Stream<List<Map<String, dynamic>>> _changeFeedStream;

  @override
  Future<List<OfferCatalogItem>> fetchOffers({
    required MobileNetwork network,
  }) async {
    final dynamic response = await _client
        .from(_offersTable)
        .select()
        .eq('is_active', true)
        .eq('network', network.name)
        .order('display_order')
        .order('selling_price');

    return _mapRows(response, network: network);
  }

  @override
  Stream<List<OfferCatalogItem>> watchOffers({
    required MobileNetwork network,
  }) async* {
    List<OfferCatalogItem> previous = await fetchOffers(network: network);
    yield previous;

    try {
      // Le même repository peut être réécouté lors d'un changement de réseau.
      // Un flux broadcast unique évite toute double écoute du canal Realtime.
      await for (final List<Map<String, dynamic>> _ in _changeFeedStream) {
        final List<OfferCatalogItem> next = await fetchOffers(network: network);
        if (_sameOffers(previous, next)) {
          continue;
        }
        previous = next;
        yield next;
      }
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'SupabaseOfferCatalogRepository.Realtime',
        error,
        stackTrace: stackTrace,
      );
    }
  }

  List<OfferCatalogItem> _mapRows(
    dynamic response, {
    required MobileNetwork network,
  }) {
    final List<OfferCatalogItem> offers = <OfferCatalogItem>[];
    if (response is! List) {
      return const <OfferCatalogItem>[];
    }

    for (final dynamic row in response) {
      if (row is! Map<String, dynamic>) {
        continue;
      }
      final OrderOperationType? operationType = _operationType(
        row['operation_type']?.toString() ?? '',
      );
      final String id = row['id']?.toString().trim() ?? '';
      final String label = row['catalog_label']?.toString().trim() ?? '';
      final int? amount = _int(row['selling_price']);
      if (id.isEmpty || label.isEmpty || operationType == null || amount == null) {
        continue;
      }
      offers.add(
        OfferCatalogItem(
          id: id,
          network: network,
          operationType: operationType,
          label: label,
          suggestedAmount: amount,
        ),
      );
    }

    return List<OfferCatalogItem>.unmodifiable(offers);
  }

  bool _sameOffers(List<OfferCatalogItem> a, List<OfferCatalogItem> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int index = 0; index < a.length; index++) {
      final OfferCatalogItem left = a[index];
      final OfferCatalogItem right = b[index];
      if (left.id != right.id ||
          left.network != right.network ||
          left.operationType != right.operationType ||
          left.label != right.label ||
          left.suggestedAmount != right.suggestedAmount) {
        return false;
      }
    }
    return true;
  }

  OrderOperationType? _operationType(String value) {
    for (final OrderOperationType type in OrderOperationType.values) {
      if (type.name == value) {
        return type;
      }
    }
    return null;
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
}
