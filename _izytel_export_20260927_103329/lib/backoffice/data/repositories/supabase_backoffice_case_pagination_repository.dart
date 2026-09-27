import 'package:cabine_flow/features/agents/domain/models/agent_issue_center_models.dart';
import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';
import 'package:cabine_flow/features/support/domain/models/support_request.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BackofficeSupportPageItem {
  const BackofficeSupportPageItem({required this.request, this.refund});
  final SupportRequest request;
  final RefundCase? refund;
}

class BackofficeSupportPageData {
  const BackofficeSupportPageData({
    required this.items,
    required this.total,
    required this.allCount,
    required this.newCount,
    required this.inProgressCount,
    required this.resolvedCount,
  });
  final List<BackofficeSupportPageItem> items;
  final int total;
  final int allCount;
  final int newCount;
  final int inProgressCount;
  final int resolvedCount;
}

class BackofficeRefundPageData {
  const BackofficeRefundPageData({
    required this.items,
    required this.total,
    required this.pendingCount,
    required this.approvedCount,
    required this.completedCount,
    required this.exposure,
    required this.allCount,
    required this.refundedCount,
    required this.reconciledCount,
    required this.rejectedCount,
  });
  final List<RefundCase> items;
  final int total;
  final int pendingCount;
  final int approvedCount;
  final int completedCount;
  final int exposure;
  final int allCount;
  final int refundedCount;
  final int reconciledCount;
  final int rejectedCount;
}

class BackofficeAgentIssuePageData {
  const BackofficeAgentIssuePageData({
    required this.items,
    required this.total,
    required this.allCount,
    required this.openCount,
    required this.inProgressCount,
    required this.resolvedCount,
    required this.cancelledCount,
    required this.generatedAt,
    required this.callerRole,
    required this.scopeType,
  });
  final List<AgentIssueCenterItem> items;
  final int total;
  final int allCount;
  final int openCount;
  final int inProgressCount;
  final int resolvedCount;
  final int cancelledCount;
  final DateTime? generatedAt;
  final String callerRole;
  final String scopeType;
}

class SupabaseBackofficeCasePaginationRepository {
  SupabaseBackofficeCasePaginationRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<BackofficeSupportPageData> fetchSupportPage({
    DateTime? start,
    DateTime? end,
    required String scope,
    required String query,
    required int page,
    required int pageSize,
  }) async {
    final Map<String, dynamic> json = _map(await _client.rpc(
      'izytel_bo75b1_support_page',
      params: <String, dynamic>{
        'p_start': start?.toUtc().toIso8601String(),
        'p_end': end?.toUtc().toIso8601String(),
        'p_scope': scope,
        'p_query': query.trim(),
        'p_offset': (page - 1) * pageSize,
        'p_limit': pageSize,
      },
    ));
    final Map<String, dynamic> summary = _map(json['summary']);
    final List<BackofficeSupportPageItem> items = _list(json['items'])
        .map((Map<String, dynamic> item) {
          final SupportRequest? request = _supportFromRow(_map(item['request']));
          if (request == null) return null;
          final Map<String, dynamic> refundJson = _map(item['refund']);
          return BackofficeSupportPageItem(
            request: request,
            refund: refundJson.isEmpty ? null : _refundFromRow(refundJson),
          );
        })
        .whereType<BackofficeSupportPageItem>()
        .toList(growable: false);
    return BackofficeSupportPageData(
      items: items,
      total: _int(json['total']),
      allCount: _int(summary['all']),
      newCount: _int(summary['new']),
      inProgressCount: _int(summary['in_progress']),
      resolvedCount: _int(summary['resolved']),
    );
  }

