# Correction INVALID_ZONE dans la fiche Agent — 15 novembre 2026

Le profil Agent conservait des identifiants de zones absentes du catalogue territorial actuel. Le formulaire initialisait sa sélection avec tous ces identifiants, sans les afficher. Choisir la nouvelle zone active ajoutait son identifiant aux anciens ; le service refusait alors la demande avec `INVALID_ZONE`.

## Correction ciblée

- Initialiser la sélection uniquement avec les zones encore actives et afficher un avertissement lorsqu’il existe d’anciennes associations indisponibles.
- Présenter uniquement les zones actives et demander une sélection explicite si aucune zone valide n’est conservée. Aucun remplacement n’est choisi automatiquement.
- Conserver les capacités et quotas saisis lors de l’enregistrement.
- Afficher une consigne compréhensible si une zone devient indisponible entre l’ouverture et l’enregistrement.
- Attendre la fin de fermeture du dialogue avant de libérer ses contrôleurs ; le test du parcours révélait leur utilisation pendant l’animation de sortie.

Les contrôles de zones côté serveur restent en place. Aucune zone ni aucun compte réel n’a été modifié pendant ce correctif. La base ne présentait aucune opération utilisateurs pending/failed lors du diagnostic ; aucun déblocage de saga n’a été effectué.

## Vérification et publication

- 3 tests widget de régression réussis : anciennes zones puis sélection active ; sélection valide conservée avec exclusion des zones supprimées/inactives ; refus sans zone active disponible. Fermeture sans erreur des contrôleurs et conservation des capacités/quotas vérifiées.
- 23 tests existants du formulaire et du dépôt d’administration utilisateurs réussis.
- Analyse des 3 fichiers Dart concernés : aucun diagnostic.
- Build Web du back-office réussi.
- Hosting `d0fbc92f5e1ad7cb`, publié sur https://izytel-backoffice-4bca7.web.app ; 4 fichiers servis comparés au build local à 23:37 UTC, tous identiques.
- SHA-256 `main.dart.js` : `18d416ff30f6d50e70209ed2e1769c331815db848be853cbb46f605ed13179b1`.
- Marqueur publié : `change: agent-zone-selection`, `sourceDirty: true` (base Git `1a0f40bb0d17710e63c70d0d06b0ab93043fa432`, correctifs locaux non commités).

Commandes ciblées :

```powershell
flutter test --no-pub test/app/modules/backoffice/agent_zone_edit_test.dart --reporter expanded
flutter test --no-pub test/app/modules/backoffice/user_administration_dialog_test.dart test/app/modules/backoffice/user_administration_repository_test.dart --reporter expanded
flutter analyze --no-pub lib/app/modules/backoffice/views/team/backoffice_agents_page.dart lib/app/data/repositories/backoffice_user_administration_repository.dart test/app/modules/backoffice/agent_zone_edit_test.dart
flutter build web --no-pub -t lib/main_backoffice.dart --output build/catalog_import_backoffice
```

Preuves locales : `scratch/agent_zone_edit_regression.log`, `agent_zone_edit_tests.log`, `agent_zone_edit_analyze.log`, `agent_zone_edit_build.log`, `agent_zone_hosting_deploy.json`, `agent_zone_hosting_results.json`. Le log combiné conserve également les premiers essais du nouveau test ; son résultat final réussi est dans `agent_zone_edit_regression.log`.

Recette utilisateur : actualiser complètement (`Ctrl + F5`), rouvrir la fiche Agent, sélectionner la zone active « Abidjan, Abidjan », puis enregistrer. La mutation authentifiée réelle reste à effectuer par l’Admin. Retour arrière frontend : restaurer Hosting `5c85c013e26260da` ; aucune migration SQL associée.
