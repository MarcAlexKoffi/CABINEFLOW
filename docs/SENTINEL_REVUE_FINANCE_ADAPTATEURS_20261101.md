# SENTINEL — adaptateurs Finance — 1 novembre 2026

Revue indépendante en lecture seule des nouveaux adaptateurs mobile, du modèle de snapshot et de `20261101012308_finance_mobile_canonical_reads.sql`. Aucun changement de ces fichiers par cette revue. Deux SELECT de métadonnées ont été exécutés, sans lecture de lignes métier ni écriture distante.

## Conclusion limitée au changement examiné

Aucun nouveau P0/P1 démontré dans la migration de lecture ou dans le choix d'une écriture canonique commune avec le Back-office. Le registre des commandes financières est désormais Supabase pour crédits/règlements/dépenses/Wave/clôtures ; l'adaptateur ne crée pas une seconde écriture Firestore pour ces opérations. La lecture Firestore restante dans createCustomerCredit sert à reconstruire une ancienne commande pour l'API d'autorisation existante et ne constitue pas une seconde écriture financière.

La RPC de lecture applique la garde Admin serveur avant SQL, une whitelist fermée des tables et clés, un search_path vide et une taille bornée. Les noms SQL proviennent uniquement du case, les curseurs restent liés par paramètres. Les grants à anon/authenticated n'évitent pas la garde métier. La pagination lexicographique est stable pour ces clés uniques non nulles.

Confirmation distante de structure : `phase5_agent_recharges.source_firestore_id` est NOT NULL et UNIQUE (PK distincte id UUID), `phase5_supplier_accounts.supplier_id` est la PK. Le choix de ces deux curseurs est donc cohérent ; aucune supposition de nullabilité n'est nécessaire. Les fournisseurs du snapshot ne sont pas limités dans la définition SQL versionnée examinée, contrairement à plusieurs historiques de flux ; aucune anomalie de troncature fournisseurs n'est retenue.

## P1 constatés lors de la revue initiale

- `SupabaseBackofficeFinanceRepository.recordSupplierRecharge` et recordSupplierPayment fabriquent une operation_key temporelle à chaque appel. Une tentative métier rejouée ne conserve pas sa clé précédente. Le nouvel adaptateur réutilise cette API, donc ne corrige pas cette faiblesse préexistante. Correctif attendu : clé d'opération stable créée avant la première tentative, conservée jusqu'au résultat déterminé, et contrainte/résultat serveur idempotent.
- `izytel_finance_record_expense` versionnée génère son ID sans clé de requête stable. Une réponse perdue puis un nouvel appel peuvent créer une seconde dépense. Le nouveau chemin canonique élimine le miroir divergent, sans démontrer une nouvelle garantie exactly-once. Une évolution RPC dédiée et des tests de réponse perdue/concurrence restent nécessaires.

**Statut après correctifs locaux** : ces deux constats ont conduit aux clés stables par intention, à la RPC `izytel_finance_record_expense_once` et à la fermeture de l'ancien endpoint direct aux rôles clients. Les fenêtres Réessayer du BO et du mobile conservent la même demande. Les tests SQL, transport et widget cités dans le bilan final ont été exécutés avec succès. Cela ne revendique pas une garantie physique exactly-once après disparition de la clé ou redémarrage complet du client.

La contre-revue de fin a aussi révélé deux défauts corrigés avant livraison : une écriture Firestore locale non confirmée pouvait provoquer une invalidation de session (désormais filtrée par `hasPendingWrites`) ; le formulaire mobile recréait son brouillon après erreur (désormais capturé une seule fois et repris explicitement). Les tests de session/navigation et le parcours widget de réponse perdue ont été rejoués, puis la suite complète finale a réussi : 1077 tests. Les limites de recette réelle restent applicables.

## Limites à garder visibles

- `fetchRows` lit toutes les pages, mais ne produit pas un snapshot multi-pages atomique. Les mises à jour concurrentes des montants pendant la lecture peuvent produire une vue temporairement mélangée ; ne pas réutiliser cette lecture client pour valider un paiement ou produire une clôture financière opposable. Le serveur recalcule justement les clôtures dans l'API commune.
- `fetchWaveSnapshot` exige wave_totals au lieu de présenter un historique tronqué comme solde exact. Il faut que la RPC réelle fournisse ces agrégats et que les clés soient testées sur le schéma de recette ; la vérification de simples réponses HTTP simulées ne prouve pas ce déploiement.
- Les clés inconnues et pages incohérentes échouent explicitement ; aucune erreur de permission ne devient une liste vide dans ce nouvel adaptateur.
- La lecture de l'ancienne commande depuis Firestore peut refuser une autorisation de crédit lorsque ce document est absent ou périmé. Aucun cas réel reproduit ici : risque de compatibilité à tester avec commande historique et commande issue du Client Web, pas un défaut démontré de mutation du registre canonique.
- Les mapper dates échouent pour les dates invalides et les réseaux inconnus ; les données historiques réelles doivent être vérifiées en recette. Le mapper ne doit pas inventer une date financière pour masquer une anomalie.

Cette revue n'a pas réexécuté les tests Flutter/build déjà centralisés par l'agent principal et ne conclut pas à la stabilité globale de la Finance. Les fondations serveur non versionnées et l'intégrité des écritures préexistantes restent traitées par le chantier Finance principal.
