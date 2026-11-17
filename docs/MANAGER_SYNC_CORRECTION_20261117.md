# Correctifs agents, paiements, fournisseurs et assistance — 17 novembre 2026

## Changements

- Détail agent : isoler l’erreur connue `ECONOMIC_PLAN_NOT_FOUND` de l’historique optionnel pour conserver le profil et les soldes enregistrés. Actualiser la fiche ouverte par signaux Supabase et lecture de secours toutes les 20 secondes.
- Historique serveur : lire les gains enregistrés sans recalculer les anciennes commandes avec un plan économique courant. Un gain absent reste inconnu ; aucun plan ni solde n’est créé.
- Paiement : en mode hybride, confirmer la commande et son audit sans écrire dans l’ancienne `autoAssignmentQueue`, refusée par les règles déployées. La publication vers Supabase reste inchangée. Accepter le rôle Manager dans la vérification du compte staff.
- Fournisseurs : lecture REST indépendante du canal Realtime, conservation de la dernière liste pendant une erreur transitoire, message explicite et nouvelle tentative sans déconnexion. Une erreur d’autorisation masque la liste ; une réponse vide valide la vide normalement.
- Assistance : rétablir la prise en charge, la résolution, la notification enregistrée et la clôture pour le Manager de la zone de la commande. Les remboursements conservent leurs autorisations existantes.

## Validation

- 19 tests Flutter ciblés réussis : paiement hybride, préservation de sa publication, fiche sans plan, actualisation d’un profil et reprise fournisseurs.
- 13 contrôles SQL réussis dans PostgreSQL embarqué : historique sans plan, gains enregistrés, refus hors zone ou pour un compte invalide, parcours d’assistance et transitions interdites.
- Analyse des sept fichiers de code et de tests concernés : aucune anomalie.
- Compilation web réussie dans `build/manager_sync_backoffice`.

## Livraison

La migration `supabase/migrations/20261117203038_team_activity_and_manager_support_repair.sql` a été appliquée au projet IzyTel (`zrxeztxaxnzxevjuhzcc`), avec confirmation de succès de l’outil. Les lectures de vérification après application et la récupération des nouveaux avis ont échoué sur le transport du connecteur ; aucun parcours de production n’est présenté comme validé.

Le backoffice a été publié sur https://izytel-backoffice-4bca7.web.app, version Hosting `a4cbcb25a8c5c0e7`. Le marqueur `manager-sync-20261117` et l’empreinte SHA-256 du JavaScript servi ont été vérifiés le 17 novembre à 22:01 UTC : `5d9b7bdd69796a6d677809563c66849e55d25049952e88ea00321ff9c092fdb3`.

L’APK Android actualisé 1.0.4 (build 5) a ensuite été généré dans `dist/android/1.0.4-build5`, avec vérification de la signature et du certificat identique à celui de la version précédente. Cette dernière génération est locale ; son installation sur les téléphones reste à effectuer. Les APK et fichiers de signature restent exclus du dépôt Git. Aucun paiement ni dossier client réel n’a été traité pendant les tests.

Le script `supabase/operations/rollback_20261117_manager_session_repair.sql` restaure les définitions des fonctions sauvegardées avant la migration. Il ne modifie aucune donnée métier.
