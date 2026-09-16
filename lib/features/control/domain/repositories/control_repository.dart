import 'package:cabine_flow/features/control/domain/models/control_snapshot.dart';

abstract interface class ControlRepository {
  Future<ControlSnapshot> fetchSnapshot();
}
