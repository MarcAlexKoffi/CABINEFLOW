import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

class SupabaseBootstrap {
  SupabaseBootstrap._();

  static const String url = 'https://zrxeztxaxnzxevjuhzcc.supabase.co';
  static const String publishableKey =
      'sb_publishable_6i0SKdOpBIAdTJj-TdepsA_LyB9dGeX';

  static bool _initialized = false;
  static StreamSubscription<User?>? _firebaseTokenSubscription;

  static bool get isInitialized => _initialized;

  static Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      await Supabase.initialize(
        url: url,
        publishableKey: publishableKey,
        debug: kDebugMode,
        accessToken: () async {
          return FirebaseAuth.instance.currentUser?.getIdToken();
        },
      );
      _initialized = true;

      // Le callback accessToken couvre la Data API et Storage. Pour Realtime,
      // on synchronise aussi explicitement le JWT Firebase avec le WebSocket.
      // Cela est indispensable lorsque Firebase restaure/change sa session
      // après l'initialisation de Supabase.
      await _syncRealtimeAuth(FirebaseAuth.instance.currentUser);
      _firebaseTokenSubscription ??= FirebaseAuth.instance
          .idTokenChanges()
          .listen(
            (User? user) {
              unawaited(_syncRealtimeAuth(user));
            },
            onError: (Object error, StackTrace stackTrace) {
              debugPrint('[SupabaseBootstrap][FirebaseToken] $error');
              debugPrintStack(stackTrace: stackTrace);
            },
          );

      return true;
    } catch (error, stackTrace) {
      debugPrint('[SupabaseBootstrap] Initialisation impossible: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  static Future<void> _syncRealtimeAuth(User? user) async {
    if (!_initialized) return;
    try {
      final String? token = await user?.getIdToken();
      await Supabase.instance.client.realtime.setAuth(token);
    } catch (error, stackTrace) {
      // Une panne Realtime ne doit jamais empêcher Firebase Auth, la Data API
      // Supabase ou le reste d'IzyTel de fonctionner.
      debugPrint('[SupabaseBootstrap][RealtimeAuth] $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
