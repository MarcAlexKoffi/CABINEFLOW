import 'package:cabine_flow/core/theme/customer_app_theme.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_order_flow_page.dart';
import 'package:flutter/material.dart';

class CustomerOrderApp extends StatelessWidget {
  const CustomerOrderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CabineFlow — Commander',
      debugShowCheckedModeBanner: false,
      theme: CustomerAppTheme.light,
      home: const CustomerOrderFlowPage(),
    );
  }
}
