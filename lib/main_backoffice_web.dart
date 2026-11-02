import 'package:cabine_flow/backoffice/backoffice_app.dart';
import 'package:cabine_flow/core/firebase/firebase_bootstrap.dart';
import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:cabine_flow/core/diagnostics/startup_trace.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  StartupTrace.start();
  await FirebaseBootstrap.initialize();
  StartupTrace.mark('firebase-initialized');

  final FirebaseAuth auth = FirebaseAuth.instance;
  await auth.setPersistence(Persistence.LOCAL);
  StartupTrace.mark('auth-persistence-configured');

  // La restauration Firebase et l'initialisation Supabase sont indépendantes
  // au démarrage. Les lancer en parallèle évite d'additionner leurs latences.
  final Future<void> restoredSession = auth.authStateChanges().first.then((_) {
    StartupTrace.mark('firebase-auth-restored');
  });
  final Future<void> supabaseReady = SupabaseBootstrap.initialize().then((_) {
    StartupTrace.mark('supabase-initialized');
  });

  runApp(
    BackofficeApp(
      authRestoration: restoredSession,
      supabaseInitialization: supabaseReady,
    ),
  );
  StartupTrace.mark('run-app');
}
