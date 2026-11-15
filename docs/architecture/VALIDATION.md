# Validation de la réorganisation

Contrôles des **14 et 15 novembre 2026**, heure d’Abidjan.
Environnement : Windows, Flutter **3.44.8**, Dart **3.12.2**, Node **24.14.0**.
Le dépôt était propre au début du chantier, sur le commit `84f4d3a`.

Ce bilan décrit la réorganisation avant nettoyage. Le
[nettoyage du 15 novembre](CLEANUP.md) a ensuite retiré neuf fichiers Dart
inutilisés et les sorties de compilation régénérables. Les résultats de
compilation ci-dessous restent les preuves de cette étape ; les binaires sont à
régénérer avec les commandes indiquées.

## Périmètre vérifié

- 390 fichiers applicatifs et 131 fichiers de tests déplacés ; 521 entrées dans
  `path-map.json`.
- 391 fichiers applicatifs comparés à HEAD avant/après suppression des directives
  Dart : 390 corps strictement identiques, un seul écart documentaire dans
  `firebase_options.dart` (exemple d’import mis à jour).
- Trois anciennes entrées conservées comme relais compatibles.
- Aucun changement dans `pubspec.yaml`, `pubspec.lock`, les règles Firestore et
  Storage, les fonctions serveur ou les migrations SQL.
- Les archives locales avec leurs anciens imports restent exclues de l’analyse ;
  `lib/`, `test/` et l’outillage maintenu restent analysés.

## Résultats

| Contrôle | Avant | Après |
|---|---|---|
| `flutter analyze --no-pub` | Réussi, aucun diagnostic | Réussi, aucun diagnostic |
| `dart tool/check_architecture.dart` | Sans objet | Réussi : 660 fichiers Dart, 521 déplacements |
| `flutter test --no-pub --reporter expanded` | 1 121 réussis, 2 ignorés, 13 échecs | Identique : 1 121 réussis, 2 ignorés, mêmes 13 échecs |
| Contrats Support BO-3A, après le dernier ajustement de chemin | Inclus dans la baseline | 5 tests réussis |
| Compilation Client Web | Non relancée avant déplacement | Réussie : `build/architecture/customer` |
| Compilation Back-office Web | Non relancée avant déplacement | Réussie : `build/architecture/backoffice` |
| Compilation Android debug personnel | Non relancée avant déplacement | Réussie : `build/app/outputs/flutter-apk/app-debug.apk` |

Les deux tests ignorés sont les captures visuelles optionnelles déjà désactivées
dans la suite habituelle. Aucune exclusion ni désactivation de test n’a été
ajoutée pour ce chantier.

La comparaison des noms de scénarios et de leurs chemins normalisés ne relève
**aucun nouvel échec ni échec disparu**. Le détail est conservé dans
[validation-results.json](validation-results.json). Les 13 échecs préexistants
empêchent néanmoins de présenter la suite complète comme réussie.

## Échecs présents avant la réorganisation

Les chemins ci-dessous sont les chemins actuels. Ces échecs ont été observés
avant les déplacements ; ils ne constituent pas des corrections livrées par ce
chantier.

| Fichier | Scénario en échec à la baseline |
|---|---|
| `test/app/modules/agent_orders/views/agent_orders_page_test.dart` | Affiche la file priorisée de la maquette et accepte : attend le libellé « Preuve » |
| `test/regressions/backoffice_bo3_real_recipe_fixes_contract_test.dart` | Libellés du formulaire Zone visibles au-dessus de la carte |
| `test/regressions/backoffice_bo3_team_support_contract_test.dart` | Zones utilise le référentiel territorial Supabase et les Agents existants |
| `test/regressions/cabiniste_mobile_role_contract_test.dart` | UI Cabiniste reliée à la couche RPC validée |
| `test/regressions/cabiniste_processing_parity_contract_test.dart` | Acceptation Cabiniste démarre puis ouvre directement le détail |
| `test/regressions/cabiniste_processing_parity_contract_test.dart` | Détail Cabiniste reprend les blocs essentiels du détail Agent |
| `test/regressions/order_queue_fallback_contract_test.dart` | File Cabiniste bascule vers la première file non vide |
| `test/regressions/phase3_terrain_proof_failed_home_contract_test.dart` | Preuve ajoutable pendant traitement ou attente |
| `test/regressions/supabase_phase4_assignment_contract_test.dart` | Succès Agent finalise directement capacité et commission Supabase |
| `test/regressions/supabase_phase5b_order_proofs_contract_test.dart` | Finalisation Agent reste Supabase-only après le cutover |
| `test/regressions/supabase_phase5_consolidated_contract_test.dart` | Succès Agent finalise Phase 5 sans pont Firebase |
| `test/regressions/wc14_round_robin_and_mobile_refresh_contract_test.dart` | Pull-to-refresh Agent ne redémarre plus les abonnements |
| `test/regressions/wc9_1_compile_scope_hotfix_contract_test.dart` | PartnerShell conserve les imports Flutter nécessaires |

## Preuves locales

Les journaux complets sont conservés dans `scratch/`, répertoire ignoré par Git :

- `architecture_baseline_analyze.log`, `architecture_baseline_tests.log` ;
- `architecture_final_analyze.log`, `architecture_final_tests.log` ;
- `architecture_targeted_tests.log` ;
- `architecture_build_customer.log`, `architecture_build_backoffice.log`,
  `architecture_build_staff.log` ;
- `architecture_body_comparison.json`.

Commandes de compilation :

```powershell
flutter build web --no-pub -t lib/main_customer.dart --output build/architecture/customer
flutter build web --no-pub -t lib/main_backoffice.dart --output build/architecture/backoffice
flutter build apk --debug --no-pub -t lib/main_staff.dart
```

Les trois compilations terminent avec un code de sortie **0**. Les sorties Web
incluent un message informatif sur le dry run Wasm réussi. Android émet des
avertissements sur la migration Kotlin et les versions XML du SDK, sans bloquer
la génération de l’APK debug.

## Limites et recette restante

Les tests automatisés utilisent les doubles et scénarios existants. Aucun paiement,
déploiement, changement de données ou modification de service distant n’a été
réalisé. Les scénarios SQL ne sont pas relancés : les fichiers serveur et SQL
restent inchangés.

La recette sur appareil Android et dans les navigateurs avec comptes réels reste
à réaliser avant une livraison produit : connexion par rôle, Retour Android,
rechargement Web, notifications, commande client, prise exclusive en file partagée,
traitement Agent/Cabiniste, finance, support et carte territoriale. La compilation
et l’absence de nouvel échec automatisé ne remplacent pas cette recette.
