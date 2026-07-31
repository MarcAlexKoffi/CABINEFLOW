import 'package:cabine_flow/core/firebase/firebase_bootstrap.dart';
import 'package:cabine_flow/customer_order_app.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  await FirebaseBootstrap.initialize();
  runApp(const CustomerOrderApp());
}
