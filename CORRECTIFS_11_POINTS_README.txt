IzyTel - lot de correctifs UI / runtime / Agent - 31/08/2026

BASE UTILISEE
- lib, android, assets et test fournis dans la conversation le 31/08/2026.
- Le fichier firestore.rules repart de la baseline Phase 13 DEPLOY SAFE qui a permis les tests Finances.
- Aucune dependance Flutter supplementaire n'est requise.

CORRECTIFS
1. Remboursement : RefundCreationSheet passe au design clair IzyTel.
2. Feedbacks : les SnackBars bas sont remplaces par IzyTelFeedback, overlay compact en haut et IgnorePointer.
   Les boutons inferieurs et la navigation restent cliquables pendant les notifications.
3. Mise en attente Agent : correction des regles Firestore PUT_ON_HOLD pour supprimer la dependance getAfter circulaire
   et tolerer les anciennes commandes en cours sans takenByUserId explicite quand l'agent affecte est bien l'agent courant.
4. Progression : Admin et Agent deduisent les etapes precedentes des etats aval et considerent
   awaitingCustomerConfirmation comme traitement reussi/termine visuellement. Le detail Admin ecoute aussi la commande en temps reel.
5. Se souvenir de moi : persistance Android via SharedPreferences + MethodChannel, sans stockage du mot de passe.
   Si la case est activee, la session Firebase est restauree au prochain lancement et l'e-mail est pre-rempli.
6. Agents & zones : panneau jaune Signalements agents supprime. La 3e metrique devient Suspendus.
7. Suspension Agent : Suspendre/Reactiver enregistre maintenant immediatement le statut au lieu de ne modifier que l'etat local du formulaire.
8. Retour Android : retour interne d'abord, retour vers Accueil depuis un autre onglet, puis double appui en 2 s pour quitter.
   Une deconnexion manuelle efface aussi le choix Se souvenir de moi.
9. Echecs : le Dashboard Admin surveille les commandes echouees en temps reel, affiche une alerte non bloquante
   lors d'un nouvel echec et ajoute une ligne rouge "commande(s) echouee(s) a traiter" ouvrant le dernier echec.
10. Historique Agent : trois onglets En cours / Reussies / Echecs. Les echecs affichent motif + observation et leur detail complet.
11. Splash : nouvelle page de lancement premium bleue utilisant assets/images/New_splash_illustration.png.

FICHIERS FIRESTORE
Le correctif n'ajoute aucune nouvelle collection. Il modifie uniquement le contrat de securite PUT_ON_HOLD.
Il faut donc REPUBLIER firestore.rules avant de tester la mise en attente Agent.

INSTALLATION
1. Faire une sauvegarde du projet actuel.
2. Extraire IzyTel_CORRECTIFS_11_POINTS_PATCH.zip a la racine de cabine_flow et accepter les remplacements.
3. Formater et verifier :
   dart format lib test
   flutter analyze
   flutter test
4. Publier les regles :
   firebase deploy --only firestore:rules --project cabineflow-4bca7
5. Le correctif "Se souvenir de moi" modifie MainActivity.kt : faire un vrai rebuild Android (pas seulement hot reload) :
   flutter clean
   flutter pub get
   flutter run

TESTS RAPIDES APRES INSTALLATION
- Remboursement : ouvrir la creation de remboursement -> feuille claire.
- Notification : executer une action et cliquer immediatement un bouton bas -> le clic doit passer.
- Agent : commencer une commande puis Mise en attente -> pas de permission-denied, statut En attente.
- Progression : reussir une commande -> 4 etapes coherentes dans Admin et Agent.
- Remember me : cocher, connexion, fermer/reouvrir -> session restauree. Se deconnecter -> retour login au prochain lancement.
- Agents & zones : aucun panneau Signalements agents. Suspendre un agent -> statut change immediatement et il n'est plus eligible 9E.
- Retour Android : depuis un sous-ecran -> retour interne; depuis un autre onglet -> Accueil; depuis Accueil -> double appui pour quitter.
- Echec Agent : marquer une commande echouee -> alerte Admin + ligne rouge Dashboard.
- Historique Agent : l'echec apparait dans l'onglet Echecs avec motif/observation.
- Splash : verifier le nouvel asset et l'animation bleue au vrai redemarrage.

VERIFICATIONS EFFECTUEES DANS LE SANDBOX
- 0 reference ScaffoldMessenger restante dans lib (feedbacks bas supprimes).
- 0 import local package:cabine_flow manquant.
- Delimiteurs Dart verifies sur tous les fichiers lib.
- firestore.rules : accolades/parentheses/crochets equilibres, 154 fonctions, aucune fonction detectee comme morte,
  taille source ~176 Ko.
- Les anciens tests de contrat Firestore devenus obsoletes ont ete ajustes (helpers supprimes / nombre de getAfter non fige).

LIMITATION
Flutter, Dart et Firebase CLI ne sont pas installes dans ce sandbox. La compilation reelle reste donc a confirmer avec
flutter analyze, flutter test et le deploy Firebase sur la machine de developpement.
