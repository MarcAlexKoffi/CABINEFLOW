import 'package:cabine_flow/shared/widgets/feature_placeholder_page.dart';
import 'package:flutter/material.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderPage(
      title: 'Plus',
      description: 'Accède aux autres fonctions de CabineFlow.',
      message:
          'Le profil, les employés, les fournisseurs, les paramètres et la déconnexion seront placés ici.',
      icon: Icons.apps_rounded,
    );
  }
}
