class CabinisteFinanceSummary {
  const CabinisteFinanceSummary({
    required this.cabinisteCount,
    required this.completedOrders,
    required this.processedAmount,
    required this.telecomMarginTotal,
    required this.cabinisteMarginTotal,
    required this.izytelMarginTotal,
    required this.customerFeeTotal,
    required this.izytelGrossGainTotal,
    required this.settlementEarnedTotal,
    required this.paidTotal,
    required this.balanceDue,
    required this.toPayCount,
  });

  factory CabinisteFinanceSummary.fromJson(Map<String, dynamic> json) {
    return CabinisteFinanceSummary(
      cabinisteCount: _int(json['cabinisteCount']),
      completedOrders: _int(json['completedOrders']),
      processedAmount: _int(json['processedAmount']),
      telecomMarginTotal: _int(json['telecomMarginTotal']),
      cabinisteMarginTotal: _int(json['cabinisteMarginTotal']),
      izytelMarginTotal: _int(json['izytelMarginTotal']),
      customerFeeTotal: _int(json['customerFeeTotal']),
      izytelGrossGainTotal: _int(json['izytelGrossGainTotal']),
      settlementEarnedTotal: _int(json['settlementEarnedTotal']),
      paidTotal: _int(json['paidTotal']),
      balanceDue: _int(json['balanceDue']),
      toPayCount: _int(json['toPayCount']),
    );
  }

  final int cabinisteCount;
  final int completedOrders;
  final int processedAmount;
  final int telecomMarginTotal;
  final int cabinisteMarginTotal;
  final int izytelMarginTotal;
  final int customerFeeTotal;
  final int izytelGrossGainTotal;
  final int settlementEarnedTotal;
  final int paidTotal;
  final int balanceDue;
  final int toPayCount;
}

class CabinisteFinancePartner {
  const CabinisteFinancePartner({
    required this.partnerId,
    required this.partnerCode,
    required this.displayName,
    required this.phoneNumber,
    required this.status,
    required this.completedOrders,
    required this.processedAmount,
    required this.telecomMarginTotal,
    required this.cabinisteMarginTotal,
    required this.izytelMarginTotal,
    required this.customerFeeTotal,
    required this.izytelGrossGainTotal,
    required this.settlementEarnedTotal,
    required this.paidTotal,
    required this.balanceDue,
    required this.earnedTransactions,
    required this.paymentStatus,
  });

  factory CabinisteFinancePartner.fromJson(Map<String, dynamic> json) {
    return CabinisteFinancePartner(
      partnerId: _string(json['partnerId']),
      partnerCode: _string(json['partnerCode']),
      displayName: _string(json['displayName'], fallback: 'Cabiniste IzyTel'),
      phoneNumber: _string(json['phoneNumber']),
      status: _string(json['status']),
      completedOrders: _int(json['completedOrders']),
      processedAmount: _int(json['processedAmount']),
      telecomMarginTotal: _int(json['telecomMarginTotal']),
      cabinisteMarginTotal: _int(json['cabinisteMarginTotal']),
      izytelMarginTotal: _int(json['izytelMarginTotal']),
      customerFeeTotal: _int(json['customerFeeTotal']),
      izytelGrossGainTotal: _int(json['izytelGrossGainTotal']),
      settlementEarnedTotal: _int(json['settlementEarnedTotal']),
      paidTotal: _int(json['paidTotal']),
      balanceDue: _int(json['balanceDue']),
      earnedTransactions: _int(json['earnedTransactions']),
      paymentStatus: _string(json['paymentStatus']),
    );
  }

  final String partnerId;
  final String partnerCode;
  final String displayName;
  final String phoneNumber;
  final String status;
  final int completedOrders;
  final int processedAmount;
  final int telecomMarginTotal;
  final int cabinisteMarginTotal;
  final int izytelMarginTotal;
  final int customerFeeTotal;
  final int izytelGrossGainTotal;
  final int settlementEarnedTotal;
  final int paidTotal;
  final int balanceDue;
  final int earnedTransactions;
  final String paymentStatus;
}

class CabinisteFinanceSnapshot {
  const CabinisteFinanceSnapshot({
    required this.summary,
    required this.partners,
  });

  factory CabinisteFinanceSnapshot.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> summary = _map(json['summary']);
    final List<CabinisteFinancePartner> partners = _list(json['partners'])
        .map((dynamic item) => CabinisteFinancePartner.fromJson(_map(item)))
        .toList(growable: false);
    return CabinisteFinanceSnapshot(
      summary: CabinisteFinanceSummary.fromJson(summary),
      partners: partners,
    );
  }

  final CabinisteFinanceSummary summary;
  final List<CabinisteFinancePartner> partners;
}

class CabinisteFinanceOrder {
  const CabinisteFinanceOrder({
    required this.orderId,
    required this.orderReference,
    required this.network,
    required this.orderAmount,
    required this.telecomMarginAmount,
    required this.cabinisteMarginAmount,
    required this.izytelMarginAmount,
    required this.customerFeeAmount,
    required this.izytelGrossGain,
    required this.cabinisteSettlementAmount,
    required this.economicStatus,
    required this.computedAt,
    required this.reversedAt,
  });

