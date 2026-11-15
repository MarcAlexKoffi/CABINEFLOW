import 'package:cabine_flow/app/domain/entities/control/control_snapshot.dart';

abstract interface class ControlRepository {
  Future<ControlSnapshot> fetchSnapshot();

  Future<ControlActivityPageData> fetchActivityPage({
    DateTime? start,
    DateTime? end,
    String? domain,
    String query = '',
    int offset = 0,
    int limit = 100,
  });

  Future<ControlAuditPageData> fetchAuditPage({
    DateTime? start,
    DateTime? end,
    String? domain,
    String query = '',
    int offset = 0,
    int limit = 100,
  });
}
