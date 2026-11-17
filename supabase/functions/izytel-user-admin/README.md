# Administration comptes — préparation locale

Endpoint `POST izytel-user-admin`. Le client fournit son JWT Firebase ; le serveur vérifie révocation et profils Admin actifs Firebase/SQL. Firebase Admin et Supabase SDK sont épinglés dans `index.ts`. Firestore utilise le transport REST.

Secrets serveur existants : `FIREBASE_SERVICE_ACCOUNT_JSON`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`. Nouvelle configuration : `IZYTEL_ADMIN_ALLOWED_ORIGINS`, origines HTTPS autorisées séparées par virgule, sans wildcard. Aucun secret Flutter.

Les origines par défaut incluent les deux domaines du back-office dédié `izytel-backoffice-4bca7.web.app` et `izytel-backoffice-4bca7.firebaseapp.com`, les anciens domaines Firebase et localhost:8080. Une liste `IZYTEL_ADMIN_ALLOWED_ORIGINS` explicite remplace ces valeurs : inclure le domaine effectivement utilisé. Non-régression HTTP : `node --test supabase/functions/izytel-user-admin/cors.test.mjs` (Node 24), sans accès aux comptes réels.

Pour une future recette autorisée, désactiver la vérification JWT Supabase gateway de **cette fonction uniquement** (`--no-verify-jwt`) car elle reçoit un JWT Firebase vérifié dans son code. Ne pas désactiver la vérification applicative. Appliquer d'abord la migration locale dans un environnement isolé. Aucun déploiement exécuté pendant cette mission.

Tests locaux : `node --test supabase/functions/izytel-user-admin/core.test.mjs`. Ces tests exercent la saga avec dépendances simulées, pas Firebase réel ni Deno Edge. `node --check index.ts` vérifie la syntaxe, pas la compatibilité npm Deno.

Les opérations pending/failed bloquent volontairement les mutations suivantes. Une réparation exige un diagnostic serveur et un journal avant déblocage par opérateur habilité ; aucun bouton client ne masque un échec partiel. Les mots de passe ne sont pas transmis ; la réinitialisation génère un lien que l'Admin doit transmettre par un canal autorisé. Une répétition d'opération terminée ne reproduit pas le lien sensible.

La suppression définitive reste refusée (`REFERENCES_NOT_VERIFIED`) tant qu'un inventaire exhaustif des références historiques n'est pas implémenté et validé. Préférer la désactivation.

## Correctif du 15 novembre 2026 — domaine du back-office

Le prévol HTTP du back-office dédié retournait `403 ORIGIN_DENIED`, ce qui produisait le message navigateur « service de gestion des utilisateurs inaccessible » avant l'envoi de la modification. Seules les deux origines exactes du back-office ont été ajoutées aux valeurs par défaut. Le code déployé a été comparé à la version distante précédente ; le cœur métier et les contrôles Firebase/Admin sont conservés.

Déployé sur Supabase IzyTel (`zrxeztxaxnzxevjuhzcc`), fonction `izytel-user-admin` v3 ACTIVE, avec le réglage gateway `verify_jwt: false` existant et vérification Firebase dans le code. Aucun compte réel modifié pendant les contrôles ; aucun nouveau build Flutter nécessaire.

Vérifié à 23:22 UTC : les deux domaines dédiés, l'ancien domaine Firebase et localhost retournent un prévol 200 avec l'origine exacte ; un domaine inconnu reste refusé en 403 et un POST sans authentification en 401. `node --test supabase/functions/izytel-user-admin/core.test.mjs supabase/functions/izytel-user-admin/cors.test.mjs` : **38 tests réussis**. L'enregistrement authentifié du compte reste à réessayer par l'Admin.

Preuves locales : `scratch/user_admin_cors_before.json`, `scratch/user_admin_cors_after.json`, `scratch/user_admin_cors_tests.log`. Sauvegarde de la fonction v2 : `scratch/user_admin_cors_before_function.json`, redéployable pour annuler ce seul correctif.