  factory CabinisteFinanceOrder.fromJson(Map<String, dynamic> json) {
    return CabinisteFinanceOrder(
      orderId: _string(json['orderId']),
      orderReference: _string(json['orderReference']),
      network: _string(json['network']),
      orderAmount: _int(json['orderAmount']),
      telecomMarginAmount: _int(json['telecomMarginAmount']),
      cabinisteMarginAmount: _int(json['cabinisteMarginAmount']),
      izytelMarginAmount: _int(json['izytelMarginAmount']),
      customerFeeAmount: _int(json['customerFeeAmount']),
      izytelGrossGain: _int(json['izytelGrossGain']),
      cabinisteSettlementAmount: _int(json['cabinisteSettlementAmount']),
      economicStatus: _string(json['economicStatus']),
      computedAt: _date(json['computedAt']),
      reversedAt: _date(json['reversedAt']),
    );
  }

  final String orderId;
  final String orderReference;
  final String network;
  final int orderAmount;
  final int telecomMarginAmount;
  final int cabinisteMarginAmount;
  final int izytelMarginAmount;
  final int customerFeeAmount;
  final int izytelGrossGain;
  final int cabinisteSettlementAmount;
  final String economicStatus;
  final DateTime? computedAt;
  final DateTime? reversedAt;
}

class CabinisteFinancePeriod {
  const CabinisteFinancePeriod({
    required this.periodId,
    required this.periodKey,
    required this.status,
    required this.settlementEarned,
    required this.paid,
    required this.balanceDue,
  });

  factory CabinisteFinancePeriod.fromJson(Map<String, dynamic> json) {
    return CabinisteFinancePeriod(
      periodId: _string(json['periodId']),
      periodKey: _string(json['periodKey']),
      status: _string(json['status']),
      settlementEarned: _int(json['settlementEarned']),
      paid: _int(json['paid']),
      balanceDue: _int(json['balanceDue']),
    );
  }

  final String periodId;
  final String periodKey;
  final String status;
  final int settlementEarned;
  final int paid;
  final int balanceDue;
}

class CabinisteFinancePayout {
  const CabinisteFinancePayout({
    required this.payoutId,
    required this.periodId,
    required this.amount,
    required this.channel,
    required this.reference,
    required this.note,
    required this.paidAt,
    required this.createdByName,
  });

  factory CabinisteFinancePayout.fromJson(Map<String, dynamic> json) {
    return CabinisteFinancePayout(
      payoutId: _string(json['payoutId']),
      periodId: _string(json['periodId']),
      amount: _int(json['amount']),
      channel: _string(json['channel']),
      reference: _string(json['reference']),
      note: _string(json['note']),
      paidAt: _date(json['paidAt']),
      createdByName: _string(json['createdByName']),
    );
  }

  final String payoutId;
  final String periodId;
  final int amount;
  final String channel;
  final String reference;
  final String note;
  final DateTime? paidAt;
  final String createdByName;
}

class CabinisteFinanceHistory {
  const CabinisteFinanceHistory({
    required this.partner,
    required this.summary,
    required this.settlementEarnedTotal,
    required this.paidTotal,
    required this.balanceDue,
    required this.earnedTransactions,
    required this.orders,
    required this.periods,
    required this.payouts,
  });

  factory CabinisteFinanceHistory.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> partner = _map(json['partner']);
    final Map<String, dynamic> account = _map(json['account']);
    final Map<String, dynamic> summaryJson = _map(json['summary']);
    return CabinisteFinanceHistory(
      partner: CabinisteFinancePartner(
        partnerId: _string(partner['id']),
        partnerCode: _string(partner['code']),
        displayName: _string(partner['displayName'], fallback: 'Cabiniste IzyTel'),
        phoneNumber: _string(partner['phoneNumber']),
        status: _string(partner['status']),
        completedOrders: _int(summaryJson['completedOrders']),
        processedAmount: _int(summaryJson['processedAmount']),
        telecomMarginTotal: _int(summaryJson['telecomMarginTotal']),
        cabinisteMarginTotal: _int(summaryJson['cabinisteMarginTotal']),
        izytelMarginTotal: _int(summaryJson['izytelMarginTotal']),
        customerFeeTotal: _int(summaryJson['customerFeeTotal']),
        izytelGrossGainTotal: _int(summaryJson['izytelGrossGainTotal']),
        settlementEarnedTotal: _int(account['settlementEarnedTotal']),
        paidTotal: _int(account['paidTotal']),
        balanceDue: _int(account['balanceDue']),
        earnedTransactions: _int(account['earnedTransactions']),
        paymentStatus: _int(account['balanceDue']) > 0 ? 'to_pay' : 'paid',
      ),
      summary: summaryJson,
      settlementEarnedTotal: _int(account['settlementEarnedTotal']),
      paidTotal: _int(account['paidTotal']),
      balanceDue: _int(account['balanceDue']),
      earnedTransactions: _int(account['earnedTransactions']),
      orders: _list(json['orders'])
          .map((dynamic item) => CabinisteFinanceOrder.fromJson(_map(item)))
          .toList(growable: false),
      periods: _list(json['periods'])
          .map((dynamic item) => CabinisteFinancePeriod.fromJson(_map(item)))
          .toList(growable: false),
      payouts: _list(json['payouts'])
          .map((dynamic item) => CabinisteFinancePayout.fromJson(_map(item)))
          .toList(growable: false),
    );
  }

  final CabinisteFinancePartner partner;
  final Map<String, dynamic> summary;
  final int settlementEarnedTotal;
  final int paidTotal;
  final int balanceDue;
  final int earnedTransactions;
  final List<CabinisteFinanceOrder> orders;
  final List<CabinisteFinancePeriod> periods;
  final List<CabinisteFinancePayout> payouts;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<dynamic> _list(dynamic value) => value is List ? value : const <dynamic>[];

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _string(dynamic value, {String fallback = ''}) {
  final String text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  final String text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
}
