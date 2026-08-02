import 'package:cabine_flow/core/firebase/firebase_bootstrap.dart';
import 'package:cabine_flow/customer_order_app.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  await FirebaseBootstrap.initialize();

  final FirebaseAuth auth = FirebaseAuth.instance;

  // Sur le Web, la session anonyme doit rester la même après une
  // actualisation, une fermeture ou l'ouverture d'un nouvel onglet.
  await auth.setPersistence(Persistence.LOCAL);

  // Attend que Firebase ait terminé de restaurer l'utilisateur enregistré
  // avant que le repository décide de créer une nouvelle session anonyme.
  await auth.authStateChanges().first;

  runApp(const CustomerOrderApp());
}
