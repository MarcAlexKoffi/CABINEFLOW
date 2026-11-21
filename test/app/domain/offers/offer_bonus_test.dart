import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:cabine_flow/app/domain/entities/offers/offer_bonus.dart';
import 'package:cabine_flow/app/domain/entities/customer/customer_offer.dart';
import 'package:cabine_flow/app/domain/entities/orders/queue_order.dart';
import 'package:cabine_flow/app/modules/customer/widgets/live_offer_bonus.dart';

void main() {
  test(
    'server values display exact 2250 Mo and explicit guaranteed 2500 Mo',
    () {
      expect(OfferBonus.volume(2250), '2,25 Go');
      expect(OfferBonus.volume(2500), '2,50 Go');
      expect(OfferBonus.volume(750), '750 Mo');
      final offer = CustomerOffer(
        id: 'maxit-750',
        network: MobileNetwork.orange,
        type: CustomerOfferType.internet,
        title: 'Pass semaine 750 Mo',
        catalogLabel: '750 Mo',
        amount: 800,
        details: const ['750 Mo'],
        category: 'maxit',
        bonus: OfferBonus(
          baseVolumeMb: 750,
          totalVolumeMb: 2250,
          kind: 'percentage',
          value: 200,
          lease: const Duration(seconds: 30),
        ),
      );
      expect(offer.categoryLabel, 'MAXIT');
      expect(offer.displayBadge, '+200 % de bonus');
      expect(offer.displayDetails, contains('Volume total : 2,25 Go'));
      expect(offer.amount, 800);
      expect(offer.details, ['750 Mo']);
      offer.bonus!.invalidate();
      expect(offer.displayBadge, isNull);
    },
  );
  test(
    'an expired projection and excessive lifetime cannot advertise a bonus',
    () {
      final now = DateTime.utc(2030, 1, 1);
      final row = {
        'base_volume_mb': 750,
        'total_volume_mb': 2250,
        'bonus_kind': 'percentage',
        'bonus_value': 200,
        'valid_until': now.add(const Duration(seconds: 5)).toIso8601String(),
      };
      expect(
        OfferBonus.fromJson(
          row,
          now,
          transportBudget: const Duration(seconds: 6),
        ).visible,
        isFalse,
      );
      final clipped = OfferBonus.fromJson({
        ...row,
        'valid_until': now.add(const Duration(days: 1)).toIso8601String(),
      }, now);
      expect(clipped.remaining <= const Duration(seconds: 30), isTrue);
    },
  );
  testWidgets(
    'cached offers lose their bonus at the lease deadline without a network update',
    (tester) async {
      var elapsed = Duration.zero;
      final offer = CustomerOffer(
        id: 'maxit-750',
        network: MobileNetwork.orange,
        type: CustomerOfferType.internet,
        title: 'Pass semaine 750 Mo',
        catalogLabel: '750 Mo',
        amount: 800,
        details: const ['750 Mo'],
        bonus: OfferBonus(
          baseVolumeMb: 750,
          totalVolumeMb: 2250,
          kind: 'percentage',
          value: 200,
          lease: const Duration(seconds: 3),
          elapsed: () => elapsed,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LiveOfferBonus(
            offer: offer,
            builder: (_) => Text(offer.displayBadge ?? 'Volume habituel'),
          ),
        ),
      );
      expect(find.text('+200 % de bonus'), findsOneWidget);
      elapsed = const Duration(seconds: 3);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Volume habituel'), findsOneWidget);
      expect(offer.amount, 800);
      expect(offer.displayDetails, ['750 Mo']);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
