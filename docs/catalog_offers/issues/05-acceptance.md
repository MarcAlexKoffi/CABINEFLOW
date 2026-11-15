# [CAT-05] Vérifier les imports et la non-régression des commandes

**Recette locale exécutée : 36 tests Flutter, 16 scénarios SQL et 5 tests du lecteur serveur réussis ; analyse et build Web réussis.** Les cases ci-dessous servent à la revue et à la recette authentifiée après mise en service. Détails et limites : [IMPLEMENTATION.md](../IMPLEMENTATION.md).

Préparer une recette Flutter + Supabase qui démontre les douze scénarios du brief sur le code réel. Les 9 tests de modèle et 10 scénarios navigateur R1 servent de cas de référence ; ils ne prouvent pas la sécurité du serveur ni le fonctionnement de l’application Flutter.

## Critères à prouver

- [ ] 4 créations BROUILLON ; aucun passage en vente automatique.
- [ ] Même fichier : 4 inchangées, aucune nouvelle offre ou écriture inutile.
- [ ] Prix modifié, même code : ID/création/historique conservés.
- [ ] Désactivation : nouvelles ventes bloquées, anciennes commandes conservées.
- [ ] Import partiel : offres absentes intactes.
- [ ] Doublons : toutes les occurrences bloquées, lignes affichées.
- [ ] Offre conditionnelle/promotionnelle non éligible : ACTIF refusé.
- [ ] Non-Admin : refus serveur sur appels directs et ressources d’import.
- [ ] Réseau perdu/retry/concurrence : pas de double application, résultats retrouvables.
- [ ] Commande créée avant modification : snapshot prix/volume/unité/frais/libellé inchangé, y compris après synchronisation ou restauration.
- [ ] 500+ lignes : pagination, progression, erreurs partielles, reprise et rapport fidèles.
- [ ] Responsive et clavier : cartes, tableau, filtres, tri, textes longs et focus accessibles.

Ajouter fichiers hostiles/limites, contrôle de version import/édition et restauration après modification. Comparer l’implémentation à la bonne révision validée, puis effectuer l’audit technique avec preuves et limites explicites.

Dépendances : CAT-01 à CAT-04. Joindre commandes, résultats, captures et contrôles non exécutés à la clôture ; ne pas réutiliser des résultats de recette d’un autre lot comme preuve de ce module.
