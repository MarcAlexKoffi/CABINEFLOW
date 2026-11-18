# Administration des comptes

Endpoint `POST izytel-user-admin`. Le client fournit son JWT Firebase ; le serveur vérifie révocation et profils Admin actifs Firebase/SQL. Firebase Admin et Supabase SDK sont épinglés dans `index.ts`. Firestore utilise le transport REST.

Secrets serveur existants : `FIREBASE_SERVICE_ACCOUNT_JSON`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`. Nouvelle configuration : `IZYTEL_ADMIN_ALLOWED_ORIGINS`, origines HTTPS autorisées séparées par virgule, sans wildcard. Aucun secret Flutter.

Les origines par défaut incluent les deux domaines du back-office dédié `izytel-backoffice-4bca7.web.app` et `izytel-backoffice-4bca7.firebaseapp.com`, les anciens domaines Firebase et localhost:8080. Une liste `IZYTEL_ADMIN_ALLOWED_ORIGINS` explicite remplace ces valeurs : inclure le domaine effectivement utilisé. Non-régression HTTP : `node --test supabase/functions/izytel-user-admin/cors.test.mjs` (Node 24), sans accès aux comptes réels.

Cette fonction reçoit un JWT Firebase vérifié dans son code : son réglage gateway existant est `verify_jwt: false`. La vérification Firebase avec révocation et les contrôles Admin actifs restent obligatoires. Tester les migrations dans un environnement isolé avant publication.

Tests locaux : `node --test supabase/functions/izytel-user-admin/core.test.mjs`. Ces tests exercent la saga avec dépendances simulées, pas Firebase réel ni Deno Edge. `node --check index.ts` vérifie la syntaxe, pas la compatibilité npm Deno.

Les opérations pending/failed bloquent volontairement les mutations suivantes. Une réparation exige un diagnostic serveur et un journal avant déblocage par opérateur habilité ; aucun bouton client ne masque un échec partiel. Les mots de passe ne sont pas transmis ; la réinitialisation génère un lien que l'Admin doit transmettre par un canal autorisé. Une répétition d'opération terminée ne reproduit pas le lien sensible.

La suppression exige la confirmation exacte de l’UID. Le serveur refuse l’auto-suppression, la suppression du dernier Admin actif, les commandes encore affectées et les zones actives d’un Manager. Il révoque les accès, supprime l’identité Firebase Auth et la fiche Firestore `users/{uid}`, puis archive le compte partenaire éventuel. Les identités métier SQL, commandes, soldes et historiques sont conservés ; le compte supprimé ne peut plus être réactivé. Les sous-collections Firestore historiques ne sont pas effacées.

## Correctif du 18 novembre 2026 — suppression des utilisateurs

Le message `REFERENCES_NOT_VERIFIED` était un refus systématique, même sans commande en cours. La migration `20261118050926_user_account_deletion_preserve_history.sql` le remplace par les contrôles métier ci-dessus et une opération serveur réservée à `service_role`. L’interface explique ce qui est conservé et actualise la liste après succès. Le contrôleur du champ de confirmation reste disponible jusqu’à la fin de l’animation du dialogue.

Validation ciblée : **49 tests serveur**, **8 scénarios SQL isolés** (`node test/user_deletion/run.mjs`), **25 tests Flutter** de l’administration et du dialogue de suppression ; analyse des fichiers Dart modifiés sans erreur. Aucun compte réel supprimé pour les tests. Sauvegarde de la fonction et des définitions SQL précédentes : `scratch/user_deletion_backup_20261118.json`. En cas d’échec partiel, conserver les accès refusés et diagnostiquer l’opération avant réparation ; ne pas réactiver automatiquement un compte dont l’identité Auth a déjà été supprimée.

Publié le 18 novembre 2026 : migration `20261118050926`, fonction Supabase v11 ACTIVE et backoffice Firebase Hosting version `a36d761fe6e805ce`. Les trois fichiers de la fonction distante correspondent aux sources locales. Vérifications HTTP : prévol autorisé 200, requêtes sans JWT ou avec JWT invalide 401. Les quatre fichiers de livraison du site correspondent au build (SHA-256), dont `main.dart.js` : `faf383aafb5f1feeb15d37e854b83fbba6530ea8fc65489deaae5ca1f378e8d4`. Une sonde SQL sur un identifiant synthétique a exécuté début, archivage et rejeu, puis annulé toutes ses écritures ; les empreintes des comptes et capacités, ainsi que les nombres d’opérations et d’audits existants, restent identiques. Preuves : `scratch/user_deletion_live_sql_proof.json`, `scratch/user_deletion_http_proof.json` et `scratch/user_deletion_hosting_results.json`. La suppression authentifiée de l’utilisateur montré dans la vidéo reste à effectuer par l’Admin.

## Correctif du 15 novembre 2026 — domaine du back-office

Le prévol HTTP du back-office dédié retournait `403 ORIGIN_DENIED`, ce qui produisait le message navigateur « service de gestion des utilisateurs inaccessible » avant l'envoi de la modification. Seules les deux origines exactes du back-office ont été ajoutées aux valeurs par défaut. Le code déployé a été comparé à la version distante précédente ; le cœur métier et les contrôles Firebase/Admin sont conservés.

Déployé sur Supabase IzyTel (`zrxeztxaxnzxevjuhzcc`), fonction `izytel-user-admin` v3 ACTIVE, avec le réglage gateway `verify_jwt: false` existant et vérification Firebase dans le code. Aucun compte réel modifié pendant les contrôles ; aucun nouveau build Flutter nécessaire.

Vérifié à 23:22 UTC : les deux domaines dédiés, l'ancien domaine Firebase et localhost retournent un prévol 200 avec l'origine exacte ; un domaine inconnu reste refusé en 403 et un POST sans authentification en 401. `node --test supabase/functions/izytel-user-admin/core.test.mjs supabase/functions/izytel-user-admin/cors.test.mjs` : **38 tests réussis**. L'enregistrement authentifié du compte reste à réessayer par l'Admin.

Preuves locales : `scratch/user_admin_cors_before.json`, `scratch/user_admin_cors_after.json`, `scratch/user_admin_cors_tests.log`. Sauvegarde de la fonction v2 : `scratch/user_admin_cors_before_function.json`, redéployable pour annuler ce seul correctif.
