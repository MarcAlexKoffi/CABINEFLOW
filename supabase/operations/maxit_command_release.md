# Max it et filtres Agent — version 1.0.9 livrée

Le champ de syntaxe existant accepte `MAXIT` et `APP:MAXIT`, enregistrés sous `APP:MAXIT`. Cette commande exige une offre ou une famille Orange associée et l’usage « Traitement d’une commande ». Création, édition, activation, suppression et historique utilisent les API existantes. Une réactivation vérifie l’ouverture de l’application plutôt qu’une SIM.

Le filtre automatique de « Mes commandes » choisit En cours, puis À accepter, puis Terminées. Un filtre choisi manuellement est conservé pendant les actualisations. Accepter/démarrer une commande remet la priorité sur En cours ; terminer/refuser choisit le prochain état disponible.

## Livraison du 19 novembre 2026

- Migration `20261119163850_ussd_maxit_command.sql` appliquée au projet Supabase IzyTel après l’autorisation explicite de l’utilisateur. Le nom du fichier local correspond à l’historique distant.
- Comparaison avant/après : 48 commandes, 12 règles, 26 versions et 8 journaux inchangés, avec empreintes identiques. Seules les quatre fonctions prévues ont changé ; droits, RLS et contrôles de résolution, de préparation et de session conservés.
- Sauvegarde ciblée du schéma : `.izytel_backups/maxit_live_schema_before.json`. Ce fichier contient les définitions et droits concernés, pas une sauvegarde complète des données.
- APK release signé 1.0.9, build 10 : `dist/android/1.0.9-build10/izytel-1.0.9-build10.apk`. Installation et version vérifiées sur Samsung SM-A566B. L’ancienne version debug a été désinstallée à cause de sa signature différente. L’écran d’accueil Agent s’affiche.
- Back-office publié après autorisation explicite : https://izytel-backoffice-4bca7.web.app. Le marqueur distant indique 1.0.9/build 10, et le fichier JavaScript téléchargé correspond exactement au paquet local : SHA-256 `00b9763a7902c6e1586c56bf721bb4b0bb1ffe3bd783eab18f65930e6662db64`.
- Le connecteur Firebase a conservé l’ancien paquet malgré son statut de succès ; la publication effective a été réalisée avec la CLI, cible `hosting:backoffice`, puis contrôlée par HTTP. Version Hosting : `5be7e8c25707d402`.
- Aucune règle, association ou commande Max it n’a été créée automatiquement. Aucune recharge ni transaction financière n’a été exécutée.

## Vérifications

- 183 tests Flutter ciblés réussis lors de l’implémentation ; les 36 tests du Back-office ont ensuite tous réussi après les ajustements finaux du dialogue.
- `flutter analyze --no-pub` : aucune erreur ni avertissement.
- `node test/ussd_sql/run.mjs` : 145 tests réussis en PostgreSQL/PGlite isolé, réexécutés après l’alignement du nom de migration.
- `node test/shared_queue/integration.mjs --exclusive-execution --maxit` : 16 contrôles réussis dans PostgreSQL local, dont concurrence, délai de cinq secondes, deuxième appareil, réexécution incertaine et intervention Manager.
- Contrôles distants en lecture seule : quatre alias valides, quatre commandes arbitraires rejetées, syntaxe USSD classique conservée, contrainte d’association validée et audit privé toujours inaccessible directement aux rôles anon/authenticated.
- Les 42 définitions de fonctions sauvegardées ont été comparées : seules les quatre modifications prévues ; aucun changement de droits. Les avis de sécurité concernant les tables USSD signalent leur RLS sans accès direct, déjà présente avant cette migration ; l’accès métier reste fourni par les RPC existantes.
- Compilations release Android et Web réussies. Journaux : `scratch/maxit_release_android_build.log`, `scratch/maxit_release_backoffice_build.log`, `scratch/maxit_release_backoffice_tests.log`, `scratch/maxit_release_sql_tests.log`, `scratch/maxit_release_hosting_deploy.log`.
- La vérification visuelle de l’accueil Agent sur appareil a réussi. Le téléphone a été débranché avant le contrôle supplémentaire du filtre sur l’écran ; les scénarios de sélection automatique et manuelle sont couverts par les tests Flutter.

Les tests natifs simulent le canal Android. Max it est installé sur le téléphone, mais son ouverture réelle par le bouton IzyTel reste à essayer après configuration d’une offre. Le paquet vérifié est [`com.orange.myorange.oci`](https://play.google.com/store/apps/details?id=com.orange.myorange.oci). Seule son activité de lancement est ouverte, sans bénéficiaire, montant ni donnée sensible. Si Max it est absent/désactivé : message et fiche Google Play. Un échec avant la préparation ne consomme pas de tentative ; après préparation, les protections contre un résultat incertain restent applicables.

## Essai manuel

1. Actualiser le Back-office avec Ctrl+F5. Dans le module des syntaxes existant, créer une règle Orange associée à l’offre ou à la famille voulue, saisir `APP:MAXIT`, puis l’activer. Vérifier son édition, sa réactivation et sa suppression dans ce même module.
2. Agent Android : utiliser une commande correspondant à cette association, accepter/démarrer et attendre l’autorisation de cinq secondes, puis choisir « Ouvrir Max it » et confirmer. Revenir dans IzyTel : la commande doit rester en traitement et son résultat se déclare avec les actions habituelles.
3. Vérifier séparément Max it absent et l’accès au Play Store. Le lancement ne valide ni ne réalise de transaction.
4. Vérifier les filtres avec commandes en cours, seulement à accepter, seulement terminées, puis un choix manuel suivi d’une actualisation.

## Retour arrière

`supabase/operations/maxit_command_rollback.sql` restaure les quatre définitions et les contraintes antérieures, à partir de la sauvegarde réelle. Il refuse de s’exécuter si des règles, versions ou journaux Max it existent : aucune donnée n’est supprimée pour forcer le retour. Ce script de secours n’a pas été exécuté sur le serveur. L’ancien paquet Back-office reste dans `build/exclusive/backoffice`.

## Fichiers de la fonctionnalité

```text
android/app/src/main/AndroidManifest.xml
android/app/src/main/kotlin/com/izytel/app/MainActivity.kt
lib/app/data/platform/ussd_dialer.dart
lib/app/domain/policies/ussd/ussd_engine.dart
lib/app/domain/repositories/ussd_repository.dart
lib/app/modules/agent_orders/controllers/agent_orders_view_model.dart
lib/app/modules/ussd/views/backoffice_ussd_page.dart
lib/app/modules/ussd/views/ussd_activity_page.dart
lib/app/modules/ussd/widgets/ussd_quick_processing_card.dart
lib/app/modules/ussd/widgets/ussd_rule_dialogs.dart
supabase/migrations/20261119163850_ussd_maxit_command.sql
supabase/operations/maxit_command_release.md
supabase/operations/maxit_command_rollback.sql
test/app/data/platform/ussd_dialer_test.dart
test/app/domain/ussd/ussd_engine_test.dart
test/app/modules/agent_orders/controllers/agent_orders_view_model_test.dart
test/app/modules/agent_orders/views/agent_orders_page_test.dart
test/app/modules/ussd/ussd_backoffice_widget_test.dart
test/app/modules/ussd/ussd_mobile_widget_test.dart
test/shared_queue/exclusive_execution_scenarios.mjs
test/support/ussd_test_doubles.dart
test/ussd_sql/maxit_cases.mjs
test/ussd_sql/run.mjs
pubspec.yaml
firebase.json
```
