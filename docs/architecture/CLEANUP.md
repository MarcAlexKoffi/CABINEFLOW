# Nettoyage du projet — 15 novembre 2026

Objectif : retirer les fichiers réellement inutilisés après la réorganisation,
en conservant les fonctionnalités, les tests, les documents de reprise et les
sauvegardes de données nécessaires.

## Éléments retirés

Volume recensé : **59 464 fichiers, environ 7,9 Go**, principalement des sorties
générées et environnements de recette. Les contrôles Flutter régénèrent ensuite
les seuls caches de test nécessaires.

- Sorties de compilation `build/`, anciens livrables régénérables `dist/` et cache
  local Firebase Hosting `.firebase/`.
- Application Android de recette générée dans `scratch/shared_queue_android_qa`
  et anciennes instances PostgreSQL temporaires des tests, après vérification
  de l’absence de processus actif.
- Ancien paquet de correctifs `izytel_correctif_wc5_v2`, ZIP de correction,
  patch Phase 9C, copie `original_dashboard_widgets.dart`, deux sauvegardes de
  règles `.bak`, anciens diagnostics bruts à la racine et journaux périmés.
- Trois sauvegardes anciennes du code dans `.izytel_backups`, récupérables dans
  l’historique Git ; les sauvegardes de données et définitions serveur sont conservées.
- Script obsolète sans action `tools/phase3_patch_firestore_manual_handoff.ps1`.
  Son test de contrat accepte déjà son absence.
- Illustration `assets/images/splash_illustration.png`, remplacée par
  `New_splash_illustration.png` et sans référence depuis l’application.

Les neuf fichiers Dart suivants ne sont atteignables depuis aucun point d’entrée,
import de test ou dépendance de contrat lisant directement le code source :

| Fichier sous `lib/app/` | Motif |
|---|---|
| `data/repositories/firestore_customer_profile_repository.dart` | Ancienne implémentation de profil sans consommateur |
| `data/repositories/firestore_refund_repository.dart` | Ancien adaptateur de remboursement sans consommateur |
| `data/repositories/firestore_support_request_repository.dart` | Ancien adaptateur Support sans consommateur |
| `domain/entities/customer/customer_beneficiary_target.dart` | Ancien choix de bénéficiaire retiré du parcours |
| `modules/customer/views/customer_step_placeholder_page.dart` | Écran provisoire remplacé par le parcours complet |
| `modules/staff_orders/views/customer_confirmation_page.dart` | Ancienne confirmation Staff sans consommateur |
| `services/finance/phase5_recharge_history_synchronizer.dart` | Ancien synchroniseur sans appelant |
| `services/migrations/legacy_support_refund_backfill_service.dart` | Ancien backfill sans appelant |
| `shared/widgets/app_logo.dart` | Ancien composant logo remplacé par les composants utilisés |

La [table de correspondance](path-map.json) conserve leurs anciens chemins avec
`status: removed`, la date et le motif. Le contrôle d’architecture distingue ces
suppressions volontaires des destinations manquantes par erreur.

## Éléments conservés

- Code utilisé par les applications, les tests et les contrats de non-régression.
- Dépendances, lockfiles, configurations, clés de signature et réglages IDE.
- Migrations, règles et fonctions serveur ; sauvegardes de données et définitions
  servant à une restauration éventuelle.
- Documents de modifications, issues GitHub, recettes et preuves de validation
  récentes ; les anciens README restent des documents historiques.
- Dépendances SQL et polices locales des tests dans `scratch/ussd_reprise_tools`,
  `scratch/shared-queue-tools`, ainsi que les fixtures visuelles utilisées.

Le modèle maintenu `test/shared_queue/device_scenarios.dart.template` utilise
désormais les imports `app/...` afin de pouvoir régénérer l’application de recette.
`.gitignore` ignore les sauvegardes `.bak` et ses doublons ont été retirés.
`analysis_options.yaml` conserve les règles actives sans les commentaires de
modèle ni les exclusions des archives supprimées.

## Validation

Contrôle d’architecture réussi : **652 sources et modèles Dart contrôlés**,
521 déplacements documentés, 9 suppressions volontaires. Analyse Flutter réussie,
sans diagnostic. La suite complète retrouve **1 121 tests réussis, 2 ignorés et
les mêmes 13 échecs préexistants**. La comparaison des noms de scénarios ne relève
aucun nouvel échec ni échec disparu par rapport à [VALIDATION.md](VALIDATION.md).

Les journaux de cette vérification sont `scratch/cleanup_analyze.log` et
`scratch/cleanup_tests.log`. Les compilations de référence sont consignées dans
le bilan de réorganisation ; elles n’ont pas été relancées pour ce retrait de
code inutilisé et d’artefacts générés.

Le [relevé des suppressions](cleanup-results.json) indique les chemins retirés,
le nombre de fichiers et le volume libéré. Les sorties de compilation peuvent
être régénérées avec les commandes du guide. Après commit, les sources versionnées
supprimées restent récupérables depuis l’historique Git.
