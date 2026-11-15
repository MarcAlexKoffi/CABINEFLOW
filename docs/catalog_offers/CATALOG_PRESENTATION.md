# Présentation du catalogue — 15 novembre 2026

Correctif ciblé côté Supabase, sans modification ni redéploiement du code client.

- `2.2000000000000002 GO` devient `2,2 GO` dans `volume` et les détails publics. Les décimales affichées utilisent la virgule ; la valeur exacte importée et l’unité restent conservées dans les données canoniques.
- `reference_operateur` fournit la nature commerciale. Les espaces multiples sont réduits à un espace.
- Pour une offre mise en avant, son badge existant affiche la nature, par exemple `Pass Max it` ou `Folie Internet`. Un nom dépassant 20 caractères reste dans les détails pour éviter de surcharger le badge.
- Pour les autres offres, la nature précède la première quantité : `C'Chic · 650 MO`. Aucun détail supplémentaire n’est ajouté : les volumes, minutes, SMS et validités restent visibles.
- La présence des badges reste liée à `mis_en_avant`, donc le classement des offres sur l’accueil est conservé. Les titres, prix, disponibilités, codes et snapshots des commandes ne changent pas.

Migration : `20261115213025_catalog_offer_presentation.sql`. Le trigger privé couvre aussi les prochains imports et les modifications du catalogue. Les commentaires, sources et preuves de livraison restent privés.

Avant correction, la migration verrouille les lignes concernées, sauvegarde leur état dans `private.catalog_presentation_backup_20261115213025` et conserve une révision d’audit `catalog_presentation_updated`. Les versions augmentent afin de protéger les formulaires ou aperçus ouverts avant le correctif.

Retour arrière contrôlé : désactiver le seul trigger `catalog_offer_presentation`, restaurer uniquement `volume`, `details` et `badge_label` depuis la sauvegarde pour les offres dont la version correspond encore à `after_version`, puis journaliser cette restauration. Si une offre a changé depuis, résoudre le conflit avant de la restaurer. Conserver sauvegarde, audit et commandes historiques.

Validation : 28 scénarios SQL isolés, dont correction de l’existant, imports suivants, réimport inchangé, conservation du classement, confidentialité et snapshots historiques. Le test `test/app/modules/customer/catalog_presentation_test.dart` utilise les composants clients existants et leur thème, avec les données publiques corrigées, aux largeurs 320, 390, 930 et 1440 px.
