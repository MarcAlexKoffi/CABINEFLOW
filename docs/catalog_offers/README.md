# Catalogue et import des offres IzyTel

**Mise à jour du 15 novembre : fonctionnalité intégrée, candidate locale vérifiée et backend déployé avec accord utilisateur.** La demande utilisateur de passer directement à l’implémentation avec le style existant remplace le gate de revue du prototype ci-dessous. Consulter le [bilan d’implémentation](IMPLEMENTATION.md), le [relevé de déploiement](deployment-results.json) et la [politique de non-régression du style](STYLE_NON_REGRESSION.md). Les 35 offres d’origine sont conservées ; aucun import automatique. Le frontend est compilé localement, sans publication d’hébergement.

Le reste de cette page décrit le prototype HTML historique, conservé comme référence du parcours.

Révision **R1 — DESIGN_REVIEW**, 15 novembre 2026. Le brief fourni demande une conception à valider avant l’implémentation. Le livrable est un prototype interactif isolé ; l’application Flutter et le backend ne sont pas modifiés par ce lot.

Décision utilisateur confirmée : **Supabase reste la source canonique ; validation et écritures d’import seront exécutées côté serveur**. La mention Firestore du brief est remplacée par cette décision.

## Ouvrir la revue

Depuis la racine du projet :

```powershell
node docs/catalog_offers/aura-r1/serve.cjs
```

Ouvrir <http://127.0.0.1:4317>. Le serveur écoute uniquement sur l’ordinateur local et expose les fichiers du prototype. Arrêt : `Ctrl+C`. Le port est configurable avec `IZYTEL_DESIGN_PORT`. Un double-clic sur `index.html` ne suffit pas : les modules et les données nécessitent le serveur local.

- [Dossier de conception R1](DESIGN_REVIEW.md) : direction, interactions, responsive et décisions ouvertes.
- [Relais d’implémentation Supabase / Flutter](IMPLEMENTATION_HANDOFF.md) : état du code et écarts à combler.
- [État du workflow](WORKFLOW_STATE.md).
- [Brouillons d’issues GitHub](issues/README.md) : travaux livrés et travaux futurs clairement distingués.
- [Résultats navigateur](aura-r1/qa/evidence/results.json), [captures de référence](aura-r1/qa/evidence/).

## Parcours à essayer

1. Filtrer Orange / MTN / Moov, chercher un code, changer le tri et passer en tableau. Sélectionner des offres puis examiner les impacts d’une modification groupée.
2. Ouvrir « Importer un fichier ». Le modèle téléchargeable est une copie identique du fichier fourni. Sa feuille OFFRES contient **40 propositions BROUILLON** : Orange 12, MTN 13, Moov 15. Les autres feuilles sont ignorées.
3. Tester « 4 nouveaux brouillons », confirmer, puis reprendre le même exemple : 4 lignes inchangées, aucune création supplémentaire.
4. Tester « Un prix modifié », puis « Voir un exemple » sous le catalogue : l’identifiant et le snapshot de la commande fictive restent identiques.
5. Tester « Doublons & erreurs » : les deux occurrences du code sont bloquées. L’application des seules lignes valides exige un choix explicite, puis une confirmation.
6. Tester « 520 lignes & reprise » : 515 créations proposées, 5 erreurs, aperçu paginé. Cocher la simulation de coupure à la confirmation, puis reprendre avec le même importId.
7. Télécharger le rapport JSON et restaurer une révision. Les créations deviennent inactives, sans effacement ; une modification ultérieure bloque la restauration.

Les huit offres initiales sont des exemples fictifs, avec des statuts variés pour présenter l’interface. Ils ne prouvent aucune disponibilité commerciale. Les propositions du classeur restent non vérifiées.

## Vérifications exécutées

```powershell
node --test docs/catalog_offers/aura-r1/qa/model.test.mjs
```

Les 9 tests du modèle vérifient les cas de fusion, doublons, publication bloquée, quantités/unités, reprise, conflits et restauration. Ils concernent la simulation locale.

La recette navigateur utilise **une installation existante** de Playwright et JSZip, sans ajouter de dépendances au projet Flutter :

```powershell
$env:IZYTEL_QA_NODE_MODULES = 'CHEMIN_VERS/node_modules'
node docs/catalog_offers/aura-r1/qa/browser.cjs
```

Le serveur doit être lancé. La recette choisit le navigateur Edge installé et vérifie 320, 390, 768 et 1440 px, le clavier, le vrai XLSX, les erreurs de fichier, la pagination, la reprise et les interactions. Les résultats datés sont consignés dans `qa/evidence/results.json`.

Aucun test de rôle serveur, RLS, authentification réelle, migration ou import de production n’a été exécuté. Ces travaux font partie des issues futures. Les tests Flutter ne sont pas relancés pour ce lot documentaire et ce prototype isolé.
