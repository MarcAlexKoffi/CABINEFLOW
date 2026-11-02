# IzyTel — bilan Administration, Finance et Notifications — 1 novembre 2026

Branche conservée : `fix/stabilisation-mobile-web-20261030`. Changements locaux non fusionnés et non publiés. Après ce bilan initial, une migration de données a normalisé deux rôles Firestore `supervisor` en `manager`, puis les migrations, fonctions Edge et règles nécessaires ont été déployées sur autorisation explicite ; voir [rapport de migration](RAPPORT_MIGRATION_DONNEES_20261101.md) et [rapport de déploiement](RAPPORT_DEPLOIEMENT_MIGRATIONS_20261101.md).

## Livrables

- [Rapport 1 — Utilisateurs](RAPPORT_1_UTILISATEURS_20261101.md)
- [Rapport 2 — Finance](RAPPORT_2_FINANCE_20261101.md)
- [Rapport 3 — Notifications](RAPPORT_3_NOTIFICATIONS_20261101.md)
- [Photographie distante de l’identité, en lecture seule](IDENTITE_PHOTOGRAPHIE_DISTANTE_20261101.md)

Les audits précèdent les correctifs et les contre-revues SENTINEL sont consignées dans les rapports. Le code réel a été conservé lorsqu’aucune preuve suffisante ne justifiait un retrait.

## Résultats et portée

**Comptes.** Création des quatre populations, modification, changement de rôle/statut/zones/réseaux, réinitialisation par lien, historique sensible et synchronisation serveur sont préparés. Les actions utilisent le JWT Firebase et une fonction privilégiée ; aucune clé Admin dans Flutter. Les échecs partiels restent visibles, audités et bloquants. La session mobile/Back-office demande une reconnexion sur changement confirmé de rôle/statut ; cache et écritures locales non confirmées ne déclenchent pas cette invalidation. La suppression définitive reste refusée tant que l’inventaire exhaustif des références n’est pas prouvé. Les comptes historiques non administrés par le nouveau parcours ne sont pas silencieusement migrés : certaines écritures Firestore legacy restent un périmètre résiduel.

**Finance.** Les nouvelles opérations de l’écran Finance mobile utilisent les RPC canoniques partagées avec le Back-office ; les versements et tableaux commissions V2 utilisent Supabase. Les agrégats Wave et capacités engagées ne dépendent plus des fenêtres de détail ; les versements Cabinistes Wave sont inclus. Les dépenses utilisent un reçu idempotent ; une reprise BO/mobile conserve sa même intention. Les RPC globales Finance sont réservées Admin. Le rapprochement mobile historique et les anciennes désynchronisations restent à traiter séparément ; aucun historique ni table n’a été supprimé ou réparé automatiquement.

**Notifications.** L’outbox existante est conservée, avec routage territorial, reprise bornée, bail et suivi par appareil. Les événements client paiement/remboursement/prise en charge support produisent une trace persistante dans la messagerie existante. Les clics Cabinistes relisent les ressources autorisées. Web Push reste désactivé ; Realtime et messagerie ne sont pas présentés comme des notifications Web en arrière-plan. La matrice du rapport 3 identifie aussi les événements non couverts.

## Vérifications exécutées

