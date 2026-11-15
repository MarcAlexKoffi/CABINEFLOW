# USSD — correction de l'affichage après migration

## Diagnostic

Le cadre `_BackofficeContentFrame` place ses pages dans un `SingleChildScrollView`. `BackofficeUssdPage` retournait un `Column` contenant un `Expanded` : cette combinaison impose une flexion verticale dans une hauteur non bornée et empêche le rendu du contenu chargé.

Un second cas est distinct : les journaux de la Data API ont enregistré des appels de configuration depuis localhost:8080 sans identité Firebase, refusés avec `401 / 42501 / USSD_AUTH_REQUIRED`. D'autres appels avec identité ont réussi. Il ne faut pas retirer cette vérification d'identité.

## Changement local

- `lib/features/ussd/presentation/backoffice_ussd_page.dart` : contenu de hauteur naturelle, compatible avec le cadre défilant et avec un affichage autonome ; indication explicite quand la session manque.
- `lib/features/ussd/data/supabase_ussd_repository.dart` : classification de `USSD_AUTH_REQUIRED` et diagnostic neutralisé via `IzyTelLog`. Aucun contournement des droits ni réessai automatique d'écriture.
- `test/features/ussd/ussd_backoffice_widget_test.dart` : couverture Admin/Manager, configuration vide/remplie dans le cadre défilant, et récupération d'une session absente.
- `test/features/ussd/ussd_repository_http_test.dart` : assertion du véritable en-tête Bearer synthétique envoyé par le client HTTP et classification de l'erreur de session sans réessai.

## Vérification

- 90 tests USSD réussis.
- Analyse Flutter sans anomalie.
- Compilation Web du backoffice réussie : `build/ussd/backoffice_web` (aucun déploiement).
- En base : appel de configuration sous rôle SQL `anon` avec claims d'un Admin actif dans une transaction annulée : réponse de forme correcte, zéro règle, zéro famille et 34 offres. Ce diagnostic SQL ne valide pas une signature JWT ni la session du navigateur.
- Aucun changement supplémentaire de schéma ou de données métier effectué pendant cette correction.

Le serveur local existant utilise `flutter run -d web-server -t .\lib\main_backoffice_web.dart --web-port 8080`. Après chargement du nouveau code (redémarrage Flutter, puis rechargement navigateur), vérifier l'affichage. Si le message de session apparaît, se déconnecter puis se reconnecter avec le compte Firebase réel.

Le contrôle visuel du navigateur n'a pas pu être automatisé : les accès navigateur et ordinateur du connecteur étaient indisponibles. La vérification visuelle finale reste à faire après redémarrage. Aucun code opérateur n'a été activé et aucun déploiement d'hébergement n'a été réalisé.