  Future<BackofficeRefundPageData> fetchRefundPage({
    DateTime? start,
    DateTime? end,
    required String scope,
    required String query,
    required int page,
    required int pageSize,
  }) async {
    final Map<String, dynamic> json = _map(await _client.rpc(
      'izytel_bo75b1_refunds_page',
      params: <String, dynamic>{
        'p_start': start?.toUtc().toIso8601String(),
        'p_end': end?.toUtc().toIso8601String(),
        'p_scope': scope,
        'p_query': query.trim(),
        'p_offset': (page - 1) * pageSize,
        'p_limit': pageSize,
      },
    ));
    final Map<String, dynamic> summary = _map(json['summary']);
    return BackofficeRefundPageData(
      items: _list(json['items'])
          .map(_refundFromRow)
          .whereType<RefundCase>()
          .toList(growable: false),
      total: _int(json['total']),
      pendingCount: _int(summary['pending']),
      approvedCount: _int(summary['approved']),
      completedCount: _int(summary['completed']),
      exposure: _int(summary['exposure']),
      allCount: _int(summary['all']),
      refundedCount: _int(summary['refunded']),
      reconciledCount: _int(summary['reconciled']),
      rejectedCount: _int(summary['rejected']),
    );
  }


  Future<Set<String>> fetchRefundOrderIds() async {
    final dynamic response = await _client.from('refunds').select('order_id');
    final List<Map<String, dynamic>> rows = _list(response);
    return rows
        .map((Map<String, dynamic> row) => _string(row['order_id']))
        .where((String value) => value.isNotEmpty)
        .toSet();
  }

  Future<BackofficeAgentIssuePageData> fetchAgentIssuePage({
    DateTime? start,
    DateTime? end,
    required String scope,
    required String? network,
    required String query,
    required String sort,
    required int page,
    required int pageSize,
  }) async {
    final Map<String, dynamic> json = _map(await _client.rpc(
      'izytel_bo75b1_agent_issues_page',
      params: <String, dynamic>{
        'p_start': start?.toUtc().toIso8601String(),
        'p_end': end?.toUtc().toIso8601String(),
        'p_scope': scope,
        'p_network': network,
        'p_query': query.trim(),
        'p_sort': sort,
        'p_offset': (page - 1) * pageSize,
        'p_limit': pageSize,
      },
    ));
    final Map<String, dynamic> summary = _map(json['summary']);
    final Map<String, dynamic> scopeJson = _map(json['scope']);
    return BackofficeAgentIssuePageData(
      items: _list(json['items'])
          .map(AgentIssueCenterItem.fromJson)
          .toList(growable: false),
      total: _int(json['total']),
      allCount: _int(summary['all']),
      openCount: _int(summary['open']),
      inProgressCount: _int(summary['in_progress']),
      resolvedCount: _int(summary['resolved']),
      cancelledCount: _int(summary['cancelled']),
      generatedAt: _date(json['generated_at']),
      callerRole: _string(json['caller_role']),
      scopeType: _string(scopeJson['type']),
    );
  }

  SupportRequest? _supportFromRow(Map<String, dynamic> row) {
    final String id = _string(row['id']);
    final String orderId = _string(row['order_id']);
    final String reference = _string(row['order_reference']);
    final String uid = _string(row['customer_auth_uid']);
    final DateTime? createdAt = _date(row['created_at']);
    final DateTime? updatedAt = _date(row['updated_at']);
    if (id.isEmpty || orderId.isEmpty || reference.isEmpty || uid.isEmpty || createdAt == null || updatedAt == null) {
      return null;
    }
    return SupportRequest(
      id: id,
      orderId: orderId,
      orderReference: reference,
      customerAuthUid: uid,
      type: SupportRequestTypeX.fromStorage(_string(row['type'])),
      description: _string(row['description']),
      status: SupportRequestStatusX.fromStorage(_string(row['status'])),
      createdAt: createdAt,
      updatedAt: updatedAt,
      assignedTo: _nullable(row['assigned_to']),
      assignedToName: _nullable(row['assigned_to_name']),
      inProgressAt: _date(row['in_progress_at']),
      resolutionNote: _nullable(row['resolution_note']),
      resolvedAt: _date(row['resolved_at']),
      resolvedBy: _nullable(row['resolved_by']),
      resolvedByName: _nullable(row['resolved_by_name']),
      customerNotifiedAt: _date(row['customer_notified_at']),
      customerNotifiedBy: _nullable(row['customer_notified_by']),
      customerNotifiedByName: _nullable(row['customer_notified_by_name']),
      notificationChannel: _nullable(row['notification_channel']),
      closedAt: _date(row['closed_at']),
      closedBy: _nullable(row['closed_by']),
      closedByName: _nullable(row['closed_by_name']),
    );
  }

