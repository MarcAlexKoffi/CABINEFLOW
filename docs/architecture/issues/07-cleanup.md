# [Nettoyage] Retirer le code inutilisé et les artefacts obsolètes

## Objectif et état

Alléger le projet après sa réorganisation et éviter que les collaborateurs travaillent sur d’anciens écrans, correctifs ou copies de code.

**Nettoyage effectué et contrôlé le 15 novembre 2026 ; revue restante.**

## Modifications réalisées

- Retrait de neuf fichiers Dart sans consommateur applicatif, test ou contrat de code source.
- Retrait d’un ancien asset de splash remplacé, de copies de correctifs, d’un script obsolète, de diagnostics périmés et de sauvegardes de code anciennes.
- Nettoyage des anciennes sorties de compilation, caches d’hébergement et environnements de recette régénérables : environ 7,9 Go recensés au moment du nettoyage. Les compilations ultérieures recréent leurs propres sorties.
- Mise à jour de `.gitignore`, des exclusions devenues inutiles dans `analysis_options.yaml` et du modèle de scénario de recette maintenu.
- Conservation des sauvegardes de données, migrations, règles, fonctions serveur et documents de reprise utiles.

## Fichiers à consulter

- `docs/architecture/CLEANUP.md` : liste des neuf fichiers Dart retirés et justification des suppressions.
- `docs/architecture/cleanup-results.json` : relevé des chemins et volumes.
- `docs/architecture/path-map.json` : entrées supprimées avec `status: removed` et motif.
- `.gitignore`, `analysis_options.yaml`, `test/shared_queue/device_scenarios.dart.template`.

## Vérifications et clôture

- [x] Contrôle d’architecture après nettoyage : 652 sources/modèles Dart contrôlés ; neuf suppressions reconnues.
- [x] Analyse Flutter sans diagnostic.
- [x] Suite complète identique à la baseline : 1 121 réussites, 2 ignorés et les mêmes 13 échecs préexistants.
- [ ] Vérifier les suppressions dans la PR avec le relevé de nettoyage.
- [ ] Vérifier que les instructions de régénération des builds restent accessibles.
- [ ] Relier cette issue à l’issue Architecture et aux commits concernés.

Les résultats portent sur le nettoyage du 15 novembre. Les sorties de compilation régénérées depuis ne constituent pas des suppressions manquantes.
