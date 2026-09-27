import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reprise ponctuelle des anciens écrans financiers Firestore vers BO-5.
///
/// Firestore n'est jamais écrit ici. Le service ne sert qu'à conserver
/// l'historique créé avant le cutover Supabase.
class LegacyFinanceBackfillService {
  LegacyFinanceBackfillService({FirebaseFirestore? firestore, SupabaseClient? client})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _client = client ?? Supabase.instance.client;

  final FirebaseFirestore _firestore;
  final SupabaseClient _client;

  Future<int> runIfNeeded() async {
    if (!SupabaseBootstrap.isInitialized) {
      return 0;
    }
    try {
      final dynamic needed = await _client.rpc('izytel_finance_backfill_needed');
      if (needed != true) {
        return 0;
      }
      return _run();
    } catch (error, stackTrace) {
      IzyTelLog.backendError('LegacyFinanceBackfillService.Auto', error, stackTrace: stackTrace);
      return 0;
    }
  }

  Future<int> _run() async {
    int imported = 0;
    imported += await _importCollection('customerCredits', 'credit', _creditPayload);
    imported += await _importCollection('customerCreditSettlements', 'credit_settlement', _settlementPayload);
    imported += await _importCollection('financeExpenses', 'expense', _expensePayload);
    imported += await _importCollection('waveBalanceAdjustments', 'wave_adjustment', _waveAdjustmentPayload);
    imported += await _importCollection('dailyFinancialClosings', 'closing', _closingPayload);

    final DocumentSnapshot<Map<String, dynamic>> wave =
        await _firestore.collection('financeSettings').doc('wave').get();
    final Map<String, dynamic>? waveData = wave.data();
    if (wave.exists && waveData != null) {
      await _client.rpc('izytel_import_legacy_finance', params: <String, dynamic>{
        'p_kind': 'wave_setting',
        'p_legacy_id': wave.id,
        'p_payload': _waveSettingPayload(waveData),
      });
      imported += 1;
    }

    await _client.rpc('izytel_finish_finance_backfill', params: <String, dynamic>{
      'p_imported_count': imported,
    });
    return imported;
  }

