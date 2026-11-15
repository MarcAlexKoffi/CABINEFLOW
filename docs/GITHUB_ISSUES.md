# Issues GitHub — modifications IzyTel

Préparé le 15 novembre 2026 pour `MarcAlexKoffi/CABINEFLOW`. Cinq issues principales sont prêtes à copier. Les quatre premiers lots sont implémentés ; leur revue et leur association à une PR restent à faire. La cinquième décrit la recette et la publication frontend restantes.

| Ordre | Titre à copier dans GitHub | Description complète | État réel | Labels suggérés |
|---|---|---|---|---|
| 1 | [Architecture] Réorganiser IzyTel selon l’architecture de référence | [ARCH-00](architecture/issues/00-epic.md) | Implémenté localement ; revue/recette restantes | `refactor`, `documentation` |
| 2 | [Nettoyage] Retirer le code inutilisé et les artefacts obsolètes | [ARCH-07](architecture/issues/07-cleanup.md) | Nettoyage effectué et contrôlé | `chore` |
| 3 | [Catalogue] Gérer les offres et les imports XLSX sécurisés avec Supabase | [CAT-00](catalog_offers/issues/00-epic.md) | Application intégrée ; backend déployé ; frontend non publié | `enhancement` |
| 4 | [Correctif] Empêcher le débordement des actions du catalogue | [CAT-06](catalog_offers/issues/06-responsive-intro.md) | Corrigé et testé localement | `bug` |
| 5 | [Recette] Valider les imports et publier le Back-office compatible | [CAT-07](catalog_offers/issues/07-production-acceptance.md) | À réaliser | `testing`, `deployment` |

Les labels sont des suggestions à adapter à ceux du dépôt. `ARCH-00` et `CAT-00` sont des repères locaux, pas des numéros GitHub. Les cases cochées indiquent des travaux déjà réalisés ; les cases ouvertes sont les actions de revue ou de recette restantes.

## Publication

1. Ouvrir [la création d’une issue](https://github.com/MarcAlexKoffi/CABINEFLOW/issues/new).
2. Choisir une issue vierge lorsque l’option est disponible. Copier la première ligne du fichier comme titre, sans son `#`, et le reste comme description.
3. Publier les cinq issues dans l’ordre du tableau. Affecter les personnes chargées des revues et de la recette.
4. Relier le correctif d’affichage et la recette à l’issue Catalogue. Relier le nettoyage à l’issue Architecture.
5. Ajouter aux issues les liens vers les commits/PR qui portent réellement leurs changements. Vérifier les critères restants avant clôture.

Les fichiers cités dans les descriptions sont des chemins depuis la racine du dépôt. Ils deviennent consultables sur GitHub après publication du code correspondant. Les journaux `scratch/` restent locaux ; les bilans JSON et documents dans `docs/` sont les preuves partageables.

## Repérage pour l’équipe

- Ancien fichier à retrouver : `docs/architecture/path-map.json`.
- Organisation et conventions : `docs/architecture/README.md`.
- Éléments retirés : `docs/architecture/CLEANUP.md`.
- Fonctionnalité et fichiers modifiés : `docs/catalog_offers/IMPLEMENTATION.md`.
- Backend effectivement déployé : `docs/catalog_offers/deployment-results.json`.
- Recette pas à pas : `docs/catalog_offers/RECETTE.md`.

## Commits locaux préparés le 15 novembre 2026

Branche : `refactor/architecture-catalogue-20261115`, créée à partir de `84f4d3a`.

| Commit | Contenu | Issues principales concernées |
|---|---|---|
| `4cf7ff4` | Backend Supabase, migrations, modèle et tests serveur | Catalogue |
| `8a90662` | Nettoyage des fichiers inutilisés et anciens artefacts | Nettoyage |
| `cf7a814` | Réorganisation, interface catalogue, correctif responsive et tests associés | Architecture, Catalogue, Correctif |
| `docs: documenter les changements, les issues et la recette` | Documentation et descriptions d’issues, y compris ce guide | Les cinq issues |

Le dernier commit se retrouve par son titre avec `git log -4 --oneline`. La réorganisation et l’interface catalogue partagent des fichiers ; elles sont enregistrées ensemble pour conserver un état applicatif complet. Le contrôle final d’architecture porte sur 662 sources/modèles Dart, 521 déplacements documentés et neuf suppressions volontaires.

Ces commits sont locaux à la préparation. Les numéros d’issues GitHub pourront être ajoutés aux descriptions de PR après création des issues. Les contrôles fonctionnels déjà exécutés sont détaillés dans les bilans de chaque lot ; la création des commits ne constitue pas une nouvelle recette de production.

Pour répartir une revue plus finement, les six lots techniques d’architecture sont dans [architecture/issues](architecture/issues/README.md) et les cinq lots techniques du catalogue dans [catalog_offers/issues](catalog_offers/issues/README.md). Ces fichiers détaillent les deux issues principales correspondantes ; les créer en sous-issues seulement si ce découpage aide l’équipe.

Aucune issue distante n’a été créée par cette préparation.