| Contrôle | Résultat et preuve |
|---|---|
| `flutter analyze --no-pub` | PASS, aucun diagnostic — `scratch/admin_finance_notifications_delivery_analyze.log` |
| `flutter test --no-pub --reporter expanded` | **1077 tests PASS**, dont comptes, Auth, Finance, notifications, navigation et régressions — `scratch/admin_finance_notifications_delivery_suite.log` |
| Saga comptes Node | **25 tests PASS** — `node --test supabase/functions/izytel-user-admin/core.test.mjs` |
| Autorisations et mutations comptes PostgreSQL | **21 contrôles PASS** — `node supabase/tests/user_admin_behavior_test.mjs` |
| Agrégats/idempotence Finance PostgreSQL | **7 cas PASS** — `node test/finance_sql/run.mjs` |
| Pagination Finance PostgreSQL | **10 cas PASS** — `node supabase/tests/finance_mobile_canonical_test.mjs` |
| Événements, territoire, déduplication, bail, messages et owner RLS | PASS — `node supabase/tests/notifications_pipeline_test.mjs` |
| Dispatch multi-appareils, token invalide, retry sélectif | PASS — `node supabase/tests/notifications_dispatch_test.mjs` |
| Syntaxe des deux fonctions Edge | PASS — `node --experimental-strip-types --check` ; ne remplace pas le runtime Deno |
| Reprise du formulaire mobile après réponse perdue | PASS, même brouillon conservé ; transport Manager même clé — test widget et transport inclus dans la suite |
| Build Android | PASS, **APK debug** — `scratch/admin_finance_notifications_delivery_android_build.log` |
| Build Back-office Web | PASS — `scratch/admin_finance_notifications_delivery_backoffice_build.log` |
| Build Client Web | PASS — `scratch/admin_finance_notifications_final_customer_build.log` |
| `git diff --check` | PASS |
| Recherche de marqueurs de secrets serveur dans lib/web et bundles Web | Aucun marqueur trouvé ; aucune clé privée/service role ajoutée au client |

Commandes de build exécutées :

```text
flutter build apk --debug --no-pub
flutter build web --no-pub --no-wasm-dry-run -t lib/main_backoffice_web.dart --output build/administration/backoffice_web
flutter build web --no-pub --no-wasm-dry-run -t lib/main_customer_web.dart --output build/administration/customer_web
```

Artefacts locaux : `build/app/outputs/flutter-apk/app-debug.apk`, `build/administration/backoffice_web`, `build/administration/customer_web`. Les avertissements Android Kotlin/versions de métadonnées SDK n’ont pas empêché le build debug. Aucun build release signé ni installation sur appareil n’est revendiqué.

Les tests PostgreSQL utilisent PGlite et des schémas/identités synthétiques. Les tests de saga et de dispatch injectent des services simulés ; ils ne prouvent pas la réception FCM ou la création Firebase réelle. Les logs sous scratch sont locaux et ignorés par Git.

## Migrations créées et appliquées

1. `20261101011937_notifications_territory_delivery_recovery.sql`
2. `20261101012308_finance_mobile_canonical_reads.sql`
3. `20261101062456_finance_exact_wave_totals_and_expense_idempotency.sql`
4. `20261101062508_admin_accounts_lifecycle.sql`
5. `20261101142339_notifications_retry_scheduler.sql`

Elles sont appliquées à la base distante. Les quatre migrations initiales portent les versions distantes `20261101142201`, `20261101142206`, `20261101142212` et `20261101142217`. La cinquième active `pg_cron` et le réveil de l'outbox toutes les minutes. La migration de données distincte est décrite dans son rapport dédié.

## Serveur, dépendances et configuration

