import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A device-local capability, bound on the server to Firebase's auth_time.
/// Persist before sending a write so a lost response can be queried safely.
class OrderExecutionSession {
  static const header = 'x-izytel-execution-key';
  static final Map<String, Future<String>> _pending = {};

  static String randomKey() {
    final random = Random.secure();
    return List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static Future<String> key() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Reconnectez-vous avant de démarrer.');
    final token = await user.getIdTokenResult();
    final authTime = token.claims?['auth_time'];
    if (authTime == null) {
      throw StateError('Reconnectez-vous avant de démarrer.');
    }
    final storageKey = 'izytel.execution.${user.uid}.$authTime';
    return _storedKey(storageKey);
  }

  static Future<String> operationKey(String operation) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Reconnectez-vous avant de continuer.');
    return _storedKey('izytel.operation.$uid.$operation');
  }

  static Future<void> finishOperation(String operation) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final name = 'izytel.operation.$uid.$operation';
    await (await SharedPreferences.getInstance()).remove(name);
    _pending.remove(name);
  }

  static Future<String> _storedKey(String storageKey) async {
    try {
      return await _pending.putIfAbsent(storageKey, () async {
        final preferences = await SharedPreferences.getInstance();
        final stored = preferences.getString(storageKey);
        if (stored != null) return stored;
        final created = randomKey();
        if (!await preferences.setString(storageKey, created)) {
          throw StateError('Impossible de préparer cette session. Réessayez.');
        }
        return created;
      });
    } catch (_) {
      _pending.remove(storageKey);
      rethrow;
    }
  }
}