  RefundCase? _refundFromRow(Map<String, dynamic> row) {
    final String orderId = _string(row['order_id']);
    final String reference = _string(row['order_reference']);
    final String clientName = _string(row['client_name']);
    final DateTime? requestedAt = _date(row['requested_at']);
    final DateTime? updatedAt = _date(row['updated_at']);
    if (orderId.isEmpty || reference.isEmpty || clientName.isEmpty || requestedAt == null || updatedAt == null) return null;
    return RefundCase(
      id: orderId,
      orderId: orderId,
      orderReference: reference,
      origin: RefundOriginX.fromStorage(_string(row['origin'])),
      supportRequestId: _string(row['support_request_id']),
      supportRequestType: _string(row['support_request_type']),
      supportRequestDescription: _string(row['support_request_description']),
      customerAuthUid: _nullable(row['customer_auth_uid']),
      clientName: clientName,
      clientWhatsappPhone: _string(row['client_whatsapp_phone']),
      originalAmount: _int(row['original_amount']),
      amount: _int(row['amount']),
      reason: RefundReasonX.fromStorage(_string(row['reason'])),
      reasonNote: _string(row['reason_note']),
      paymentChannel: _string(row['payment_channel'], fallback: 'wave'),
      originalPaymentReference: _nullable(row['original_payment_reference']),
      status: RefundStatusX.fromStorage(_string(row['status'])),
      requestedAt: requestedAt,
      requestedBy: _string(row['requested_by']),
      requestedByName: _string(row['requested_by_name']),
      updatedAt: updatedAt,
      approvedAt: _date(row['approved_at']),
      approvedBy: _nullable(row['approved_by']),
      approvedByName: _nullable(row['approved_by_name']),
      rejectedAt: _date(row['rejected_at']),
      rejectedBy: _nullable(row['rejected_by']),
      rejectedByName: _nullable(row['rejected_by_name']),
      rejectionReason: _nullable(row['rejection_reason']),
      refundReference: _nullable(row['refund_reference']),
      refundedAt: _date(row['refunded_at']),
      refundedBy: _nullable(row['refunded_by']),
      refundedByName: _nullable(row['refunded_by_name']),
      customerNotifiedAt: _date(row['customer_notified_at']),
      customerNotifiedBy: _nullable(row['customer_notified_by']),
      customerNotifiedByName: _nullable(row['customer_notified_by_name']),
      notificationChannel: _nullable(row['notification_channel']),
      reconciledAt: _date(row['reconciled_at']),
      reconciledBy: _nullable(row['reconciled_by']),
      reconciledByName: _nullable(row['reconciled_by_name']),
    );
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is! Map) return <String, dynamic>{};
    return value.map((dynamic key, dynamic item) => MapEntry(key.toString(), item));
  }

  List<Map<String, dynamic>> _list(Object? value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value.whereType<Map>().map((Map<dynamic, dynamic> item) => item.map((dynamic key, dynamic field) => MapEntry(key.toString(), field))).toList(growable: false);
  }

  String _string(Object? value, {String fallback = ''}) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String? _nullable(Object? value) {
    final String valueText = _string(value);
    return valueText.isEmpty ? null : valueText;
  }

  int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? _date(Object? value) {
    if (value is DateTime) return value.toLocal();
    final String raw = _string(value);
    return raw.isEmpty ? null : DateTime.tryParse(raw)?.toLocal();
  }
}
