import 'package:cabine_flow/shared/widgets/feature_placeholder_page.dart';
import 'package:flutter/material.dart';

class PaymentsPage extends StatelessWidget {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderPage(
      title: 'Paiements',
      description: 'Vérifie et associe les paiements reçus.',
      message:
          'Les paiements détectés et leurs rapprochements seront ajoutés progressivement.',
      icon: Icons.payments_rounded,
    );
  }
}
