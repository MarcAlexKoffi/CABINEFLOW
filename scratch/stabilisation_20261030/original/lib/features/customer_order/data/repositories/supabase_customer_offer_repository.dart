import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
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

    return _mapRows(
      response,
      forcedNetwork: network,
      forcedType: expectedType,
    );
  }

  @override
  Stream<List<CustomerOffer>> watchOffers({
    required CustomerService service,
    required MobileNetwork network,
  }) {
    return _watchRefresh(
      () => fetchOffers(service: service, network: network),
    );
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
  ) async* {
    List<CustomerOffer> previous = await loader();
    yield previous;

    try {
      // Une seule souscription Supabase alimente tous les écrans client.
      // Le flux broadcast évite `Bad state: Stream has already been listened to`
      // pendant les transitions AnimatedSwitcher où deux pages peuvent se
      // chevaucher quelques millisecondes.
      await for (final List<Map<String, dynamic>> _ in _changeFeedStream) {
        final List<CustomerOffer> next = await loader();
        if (_sameOffers(previous, next)) {
          continue;
        }
        previous = next;
        yield next;
      }
    } catch (error, stackTrace) {
      // Le snapshot REST reste exploitable si le WebSocket est indisponible.
      IzyTelLog.backendError(
        'SupabaseCustomerOfferRepository.Realtime',
        error,
        stackTrace: stackTrace,
      );
    }
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

  bool _sameOffers(List<CustomerOffer> a, List<CustomerOffer> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int index = 0; index < a.length; index++) {
      final CustomerOffer left = a[index];
      final CustomerOffer right = b[index];
      if (left.id != right.id ||
          left.network != right.network ||
          left.type != right.type ||
          left.title != right.title ||
          left.catalogLabel != right.catalogLabel ||
          left.amount != right.amount ||
          left.badgeLabel != right.badgeLabel ||
          !_sameStrings(left.details, right.details)) {
        return false;
      }
    }
    return true;
  }

  bool _sameStrings(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int index = 0; index < a.length; index++) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
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
