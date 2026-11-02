import 'dart:async';

import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

/// A cache/network error never becomes a fabricated revocation.
class SessionAccessRecord {
  const SessionAccessRecord({
    required this.role,
    required this.active,
    this.serverConfirmed = true,
  });
  final String role;
  final bool active;
  final bool serverConfirmed;
  bool allows(AppUser user) {
    final expected = switch (user.role) {
      UserRole.administrator => 'admin',
      UserRole.manager || UserRole.supervisor => 'manager',
      _ => user.role.name,
    };
    final actual = switch (role) {
      'administrator' => 'admin',
      'supervisor' => 'manager',
      'partner' => 'cabiniste',
      _ => role,
    };
    return active && expected == actual;
  }
}

/// Forces re-authentication after a confirmed administrative role/status change.
/// Backend rules and SQL guards remain responsible for resource authorization.
class SessionAccessBoundary extends StatefulWidget {
  const SessionAccessBoundary({
    super.key,
    required this.user,
    required this.onAccessChanged,
    required this.child,
    this.accessRecords,
  });
  final AppUser user;
  final Future<void> Function() onAccessChanged;
  final Widget child;
  final Stream<SessionAccessRecord>? accessRecords;
  @override
  State<SessionAccessBoundary> createState() => _SessionAccessBoundaryState();
}

class _SessionAccessBoundaryState extends State<SessionAccessBoundary> {
  StreamSubscription<SessionAccessRecord>? _subscription;
  bool _invalidated = false;
  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(SessionAccessBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.user.role != widget.user.role ||
        oldWidget.accessRecords != widget.accessRecords) {
      unawaited(_subscription?.cancel());
      _invalidated = false;
      _listen();
    }
  }

  Stream<SessionAccessRecord>? _records() {
    if (widget.accessRecords != null) return widget.accessRecords;
    if (Firebase.apps.isEmpty ||
        FirebaseAuth.instance.currentUser?.uid != widget.user.id) {
      return null;
    }
    if (widget.user.role == UserRole.cabiniste) {
      if (!SupabaseBootstrap.isInitialized) return null;
      return Supabase.instance.client
          .from('partner_accounts')
          .stream(primaryKey: const ['id'])
          .eq('firebase_uid', widget.user.id)
          .map(
            (rows) => SessionAccessRecord(
              role: 'cabiniste',
              active: rows.any((r) => r['status'] == 'active'),
            ),
          );
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.id)
        .snapshots(includeMetadataChanges: true)
        .map(
          (doc) => SessionAccessRecord(
            role: doc.data()?['role']?.toString() ?? '',
            active: doc.exists && doc.data()?['isActive'] == true,
            serverConfirmed:
                !doc.metadata.isFromCache && !doc.metadata.hasPendingWrites,
          ),
        );
  }

  void _listen() {
    _subscription = _records()?.listen(
      (record) {
        if (!mounted ||
            _invalidated ||
            !record.serverConfirmed ||
            record.allows(widget.user)) {
          return;
        }
        _invalidated = true;
        unawaited(
          Future<void>(() async {
            if (mounted) await widget.onAccessChanged();
          }).catchError((Object error, StackTrace stack) {
            IzyTelLog.backendError(
              'SessionAccessBoundary.invalidate',
              error,
              stackTrace: stack,
            );
          }),
        );
      },
      onError: (Object error, StackTrace stack) {
        IzyTelLog.backendError(
          'SessionAccessBoundary.read',
          error,
          stackTrace: stack,
        );
      },
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
