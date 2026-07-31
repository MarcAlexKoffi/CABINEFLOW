import 'package:cabine_flow/features/customer_order/domain/models/customer_order_draft.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_order_repository.dart';

class FakeCustomerOrderRepository implements CustomerOrderRepository {
  int _sequence = 0;

  @override
  Future<CustomerOrderReceipt> declarePayment({
    required CustomerOrderDraft draft,
  }) async {
    _validateDraft(draft);

    await Future<void>.delayed(
      const Duration(milliseconds: 650),
    );

    final DateTime now = DateTime.now();
    _sequence++;

    return CustomerOrderReceipt(
      id: 'customer-order-${now.microsecondsSinceEpoch}',
      reference: _buildReference(now, _sequence),
      draft: draft,
      createdAt: now,
      paymentDeclaredAt: now,
      status: CustomerOrderTrackingStatus.paymentDeclared,
    );
  }

  String _buildReference(DateTime date, int sequence) {
    final String year = date.year.toString().padLeft(4, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    final String number = sequence.toString().padLeft(4, '0');

    return 'CF-$year$month$day-$number';
  }

  void _validateDraft(CustomerOrderDraft draft) {
    if (draft.identity == null ||
        draft.service == null ||
        draft.network == null ||
        draft.selectedOfferLabel == null ||
        (draft.amount ?? 0) <= 0 ||
        draft.beneficiaryNumber == null) {
      throw StateError(
        'La commande est incomplète. Revenez au récapitulatif.',
      );
    }
  }
}
