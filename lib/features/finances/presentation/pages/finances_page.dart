import 'package:cabine_flow/shared/widgets/feature_placeholder_page.dart';
import 'package:flutter/material.dart';

class FinancesPage extends StatelessWidget {
  const FinancesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderPage(
      title: 'Finances',
      description: 'Suis les caisses, les soldes et les résultats.',
      message:
          'La caisse Wave, les réseaux, les fournisseurs et les dépenses seront regroupés ici.',
      icon: Icons.account_balance_wallet_rounded,
    );
  }
}
