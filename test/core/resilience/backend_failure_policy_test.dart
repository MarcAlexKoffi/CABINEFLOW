import 'dart:async';

import 'package:cabine_flow/core/resilience/backend_failure_policy.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('BackendFailurePolicy.classify', () {
    test('distinguishes timeout and network failures', () {
      expect(
        BackendFailurePolicy.classify(TimeoutException('late response')),
        BackendFailureKind.timeout,
      );
      expect(
        BackendFailurePolicy.classify(Exception('connection refused')),
        BackendFailureKind.network,
      );
      expect(
        BackendFailurePolicy.classify(
          const _SyntheticWebFailure('XMLHttpRequest error.'),
        ),
        BackendFailureKind.network,
      );
      expect(
        BackendFailurePolicy.classify(_RealtimeSubscribeException()),
        BackendFailureKind.network,
      );
      expect(
        BackendFailurePolicy.safeCode(_RealtimeSubscribeException()),
        'supabase-realtime:subscribe',
      );
    });

    test('distinguishes Firebase session and permission failures', () {
      expect(
        BackendFailurePolicy.classify(
          FirebaseException(plugin: 'auth', code: 'user-token-expired'),
        ),
        BackendFailureKind.unauthorized,
      );
      expect(
        BackendFailurePolicy.classify(
          FirebaseException(plugin: 'firestore', code: 'permission-denied'),
        ),
        BackendFailureKind.forbidden,
      );
    });

    test('distinguishes PostgREST auth, RLS, RPC and server failures', () {
      expect(
        BackendFailurePolicy.classify(
          const PostgrestException(message: 'expired', code: 'PGRST301'),
        ),
        BackendFailureKind.unauthorized,
      );
      expect(
        BackendFailurePolicy.classify(
          const PostgrestException(message: 'denied', code: '42501'),
        ),
        BackendFailureKind.forbidden,
      );
      expect(
        BackendFailurePolicy.classify(
          const PostgrestException(message: 'missing RPC', code: 'PGRST202'),
        ),
        BackendFailureKind.notFound,
      );
      expect(
        BackendFailurePolicy.classify(
          const PostgrestException(message: 'backend down', code: 'PGRST000'),
        ),
        BackendFailureKind.network,
      );
    });

    test('marks malformed responses as contract failures', () {
      expect(
        BackendFailurePolicy.classify(StateError('invalid snapshot')),
        BackendFailureKind.contract,
      );
    });
  });
}

class _SyntheticWebFailure implements Exception {
  const _SyntheticWebFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class _RealtimeSubscribeException implements Exception {}
