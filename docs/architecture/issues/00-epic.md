# [Architecture] Réorganiser IzyTel selon l’architecture de référence

## Objectif et état

Rendre le code plus facile à retrouver et à relire en reprenant l’organisation de `IzyTel-main` sous `lib/app`. La réorganisation porte sur les dossiers et les imports, avec les comportements existants conservés.

**Implémenté localement les 14 et 15 novembre 2026 ; revue et recette manuelle restantes.**

## Modifications réalisées

- Déplacement de 390 fichiers applicatifs et de 131 fichiers de tests, avec 521 correspondances documentées.
- Regroupement des entités, contrats, permissions et règles métier dans `lib/app/domain`.
- Regroupement des repositories, mappers et sources dans `lib/app/data`, et des services transversaux dans `lib/app/services`.
- Organisation des pages, ViewModels et widgets dans `lib/app/modules/<module>/`.
- Centralisation du socle technique, des composants partagés, des routes et des thèmes dans `core`, `shared`, `routes` et `theme`.
- Harmonisation des trois points d’entrée : `main_staff.dart`, `main_customer.dart`, `main_backoffice.dart`. Les anciennes entrées restent des relais compatibles.
- Adaptation des imports, des tests et des références de configuration. Le package reste `cabine_flow` et les ViewModels gardent leur fonctionnement actuel.

## Où retrouver les changements

| Besoin | Chemin depuis la racine |
|---|---|
| Guide et conventions | `docs/architecture/README.md` |
| Ancien chemin → nouveau chemin | `docs/architecture/path-map.json` |
| Contrôle automatique | `tool/check_architecture.dart` |
| Domaine | `lib/app/domain/` |
| Données et services | `lib/app/data/`, `lib/app/services/` |
| Écrans et ViewModels | `lib/app/modules/` |
| Initialisation des applications | `lib/main_staff.dart`, `lib/main_customer.dart`, `lib/main_backoffice.dart` |
| Résultats et limites | `docs/architecture/VALIDATION.md`, `docs/architecture/validation-results.json` |

## Vérifications déjà réalisées

- [x] Analyse Flutter sans diagnostic.
- [x] Contrôle d’architecture et correspondances de chemins vérifiés.
- [x] Comparaison des corps Dart après retrait des directives : 390 corps identiques, un écart documentaire dans l’exemple d’import Firebase.
- [x] Compilations Client Web, Back-office Web et Android debug réussies à cette étape.
- [x] Suite complète comparée avant/après : 1 121 réussites, 2 tests ignorés et les mêmes 13 échecs préexistants. Détail dans `VALIDATION.md` ; la suite globale n’est pas annoncée comme verte.

## Revue et clôture

- [ ] Vérifier les déplacements à l’aide de `path-map.json` et du diff de la PR.
- [ ] Vérifier les démarrages des trois applications et les parcours existants avec les comptes de recette.
- [ ] Joindre les liens des commits/PR et les résultats de la recette.

Pour répartir la revue : ARCH-01 domaine ; ARCH-02 données/services ; ARCH-03 modules ; ARCH-04 socle/thèmes/composants ; ARCH-05 entrées/routes ; ARCH-06 tests/documentation. Les descriptions sont dans `docs/architecture/issues/01-*.md` à `06-*.md`.

Le nettoyage est décrit dans ARCH-07. L’évolution fonctionnelle Catalogue et ses migrations sont décrites dans CAT-00. Retour arrière de la structure par revert des commits concernés, en tenant compte des changements qui utilisent déjà les nouveaux chemins.
