# [Catalogue] Gérer les offres et les imports XLSX sécurisés avec Supabase

## Objectif et état

Permettre à l’Admin de gérer le catalogue et d’importer plusieurs offres depuis le modèle Excel, avec aperçu, confirmation, compte rendu et restauration. Un code permanent met à jour la même offre ; les lignes absentes restent intactes et les commandes historiques sont conservées.

**Actualisation du 15 novembre 2026 : backend et Back-office déployés. L’import publie désormais en une confirmation et les natures/volumes sont corrigés, voir CAT-08. La recette authentifiée complète reste à réaliser.** Les chiffres de l’intégration initiale ci-dessous restent des preuves historiques ; les bilans récents sont `direct-import-results.json` et `presentation-results.json`.

## Modifications réalisées dans le Back-office

- Conservation du style existant : surfaces, cartes, boutons, badges et navigation. Comparaisons visuelles d’origine conservées.
- Recherche par nom/code, filtres réseau/service/famille/statut, tri, pagination et vues cartes/tableau.
- Création et duplication en brouillon depuis l’éditeur, formulaire structuré, rattachement explicite d’un code permanent aux offres historiques, métadonnées de vérification facultatives et familles configurables. Les lignes UPSERT importées sont publiées après confirmation.
- Import XLSX avec modèle téléchargeable, aperçu des écarts et erreurs, confirmation explicite, progression, reprise, rapport JSON et restauration contrôlée.
- Export CSV, historique des offres/imports et aperçu des changements groupés.

## Modifications réalisées côté serveur

- Supabase reste le catalogue canonique. Lecture XLSX sur le serveur, limitée à la feuille `OFFRES` et aux 22 colonnes attendues ; fichiers, décompression et nombre de lignes bornés ; formules et macros refusées.
- Contrôle de l’Admin actif, validation des valeurs, protection des métadonnées internes et blocage de toutes les occurrences d’un code en doublon.
- Préparation sans modification d’offre, puis application confirmée par lots de 50 avec importId, versions, audit et reprise idempotente.
- Restauration compensatoire avec contrôle des conflits ; aucune suppression de commande ni de mouvement financier.
- Snapshots immuables pour les nouvelles commandes canoniques. Les anciens historiques ne sont pas reconstruits à partir du catalogue actuel et aucun frais absent du schéma n’est inventé.

## Fichiers à relire

| Zone | Chemin depuis la racine |
|---|---|
| Page catalogue | `lib/app/modules/backoffice/views/catalog/backoffice_offers_page.dart` |
| Assistant d’import | `lib/app/modules/backoffice/views/catalog/catalog_import_dialog.dart` |
| Formulaire et règles | `lib/app/modules/backoffice/views/catalog/catalog_offer_details_dialog.dart` |
| Changements groupés | `lib/app/modules/backoffice/views/catalog/catalog_bulk_dialog.dart` |
| Modèles et contrats | `lib/app/domain/entities/offers/`, `lib/app/domain/repositories/catalog_import_repository.dart` |
| Repository | `lib/app/data/repositories/supabase_admin_offer_repository.dart` |
| Migration | `supabase/migrations/20261115133000_catalog_offer_imports.sql` |
| Lecteur et fonction serveur | `supabase/functions/izytel-catalog-import/` |
| Modèle fourni | `assets/templates/Modele_import_offres_IzyTel.xlsx` |

## Vérifications et mise en service déjà réalisées

- [x] Analyse Flutter et build Web réussis.
- [x] Intégration initiale : 36 tests Flutter ciblés, 16 scénarios SQL isolés et 5 tests du lecteur XLSX réussis.
- [x] Après le correctif CAT-06 : 16 tests UI/repository/style réussis, dont les deux goldens d’origine ; ces contrôles recouvrent une partie de la suite initiale.
- [x] Sauvegarde privée des 35 offres avant migration ; tous les champs d’origine sont restés identiques après migration.
- [x] Migration catalogue appliquée sous la version distante `20261115141733` ; fonction `izytel-catalog-import` v1 ACTIVE.
- [x] Cinq contrôles HTTP réussis, RPC anonyme refusée et accès direct client aux cinq tables internes refusé. Aucun import automatique du modèle lors du déploiement.

Preuves partageables : `docs/catalog_offers/IMPLEMENTATION.md`, `implementation-results.json`, `sql-results.json`, `deployment-results.json` et `STYLE_NON_REGRESSION.md`.

## Actions restantes

- [ ] Relire les changements et rattacher les commits/PR à cette issue.
- [x] Publier le Back-office compatible ; version Hosting actuelle `7118b910604dda10`.
- [ ] Exécuter la recette authentifiée Admin/non-Admin et joindre les résultats.
- [x] Appliquer la décision utilisateur de publication directe ; les métadonnées de vérification ne sont plus un prérequis de publication.
- [ ] Rattacher explicitement les codes historiques avant d’importer leurs mises à jour.

Les travaux techniques détaillés CAT-01 à CAT-05 sont dans `docs/catalog_offers/issues/`. Le correctif d’affichage est suivi par CAT-06 ; la recette et la publication par CAT-07. La suite globale du projet comporte des échecs préexistants documentés dans le bilan d’architecture ; les résultats ci-dessus concernent les contrôles ciblés exécutés.
