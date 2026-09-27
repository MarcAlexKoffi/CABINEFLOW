import 'package:cabine_flow/backoffice/backoffice_app.dart';
import 'package:cabine_flow/core/firebase/firebase_bootstrap.dart';
import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  await FirebaseBootstrap.initialize();

  final FirebaseAuth auth = FirebaseAuth.instance;
  await auth.setPersistence(Persistence.LOCAL);

  // La restauration Firebase et l'initialisation Supabase sont indépendantes
  // au démarrage. Les lancer en parallèle évite d'additionner leurs latences.
  final Future<User?> restoredSession = auth.authStateChanges().first;
  final Future<bool> supabaseReady = SupabaseBootstrap.initialize();
  await restoredSession;
  await supabaseReady;

  runApp(const BackofficeApp());
}
