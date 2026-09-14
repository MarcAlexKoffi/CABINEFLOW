import 'package:cabine_flow/backoffice/backoffice_app.dart';
import 'package:cabine_flow/core/firebase/firebase_bootstrap.dart';
import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  await FirebaseBootstrap.initialize();

  final FirebaseAuth auth = FirebaseAuth.instance;
  await auth.setPersistence(Persistence.LOCAL);
  await auth.authStateChanges().first;

  // Le back-office réutilise les mêmes sources canoniques Supabase que le
  // mobile staff. L'initialisation intervient après restauration Firebase afin
  // que le JWT staff soit immédiatement disponible pour la Data API/Realtime.
  await SupabaseBootstrap.initialize();

  runApp(const BackofficeApp());
}
