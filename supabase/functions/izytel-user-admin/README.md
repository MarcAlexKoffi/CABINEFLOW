# Administration comptes — préparation locale

Endpoint `POST izytel-user-admin`. Le client fournit son JWT Firebase ; le serveur vérifie révocation et profils Admin actifs Firebase/SQL. Firebase Admin et Supabase SDK sont épinglés dans `index.ts`. Firestore utilise le transport REST.

Secrets serveur existants : `FIREBASE_SERVICE_ACCOUNT_JSON`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`. Nouvelle configuration : `IZYTEL_ADMIN_ALLOWED_ORIGINS`, origines HTTPS autorisées séparées par virgule, sans wildcard. Aucun secret Flutter.

Pour une future recette autorisée, désactiver la vérification JWT Supabase gateway de **cette fonction uniquement** (`--no-verify-jwt`) car elle reçoit un JWT Firebase vérifié dans son code. Ne pas désactiver la vérification applicative. Appliquer d'abord la migration locale dans un environnement isolé. Aucun déploiement exécuté pendant cette mission.

Tests locaux : `node --test supabase/functions/izytel-user-admin/core.test.mjs`. Ces tests exercent la saga avec dépendances simulées, pas Firebase réel ni Deno Edge. `node --check index.ts` vérifie la syntaxe, pas la compatibilité npm Deno.

Les opérations pending/failed bloquent volontairement les mutations suivantes. Une réparation exige un diagnostic serveur et un journal avant déblocage par opérateur habilité ; aucun bouton client ne masque un échec partiel. Les mots de passe ne sont pas transmis ; la réinitialisation génère un lien que l'Admin doit transmettre par un canal autorisé. Une répétition d'opération terminée ne reproduit pas le lien sensible.

La suppression définitive reste refusée (`REFERENCES_NOT_VERIFIED`) tant qu'un inventaire exhaustif des références historiques n'est pas implémenté et validé. Préférer la désactivation.
