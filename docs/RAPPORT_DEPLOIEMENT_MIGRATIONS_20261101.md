# IzyTel — déploiement des migrations — 1 novembre 2026

Déploiement exécuté sur demande explicite après les audits et validations locales.

## Migrations Supabase appliquées

1. `notifications_territory_delivery_recovery` — version distante `20261101142201`.
2. `finance_mobile_canonical_reads` — version distante `20261101142206`.
3. `finance_exact_wave_totals_and_expense_idempotency` — version distante `20261101142212`.
4. `admin_accounts_lifecycle` — version distante `20261101142217`.
5. `notifications_retry_scheduler` — migration CLI locale `20261101142339_notifications_retry_scheduler.sql`, appliquée au distant.

Le planificateur `pg_cron` est installé et le job actif `izytel-notification-retry-wakeup` exécute chaque minute `private.izytel_notification_retry_wakeup()`.

## Fonctions et règles

- `izytel-notification-dispatch` : version 3 active.
- `izytel-user-admin` : version 2 active ; le JWT Firebase est vérifié dans la fonction avec contrôle de révocation et double autorisation Admin Firestore/SQL.
- CORS vérifié depuis `http://localhost:8080` : préflight HTTP 200 avec origine exacte, aucun wildcard.
- Règles Firestore compilées et publiées dans le ruleset `04085227-df64-49c2-8757-d01e53ccd9c8`.

## Contrôles post-migration

- Six RPC Administration présentes, exécutables par `service_role`, non exécutables par `anon` ou `authenticated`.
- RLS active sur les opérations et l'audit Administration ; index de mutation unique présent.
- Pagination Finance, dépense idempotente, table de livraison et réveil Notifications présents.
- Ancienne RPC de dépense non exécutable par `anon` et `authenticated`.
- Volumes métier contrôlés avant/après : 3 accès staff, 105 paiements, 3 dépenses et 47 commissions, sans perte constatée.

## Limites

Le déploiement ne constitue pas une recette métier réelle. Aucun compte de test n'a été créé, aucune dépense, aucun paiement, aucun remboursement et aucun envoi FCM réel n'a été déclenché pendant cette opération. La suppression définitive des comptes reste volontairement refusée.
