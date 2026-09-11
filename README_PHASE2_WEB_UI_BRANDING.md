# IzyTel — Phase 2 Web UI/UX + Branding

Baseline reçue : `lib(5).zip` + `test(6).zip` + `web.zip`.

## Objectif

Finaliser la version Web client IzyTel sans modifier le parcours métier validé.

## Modifications

- Nouveau hero Web plus simple et plus original, construit en Flutter (pas d'image IA) avec aperçu téléphone IzyTel.
- Identité visuelle harmonisée avec le mobile : bleu IzyTel, Manrope, cartes, boutons, champs et hiérarchie typographique.
- Header IzyTel renforcé avec le vrai logo fourni dans les assets.
- Cartes interactives avec hover discret sur Web/desktop.
- Barre de navigation client responsive : mobile plein écran, desktop compacte et flottante.
- Parcours de commande mieux cadré sur desktop, sans changer les étapes ni la logique.
- Paiement et confirmation raccordés au branding IzyTel.
- Catalogue, historique, récupération et aide mieux dimensionnés sur desktop.
- Loader HTML IzyTel avant le premier frame Flutter pour éviter l'écran blanc au démarrage.
- Favicon, Apple touch icon et icônes PWA remplacés par le vrai logo IzyTel.
- Manifest PWA adapté au Web responsive (`orientation: any`).
- Métadonnées navigateur / partage mises à jour.

## Non modifié

- Firebase / Firestore.
- Supabase.
- FCM / notifications.
- Flux de paiement métier.
- Collections et règles de sécurité.
- Package Android.
- Accès Admin mobile.

## Validation locale

```powershell
flutter pub get
flutter analyze
flutter test .\test\regressions\phase2_web_branding_quality_contract_test.dart
flutter test .\test\regressions\phase2_branding_quality_contract_test.dart
flutter test .\test\regressions\navigation_stack_contract_test.dart
flutter test .\test\regressions\notifications_complete_block_contract_test.dart
flutter build web --release --target .\lib\main_customer_web.dart
```

Après le build, ouvrir `build/web` ou déployer d'abord sur le channel Firebase Hosting de préproduction pour vérifier : téléphone, tablette et ordinateur.
