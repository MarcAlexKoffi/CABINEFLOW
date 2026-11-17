# Correction de la création des syntaxes USSD — 15 novembre 2026

Le formulaire refusait une syntaxe valide dès qu’un espace, un retour de ligne ou un caractère de formatage invisible accompagnait le copier-coller. Dans l’enregistrement `224623`, le compteur affiche 25 caractères pour une forme canonique qui en compte 24, ce qui concorde avec ce défaut. Le refus avec un espace final a été reproduit par un test avant correction (`invalid_template`).

## Comportement livré

- Nettoyer uniquement les caractères de marge avant/après la syntaxe, côté Dart et dans la normalisation SQL.
- Conserver la conversion des alias français, par exemple `*412*2*numéro_du_destinataire#` vers `*412*2*{{msisdn_local}}#`.
- Afficher l’aperçu fictif et permettre l’enregistrement du brouillon après ce nettoyage.
- Conserver les caractères internes, les contrôles de syntaxe, les variables autorisées, les limites de longueur et la validation SIM séparée pour l’activation.

Le thème, la disposition du formulaire et les règles enregistrées ne sont pas modifiés. Les outils de lecture vidéo restent dans `scratch/`.

## Vérifications exécutées

| Contrôle | Résultat |
| --- | --- |
| Tests Flutter : moteur, formulaire et dépôt HTTP USSD | 124 réussis |
| Tests PostgreSQL isolés PGlite, dont vecteurs partagés Dart/SQL | 118 réussis |
| Analyse des 3 fichiers Dart concernés | Aucune erreur |
| Compilation du back-office | Réussie |
| Normalisation et génération sur le serveur réel, données fictives | 4 cas réussis |
| Refus serveur des syntaxes mal formées internes | 4 cas réussis |
| Vérification HTTP des 4 fichiers publiés | Empreintes identiques au build corrigé |

Les droits du helper SQL restent privés (`anon` et `authenticated` sans EXECUTE direct). Les compteurs et l’empreinte des règles sont identiques avant/après migration. Aucun brouillon de recette n’a été créé dans la base réelle. Le parcours authentifié complet dans le navigateur de l’utilisateur reste à réessayer.

```powershell
flutter test --no-pub test/app/domain/ussd/ussd_engine_test.dart test/app/modules/ussd/ussd_backoffice_widget_test.dart test/app/data/ussd/ussd_repository_http_test.dart --reporter expanded
node test/ussd_sql/run.mjs
flutter analyze --no-pub lib/app/domain/policies/ussd/ussd_engine.dart test/app/domain/ussd/ussd_engine_test.dart test/app/modules/ussd/ussd_backoffice_widget_test.dart
flutter build web --no-pub -t lib/main_backoffice.dart --output build/catalog_import_backoffice
```

## Mise en ligne

- Back-office : https://izytel-backoffice-4bca7.web.app
- Version Hosting : `5c85c013e26260da`, vérifiée le 15 novembre 2026 à 23:14 UTC.
- SHA-256 `main.dart.js` : `e670fb35cfb53b58562e899743da76f3a5a6f0c20bbee4c4c46798f59af16fa8`.
- Build issu de `1a0f40bb0d17710e63c70d0d06b0ab93043fa432` avec ce correctif local non commité ; le marqueur publié indique `sourceDirty: true` et `change: ussd-template-clipboard-padding`.
- Supabase IzyTel : `zrxeztxaxnzxevjuhzcc`. Migration locale `20261115230624_ussd_template_clipboard_padding.sql`, version distante `20261115230858`.
- Le connecteur Firebase a annoncé un succès sans servir le nouveau build. La publication effective a ensuite réussi avec la CLI, uniquement sur `hosting:backoffice`, puis a été contrôlée par HTTP.

Preuves locales : `scratch/ussd_paste_baseline.log`, `ussd_paste_flutter.log`, `ussd_paste_sql.log`, `ussd_paste_analyze.log`, `ussd_paste_web_build.log`, `ussd_paste_hosting_deploy.json`, `ussd_paste_hosting_results.json`.

Pour revenir en arrière, restaurer la version Hosting précédente et uniquement l’ancienne définition de `private.ussd_normalize_template(text)` présente dans `20261031224809_ussd_template_aliases_secret_and_draft_catalog.sql`. Ne pas rejouer cette ancienne migration complète. Aucune restauration de données n’est nécessaire.

Après actualisation complète du back-office (`Ctrl + F5`), réessayer la création avec la syntaxe de l’enregistrement : l’aperçu doit apparaître et le brouillon doit s’enregistrer.
