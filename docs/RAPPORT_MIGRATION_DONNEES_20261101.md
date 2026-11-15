# IzyTel — migration de données — 1 novembre 2026

Migration exécutée après le bilan Administration, Finance et Notifications, sur demande explicite du propriétaire du projet.

## Contrôles préalables

- Projet Supabase vérifié : `IzyTel` (`zrxeztxaxnzxevjuhzcc`), état `ACTIVE_HEALTHY`.
- Les reprises historiques déjà enregistrées étaient terminées : `firestore_bo5` (Finance, 23 éléments), `firestore_zones_v1` (Territoire, 2 éléments) et `firestore_offers_v1` (Catalogue, 34 éléments).
- Les registres SQL contenaient déjà un Administrateur et deux Managers canoniques actifs.
- Aucun conflit de population active n'a été détecté pour les comptes staff examinés.
- Les quatre nouvelles migrations SQL du chantier Administration/Finance/Notifications ne figuraient pas dans l'historique distant. Elles n'ont pas été appliquées dans cette opération de données, car leur mise en service doit être coordonnée avec l'application, les fonctions Edge et les règles Firestore.

## Écriture exécutée

Deux profils Firestore `users` portaient encore l'alias historique `supervisor` alors que leurs registres SQL étaient déjà `manager`, actifs et cohérents. Seul le champ `role` de ces deux documents a été remplacé par la valeur canonique `manager`. Les autres champs ont été conservés.

## Vérification après migration

Résultat de la recherche Firestore :

- `manager` : 2 profils ;
- `supervisor` : 0 ;
- `administrator` : 0 ;
- `operator` : 0 ;
- `partner` : 0.

Les deux comptes restent des Managers actifs dans `public.izytel_staff_access`. Aucune donnée financière, commande, message, identité Firebase Auth ou autre profil n'a été modifié.

## Périmètre restant

Cette opération normalise uniquement les données dont la correspondance était certaine. Elle ne tente pas de rapprocher automatiquement les historiques financiers Firestore/Supabase, de convertir un éventuel rôle `operator`, de rattacher un compte Auth orphelin ni de marquer les comptes historiques comme `adminManaged` sans passage par la saga d'administration.
