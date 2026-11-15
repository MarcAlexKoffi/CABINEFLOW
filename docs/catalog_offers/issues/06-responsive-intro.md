# [Correctif] Empêcher le débordement des actions du catalogue

## Problème observé

Dans Catalogue → Offres & tarifs, une largeur desktop intermédiaire affichait un grand espace vide et une bande jaune/noire avant les offres. Le problème a été signalé dans la vidéo utilisateur du 15 novembre 2026 à 14:27.

Le `Row` desktop de l’introduction laissait une largeur non bornée au `Wrap` des six actions Admin. Les boutons prenaient l’espace nécessaire au titre et à sa description. Le test reproduit un débordement de 375 pixels à une largeur de fenêtre de test de 884 px.

**État : corrigé et testé localement ; contrôle visuel dans la session utilisateur restant.**

## Correction réalisée

- Plafonner la largeur de la barre d’actions à 440 px dans la page catalogue.
- Laisser les boutons passer à la ligne en conservant les styles existants et de la place pour le texte.
- Ajouter un test aux largeurs 840, 884, 930, 1024 et 1280 px : absence de débordement, hauteur d’introduction bornée et six actions à l’intérieur de sa surface.

## Fichiers concernés

- `lib/app/modules/backoffice/views/catalog/backoffice_offers_page.dart`.
- `test/app/modules/backoffice/catalog_import_ui_test.dart`, scénario `admin import actions wrap without overflowing at desktop content widths`.
- `docs/catalog_offers/implementation-results.json`, section `followUpLayoutFix`.

## Vérifications et clôture

- [x] Échec reproduit avant correction.
- [x] Les 16 tests UI/repository/style ciblés passent après correction.
- [x] Les deux goldens d’origine passent sans régénération.
- [x] Analyse sans anomalie et compilation Web réussie.
- [ ] Redémarrer l’application locale avec `R` dans le terminal Flutter, puis contrôler Offres & tarifs à la taille de la vidéo.
- [ ] Relire le diff et rattacher le commit/PR à l’issue Catalogue.

La correction est limitée à la présentation de cette page. Les règles métier et le backend restent ceux décrits dans CAT-00.
