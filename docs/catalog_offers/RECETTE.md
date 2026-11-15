# Recette locale — catalogue et imports

15 novembre 2026. Cette recette teste l’application Flutter réelle avec le backend IzyTel déployé. **Un import confirmé écrit dans le backend réel.** Réserver des codes aux essais et conserver les offres en brouillon.

## Lancement

Depuis la racine du dépôt :

```powershell
flutter pub get
flutter run -d chrome -t lib/main_backoffice.dart --web-hostname localhost --web-port 8080
```

Le port 8080 est autorisé par la fonction. Se connecter avec un Admin actif et ouvrir Catalogue → Offres & tarifs. Si le terminal Flutter tourne déjà, `R` recharge l’application avec les derniers changements.

## Préparation

Dans Importer un fichier → Télécharger le modèle, enregistrer une copie XLSX. Garder les 22 en-têtes et seulement quatre lignes de la feuille `OFFRES`. Utiliser les codes `RECETTE_20261115_01` à `04`, des noms commençant par « RECETTE », `action=UPSERT` et `statut=BROUILLON`. Conserver les autres valeurs valides du modèle. Relever le nombre initial d’offres et les IDs des offres de recette après création.

## Scénarios

| Étape | Manipulation | Résultat attendu |
|---|---|---|
| 1. Aperçu | Choisir le fichier puis fermer sans confirmation | Quatre créations proposées ; aucune offre ajoutée |
| 2. Création | Recharger, continuer et confirmer explicitement | Quatre brouillons ; résultats et rapport cohérents |
| 3. Idempotence | Réimporter exactement le même fichier | Quatre lignes inchangées ; aucun doublon |
| 4. Prix | Augmenter le prix d’une ligne sans changer son code puis importer | Une modification, trois inchangées ; ID conservé |
| 5. Restauration | Restaurer immédiatement la dernière révision de prix | Ancien prix rétabli ; aucune offre supprimée |
| 6. Doublons | Dans une copie, ajouter une seconde occurrence d’un code | Toutes les occurrences du code sont bloquées avec les numéros de ligne ; ne pas appliquer ce fichier |
| 7. Partiel | Fichier contenant deux occurrences d’un code de recette et une nouvelle ligne valide avec le code `RECETTE_20261115_05` | Deux erreurs ; continuer exige le choix explicite des lignes valides, puis une confirmation ; seule la nouvelle ligne est créée |
| 8. Désactivation | Fichier avec les mêmes en-têtes et une ligne contenant seulement `action=DESACTIVER` et un code existant de recette | Offre inactive ; les offres absentes restent intactes |
| 9. Publication refusée | Préparer une offre de recette ACTIF avec `activable_pour_tiers=A_VERIFIER` et `canal_activation=A_VERIFIER` | Ligne bloquée dans l’aperçu ; aucune activation |
| 10. Historique | Examiner historique des imports/offres et télécharger un rapport | Auteur, changements, résultats et état de la révision cohérents |

Pour tester la reprise, interrompre le réseau pendant le traitement d’un lot de recette. Rétablir le réseau puis reprendre le même import depuis l’assistant ou l’historique. Vérifier l’importId, le résultat final et l’absence de doublon. Une interruption après confirmation peut laisser des écritures déjà appliquées : vérifier l’historique avant toute nouvelle action.

Pour tester un conflit, préparer un changement de prix sans le confirmer, modifier ensuite cette offre de recette dans une seconde session, puis confirmer le premier aperçu. L’import doit signaler le conflit et conserver la modification plus récente. Utiliser des codes distincts des étapes 1 à 10 pour que cette vérification ne perturbe pas leur restauration.

Avec un compte non-Admin, vérifier l’absence des actions de gestion. Un appel direct à une RPC protégée doit être refusé ; ce contrôle peut être réalisé dans le client de test HTTP habituel avec le JWT de ce compte, en conservant uniquement le statut et une réponse expurgée dans les preuves.

## Présentation et fin de recette

Tester les largeurs 320, 390, 768 et 1440 px, ainsi qu’une fenêtre desktop à largeur intermédiaire. La barre latérale réduit la place disponible pour le contenu. Le test automatisé de CAT-06 couvre les largeurs de contenu 840, 884, 930, 1024 et 1280 px.

Contrôler la lecture des textes, les cartes/tableaux, les filtres et les dialogues, l’absence de bande de débordement et de grand espace vide, ainsi que la fermeture par Échap hors traitement. À la fin, filtrer le préfixe de recette et désactiver toutes les offres d’essai.

Conserver un tableau avec date, version, compte/rôle sans mot de passe, scénario, attendu, observé, statut et preuve. Les snapshots de commandes et les scénarios financiers utilisent les fixtures SQL isolées ; la recette ci-dessus ne demande aucun paiement réel.

## Contrôles automatisés

```powershell
flutter analyze --no-pub
flutter test --no-pub test/app/modules/backoffice/catalog_import_ui_test.dart test/app/modules/backoffice/catalog_import_repository_test.dart test/app/modules/backoffice/catalog_style_regression_test.dart
npm ci --prefix test/catalog_import
node test/catalog_import/run.mjs
```

Le groupe Flutter ciblé compte 16 tests après CAT-06. Les 16 scénarios SQL utilisent un PostgreSQL isolé. Les cinq tests du lecteur XLSX et les prérequis Deno sont décrits dans `test/catalog_import/README.md`. Les résultats de la suite globale antérieure sont détaillés dans `docs/architecture/VALIDATION.md`.
