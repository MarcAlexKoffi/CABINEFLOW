import 'package:cabine_flow/app/theme/customer_app_theme.dart';
import 'package:cabine_flow/app/modules/customer/views/customer_order_flow_page.dart';
import 'package:flutter/material.dart';

class CustomerOrderApp extends StatelessWidget {
  const CustomerOrderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IzyTel Web — Recharge en ligne',
      debugShowCheckedModeBanner: false,
      theme: CustomerAppTheme.light,
      themeAnimationDuration: const Duration(milliseconds: 220),
      home: const CustomerOrderFlowPage(),
    );
  }
}
