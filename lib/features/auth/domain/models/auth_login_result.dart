import 'package:cabine_flow/features/auth/domain/models/app_user.dart';

import 'app_user.dart';

enum AuthLoginStatus {
  authenticated,
  pendingActivation,
  inactive,
  invalidCredentials,
  unavailable,
}

class AuthLoginResult {
  AuthLoginResult.authenticated(AppUser authenticatedUser)
    : status = AuthLoginStatus.authenticated,
      user = authenticatedUser,
      profileName = authenticatedUser.name,
      email = null,
      message = null;

  const AuthLoginResult.pendingActivation({
    required this.profileName,
    required this.email,
    this.message,
  }) : status = AuthLoginStatus.pendingActivation,
       user = null;

  const AuthLoginResult.inactive({
    required this.profileName,
    required this.email,
    this.message,
  }) : status = AuthLoginStatus.inactive,
       user = null;

  const AuthLoginResult.invalidCredentials({this.message})
    : status = AuthLoginStatus.invalidCredentials,
      user = null,
      profileName = null,
      email = null;

  const AuthLoginResult.unavailable({this.message})
    : status = AuthLoginStatus.unavailable,
      user = null,
      profileName = null,
      email = null;

  final AuthLoginStatus status;
  final AppUser? user;
  final String? profileName;
  final String? email;
  final String? message;

  bool get isAuthenticated {
    return status == AuthLoginStatus.authenticated && user != null;
  }

  bool get requiresAccessScreen {
    return status == AuthLoginStatus.pendingActivation ||
        status == AuthLoginStatus.inactive;
  }
}
