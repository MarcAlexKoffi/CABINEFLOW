# IzyTel - Phase 1 / Bloc Notifications complet

Baseline utilisee : lib(4).zip + test(5).zip + pubspec(1).yaml.

## Ce bloc regroupe

- FCM deja valide sur Android.
- Enregistrement du token FCM dans Supabase par Firebase UID.
- Mise a jour automatique si le token FCM change.
- Desactivation du token lors d'une deconnexion volontaire.
- File serveur `izytel_notification_outbox` protegee par RLS.
- Notification Agent lors d'une nouvelle affectation.
- Notification Agent lors d'une reaffectation apres refus.
- Notification Manager/Admin lorsqu'une commande passe en `manual_required`.
- Notification Manager/Admin lors d'un nouveau signalement Agent.
- Notification Agent quand son signalement est resolu.
- Ouverture de la commande cible depuis une notification Agent/Manager.
- Ouverture du centre de signalements depuis une notification Manager.
- Affichage d'un feedback IzyTel quand un message arrive au premier plan.
- Suppression automatique des tokens FCM invalides par le dispatcher serveur.

## Ce qui a deja ete deployee cote Supabase

- Migration `izytel_notifications_block`.
- Extension Supabase `pg_net`.
- Tables `izytel_notification_devices` et `izytel_notification_outbox`.
- RPC d'enregistrement/desactivation des appareils.
- Triggers AFTER sur Phase 4 et `agent_issues`.
- Edge Function `izytel-notification-dispatch`.

Les triggers de notification capturent leurs propres erreurs : une panne FCM ne doit pas annuler une affectation, un refus ou un signalement.

## Une seule activation serveur reste manuelle

L'Edge Function a besoin d'un identifiant Google serveur pour envoyer via FCM HTTP v1.
Ne jamais mettre cette cle dans Flutter, Git, un ZIP de l'application ou un message ChatGPT.

Approche recommandee :
1. Google Cloud Console du projet Firebase `cabineflow-4bca7`.
2. Creer un compte de service dedie, par exemple `izytel-fcm-sender`.
3. Lui attribuer uniquement le role `Firebase Cloud Messaging API Admin` (`roles/firebasecloudmessaging.admin`).
4. Creer une cle JSON pour ce compte de service.
5. Supabase Dashboard > Edge Functions > Secrets.
6. Creer le secret `FIREBASE_SERVICE_ACCOUNT_JSON` et coller le contenu JSON complet comme valeur.
7. Supprimer le fichier JSON telecharge du poste apres enregistrement du secret ou le conserver uniquement dans un coffre-fort securise.

Cette operation n'active ni App Check, ni Cloud Functions Firebase et ne modifie aucune regle Firestore.

## Installation mobile

Copier `lib/`, `test/` et `pubspec.yaml` de ce ZIP dans le projet, puis :

```powershell
flutter pub get
flutter analyze
flutter test .\test\core\notifications\izytel_notification_payload_test.dart
flutter test .\test\regressions\m5_notifications_foundation_contract_test.dart
flutter test .\test\regressions\notifications_complete_block_contract_test.dart
```

Puis :

```powershell
flutter run
```

Apres connexion Agent ou Manager, la console doit contenir :

```text
[FCM][device-registered] uid=... platform=android
```

## Test fonctionnel groupe

1. Se connecter une fois avec chaque compte/appareil a notifier afin d'enregistrer les tokens.
2. Mettre l'application Agent en arriere-plan.
3. Creer/affecter une commande : l'Agent cible doit etre notifie.
4. Refuser avec l'Agent A : l'Agent B doit recevoir la reaffectation si eligible.
5. Epuiser les Agents eligibles : le Manager doit recevoir `Affectation manuelle requise`.
6. Toucher la notification : IzyTel doit ouvrir la commande cible.
7. Creer un signalement Agent : le Manager doit etre notifie et le tap doit ouvrir le centre de signalements.
8. Resoudre le signalement : l'Agent concerne doit etre notifie.

## Securite / retour arriere

- Aucun fichier `firestore.rules` dans ce bloc.
- Aucun secret FCM dans le code mobile.
- Aucun App Check.
- Aucune Cloud Function Firebase.
- L'Edge Function Supabase ne fait rien tant que `FIREBASE_SERVICE_ACCOUNT_JSON` n'est pas configure.
- Les donnees metier restent operationnelles meme si le dispatcher de notifications est indisponible.
