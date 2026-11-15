# [Architecture] Harmoniser les points d’entrée et routes

## Objectif

Présenter les mêmes noms d’entrées que `IzyTel-main`, tout en conservant les
commandes de lancement et l’ordre de démarrage actuel de chaque surface.

## Modifications prévues

- Renommer les entrées principales en `main_staff.dart`, `main_customer.dart`
  et `main_backoffice.dart`.
- Conserver `main.dart`, `main_customer_web.dart` et `main_backoffice_web.dart`
  comme relais vers les nouvelles entrées.
- Regrouper les applications racines dans `app/` et les routes dans `app/routes`.
- Déplacer les options Firebase dans `app/config` et adapter `firebase.json`.
- Documenter les nouvelles commandes de lancement.

## Critères d’acceptation

- [ ] Le personnel initialise Firebase, FCM puis Supabase avant l’application mobile.
- [ ] Le client conserve la session Web locale sans attendre inutilement sa restauration.
- [ ] Le Back-office conserve sa restauration de session et son initialisation Supabase parallèles.
- [ ] Les nouvelles entrées compilent ; les trois anciennes délèguent vers les bonnes entrées.
- [ ] Le package `cabine_flow`, les identifiants d’applications et les options d’environnement sont conservés.

## Dépendances et livraison

Dépend d’ARCH-02, ARCH-03 et ARCH-04. Implémentation locale préparée.
Aucune publication Hosting ou mobile n’est incluse.
