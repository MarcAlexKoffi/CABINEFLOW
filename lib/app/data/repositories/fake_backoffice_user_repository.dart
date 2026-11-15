import 'package:cabine_flow/app/domain/entities/backoffice/backoffice_user_account.dart';
import 'package:cabine_flow/app/domain/repositories/backoffice_user_repository.dart';

class FakeBackofficeUserRepository implements BackofficeUserRepository {
  const FakeBackofficeUserRepository({this.users = const <BackofficeUserAccount>[]});

  final List<BackofficeUserAccount> users;

  @override
  Stream<List<BackofficeUserAccount>> watchUsers() {
    return Stream<List<BackofficeUserAccount>>.value(
      List<BackofficeUserAccount>.unmodifiable(users),
    );
  }
}