- Nouvelle fonction : `supabase/functions/izytel-user-admin`.
- Fonction existante modifiée : `supabase/functions/izytel-notification-dispatch`.
- Nouvelle configuration serveur : `IZYTEL_ADMIN_ALLOWED_ORIGINS`, liste explicite des origines Web autorisées.
- Secrets serveur existants réutilisés : `FIREBASE_SERVICE_ACCOUNT_JSON`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`. Aucune valeur secrète créée, copiée dans Flutter ou livrée dans les rapports.
- `http: 1.6.0`, déjà présent en développement, devient dépendance applicative ; aucune mise à niveau de version. Résolution `flutter pub get --offline` réussie.
- Le JWT Firebase doit être vérifié dans la nouvelle fonction. Sa future configuration gateway est décrite dans son README ; ne pas désactiver la vérification applicative. Références : [Supabase — Authorization headers](https://supabase.com/docs/guides/functions/auth-headers), [Firebase — Manage user sessions](https://firebase.google.com/docs/auth/admin/manage-sessions).

## Actions distantes et contrôles non exécutés

Actions distantes effectuées : lectures de comptes/profils et de métadonnées, fonctions, contraintes, règles d’accès et conseillers Supabase ; normalisation de deux rôles Firestore ; application des cinq migrations listées ; déploiement des deux fonctions Edge ; activation du job `pg_cron` ; compilation et publication des règles Firestore. Les identités sont abrégées dans les rapports versionnés. Aucune modification Firebase Auth, paiement, remboursement, envoi de message externe, publication applicative ou merge n'a été effectué.

La validation distante des règles Firestore a d’abord rencontré plusieurs **HTTP 503**. Une tentative ultérieure a compilé les règles puis la relance a créé et publié le ruleset `04085227-df64-49c2-8757-d01e53ccd9c8`. Les contrats locaux et la compilation distante sont donc validés ; les scénarios réels par rôle restent à exécuter.

Non exécutés : opération Administration authentifiée avec Firebase Admin réel, création Firebase Auth réelle, révocation sur token déjà émis et appareil, réception Android foreground/background/killed, rotation réelle et multi-appareils, navigateur fermé et Web Push, paiement réel et build Android release signé. Les RPC/RLS ont été contrôlées sur le schéma distant et `pg_cron` est désormais actif ; les scénarios métier réels restent à exécuter avec des comptes et opérations de test.

## Recette restante

1. Migrations, fonctions Edge, planificateur et règles Firestore sont déployés ; effectuer maintenant les scénarios réels avec des comptes de test et surveiller les journaux serveur.
2. Le nouvel endpoint dépense est actif et l'ancien endpoint direct est fermé aux rôles clients : utiliser la version locale actuelle de l'application pour la recette et ne pas remettre une ancienne version en service.
3. Vérifier les quatre populations, changements de rôle/statut, dernier Admin, fiche Agent spécialisée, opérations incomplètes et procédure de réparation habilitée. Ne pas débloquer une saga échouée sans diagnostic.
4. Tester doubles clics, perte de réponse après commit, remboursements et commissions avec données de recette, écarts Wave/clôtures et gros volumes. Après fermeture du parcours ou redémarrage complet, vérifier l’historique avant de créer une nouvelle intention ; aucune file locale durable de commandes n’est ajoutée.
5. Vérifier les appareils Android et les clics avec session expirée et ressource devenue interdite ; configurer le réveil de l’outbox et observer les statuts. La recette Web porte sur la messagerie persistante ; Web Push nécessite une décision et une configuration distinctes.
6. Traiter le rapprochement mobile historique, les comptes legacy non migrés et les événements restant non couverts avant de revendiquer une stabilisation intégrale. Aucun « tout fonctionne » global n’est déduit des tests locaux.

## Fichiers modifiés ou créés

- `docs/FINANCE_AUDIT_INITIAL_20261101.md`
- `docs/IDENTITE_PHOTOGRAPHIE_DISTANTE_20261101.md`
- `docs/NOTIFICATIONS_AUDIT_INITIAL_20261101.md`
- `docs/RAPPORT_1_UTILISATEURS_20261101.md`
- `docs/RAPPORT_2_FINANCE_20261101.md`
- `docs/RAPPORT_3_NOTIFICATIONS_20261101.md`
- `docs/SENTINEL_REVUE_FINANCE_ADAPTATEURS_20261101.md`
- `docs/UTILISATEURS_AUDIT_INITIAL_20261101.md`
- `firestore.rules`
- `lib/app/app.dart`
- `lib/backoffice/backoffice_app.dart`
- `lib/backoffice/data/repositories/backoffice_user_administration_repository.dart`
- `lib/backoffice/data/repositories/firestore_backoffice_user_repository.dart`
- `lib/backoffice/data/repositories/supabase_backoffice_finance_repository.dart`
- `lib/backoffice/domain/models/backoffice_finance_snapshot.dart`
- `lib/backoffice/domain/models/backoffice_user_account.dart`
- `lib/backoffice/domain/repositories/backoffice_finance_repository.dart`
- `lib/backoffice/presentation/pages/backoffice_users_page.dart`
- `lib/backoffice/presentation/pages/finances/backoffice_finance_page.dart`
- `lib/backoffice/presentation/widgets/backoffice_user_admin_dialog.dart`
- `lib/features/agents/data/repositories/firestore_agent_repository.dart`
- `lib/features/auth/presentation/widgets/session_access_boundary.dart`
- `lib/features/commissions/data/repositories/hybrid_commission_repository.dart`
- `lib/features/commissions/data/repositories/supabase_commission_v2_repository.dart`
- `lib/features/commissions/presentation/pages/commission_v2_dashboard_page.dart`
- `lib/features/customer_order/presentation/pages/customer_order_flow_page.dart`
- `lib/features/finances/data/repositories/manager_read_only_finance_operations_repository.dart`
- `lib/features/finances/data/repositories/supabase_finance_operations_repository.dart`
- `lib/features/finances/domain/services/finance_calculators.dart`
- `lib/features/finances/domain/services/finance_operation_key.dart`
- `lib/features/finances/presentation/pages/daily_financial_closing_page.dart`
- `lib/features/finances/presentation/pages/finance_expenses_page.dart`
- `lib/features/finances/presentation/pages/finances_page.dart`
- `lib/features/finances/presentation/pages/supplier_finance_page.dart`
- `lib/features/finances/presentation/pages/wave_cash_page.dart`
- `lib/features/finances/presentation/widgets/financial_intent_retry.dart`
- `lib/features/partners/presentation/pages/partner_shell_page.dart`
- `pubspec.lock`
- `pubspec.yaml`
- `supabase/functions/izytel-notification-dispatch/index.ts`
- `supabase/functions/izytel-user-admin/README.md`
- `supabase/functions/izytel-user-admin/core.mjs`
- `supabase/functions/izytel-user-admin/core.test.mjs`
- `supabase/functions/izytel-user-admin/deno.json`
- `supabase/functions/izytel-user-admin/index.ts`
- `supabase/migrations/20261101011937_notifications_territory_delivery_recovery.sql`
- `supabase/migrations/20261101012308_finance_mobile_canonical_reads.sql`
- `supabase/migrations/20261101062456_finance_exact_wave_totals_and_expense_idempotency.sql`
- `supabase/migrations/20261101062508_admin_accounts_lifecycle.sql`
- `supabase/tests/finance_mobile_canonical_test.mjs`
- `supabase/tests/notifications_dispatch_test.mjs`
- `supabase/tests/notifications_pipeline_test.mjs`
- `supabase/tests/user_admin_behavior_test.mjs`
- `supabase/tests/user_admin_preflight.sql`
- `test/backoffice/user_administration_dialog_test.dart`
- `test/backoffice/user_administration_repository_test.dart`
- `test/features/auth/presentation/session_access_boundary_test.dart`
- `test/features/commissions/data/supabase_commission_v2_repository_test.dart`
- `test/features/finances/data/finance_operation_key_transport_test.dart`
- `test/features/finances/data/supabase_finance_operations_repository_test.dart`
- `test/features/finances/domain/exact_wave_totals_test.dart`
- `test/features/finances/financial_intent_retry_widget_test.dart`
- `test/finance_sql/run.mjs`
- `test/regressions/backoffice_bo1_foundation_contract_test.dart`
- `test/regressions/supabase_phase3_suppliers_contract_test.dart`
- `docs/BILAN_ADMIN_FINANCE_NOTIFICATIONS_20261101.md` (ce bilan)

