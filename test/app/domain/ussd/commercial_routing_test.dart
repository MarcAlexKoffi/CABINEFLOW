import 'package:flutter_test/flutter_test.dart';
import 'package:cabine_flow/app/domain/policies/ussd/ussd_engine.dart';
import 'package:cabine_flow/app/domain/repositories/ussd_repository.dart';

Map<String, dynamic> rule({
  String? category,
  String service = 'all',
  String template = 'APP:MAXIT',
}) => {
  'id': category ?? 'legacy',
  'version': 1,
  'network': 'orange',
  'service': service,
  'actor_scope': 'both',
  'ussd_template': template,
  'priority': 0,
  'status': 'active',
  'effective_from': '2020-01-01T00:00:00Z',
  'commercial_category': category,
};
void main() {
  for (final category in ['maxit', 'calls']) {
    test('$category Max it action requires the exact catalogue context', () {
      final data = {
        'status': 'available',
        'code': 'APP:MAXIT',
        'rule': rule(category: category),
        'context': {
          'commercial_category': category,
          'offer_id': 'stable-offer-id',
          'network': 'orange',
          'service': 'callBundle',
        },
      };
      expect(UssdResolution.fromJson(data).isMaxIt, isTrue);
      expect(
        () => UssdResolution.fromJson({
          ...data,
          'context': {
            'commercial_category': 'internet',
            'offer_id': 'stable-offer-id',
          },
        }),
        throwsFormatException,
      );
      expect(
        () => UssdResolution.fromJson({
          ...data,
          'context': {'commercial_category': category},
        }),
        throwsFormatException,
      );
    });
  }
  test(
    'commercial selection ignores legacy subscriptions, without fallback',
    () {
      final rules = [
        UssdRule.fromJson(rule(category: 'maxit')),
        UssdRule.fromJson(
          rule(service: 'internetSubscription', template: '*999#'),
        ),
      ];
      expect(
        UssdRule.select(
          rules,
          network: 'orange',
          service: 'internetSubscription',
          actor: 'agent',
          now: DateTime.utc(2030),
          commercialCategory: 'maxit',
        )!.isMaxIt,
        isTrue,
      );
      expect(
        UssdRule.select(
          rules,
          network: 'orange',
          service: 'internetSubscription',
          actor: 'agent',
          now: DateTime.utc(2030),
          commercialCategory: 'internet',
        ),
        isNull,
      );
    },
  );
  test('a category cannot redirect a credit transfer to Max it', () {
    final transfer = UssdRule.fromJson(
      rule(
        service: 'unitTransfer',
        template: '#154*1*{{msisdn_local}}*1*{{amount}}#',
      ),
    );
    final result = UssdRule.select(
      [UssdRule.fromJson(rule(category: 'maxit')), transfer],
      network: 'orange',
      service: 'unitTransfer',
      actor: 'agent',
      now: DateTime.utc(2030),
      commercialCategory: 'maxit',
    );
    expect(result, same(transfer));
  });
}
