# Fiche Manager sans plan de rémunération — 15 novembre 2026

La récupération du profil réussissait, puis l’aperçu financier renvoyait `P0001 / MANAGER_COMPENSATION_PLAN_NOT_FOUND`. L’attente groupée du dépôt propageait cette erreur à toute la fiche. La lecture du serveur a confirmé l’absence de plan Manager de supervision.

## Comportement livré

Le dépôt traite uniquement ce code et ce message précis comme un état `not_configured` pour l’aperçu de la fiche Manager. Le profil, le périmètre et l’historique continuent à être chargés. Les erreurs d’autorisation et les autres erreurs serveur continuent à être propagées.

La fiche présente « Plan de rémunération non configuré », sans afficher de projection inventée ni proposer une clôture sans plan. L’historique existant reste consultable. Aucun plan, montant, droit à rémunération, compte ou écriture comptable n’a été créé/modifié ; aucune migration SQL n’est associée au correctif.

## Validation

- 5 tests de régression réussis : profil/historique préservés sans plan, aucune RPC d’écriture, aperçu existant conservé, erreurs d’autorisation/autres erreurs non masquées, consultation du profil et de l’historique sans action de clôture.
- Analyse des 3 fichiers Dart concernés : aucun diagnostic.
- Build Web du back-office réussi.
- 4 fichiers publiés comparés par SHA-256 au build local : identiques.

```powershell
flutter test --no-pub test/app/modules/backoffice/manager_detail_missing_plan_test.dart --reporter expanded
flutter analyze --no-pub lib/app/data/repositories/supabase_team_supervision_repository.dart lib/app/modules/team/views/team_member_detail_page.dart test/app/modules/backoffice/manager_detail_missing_plan_test.dart
flutter build web --no-pub -t lib/main_backoffice.dart --output build/catalog_import_backoffice
```

## Publication et recette

Back-office : https://izytel-backoffice-4bca7.web.app ; Hosting `6347fb09e1fd877a`, vérifié le 15 novembre 2026 à 23:55 UTC. Version précédente pour retour arrière : `d0fbc92f5e1ad7cb`.

SHA-256 `main.dart.js` : `5ae1617f5a78deea31b542c073819edaddff9638826eebb132be293ecff7f0cc`. Le marqueur indique `change: manager-detail-missing-plan`, `sourceDirty: true`, base Git `1a0f40bb0d17710e63c70d0d06b0ab93043fa432` avec les correctifs locaux non commités.

Preuves locales : `scratch/manager_missing_plan_regression.log`, `manager_missing_plan_analyze.log`, `manager_missing_plan_build.log`, `manager_missing_plan_hosting_deploy.json`, `manager_missing_plan_hosting_results.json`.

Après `Ctrl + F5`, rouvrir la fiche Manager et consulter ses onglets Profil/Historique. Le contrôle authentifié réel reste à effectuer par l’utilisateur ; les tests HTTP applicatifs emploient des réponses fictives et ne modifient aucune donnée réelle. La configuration métier du plan reste nécessaire pour les futurs calculs et clôtures.
