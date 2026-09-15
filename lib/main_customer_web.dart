import 'package:cabine_flow/core/firebase/firebase_bootstrap.dart';
import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:cabine_flow/customer_order_app.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  await FirebaseBootstrap.initialize();

  final FirebaseAuth auth = FirebaseAuth.instance;

  // Sur le Web, la session anonyme doit rester la même après une
  // actualisation, une fermeture ou l'ouverture d'un nouvel onglet.
  await auth.setPersistence(Persistence.LOCAL);

  // Le catalogue public n'a pas besoin d'attendre la restauration Firebase.
  // Les repositories de commandes/profil savent déjà attendre la session
  // restaurée avant de créer une éventuelle session anonyme. On peut donc
  // afficher l'accueil immédiatement après le bootstrap Supabase local.
  await SupabaseBootstrap.initialize();

  runApp(const CustomerOrderApp());
}
