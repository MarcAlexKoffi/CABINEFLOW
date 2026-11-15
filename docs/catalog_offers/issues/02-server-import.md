# [CAT-02] Valider et fusionner les imports d’offres côté serveur Supabase

**Implémenté et déployé avec accord utilisateur : fonction v1 ACTIVE.** `supabase/functions/izytel-catalog-import/` lit le vrai XLSX sur le serveur ; la migration contient préparation, validation, confirmation et application sécurisées. Les cases servent à la revue/recette ; [16 scénarios SQL et 5 tests du lecteur sont réussis](../IMPLEMENTATION.md). Les refus d’accès et le prévol HTTP sont vérifiés à distance ; aucun import automatique.

Un fichier de 40 brouillons ou une modification de prix doit produire un aperçu puis une application autorisée, sans doublons ni écrasement silencieux. Le parseur navigateur du prototype aide à la revue ; il ne constitue pas une validation de confiance.

## Travail prévu

- [ ] Créer un parcours serveur de préparation lié au contenu, à l’acteur et aux versions ; aucune écriture d’offre durant l’aperçu.
- [ ] Accepter XLSX/OFFRES uniquement avec les 22 colonnes du modèle ; ne pas importer les feuilles d’aide.
- [ ] Borner taille, décompression, lignes et complexité ; refuser macros, formules et archives ambiguës ; traiter URLs et HTML comme texte.
- [ ] Valider valeurs, quantités, précision, unités, familles/opérateurs et conditions de publication.
- [ ] Rejeter toutes les lignes d’un code répété avec numéros de ligne ; interdire les collisions entre opérateurs.
- [ ] UPSERT : conserver ID/création/historique et ne modifier que les champs différents ; aucune écriture pour les lignes identiques.
- [ ] DESACTIVER : action + code suffisent ; conserver l’offre et ses historiques ; ne pas toucher aux offres absentes du fichier.
- [ ] Recontrôler l’Admin serveur à préparation/confirmation/application et protéger également les RPC unitaires, rapports et sauvegardes.
- [ ] Lier la confirmation au contenu et au choix explicite d’exclure les lignes bloquées ; refuser les versions devenues obsolètes.

## Acceptation

Quatre nouvelles offres créent quatre brouillons. La réimportation produit quatre inchangées. Changer le prix avec le même code conserve l’ID. Deux occurrences du même code ne désignent aucun vainqueur. Un manager/agent non autorisé est refusé en appel direct au serveur. Aucune clé privilégiée n’est exposée au front.

Dépendance : CAT-01. Préparer des tests SQL/intégrés avant toute migration ou mise en service ; aucune exécution de production n’est incluse dans la R1.
