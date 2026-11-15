import 'package:cabine_flow/app/app.dart';
import 'package:cabine_flow/app/data/sources/firebase_bootstrap.dart';
import 'package:cabine_flow/app/services/notifications/firebase_messaging_bootstrap.dart';
import 'package:cabine_flow/app/data/sources/supabase_bootstrap.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  await FirebaseBootstrap.initialize();
  await FirebaseMessagingBootstrap.initialize();
  await SupabaseBootstrap.initialize();
  runApp(const CabineFlowApp());
}
