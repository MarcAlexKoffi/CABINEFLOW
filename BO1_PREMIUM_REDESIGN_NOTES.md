# IzyTel — BO-1 Premium Redesign

Ce patch remplace uniquement la couche visuelle du back-office BO-1 et ajoute un design system Web dédié.

## Changements

- nouveau `BackofficeTheme` dédié au Web staff ;
- page de connexion premium responsive desktop / tablette / mobile ;
- sidebar sombre premium avec navigation par rôle ;
- topbar et cadre de contenu harmonisés ;
- dashboard BO-1 entièrement retravaillé ;
- page Utilisateurs retravaillée : métriques, filtres, registre, cartes mobiles et détail ;
- écran de chargement du back-office aligné sur cette identité ;
- test widget rendu plus robuste avec `ensureVisible` ;
- contrat de non-régression du design premium ajouté.

## Non modifié

- logique Firebase Auth ;
- règles de rôles Admin / Manager ;
- repository Utilisateurs ;
- Firebase / Supabase ;
- Admin mobile existant ;
- Web client ;
- logique métier des modules déjà validés.

## Vérification locale

```powershell
flutter analyze
flutter test .\test\backoffice_bo1_widget_test.dart
flutter test .\test\regressions\backoffice_bo1_foundation_contract_test.dart
flutter test .\test\regressions\backoffice_bo1_premium_design_contract_test.dart
flutter run -d chrome -t .\lib\main_backoffice_web.dart
```

Le conteneur de génération ne dispose pas du SDK Flutter/Dart : les contrôles effectués ici sont des contrôles source (délimiteurs, contrats et présence des invariants). La validation finale `flutter analyze` et `flutter test` doit donc être faite sur le poste Flutter du projet.
