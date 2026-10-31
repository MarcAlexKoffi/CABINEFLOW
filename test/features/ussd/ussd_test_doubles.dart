import 'dart:async';
import 'package:cabine_flow/features/ussd/domain/ussd_engine.dart';
import 'package:cabine_flow/features/ussd/domain/ussd_repository.dart';
import 'package:cabine_flow/features/ussd/platform/ussd_dialer.dart';

UssdRule syntheticRule({
  String id = 'synthetic-rule',
  String status = 'active',
  int version = 2,
}) => UssdRule(
  id: id,
  version: version,
  network: 'moov',
  service: 'internetSubscription',
  scope: 'both',
  template: '*999*{{msisdn_local}}#',
  priority: 0,
  status: status,
  effectiveFrom: DateTime.utc(2020),
);
UssdResolution syntheticResolution({
  bool mismatch = false,
  int version = 2,
  String? attemptId,
  int validForMs = 10000,
  String beneficiary = '0101010101',
}) => UssdResolution(
  status: 'available',
  reason: '',
  rule: syntheticRule(version: version),
  code: '*999*$beneficiary#',
  mismatch: mismatch,
  attemptId: attemptId,
  validForMs: validForMs,
  context: {
    'network': 'moov',
    'service': 'internetSubscription',
    'beneficiary': beneficiary,
    'offer_label': 'Offre synthétique',
    'amount': 1000,
  },
);

class UssdTestRepository implements UssdRepository {
  int resolutions = 0, preparations = 0, recordings = 0, reportCount = 0;
  UssdResolution response = syntheticResolution();
  bool failRead = false, revokeOnPrepare = false;
  String? lastStatus, lastReason;
  int? reportedVersion;
  Map<String, dynamic>? saved;
  int statusChanges = 0;
  int leaseMs = 10000;
  @override
  Future<UssdResolution> resolve(String orderId) async {
    resolutions++;
    if (failRead) throw StateError('synthetic offline');
    return response;
  }

  @override
  Future<UssdResolution> prepare(
    String orderId,
    UssdResolution confirmed,
    String requestId,
  ) async {
    preparations++;
    return revokeOnPrepare
        ? const UssdResolution(status: 'unavailable', reason: 'rule_changed')
        : syntheticResolution(
            mismatch: response.mismatch,
            version: response.rule!.version,
            attemptId: 'synthetic-attempt',
            validForMs: leaseMs,
          );
  }

  @override
  Future<void> recordResult(
    String attemptId,
    String status,
    String? errorCode,
  ) async {
    recordings++;
    lastStatus = status;
    lastReason = errorCode;
  }

  @override
  Future<void> report(
    String orderId,
    UssdResolution? resolution,
    String reason,
    String note,
  ) async {
    reportCount++;
    reportedVersion = resolution?.rule?.version;
  }

  @override
  Future<Map<String, dynamic>> configuration() async => {
    'rules': [
      {
        'id': 'synthetic-rule',
        'version': 2,
        'network': 'moov',
        'service': 'internetSubscription',
        'actor_scope': 'both',
        'ussd_template': '*999*{{msisdn_local}}#',
        'priority': 0,
        'status': 'draft',
        'effective_from': '2020-01-01T00:00:00Z',
        'updated_by': 'synthetic-admin',
      },
    ],
    'families': [],
    'offers': [],
  };
  @override
  Future<void> saveRule(
    Map<String, dynamic> payload, {
    String? id,
    int? version,
  }) async {
    saved = payload;
  }

  @override
  Future<void> setStatus(
    UssdRule rule,
    String status, {
    String? simType,
  }) async {
    statusChanges++;
  }

  @override
  Future<List<Map<String, dynamic>>> reports({int offset = 0}) async => [];
  @override
  Future<List<Map<String, dynamic>>> logs({int offset = 0}) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class UssdTestDialer implements UssdDialer {
  int opens = 0;
  Completer<void>? pending;
  bool fail = false;
  @override
  bool supported = true;
  @override
  Future<void> open(String code) async {
    opens++;
    if (fail) throw StateError('synthetic no dialer');
    await pending?.future;
  }
}
