# IzyTel — Refonte V1 : fondation + 5 écrans maîtres

Cette livraison migre le socle visuel et les cinq écrans maîtres validés :

1. Splash / Connexion
2. Accueil Admin
3. Commandes Admin
4. Détail d'une commande Admin
5. File Agent (avec le détail opérationnel Agent harmonisé)

Elle ajoute aussi :
- thème clair premium IzyTel ;
- typographie Manrope via `google_fonts` ;
- composants IzyTel réutilisables ;
- avatar utilisateur ouvrant un menu mobile ;
- navigation par pile persistante pour les onglets Admin et Agent ;
- correction structurée du bouton Retour Android ;
- nom Android visible `IzyTel` et démarrage natif clair pour éviter le flash noir.

## 0. Important

Cette livraison est volontairement la première tranche de la refonte. Les écrans Paiements, Finances, Plus, Remboursements, Commissions, Agents, Offres, etc. restent encore sur leur style historique jusqu'à la tranche suivante. C'est attendu : le but est d'abord de valider le nouveau socle sur téléphone avant de migrer tout le reste.

Aucune règle Firestore n'est modifiée.
Aucune logique 9E, remboursement ou commission n'est modifiée.

## 1. Installation

Après avoir remplacé les fichiers du patch, exécuter à la racine du projet :

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
```

Résultats attendus :

```text
No issues found!
All tests passed!
```

Si `flutter analyze` ou `flutter test` échoue, ne continuer pas le déploiement : conserver la sortie complète pour diagnostic.

## 2. Test Splash / Connexion

Relancer l'application complètement.

Attendu :
- écran clair dès le lancement ;
- aucune mention visible `CabineFlow` ;
- symbole IzyTel + `IzyTel` ;
- slogan `Simple. Rapide. Fiable.` ;
- écran de connexion clair et lisible ;
- clavier sans overflow ;
- affichage/masquage du mot de passe fonctionnel ;
- authentification identique à avant.

## 3. Test Accueil Admin

Se connecter avec un compte Admin.

Vérifier :
- fond clair ;
- `Bonjour <prénom>` + date ;
- avatar à droite ;
- encaissements du jour ;
- bloc `À faire maintenant` ;
- activité du jour ;
- logos Orange / MTN / Moov réels ;
- commandes prioritaires ;
- aucun `RIGHT OVERFLOWED` ou `BOTTOM OVERFLOWED`.

Appuyer sur l'avatar :
- le bottom sheet compte s'ouvre ;
- les actions sont lisibles ;
- `Se déconnecter` est présent ;
- fermer le sheet ne change rien à la session.

## 4. Test navigation / Retour Android Admin

### 4.1 Onglet racine
- Depuis Accueil, ouvrir Commandes.
- Appuyer sur Retour Android.
- Attendu : retour sur Accueil, pas fermeture de l'application.

### 4.2 Sous-écran
- Accueil -> Commandes -> ouvrir une commande.
- Appuyer sur Retour Android.
- Attendu : retour à la liste Commandes.
- Appuyer une nouvelle fois sur Retour Android.
- Attendu : retour Accueil.

### 4.3 Bouton retour visuel
- Ouvrir à nouveau un détail commande.
- Utiliser la flèche du header.
- Attendu : même résultat fonctionnel que Retour Android.

### 4.4 Sortie de l'application
- Se placer à la racine Accueil.
- Appuyer sur Retour Android.
- Attendu : Android peut quitter l'application uniquement à ce niveau.

## 5. Test Commandes Admin

Vérifier les onglets et filtres existants :
- À traiter ;
- En cours ;
- Terminées ;
- Tous / Orange / MTN / Moov ;
- tri existant ;
- actualisation.

Vérifier qu'une carte montre clairement :
- vrai logo réseau ;
- offre ;
- bénéficiaire ;
- montant ;
- statut ;
- référence secondaire.

Les actions métier doivent fonctionner exactement comme avant.

## 6. Test Détail commande Admin

Ouvrir une commande réelle.

Vérifier :
- résumé principal lisible ;
- réseau / offre / bénéficiaire / montant ;
- progression compacte ;
- sections repliables ;
- Client ;
- Paiement ;
- Détails de la commande ;
- Demandes client ;
- Traitement ;
- Journal d'activité ;
- WhatsApp utilise le vrai logo ;
- l'identifiant technique client n'est plus une information dominante ;
- actualisation fonctionnelle ;
- journal d'activité 11C inchangé fonctionnellement.

## 7. Test File Agent

Se connecter avec un Agent possédant plusieurs commandes.

Vérifier :
- header clair avec disponibilité réelle ;
- avatar ouvrant le menu ;
- onglets À accepter / En cours / Terminées ;
- priorité 1, 2, 3... toujours dans le bon ordre ;
- réseau + vrai logo ;
- offre, numéro, montant, statut ;
- aucune régression du tri prioritaire.

Tester :
- accepter une commande ;
- refuser une commande ;
- ouvrir une commande en cours ;
- utiliser Retour Android depuis le détail : retour à la file, sans quitter l'app.

## 8. Test traitement Agent

Sur une commande en cours :
- détail clair ;
- résumé principal ;
- timeline ;
- Appareil photo ;
- Galerie ;
- preuve enregistrée ;
- Mettre en attente ;
- Reprendre ;
- Signaler échec ;
- Marquer comme réussi.

Vérifier que les règles métier restent identiques :
- preuve obligatoire pour réussir ;
- capacité déduite une seule fois sur succès ;
- commission Phase 12 créée une seule fois sur succès ;
- aucune commission sur refus/échec.

## 9. Test avatar / déconnexion

### Admin
- avatar -> Se déconnecter ;
- Annuler : session conservée ;
- Confirmer : retour Connexion ;
- Retour Android : ne doit pas rouvrir l'Admin.

### Agent
- avatar ou Profil -> Se déconnecter ;
- même vérification.

## 10. Non-régression minimale

Faire un scénario complet :

```text
commande client
-> paiement déclaré
-> paiement confirmé
-> affectation automatique
-> acceptation Agent
-> traitement
-> preuve
-> réussite
```

Attendu simultanément :
- commande correcte ;
- auto-affectation 9E correcte ;
- capacité correcte ;
- audit correct ;
- commission +10 F ;
- aucune erreur Firestore nouvelle.

## 11. Firestore

Ne pas exécuter :

```powershell
firebase deploy --only firestore:rules
```

Les Rules ne changent pas dans cette livraison.
