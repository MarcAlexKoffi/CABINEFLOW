# IzyTel V3.6 - Agent UI fixes

Cette passe corrige uniquement l'interface Agent a partir de la baseline V3.5/V3.4 verte.

## 1. Commandes Agent - En cours
- Cartes agrandies et restructurees.
- Logo + reseau + statut visibles en tete.
- Offre remise au premier niveau visuel.
- Numero beneficiaire affiche dans une zone transactionnelle dediee.
- Format telephone CI lisible : `+225 01 52 36 82 90`.
- Montant conserve a droite du numero.
- Le meme formatage est applique aux cartes de priorite.

## 2. Historique Agent
- Titre, sous-titre et onglets remis a l'echelle du design system IzyTel.
- Onglets portes a 48 dp et texte a 13 px.
- Cartes plus grandes et plus structurees.
- Logo, reseau, statut, offre, numero et montant lisibles sans effet de miniaturisation.
- Numero CI groupe par paires.
- Iconographie Material Symbols Rounded.

## 3. Detail commande Agent
- Numero beneficiaire groupe par paires et agrandi.
- Montant renforce visuellement.
- Les numeros affiches dans les feuilles Client / Details de l'offre sont aussi formates.
- Timeline : les libelles comme `En traitement` utilisent un scale-down controle au lieu d'etre tronques.
- Barre d'actions : repartition 40/60 et labels adaptatifs pour afficher en entier :
  - `Mettre en attente`
  - `Marquer comme reussie`

## Fichiers modifies
- `lib/features/orders/presentation/pages/agent_orders_page.dart`
- `lib/features/orders/presentation/pages/agent_history_page.dart`
- `lib/features/orders/presentation/pages/agent_order_detail_view.dart`

## Verification a lancer localement
```powershell
dart format lib
flutter analyze
flutter test
flutter run
```

Aucune logique Firestore, auto-affectation, paiement, remboursement ou traitement metier n'a ete modifiee.
