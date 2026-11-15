# [CAT-04] Persister les révisions, reprises et restaurations d’import

**Persistance serveur implémentée et vérifiée sur PostgreSQL isolé.** Le même importId reprend les lots ; les versions protègent application et restauration ; les métadonnées internes restent réservées aux Admins. Voir [les preuves et la mise en service](../IMPLEMENTATION.md). Les cases restent des points de revue/recette distante.

Une perte réseau après confirmation ne doit ni appliquer deux fois un lot ni masquer les changements déjà appliqués. L’administrateur doit retrouver un compte rendu et pouvoir restaurer une révision sans effacer l’historique commercial ou financier.

## Travail prévu

- [ ] Persister importId, auteur, contenu confirmé, versions attendues, périmètre valide/exclu, ancien/nouveau état et résultats par ligne.
- [ ] Garantir l’unicité et l’idempotence des étapes côté serveur, y compris requêtes concurrentes et réponses perdues.
- [ ] Traiter par lots bornés avec progression, statut partiel et reprise durable ; ne pas promettre d’atomicité globale sur plusieurs lots.
- [ ] Enregistrer et exposer les conflits de version sans écrasement silencieux.
- [ ] Fournir historique et rapport téléchargeable avec contrôle d’accès.
- [ ] Restaurer par révision compensatoire avec contrôle des modifications ultérieures ; garder les créations inactives et auditées plutôt que les supprimer.
- [ ] Définir rétention et sauvegarde des révisions ; vérifier que restauration ne modifie aucune commande ni mouvement financier.

## Acceptation

Avec 500+ lignes et des erreurs, la progression et le compte rendu correspondent aux résultats effectivement appliqués. Après coupure/reconnexion, le même importId reprend sans double application. Une offre éditée après l’import bloque la restauration concernée selon une politique explicite. Les snapshots de commandes restent identiques.

Dépendances : backend CAT-02 déployé avec accord utilisateur ; frontend CAT-03 compilé localement, hébergement et recette authentifiée restants. La candidate contient la persistance serveur réelle ; la simulation R1 est seulement une archive historique. Une sauvegarde privée des 35 offres précède la migration ; [relevé](../deployment-results.json).
