import 'package:cabine_flow/backoffice/domain/models/backoffice_user_account.dart';

abstract class BackofficeUserRepository {
  Stream<List<BackofficeUserAccount>> watchUsers();
}
