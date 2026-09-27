import 'package:cabine_flow/features/commissions/domain/models/commission_models.dart';
import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';
import 'package:cabine_flow/features/finances/domain/services/finance_calculators.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('un remboursement Wave effectué diminue le solde théorique', () {
    final DateTime effectiveAt = DateTime(2026, 9, 14, 8);
    final WaveCashSnapshot snapshot = WaveFinanceCalculator.calculate(
      opening: WaveOpeningBalance(
        amount: 100000,
        effectiveAt: effectiveAt,
        updatedAt: effectiveAt,
        updatedBy: 'admin',
        updatedByName: 'Admin',
      ),
      orders: const <QueueOrder>[],
      refunds: <RefundCase>[
        RefundCase(
          id: 'refund-1',
          orderId: 'order-1',
          orderReference: 'CF-20260914-TEST01',
          supportRequestId: 'support-1',
          supportRequestType: 'transactionFailed',
          supportRequestDescription: 'Transaction échouée',
          customerAuthUid: 'customer-1',
          clientName: 'Client Test',
          clientWhatsappPhone: '+2250102030405',
          originalAmount: 10000,
          amount: 10000,
          reason: RefundReason.transactionFailed,
          reasonNote: '',
          paymentChannel: 'wave',
          originalPaymentReference: 'PAY-1',
          status: RefundStatus.refunded,
          requestedAt: effectiveAt,
          requestedBy: 'admin',
          requestedByName: 'Admin',
          updatedAt: effectiveAt.add(const Duration(minutes: 10)),
          refundReference: 'REF-1',
          refundedAt: effectiveAt.add(const Duration(minutes: 10)),
          refundedBy: 'admin',
          refundedByName: 'Admin',
        ),
      ],
      commissionPayouts: const <CommissionPayout>[],
      supplierPayments: const <SupplierPayment>[],
      creditSettlements: const <CustomerCreditSettlement>[],
      expenses: const <FinanceExpense>[],
    );

    expect(snapshot.refunds, 10000);
    expect(snapshot.outgoing, 10000);
    expect(snapshot.theoreticalBalance, 90000);
  });

  test('un remboursement seulement créé ou approuvé ne réduit pas encore Wave', () {
    final DateTime effectiveAt = DateTime(2026, 9, 14, 8);
    final WaveCashSnapshot snapshot = WaveFinanceCalculator.calculate(
      opening: WaveOpeningBalance(
        amount: 100000,
        effectiveAt: effectiveAt,
        updatedAt: effectiveAt,
        updatedBy: 'admin',
        updatedByName: 'Admin',
      ),
      orders: const <QueueOrder>[],
      refunds: <RefundCase>[
        RefundCase(
          id: 'refund-2',
          orderId: 'order-2',
          orderReference: 'CF-20260914-TEST02',
          supportRequestId: 'support-2',
          supportRequestType: 'wrongAmount',
          supportRequestDescription: 'Mauvais montant',
          customerAuthUid: 'customer-2',
          clientName: 'Client Test',
          clientWhatsappPhone: '+2250102030405',
          originalAmount: 15000,
          amount: 5000,
          reason: RefundReason.wrongAmount,
          reasonNote: '',
          paymentChannel: 'wave',
          originalPaymentReference: 'PAY-2',
          status: RefundStatus.approved,
          requestedAt: effectiveAt,
          requestedBy: 'admin',
          requestedByName: 'Admin',
          updatedAt: effectiveAt,
        ),
      ],
      commissionPayouts: const <CommissionPayout>[],
      supplierPayments: const <SupplierPayment>[],
      creditSettlements: const <CustomerCreditSettlement>[],
      expenses: const <FinanceExpense>[],
    );

    expect(snapshot.refunds, 0);
    expect(snapshot.theoreticalBalance, 100000);
  });
}
