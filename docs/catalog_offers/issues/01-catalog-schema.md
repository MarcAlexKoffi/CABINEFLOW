# [CAT-01] Établir les codes permanents et les règles de publication du catalogue

**Implémenté et migration appliquée avec accord utilisateur.** Source : `supabase/migrations/20261115133000_catalog_offer_imports.sql`, version distante `20261115141733`. Mapping explicite, publication configurable, projection publique séparée des métadonnées Admin. Les 35 offres conservent tous leurs champs d’origine. Les cases ci-dessous sont des points de revue/recette ; voir [les preuves](../IMPLEMENTATION.md).

Le modèle Excel possède des codes, familles et critères de publication qui ne sont pas représentés entièrement par `AdminOffer` et le schéma BO-4. Préparer une extension compatible de `catalog_offers` en gardant les identifiants techniques et les lectures existantes du catalogue client.

## Travail prévu

- [ ] Examiner les migrations postérieures à BO-4 et les RPC réellement utilisées.
- [ ] Définir un mapping explicite des offres historiques vers un `code_offre` unique et permanent, avec contrôle des collisions et de la casse ; ne pas identifier par nom/prix/durée.
- [ ] Structurer quantité et unité sans équivalence automatique GO/MO ; définir le mapping des types MIXTE/APPELS/SOCIAL vers les types existants.
- [ ] Charger familles et compatibilités depuis une configuration serveur, sans redéploiement du front.
- [ ] Distinguer brouillon/actif/inactif en conservant la compatibilité des lectures `is_active` ; définir suspension/archive sans suppression physique.
- [ ] Définir fraîcheur de vérification, activation pour tiers, canal confirmé et preuve de livraison conditionnelle ; appliquer les règles aussi aux modifications unitaires.
- [ ] Établir une version de concurrence et une migration/backfill testés et réversibles.

## Acceptation

Les mêmes offres gardent ID, date de création et liens historiques. Un brouillon non vérifié ne devient pas vendable. Une famille incompatible ou un code déjà affecté à un autre opérateur est rejeté. Les configurations changent sans redéploiement du front. Aucun prix de commande historique n’est recalculé.

Dépendances : décisions métier identifiées dans `docs/catalog_offers/DESIGN_REVIEW.md`. Référence technique : `IMPLEMENTATION_HANDOFF.md`. Aucun schéma nouveau n’a été appliqué par la R1.
