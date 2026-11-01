import 'dart:convert';
import 'dart:io';
import 'package:cabine_flow/features/ussd/domain/ussd_engine.dart';
import 'package:cabine_flow/features/orders/data/mappers/firestore_order_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final input in [
    '+225 07 07 07 07 07',
    '002250707070707',
    '2250707070707',
    '07 07 07 07 07',
    '07-07-07-07-07',
    '0707070707',
  ]) {
    test('strict normalization: $input', () {
      final number = UssdPhoneNumber.parse(input);
      expect(number.local, '0707070707');
      expect(number.network, 'orange');
    });
  }
  for (final entry in {
    '0101010101': 'moov',
    '0505050505': 'mtn',
    '0707070707': 'orange',
  }.entries) {
    test(
      'reference operator ${entry.value}',
      () => expect(UssdPhoneNumber.parse(entry.key).network, entry.value),
    );
  }
  test('unknown mobile prefix is rejected rather than silently assigned', () {
    expect(
      () => UssdPhoneNumber.parse('0202020202'),
      throwsA(isA<UssdValidationException>()),
    );
  });
  for (final input in [
    '',
    '123',
    '01010101010',
    'abc0101010101',
    '01/01/01/01/01',
    '0101010101*1#',
    '+33 0101010101',
    '225+0101010101',
    '01\t01 01 01 01',
    '01\n01 01 01 01',
    '+225+2250101010101',
    'tel:0101010101',
  ]) {
    test(
      'reject invalid phone: ${jsonEncode(input)}',
      () => expect(
        () => UssdPhoneNumber.parse(input),
        throwsA(
          isA<UssdValidationException>().having(
            (e) => e.code,
            'code',
            'invalid_beneficiary',
          ),
        ),
      ),
    );
  }
  final vectors =
      jsonDecode(
            File('test/ussd_sql/generation_vectors.json').readAsStringSync(),
          )
          as List;
  for (final raw in vectors) {
    final v = Map<String, dynamic>.from(raw as Map);
    test('shared SQL/Dart grammar: ${v['name']}', () {
      String generate() => UssdEngine.generate(
        v['template'] as String,
        UssdValues(
          beneficiary: v['beneficiary'] as String?,
          amount: v['amount'] as int?,
          offerCode: v['offer_code'] as String?,
          quantity: v['quantity'] as int?,
          secretCode: v['secret_code'] as String?,
        ),
      );
      if (v['error'] != null) {
        expect(
          generate,
          throwsA(
            isA<UssdValidationException>().having(
              (e) => e.code,
              'code',
              v['error'],
            ),
          ),
        );
      } else {
        expect(generate(), v['expected']);
      }
    });
  }
  for (final alias in [
    'numéro_du_destinataire',
    'numero_du_destinataire',
    'NUMÉRO',
    'numero',
    'Bénéficiaire',
    'nume\u0301ro',
  ]) {
    test('human beneficiary token normalizes: $alias', () {
      final input = '*412*2*$alias#';
      expect(UssdEngine.normalizeTemplate(input), '*412*2*{{msisdn_local}}#');
      expect(
        UssdEngine.normalizeTemplate('*412*2*{{$alias}}#'),
        '*412*2*{{msisdn_local}}#',
      );
      expect(
        UssdEngine.generate(input, const UssdValues(beneficiary: '0101010101')),
        '*412*2*0101010101#',
      );
    });
  }
  test('human variables normalize once and preserve canonical digits/hash', () {
    const input = '*410*numéro*montant*CODE SECRET#';
    const expected = '*410*{{msisdn_local}}*{{amount}}*{{secret_code}}#';
    expect(UssdEngine.normalizeTemplate(input), expected);
    expect(UssdEngine.normalizeTemplate(expected), expected);
    expect(
      UssdEngine.normalizeTemplate('*999*code_offre*QUANTITÉ#'),
      '*999*{{offer_code}}*{{quantity}}#',
    );
    expect(
      UssdEngine.normalizeTemplate('#154*1*0707070707#'),
      '#154*1*0707070707#',
    );
  });
  test(
    'normalization never rewrites unknown substrings into valid variables',
    () {
      for (final input in [
        '*412*2*mon_numéro#',
        '*412*2*numero123#',
        '*412*2*{{foobar}}#',
        '*412*2*{{numero}#',
      ]) {
        expect(
          () => UssdEngine.validateTemplate(input),
          throwsA(isA<UssdValidationException>()),
        );
      }
    },
  );
  test('balance utility is never selected as an order shortcut', () {
    final utility = UssdRule.fromJson({
      'id': 'balance',
      'version': 1,
      'network': 'moov',
      'service': null,
      'purpose': 'balance',
      'actor_scope': 'both',
      'ussd_template': '*414*{{secret_code}}#',
      'priority': 100,
      'status': 'active',
      'effective_from': '2020-01-01T00:00:00Z',
    });
    expect(utility.service, '');
    expect(
      UssdRule.select(
        [utility],
        network: 'moov',
        service: '',
        actor: 'agent',
        now: DateTime.utc(2026),
      ),
      isNull,
    );
  });
  test('code and numeric values are bounded', () {
    expect(
      () => UssdEngine.generate(
        '*999*{{offer_code}}#',
        UssdValues(offerCode: '1' * 21),
      ),
      throwsA(isA<UssdValidationException>()),
    );
    expect(
      () => UssdEngine.validateCode('*${'1' * 181}#'),
      throwsA(isA<UssdValidationException>()),
    );
    expect(
      () => UssdEngine.generate(
        '*999*{{quantity}}#',
        const UssdValues(quantity: 1000000),
      ),
      throwsA(isA<UssdValidationException>()),
    );
  });
  final now = DateTime.utc(2026, 10, 31);
  UssdRule rule(
    String id, {
    String? family,
    String? offer,
    int priority = 0,
    String status = 'active',
    String scope = 'both',
    String network = 'moov',
    String service = 'internetSubscription',
    DateTime? from,
    DateTime? until,
  }) => UssdRule(
    id: id,
    version: 1,
    network: network,
    service: service,
    scope: scope,
    template: '*999#',
    priority: priority,
    status: status,
    familyId: family,
    offerId: offer,
    effectiveFrom: from ?? DateTime.utc(2020),
    effectiveUntil: until,
  );
  UssdRule? select(List<UssdRule> rules, {String actor = 'agent'}) =>
      UssdRule.select(
        rules,
        network: 'moov',
        service: 'internetSubscription',
        actor: actor,
        now: now,
        offerId: 'offer',
        familyId: 'family',
      );
  test('exact offer beats family and high priority generic', () {
    expect(
      select([
        rule('generic', priority: 1000),
        rule('family', family: 'family', priority: 50),
        rule('exact', offer: 'offer', priority: -10),
      ])!.id,
      'exact',
    );
  });
  test(
    'family beats generic',
    () => expect(
      select([rule('g', priority: 100), rule('f', family: 'family')])!.id,
      'f',
    ),
  );
  test(
    'highest priority inside one level',
    () => expect(select([rule('a'), rule('b', priority: 1)])!.id, 'b'),
  );
  test(
    'ambiguous equality never picks an arbitrary code',
    () => expect(
      () => select([rule('a'), rule('b')]),
      throwsA(
        isA<UssdValidationException>().having(
          (e) => e.code,
          'code',
          'ambiguous_rule',
        ),
      ),
    ),
  );
  test(
    'inactive expired future wrong-scope and unrelated associations excluded',
    () => expect(
      select([
        rule('draft', status: 'draft'),
        rule('disabled', status: 'disabled'),
        rule('expired', until: now),
        rule('future', from: now.add(const Duration(seconds: 1))),
        rule('cabiniste', scope: 'cabiniste'),
        rule('orange', network: 'orange'),
        rule('calls', service: 'calls'),
        rule('wrong-offer', offer: 'other'),
        rule('wrong-family', family: 'other'),
      ]),
      isNull,
    ),
  );
  test(
    'effective interval is inclusive start and exclusive end',
    () => expect(
      select([
        rule('current', from: now, until: now.add(const Duration(seconds: 1))),
      ])!.id,
      'current',
    ),
  );
  test(
    'Cabiniste scope is honored',
    () => expect(
      select([rule('c', scope: 'cabiniste')], actor: 'cabiniste')!.id,
      'c',
    ),
  );
  test(
    'legacy order mapping retains the stable offer identity through copy',
    () {
      final order = FirestoreOrderMapper.fromMap(
        id: 'synthetic',
        data: {
          'offerId': 'stable-id',
          'network': 'moov',
          'operationType': 'internetSubscription',
          'amount': 1000,
        },
      );
      expect(order.offerId, 'stable-id');
      expect(order.copyWith().offerId, 'stable-id');
      expect(
        FirestoreOrderMapper.fromMap(id: 'legacy', data: {}).offerId,
        isNull,
      );
    },
  );
}
