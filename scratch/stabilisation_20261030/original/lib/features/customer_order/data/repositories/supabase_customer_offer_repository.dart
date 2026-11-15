import 'package:cabine_flow/core/resilience/backend_read_stream.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_offer.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_offer_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Source canonique des offres visibles sur le Web client IzyTel.
///
/// BO-4 utilise un signal Realtime public sans donnée métier. À chaque
/// mutation du catalogue, le client refait une lecture REST des seules offres
/// actives. Cette stratégie propage aussi correctement une désactivation : le
/// signal reste visible même lorsque l'offre désactivée ne l'est plus via RLS.
class SupabaseCustomerOfferRepository implements CustomerOfferRepository {
  SupabaseCustomerOfferRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String _offersTable = 'catalog_offers';
  static const String _changeFeedTable = 'catalog_change_feed';

  final SupabaseClient _client;
  Stream<List<Map<String, dynamic>>>? _changeFeedStream;

  Stream<Object?> _catalogSignals() async* {
    // Broadcast allows overlapping pages without
    // Bad state: Stream has already been listened to.
    final stream = _changeFeedStream ??= _client
        .from(_changeFeedTable)
        .stream(primaryKey: const <String>['id'])
        .eq('id', 1)
        .asBroadcastStream(
          onCancel: (subscription) {
            _changeFeedStream = null;
            subscription.cancel();
          },
        );
    await for (final rows in stream) {
      yield rows;
    }
  }

  @override
  Future<List<CustomerOffer>> fetchOffers({
    required CustomerService service,
    required MobileNetwork network,
  }) async {
    final CustomerOfferType? expectedType = _typeForService(service);
    if (expectedType == null) {
      return const <CustomerOffer>[];
    }

    final dynamic response = await _client
        .from(_offersTable)
        .select()
        .eq('is_active', true)
        .eq('network', network.name)
        .eq('service', service.name)
        .order('display_order')
        .order('selling_price');

    return _mapRows(response, forcedNetwork: network, forcedType: expectedType);
  }

  @override
  Stream<List<CustomerOffer>> watchOffers({
    required CustomerService service,
    required MobileNetwork network,
  }) {
    return _watchRefresh(() => fetchOffers(service: service, network: network));
  }

  @override
  Stream<List<CustomerOffer>> watchAllOffers() {
    return _watchRefresh(_fetchAllOffers);
  }

  Future<List<CustomerOffer>> _fetchAllOffers() async {
    final dynamic response = await _client
        .from(_offersTable)
        .select()
        .eq('is_active', true)
        .order('display_order')
        .order('selling_price');

    return _mapRows(response);
  }

  Stream<List<CustomerOffer>> _watchRefresh(
    Future<List<CustomerOffer>> Function() loader,
  ) {
    return BackendReadStream.watch(
      fetch: loader,
      label: 'CustomerOffers.read',
      refreshSignals: _catalogSignals,
    );
  }

  List<CustomerOffer> _mapRows(
    dynamic response, {
    MobileNetwork? forcedNetwork,
    CustomerOfferType? forcedType,
  }) {
    final List<CustomerOffer> offers = <CustomerOffer>[];
    if (response is! List) {
      return const <CustomerOffer>[];
    }

    for (final dynamic row in response) {
      if (row is! Map<String, dynamic>) {
        continue;
      }

      final MobileNetwork? network =
          forcedNetwork ?? _network(row['network']?.toString() ?? '');
      final CustomerOfferType? type =
          forcedType ?? _typeFromService(row['service']?.toString() ?? '');
      final String id = row['id']?.toString().trim() ?? '';
      final String title = row['title']?.toString().trim() ?? '';
      final String label = row['catalog_label']?.toString().trim() ?? '';
      final int? amount = _int(row['selling_price']);

      if (network == null ||
          type == null ||
          id.isEmpty ||
          title.isEmpty ||
          label.isEmpty ||
          amount == null) {
        continue;
      }

      offers.add(
        CustomerOffer(
          id: id,
          network: network,
          type: type,
          title: title,
          catalogLabel: label,
          amount: amount,
          details: _stringList(row['details']),
          badgeLabel: _optionalString(row['badge_label']),
        ),
      );
    }

    return List<CustomerOffer>.unmodifiable(offers);
  }

  CustomerOfferType? _typeForService(CustomerService service) {
    return switch (service) {
      CustomerService.internetSubscription => CustomerOfferType.internet,
      CustomerService.calls => CustomerOfferType.calls,
      CustomerService.unitTransfer => null,
    };
  }

  CustomerOfferType? _typeFromService(String value) {
    if (value == CustomerService.internetSubscription.name) {
      return CustomerOfferType.internet;
    }
    if (value == CustomerService.calls.name) {
      return CustomerOfferType.calls;
    }
    return null;
  }

  MobileNetwork? _network(String value) {
    for (final MobileNetwork network in MobileNetwork.values) {
      if (network.name == value) {
        return network;
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

  String? _optionalString(Object? value) {
    final String cleaned = value?.toString().trim() ?? '';
    return cleaned.isEmpty ? null : cleaned;
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
}
