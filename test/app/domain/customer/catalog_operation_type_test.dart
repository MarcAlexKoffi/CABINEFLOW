import 'package:cabine_flow/app/domain/entities/customer/customer_offer.dart';
import 'package:cabine_flow/app/domain/entities/customer/customer_order_draft.dart';
import 'package:cabine_flow/app/domain/entities/customer/customer_service.dart';
import 'package:cabine_flow/app/domain/entities/offers/offer_bonus.dart';
import 'package:cabine_flow/app/domain/entities/orders/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mixed = CustomerOffer(
    id: 'cchic-mixed',
    network: MobileNetwork.mtn,
    type: CustomerOfferType.calls,
    title: 'Offre C’CHIC',
    catalogLabel: 'C’CHIC',
    amount: 800,
    details: [],
    category: 'cchic',
    operationType: OrderOperationType.mixedBundle,
  );

  test('canonical mixed type survives a bonus without a Mixte badge', () {
    final promoted = mixed.withBonus(
      OfferBonus(
        baseVolumeMb: 750,
        totalVolumeMb: 2250,
        kind: 'percentage',
        value: 200,
        lease: const Duration(seconds: 30),
      ),
    );
    expect(promoted.displayBadge, '+200 % de bonus');
    final draft = CustomerOrderDraft(
      service: CustomerService.calls,
      offer: promoted,
    );
    expect(draft.operationType, OrderOperationType.mixedBundle);
    promoted.bonus!.invalidate();
    expect(draft.operationType, OrderOperationType.mixedBundle);
    expect(promoted.amount, 800);
  });

  test('transfer and legacy drafts retain their original business type', () {
    expect(
      const CustomerOrderDraft(
        service: CustomerService.unitTransfer,
        offer: mixed,
      ).operationType,
      OrderOperationType.unitTransfer,
    );
    expect(
      const CustomerOrderDraft(
        service: CustomerService.internetSubscription,
      ).operationType,
      OrderOperationType.internetSubscription,
    );
    expect(
      const CustomerOrderDraft(service: CustomerService.calls).operationType,
      OrderOperationType.callBundle,
    );
    expect(const CustomerOrderDraft().operationType, isNull);
  });
}