  Future<int> _importCollection(
    String collection,
    String kind,
    Map<String, dynamic> Function(Map<String, dynamic> source, String id) mapper,
  ) async {
    const int batchSize = 250;
    int imported = 0;
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;

    while (true) {
      Query<Map<String, dynamic>> query = _firestore
          .collection(collection)
          .orderBy(FieldPath.documentId)
          .limit(batchSize);
      if (cursor != null) {
        query = query.startAfterDocument(cursor);
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        break;
      }

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
        await _client.rpc('izytel_import_legacy_finance', params: <String, dynamic>{
          'p_kind': kind,
          'p_legacy_id': doc.id,
          'p_payload': mapper(doc.data(), doc.id),
        });
        imported += 1;
      }

      if (snapshot.docs.length < batchSize) {
        break;
      }
      cursor = snapshot.docs.last;
    }
    return imported;
  }

  Map<String, dynamic> _creditPayload(Map<String, dynamic> d, String id) => <String, dynamic>{
        'id': id,
        'order_id': _s(d['orderId'], fallback: id),
        'order_reference': _s(d['orderReference'], fallback: 'LEGACY-$id'),
        'client_name': _s(d['clientName'], fallback: 'Client'),
        'client_whatsapp_phone': _s(d['clientWhatsappPhone']),
        'amount': _i(d['amount']),
        'paid_amount': _i(d['paidAmount']),
        'status': _s(d['status'], fallback: 'open'),
        'note': _nullable(d['note']),
        'created_at': _date(d['createdAt']),
        'created_by_uid': _s(d['createdBy']),
        'created_by_name': _s(d['createdByName'], fallback: 'Historique'),
        'updated_at': _date(d['updatedAt']),
        'settled_at': _date(d['settledAt']),
      };

  Map<String, dynamic> _settlementPayload(Map<String, dynamic> d, String id) => <String, dynamic>{
        'credit_id': _s(d['creditId'], fallback: _s(d['orderId'])),
        'order_id': _s(d['orderId']),
        'order_reference': _s(d['orderReference']),
        'client_name': _s(d['clientName'], fallback: 'Client'),
        'amount': _i(d['amount']),
        'payment_channel': _s(d['channel'], fallback: _s(d['paymentChannel'], fallback: 'other')),
        'payment_reference': _s(d['reference'], fallback: _s(d['paymentReference'], fallback: 'LEGACY-$id')),
        'note': _nullable(d['note']),
        'paid_at': _date(d['paidAt']),
        'created_by_uid': _s(d['createdBy']),
        'created_by_name': _s(d['createdByName'], fallback: 'Historique'),
      };

  Map<String, dynamic> _expensePayload(Map<String, dynamic> d, String id) => <String, dynamic>{
        'category': _s(d['category'], fallback: 'other'),
        'amount': _i(d['amount']),
        'description': _s(d['description'], fallback: 'Dépense historique'),
        'payment_channel': _s(d['channel'], fallback: _s(d['paymentChannel'], fallback: 'other')),
        'payment_reference': _nullable(d['reference'] ?? d['paymentReference']),
        'spent_at': _date(d['spentAt']),
        'created_by_uid': _s(d['createdBy']),
        'created_by_name': _s(d['createdByName'], fallback: 'Historique'),
      };

  Map<String, dynamic> _waveAdjustmentPayload(Map<String, dynamic> d, String id) => <String, dynamic>{
        'previous_opening_balance': _i(d['previousOpeningBalance']),
        'opening_balance': _i(d['openingBalance']),
        'effective_at': _date(d['effectiveAt']),
        'note': _nullable(d['note']),
        'created_by_uid': _s(d['createdBy']),
        'created_by_name': _s(d['createdByName'], fallback: 'Historique'),
      };

  Map<String, dynamic> _waveSettingPayload(Map<String, dynamic> d) => <String, dynamic>{
        'opening_balance': _i(d['openingBalance']),
        'effective_at': _date(d['effectiveAt']),
        'note': _nullable(d['note']),
        'updated_at': _date(d['updatedAt']),
        'updated_by_uid': _s(d['updatedBy']),
        'updated_by_name': _s(d['updatedByName'], fallback: 'Historique'),
      };

  Map<String, dynamic> _closingPayload(Map<String, dynamic> d, String id) => <String, dynamic>{
        'date_key': _s(d['dateKey'], fallback: id),
        'client_receipts': _i(d['clientReceipts']),
        'successful_orders_count': _i(d['successfulOrdersCount']),
        'successful_orders_amount': _i(d['successfulOrdersAmount']),
        'supplier_recharge_principal': _i(d['supplierRechargePrincipal']),
        'supplier_recharge_bonus': _i(d['supplierRechargeBonus']),
        'supplier_recharge_received': _i(d['supplierRechargeReceived']),
        'supplier_payments': _i(d['supplierPayments']),
        'credits_created': _i(d['creditsCreated']),
        'credit_settlements': _i(d['creditSettlements']),
        'customer_receivables': _i(d['customerReceivables']),
        'expenses': _i(d['expenses']),
        'refunds': _i(d['refunds']),
        'commissions_earned': _i(d['commissionsEarned']),
        'commissions_paid': _i(d['commissionsPaid']),
        'orange_available': _i(d['orangeAvailable']),
        'orange_committed': _i(d['orangeCommitted']),
        'mtn_available': _i(d['mtnAvailable']),
        'mtn_committed': _i(d['mtnCommitted']),
        'moov_available': _i(d['moovAvailable']),
        'moov_committed': _i(d['moovCommitted']),
        'supplier_debt': _i(d['supplierDebt']),
        'commission_debt': _i(d['commissionDebt']),
        'wave_theoretical_balance': _i(d['waveTheoreticalBalance']),
        'wave_actual_balance': _i(d['waveActualBalance']),
        'wave_difference': _i(d['waveDifference']),
        'wave_difference_note': _nullable(d['waveDifferenceNote']),
        'estimated_profit': _i(d['estimatedProfit']),
        'closed_at': _date(d['closedAt']),
        'closed_by_uid': _s(d['closedBy']),
        'closed_by_name': _s(d['closedByName'], fallback: 'Historique'),
      };

  String _s(Object? value, {String fallback = ''}) {
    final String result = value?.toString().trim() ?? '';
    return result.isEmpty ? fallback : result;
  }

  int _i(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String? _nullable(Object? value) {
    final String result = _s(value);
    return result.isEmpty ? null : result;
  }

  String? _date(Object? value) {
    if (value is Timestamp) {
      return value.toDate().toUtc().toIso8601String();
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    final String raw = _s(value);
    return raw.isEmpty ? null : raw;
  }
}
