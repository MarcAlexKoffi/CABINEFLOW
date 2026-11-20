# Correctifs prioritaires — livraison du 19 novembre 2026

Migration `20261119090007_exclusive_order_execution.sql` appliquée sur le projet IzyTel `zrxeztxaxnzxevjuhzcc` et enregistrée dans son historique. Les 47 commandes ont conservé la même empreinte avant/après migration. Les 12 fonctions et la politique de lecture précédentes sont sauvegardées dans `private.izytel_execution_schema_backup` ; copie locale dans `.izytel_backups/exclusive_execution_live_schema_before.json`. Cette sauvegarde ciblée du schéma ne constitue pas un dump complet de la base.

Les jobs existants `izytel-acceptance-delay-monitor` et `izytel-notification-retry-wakeup` restent actifs chaque minute. Leurs exécutions après migration réussissent. Les appels anonymes aux nouvelles RPC sont refusés et la lecture anonyme ne retourne aucune commande.

Back-office : https://izytel-backoffice-4bca7.web.app — compilation `build/exclusive/backoffice`, cible `hosting:backoffice`. Publication finale par CLI explicite après détection du dossier obsolète utilisé par le connecteur. Vérification HTTPS réussie : réponse 200, empreinte de `main.dart.js` identique au build local (`ce7a8614793b6588fa0c3296abd29a96863fc1ef072bd79e2dbb85e744fd8c80`) et marqueur `exclusive-execution-20261119` dans `version.json`.

Android : APK signé `dist/android/1.0.7-build8/izytel-1.0.7-build8.apk`, version 1.0.7 (8), `com.izytel.app`. Mise à jour USB effectuée sur le Samsung SM-A566B depuis 1.0.6 (7), avec `adb install -r`, sans effacement des données. Empreinte APK : `02d61d6e95826a099afa546d974e16dad9de38ea750005c78c69f07aaa8b2af3`. Certificat release identique à la version précédente.

Contrôles locaux déjà réussis : analyse Flutter, 70 tests Flutter ciblés, 15 scénarios PostgreSQL, dispatch FCM simulé et compilations Web/Android. Aucun USSD ni paiement réel n’a été déclenché par ces contrôles.

## Essais réels à effectuer

Installer cette version sur chaque téléphone Agent utilisé. Les anciens clients ne peuvent plus démarrer de traitement Agent. Les commandes historiques déjà commencées/en pause restent conservées ; avant une remise en file, le Manager doit vérifier l’absence effective d’exécution chez l’opérateur puis confirmer cette vérification dans l’application.

1. Deux Agents autorisés dans la même zone acceptent simultanément la même commande de test : un seul propriétaire, commande retirée de la file après réponse serveur, refus explicite du concurrent.
2. Après acceptation, démarrer : préparation pendant cinq secondes et autorisation serveur. Refaire avec double clic, interruption réseau et même compte sur deux téléphones ; un seul appareil accède au traitement.
3. Depuis le Manager de zone ou l’Admin, remettre en file avec motif ; vérifier historique, zone et nouvelle acceptation. Si un USSD a pu partir, vérifier l’absence réelle d’exécution avant toute confirmation ou nouvelle tentative.
4. Laisser une commande acceptée sans aboutissement : alerte du Manager après cinq minutes, au passage suivant du cron, sans doublon. Autoriser les notifications sur le téléphone du Manager.
5. Chrome : utiliser des identifiants de test enregistrés, sélectionner la suggestion dès l’ouverture puis après actualisation ; connexion possible sans actualisation supplémentaire.

## Retour arrière

En maintenance uniquement : traiter ou vérifier puis remettre en file chaque exécution `authorized`/`uncertain`. Le script `exclusive_execution_rollback.sql` refuse sinon le retour arrière. Sauvegarder de nouveau puis appliquer ce script via une migration de retour arrière dédiée et livrer les anciens clients. Ne pas supprimer l’historique de migration appliquée. Les fonctions/droits antérieurs sont restaurés ; commandes, finance et audits restent conservés. Ne pas restaurer un ancien dump sur une base ayant reçu de nouvelles commandes. Une reprise exige une nouvelle migration, les tables d’audit étant conservées.

## Fichiers créés ou modifiés

36 fichiers, chemins relatifs à `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow` :

```text
firebase.json
lib/app/data/repositories/hybrid_orders_repository.dart
lib/app/data/repositories/supabase_phase4_assignment_repository.dart
lib/app/data/repositories/supabase_phase5_finance_repository.dart
lib/app/data/repositories/supabase_ussd_repository.dart
lib/app/data/sources/order_execution_session.dart
lib/app/domain/entities/orders/queue_order.dart
lib/app/domain/repositories/order_requeue_repository.dart
lib/app/modules/agent_orders/controllers/agent_orders_view_model.dart
lib/app/modules/agent_orders/controllers/shared_order_queue_view_model.dart
lib/app/modules/agent_orders/views/agent_order_detail_view.dart
lib/app/modules/agent_orders/views/agent_orders_page.dart
lib/app/modules/agent_orders/views/shared_agent_orders_page.dart
lib/app/modules/backoffice/views/backoffice_login_page.dart
lib/app/modules/backoffice/views/operations/backoffice_assignments_page.dart
lib/app/modules/backoffice/views/operations/backoffice_failed_orders_page.dart
lib/app/modules/manager_orders/views/agent_assignment_page.dart
lib/app/modules/manager_orders/views/failed_orders_page.dart
lib/app/modules/manager_orders/views/order_detail_page.dart
lib/app/modules/manager_orders/views/orders_page.dart
lib/app/modules/manager_orders/widgets/return_order_to_queue.dart
lib/app/modules/ussd/widgets/ussd_quick_processing_card.dart
pubspec.lock
pubspec.yaml
supabase/migrations/20261119090007_exclusive_order_execution.sql
supabase/operations/exclusive_execution_release.md
supabase/operations/exclusive_execution_rollback.sql
test/app/data/ussd/ussd_repository_http_test.dart
test/app/modules/agent_orders/controllers/exclusive_execution_test.dart
test/app/modules/agent_orders/shared_order_queue_test.dart
test/app/modules/agent_orders/views/agent_orders_page_test.dart
test/app/modules/backoffice/backoffice_login_autofill_test.dart
test/app/modules/manager_orders/return_order_to_queue_test.dart
test/app/modules/ussd/ussd_mobile_widget_test.dart
test/shared_queue/exclusive_execution_scenarios.mjs
test/shared_queue/integration.mjs
```
