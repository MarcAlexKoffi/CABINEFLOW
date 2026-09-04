import 'package:cabine_flow/app/app.dart';
import 'package:cabine_flow/core/firebase/firebase_bootstrap.dart';
import 'package:cabine_flow/core/notifications/firebase_messaging_bootstrap.dart';
import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  await FirebaseBootstrap.initialize();
  await FirebaseMessagingBootstrap.initialize();
  await SupabaseBootstrap.initialize();
  runApp(const CabineFlowApp());
}
