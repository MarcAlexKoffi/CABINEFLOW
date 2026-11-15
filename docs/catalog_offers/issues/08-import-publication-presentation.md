# [Catalogue] Publier les offres dès l’import et afficher leur nature commerciale

## Problème et résultat

Les offres importées restaient en brouillon ou étaient bloquées par des prérequis de vérification. Une offre de 2,2 GO affichait `2.2000000000000002 GO`, et les noms commerciaux du fichier, comme Pass Max it, C'Chic et Folie Internet, n’étaient pas visibles.

Après ce correctif, l’Admin choisit son fichier, consulte l’aperçu puis clique sur **Importer et publier**. Les offres concernées deviennent disponibles immédiatement. Les volumes affichés utilisent la notation française et la nature commerciale apparaît avec les composants clients existants.

**Implémenté et déployé le 15 novembre 2026. Revue des commits et recette authentifiée complète à terminer.** Cette issue regroupe la livraison actuelle ; CAT-08 est un repère documentaire, pas un numéro GitHub.

## Changements réalisés

- [x] Publication directe des lignes UPSERT en BROUILLON, ACTIF ou statut vide après une seule confirmation d’import. INACTIF et DESACTIVER conservent leur effet ; les offres absentes du fichier restent intactes.
- [x] Suppression des blocages de publication liés au délai de vérification, au canal confirmé, à l’éligibilité pour un tiers et à la preuve de livraison. Les métadonnées existantes sont conservées, sans inventer de vérification.
- [x] Conservation de l’autorisation Admin actif côté serveur, des contrôles commerciaux, du traitement explicite des erreurs/doublons, de l’audit, des versions, de la reprise et de la restauration.
- [x] Action de publication groupée pour les brouillons existants, avec périmètre couvrant toutes les pages filtrées ou la sélection, récapitulatif des offres activables et motifs des erreurs commerciales.
- [x] Affichage `2,2 GO` à la place de `2.2000000000000002 GO`, sans changer la valeur décimale canonique ni l’unité importée.
- [x] Nature issue de `reference_operateur`, espaces multiples normalisés : badge des offres mises en avant, premier détail des autres offres. La présence des badges et le classement sont conservés.
- [x] Correction des 53 offres existantes, avec sauvegarde et audit. Titres, prix, disponibilité, codes, données commerciales et commandes historiques conservés.
- [x] Style existant conservé ; aucun changement ni redéploiement du code client pour la présentation des offres.

## Fichiers et preuves à relire

| Périmètre | Fichiers depuis la racine du dépôt |
|---|---|
| Back-office | `lib/app/modules/backoffice/views/catalog/backoffice_offers_page.dart`, `catalog_import_dialog.dart`, `catalog_offer_details_dialog.dart`, `catalog_bulk_dialog.dart` |
| Import serveur | `supabase/functions/izytel-catalog-import/index.ts` |
| Publication directe | `supabase/migrations/20261115205903_catalog_direct_file_publication.sql` |
| Présentation et sauvegarde | `supabase/migrations/20261115213025_catalog_offer_presentation.sql` |
| Tests | `test/catalog_import/run.mjs`, `test/app/modules/backoffice/catalog_import_ui_test.dart`, `catalog_publication_ui_test.dart`, `test/app/modules/customer/catalog_presentation_test.dart` |
| Recette et retour arrière | `docs/catalog_offers/RECETTE.md`, `CATALOG_PRESENTATION.md` |
| Livraison effective | `docs/catalog_offers/direct-import-results.json`, `presentation-results.json`, `sql-results.json` |

## Validation déjà exécutée

- [x] 22 tests Flutter ciblés du Back-office/import, dont la confirmation unique et les comparaisons de style d’origine.
- [x] 6 tests clients ciblés ; nouveaux libellés vérifiés à 320, 390, 930 et 1440 px avec le thème et les composants existants.
- [x] 28 scénarios SQL en PostgreSQL isolé : migrations, import direct, erreurs, autorisations, concurrence, reprise, restauration, présentation et confidentialité.
- [x] 5 tests du lecteur XLSX et compilation web Back-office réussis.
- [x] Analyses Dart ciblées réussies et 13 contrôles HTTP de la livraison Back-office réussis.
- [x] Contrôles serveur en production : 53 offres actives, 16 mises en avant, 53 sauvegardes et 53 événements d’audit. Empreinte commerciale identique avant/après le correctif de présentation.

Ces groupes ont été exécutés aux étapes documentées dans les bilans ; ils ne constituent pas une suite globale verte. La dernière analyse globale signale 68 erreurs préexistantes dans les anciens fichiers USSD/résilience, hors périmètre.

## Mise en service

Back-office : https://izytel-backoffice-4bca7.web.app — version Hosting `7118b910604dda10`. Fonction `izytel-catalog-import` v3 ACTIVE sur le projet Supabase IzyTel `zrxeztxaxnzxevjuhzcc`.

| Migration locale | Version déjà appliquée sur IzyTel |
|---|---|
| `20261115205903_catalog_direct_file_publication.sql` | `20261115211043` |
| `20261115213025_catalog_offer_presentation.sql` | `20261115213833` |

Ces migrations sont déjà en production. Vérifier la correspondance de l’historique de l’environnement avant de les rejouer ; ne pas lancer un `db push` global sur IzyTel pour cette livraison. Les procédures de retour arrière sont dans les guides de recette et de présentation.

## Reste à valider avant clôture

- [ ] Relire et rattacher les deux commits et la PR à cette issue.
- [ ] Exécuter la recette authentifiée Admin/non-Admin de `docs/catalog_offers/RECETTE.md`, avec des offres réservées aux essais, et joindre les résultats.
- [ ] Confirmer visuellement les libellés en production sur mobile et desktop. Désactiver les offres de recette après les essais.

La préparation du code n’a pas exécuté un import authentifié de recette en production. Les contrôles automatisés et les vérifications de données déjà effectués restent distingués de cette validation manuelle.
