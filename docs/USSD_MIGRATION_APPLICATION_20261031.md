# Application directe de la migration USSD — 31 octobre 2026

Application expressément autorisée par l'utilisateur sur le projet Supabase IzyTel existant. Aucun projet ni branche Supabase créé, aucun changement d'abonnement.

## Traçabilité

- Fichier source : `supabase/migrations/20261031005603_ussd_dynamic_shortcuts_v1.sql`.
- SHA-256 du fichier : `70c8df374919db53f54fc30087e39ac3c9af572638c37646b32ae3045d6b86c3`.
- Outil : Supabase `apply_migration`, nom `ussd_dynamic_shortcuts_v1`.
- Résultat : succès.
- Version enregistrée par Supabase : **`20261031095414`**.

Attention : l'outil a attribué un horodatage différent du préfixe du fichier local. Cette différence ne signifie pas que la migration manque sur le serveur. Avant tout futur `db push`/rapprochement d'historique, réconcilier cette correspondance ; ne pas réappliquer le fichier, ne pas rejouer toutes les migrations et ne pas réparer l'historique à l'aveugle.

## Contrôles réalisés

- Relations, colonnes/types et cinq helpers d'authentification/territoire nécessaires présents avant application.
- Aucun objet USSD préexistant en conflit.
- Après application : neuf tables USSD présentes, toutes avec RLS activée.
- Aucun droit SELECT direct pour `anon`, aucun droit INSERT direct pour `authenticated` sur ces tables ; accès via les RPC contrôlées.
- Quinze RPC publiques présentes ; aucune de ces fonctions publiques n'est SECURITY DEFINER.
- Appel de configuration en rôle SQL `anon`, sans claims d'identité : refus attendu `USSD_AUTH_REQUIRED`, vérifié dans une transaction annulée. Ce contrôle ne remplace pas un essai PostgREST avec de vrais JWT Firebase.
- Zéro règle USSD créée et zéro règle active au contrôle après migration.
- Aucun ajout de code opérateur, aucune mutation métier de commande/paiement/capacité/preuve/commission exécutée par l'intervention.

## Conseiller de sécurité avant/après

Les avertissements préexistants restent au même nombre : extension publique (1), fonctions publiques SECURITY DEFINER exécutables par `anon` (57) et par `authenticated` (59). Ils n'ont pas été modifiés dans cette intervention.

L'information `rls_enabled_no_policy` passe de 9 à 18 : les neuf nouvelles tables USSD sont intentionnellement sans policy d'accès direct, avec privilèges clients révoqués. Leur accès passe par les fonctions privées contrôlées et les wrappers publics SECURITY INVOKER. Ne pas ajouter de policy permissive pour faire disparaître cette information.

Références :
- https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy
- https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable

## Vérification applicative restante

Actualiser le backoffice puis ouvrir Catalogue > Raccourcis USSD avec un compte Admin. Vérifier l'affichage de la configuration sans créer de règle active. Tester ensuite un Manager avec son identité réelle : consultation autorisée dans son périmètre et absence d'actions d'administration.

L'interface avec un véritable JWT Admin/Manager, les SIM et l'exécution opérateur n'ont pas été testées dans cette intervention. Les essais métier en production restent exclus de cette vérification.

Ce relevé actualise les mentions historiques « migration non appliquée » des documents de livraison locale `USSD_V1_INTEGRATION.txt` et `RECETTE_REELLE_AVANT_LIVRAISON.md`. Il ne change pas les résultats de tests antérieurs ni les réserves terrain qui y figurent.
