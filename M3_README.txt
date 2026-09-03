IZYTEL - M3 MATRICE DE PERMISSIONS MANAGER
Date : 2026-09-03

IMPORTANT FIRESTORE
- Ce patch ne contient AUCUN fichier firestore.rules.
- Ne lance pas `firebase deploy --only firestore:rules` pour M3.
- Le rôle Manager est présenté dans Flutter, mais la valeur Firestore de compatibilité reste `supervisor` tant que les rules publiées sont gelées.
- Supabase utilise `manager` dans izytel_staff_access.

Si tu avais déjà extrait l'ancien patch M2 :
- M3 remet `firestore_orders_repository.dart` sur la logique compatible avec les rôles Firestore déjà publiés.
- M3 remplace aussi le test M2 qui exigeait à tort l'ajout de `manager` dans les rules.
- M3 ne remplace pas ton fichier local firestore.rules. S'il avait été modifié par M2, conserve/restaure ta baseline stable avant tout futur déploiement Firebase.

Périmètre M3
- UserRole.manager + alias supervisor -> Manager dans Flutter.
- Matrice centralisée UserPermissions.
- Manager peut affecter les commandes via le flux hybride/Supabase existant.
- Manager peut traiter les signalements Agents via Supabase.
- Les fonctions Admin sensibles restent fermées au Manager.
- Le module Finances actuel reste protégé derrière un écran d'attente Manager pour éviter les lectures/écritures Firestore Admin-only.
- Le Dashboard Manager n'ouvre pas de listener refunds Firestore.

Tests conseillés :
flutter analyze
flutter test .\test\features\auth\domain\models\app_user_manager_role_test.dart
flutter test .\test\regressions\manager_role_foundation_contract_test.dart
flutter test .\test\regressions\manager_permissions_contract_test.dart
flutter test
