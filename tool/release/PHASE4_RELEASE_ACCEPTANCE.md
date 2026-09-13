# IzyTel - Phase 4 Release - recette finale

Version cible : `1.0.0+1`  
Package Android : `com.izytel.app`  
Firebase Android App ID : `1:542869507309:android:6719f71b043fae652f10e4`

## 1. Signature officielle

1. Executer `powershell -ExecutionPolicy Bypass -File .\tool\release\setup_release_signing.ps1`.
2. Sauvegarder `android/app/izytel-release-key.jks` et ses mots de passe dans deux emplacements securises hors du depot.
3. Ne jamais envoyer le `.jks` ni `android/key.properties` dans un chat, depot Git ou stockage public.
4. Executer `powershell -ExecutionPolicy Bypass -File .\tool\release\register_firebase_sha.ps1`.

## 2. Build officiel

Executer :

`powershell -ExecutionPolicy Bypass -File .\tool\release\build_release.ps1`

Resultat attendu dans `dist/` :

- `IzyTel-1.0.0_1-release.apk`
- `IzyTel-1.0.0_1-release.aab`
- `IzyTel-1.0.0_1-release.sha256.txt`
- `IzyTel-1.0.0_1-apk-signature.txt`
- `IzyTel-1.0.0_1-aab-signature.txt`

## 3. Fresh install

Brancher le telephone Android puis executer :

`powershell -ExecutionPolicy Bypass -File .\tool\release\fresh_install.ps1`

La fresh install doit demarrer IzyTel sans `flutter run` et sans dependre du PC apres l'installation.

## 4. Recette fonctionnelle release

Sur l'APK release installe :

- [ ] Splash IzyTel correct.
- [ ] Connexion Agent reussie.
- [ ] Accueil et donnees Supabase/Firestore charges.
- [ ] Une commande peut etre acceptee/refusee selon son etat.
- [ ] Une commande acceptee peut passer en traitement.
- [ ] Une preuve peut etre prise/choisie puis enregistree.
- [ ] Une commande peut etre finalisee en succes ou en echec.
- [ ] Historique Agent consultable.
- [ ] Profil Agent consultable.
- [ ] Deconnexion fonctionnelle.

## 5. Persistance de session

1. Se connecter.
2. Fermer IzyTel depuis les apps recentes.
3. Pour simuler une vraie mort du processus, `adb shell am force-stop com.izytel.app` peut etre utilise ici.
4. Relancer IzyTel depuis son icone.
5. [ ] L'utilisateur authentifie revient dans l'espace Agent/Manager sans ressaisir son mot de passe.
6. Se deconnecter volontairement, fermer et rouvrir.
7. [ ] Apres deconnexion, IzyTel revient a l'ecran de connexion.

IMPORTANT : apres ce test, relancer IzyTel au moins une fois avant le test FCM suivant. Un package Android place dans l'etat `force-stopped` ne constitue pas un test valide de reception FCM application fermee.

## 6. FCM application fermee

1. Ouvrir IzyTel release, se connecter et autoriser les notifications.
2. Avec `watch_release_logs.ps1`, verifier qu'un message `[FCM][device-registered] platform=android` apparait.
3. Revenir a l'accueil Android puis retirer IzyTel des applications recentes (swipe). L'application doit etre fermee, mais **NE PAS utiliser `adb shell am force-stop`, le bouton Android "Forcer l'arret" ni les reglages qui placent l'application en etat force-stopped**.
4. Depuis le flux metier reel, affecter une nouvelle commande a cet Agent (ou declencher un evenement qui envoie deja une notification IzyTel).
5. [ ] La notification apparait alors que l'application n'est plus ouverte.
6. Appuyer sur la notification.
7. [ ] IzyTel demarre et restaure la session ; le payload est consomme par la navigation prevue.

## 7. Critere de cloture Phase 4

La Phase 4 peut etre figee uniquement lorsque :

- `flutter analyze` est vert ;
- `flutter test` est entierement vert ;
- APK et AAB release signes sont generes ;
- la fresh install est validee ;
- la persistance de session est validee ;
- FCM application fermee est valide ;
- les fonctions critiques Agent/Manager passent en build release.
