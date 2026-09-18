import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/core/resilience/backend_failure_policy.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/models/auth_login_result.dart';
import 'package:cabine_flow/features/auth/domain/repositories/auth_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  @override
  Future<AuthLoginResult> login({
    required String identifier,
    required String password,
  }) async {
    final String email = identifier.trim().toLowerCase();

    if (!_looksLikeEmail(email) || password.isEmpty) {
      return const AuthLoginResult.invalidCredentials();
    }

    try {
      final UserCredential credential = await _firebaseAuth
          .signInWithEmailAndPassword(email: email, password: password);

      final User? firebaseUser = credential.user;
      if (firebaseUser == null) {
        return const AuthLoginResult.unavailable(
          message: 'La session Firebase n’a pas pu être ouverte.',
        );
      }

      return _resolveAccess(
        firebaseUser: firebaseUser,
        createPendingProfileWhenMissing: true,
      );
    } on FirebaseAuthException catch (error) {
      if (_isInvalidCredentialError(error.code)) {
        return const AuthLoginResult.invalidCredentials();
      }

      if (error.code == 'user-disabled') {
        return const AuthLoginResult.unavailable(
          message: 'Ce compte Firebase Authentication a été désactivé.',
        );
      }

      return const AuthLoginResult.unavailable(
        message: 'Connexion momentanément indisponible. Réessaie dans un instant.',
      );
    } on FirebaseException catch (error, stackTrace) {
      return _handleAccessFailure(
        error,
        stackTrace,
        signOutWhenPermanent: true,
      );
    } catch (error, stackTrace) {
      return _handleAccessFailure(
        error,
        stackTrace,
        signOutWhenPermanent: true,
      );
    }
  }

  @override
  Future<AuthLoginResult> refreshCurrentAccess() async {
    try {
      final User? currentUser = _firebaseAuth.currentUser;
      if (currentUser == null) {
        return const AuthLoginResult.unavailable(
          message: 'La session a expiré. Reconnecte-toi.',
        );
      }

      // Ne force pas `reload()` au démarrage : Firebase Auth restaure déjà la
      // session locale. Un reload réseau imposé pouvait renvoyer l'utilisateur
      // à l'écran de connexion après un simple redémarrage ou une coupure.
      // La lecture du profil Firestore est rejouée en cas d'erreur transitoire
      // puis retombe sur le cache persistant du téléphone si nécessaire.
      return _resolveAccess(
        firebaseUser: currentUser,
        createPendingProfileWhenMissing: true,
      );
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-disabled' || error.code == 'user-not-found') {
        await _safeSignOut();

        return const AuthLoginResult.unavailable(
          message: 'Ce compte n’est plus disponible.',
        );
      }

      return const AuthLoginResult.unavailable(
        message: 'Connexion momentanément instable. Réessaie dans un instant.',
      );
    } on FirebaseException catch (error, stackTrace) {
      return _handleAccessFailure(
        error,
        stackTrace,
        signOutWhenPermanent: false,
      );
    } catch (error, stackTrace) {
      return _handleAccessFailure(
        error,
        stackTrace,
        signOutWhenPermanent: false,
      );
    }
  }

  @override
  Future<void> logout() async {
    await _firebaseAuth.signOut();
  }

  Future<AuthLoginResult> _resolveAccess({
    required User firebaseUser,
    required bool createPendingProfileWhenMissing,
  }) async {
    final DocumentReference<Map<String, dynamic>> profileReference = _firestore
        .collection('users')
        .doc(firebaseUser.uid);

    final DocumentSnapshot<Map<String, dynamic>> profileSnapshot =
        await _readProfileSnapshot(profileReference);

    if (!profileSnapshot.exists && createPendingProfileWhenMissing) {
      final String? email = firebaseUser.email?.trim().toLowerCase();

      if (email == null || email.isEmpty) {
        await _safeSignOut();

        return const AuthLoginResult.unavailable(
          message: 'Ce compte ne possède pas d’adresse e-mail utilisable.',
        );
      }

      final String profileName = _buildInitialName(firebaseUser, email);

      await profileReference.set(<String, dynamic>{
        'schemaVersion': 1,
        'name': profileName,
        'email': email,
        'phoneNumber': '',
        'role': 'pending',
        'isActive': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return AuthLoginResult.pendingActivation(
        profileName: profileName,
        email: email,
        message:
            'Ton profil a été créé et attend l’activation d’un administrateur.',
      );
    }

    final Map<String, dynamic>? data = profileSnapshot.data();
    if (!profileSnapshot.exists || data == null) {
      return const AuthLoginResult.unavailable(
        message: 'Le profil utilisateur est introuvable.',
      );
    }

    final String email = _readString(
      data['email'],
      fallback: firebaseUser.email ?? '',
    );

    final String name = _readString(
      data['name'],
      fallback: _buildInitialName(firebaseUser, email),
    );

    final String roleValue = _readString(
      data['role'],
      fallback: 'pending',
    ).toLowerCase();

    final bool isActive = data['isActive'] == true;

    if (roleValue == 'pending') {
      return AuthLoginResult.pendingActivation(profileName: name, email: email);
    }

    final UserRole? role = _parseRole(roleValue);
    if (role == null) {
      await _safeSignOut();

      return const AuthLoginResult.unavailable(
        message: 'Le rôle associé à ce compte n’est pas reconnu.',
      );
    }

    if (!isActive) {
      return AuthLoginResult.inactive(
        profileName: name,
        email: email,
        message: 'Ce compte a été désactivé par un administrateur.',
      );
    }

    final String phoneNumber = _readString(
      data['phoneNumber'],
      fallback: firebaseUser.phoneNumber ?? '',
    );

    return AuthLoginResult.authenticated(
      AppUser(
        id: firebaseUser.uid,
        name: name,
        phoneNumber: phoneNumber,
        role: role,
      ),
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _readProfileSnapshot(
    DocumentReference<Map<String, dynamic>> profileReference,
  ) async {
    Object? originalError;
    StackTrace? originalStackTrace;

    try {
      return await BackendFailurePolicy.retryIdempotent(
        () => profileReference.get(),
        maxAttempts: 3,
        baseDelay: const Duration(milliseconds: 300),
        maxDelay: const Duration(seconds: 2),
      );
    } catch (error, stackTrace) {
      originalError = error;
      originalStackTrace = stackTrace;
      if (!BackendFailurePolicy.canRetryRead(error)) rethrow;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> cached =
          await profileReference.get(const GetOptions(source: Source.cache));
      if (cached.exists && cached.data() != null) {
        IzyTelLog.debug('[Auth][profile-cache-fallback]');
        return cached;
      }
    } catch (cacheError, cacheStackTrace) {
      IzyTelLog.backendError(
        'Auth.profile-cache',
        cacheError,
        stackTrace: cacheStackTrace,
      );
    }

    Error.throwWithStackTrace(originalError!, originalStackTrace!);
  }

  Future<AuthLoginResult> _handleAccessFailure(
    Object error,
    StackTrace stackTrace, {
    required bool signOutWhenPermanent,
  }) async {
    final bool transient = BackendFailurePolicy.canRetryRead(error);
    IzyTelLog.backendError(
      'Auth.access',
      error,
      stackTrace: stackTrace,
    );

    if (transient) {
      return const AuthLoginResult.unavailable(
        message:
            'Connexion momentanément instable. Ta session reste ouverte ; réessaie dans un instant.',
      );
    }

    if (signOutWhenPermanent) {
      await _safeSignOut();
    }

    return const AuthLoginResult.unavailable(
      message: 'Impossible de vérifier les autorisations du compte.',
    );
  }

  String _buildInitialName(User firebaseUser, String email) {
    final String displayName = firebaseUser.displayName?.trim() ?? '';

    if (displayName.length >= 2) {
      return _limitLength(displayName, 80);
    }

    final String localPart = email.split('@').first;
    final String cleanedLocalPart = localPart
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleanedLocalPart.length < 2) {
      return 'Nouvel utilisateur';
    }

    final List<String> words = cleanedLocalPart.split(' ');
    final String formattedName = words
        .map((String word) {
          if (word.isEmpty) {
            return word;
          }

          return '${word.substring(0, 1).toUpperCase()}${word.substring(1)}';
        })
        .join(' ');

    return _limitLength(formattedName, 80);
  }

  String _limitLength(String value, int maximumLength) {
    if (value.length <= maximumLength) {
      return value;
    }

    return value.substring(0, maximumLength).trim();
  }

  bool _looksLikeEmail(String value) {
    final int atIndex = value.indexOf('@');
    final int dotIndex = value.lastIndexOf('.');

    return atIndex > 0 && dotIndex > atIndex + 1 && dotIndex < value.length - 1;
  }

  bool _isInvalidCredentialError(String code) {
    return code == 'invalid-credential' ||
        code == 'invalid-email' ||
        code == 'user-not-found' ||
        code == 'wrong-password';
  }

  UserRole? _parseRole(String value) {
    switch (value) {
      case 'admin':
      case 'administrator':
        return UserRole.administrator;
      case 'manager':
        return UserRole.manager;
      case 'supervisor':
        // Alias Firestore temporaire : le backend garde `supervisor`,
        // l application expose officiellement le role Manager.
        return UserRole.manager;
      case 'operator':
        return UserRole.operator;
      case 'agent':
        return UserRole.agent;
      default:
        return null;
    }
  }

  String _readString(Object? value, {required String fallback}) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return fallback;
  }

  Future<void> _safeSignOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (_) {
      // Ne masque pas l’erreur qui a déclenché la déconnexion.
    }
  }
}
