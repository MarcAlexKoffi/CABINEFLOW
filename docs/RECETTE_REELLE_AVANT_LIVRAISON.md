# IzyTel — recette réelle avant livraison

Date de préparation : 31 octobre 2026. Cette procédure décrit des tests à faire ; elle ne constitue pas une attestation de leur exécution.

## État connu et conditions de recette

La validation locale précédente rapporte 979 tests Flutter réussis, dont 84 nouveaux tests USSD, 69 scénarios SQL PGlite réussis, une analyse sans anomalie et trois builds réussis (Android debug, Web client, Web backoffice). Les fixtures SQL simulent les identités : elles ne valident ni la signature des JWT Firebase ni les autorisations réellement déployées. Les tests physiques Android, SIM/double SIM et restauration après destruction du processus restent à faire.

La migration `supabase/migrations/20261031005603_ussd_dynamic_shortcuts_v1.sql` est préparée, mais n'a pas été appliquée par l'agent. Au dernier contrôle en lecture seule, les tables USSD étaient absentes du serveur. Sans préparation d'une base de recette, vérifier le repli manuel ; ne pas attendre le fonctionnement des règles USSD sur ce serveur.

Utiliser un environnement Firebase/Supabase de recette et des comptes dédiés : Admin, Managers de deux zones, deux Agents et un Cabiniste. Préparer des commandes fictives attribuées, non attribuées et d'une autre zone, ainsi que les états payé/en attente/en cours/terminé. Vérifier le backend réellement ciblé avant chaque session : les configurations existantes peuvent viser la production. Ne pas déclencher de paiement réel ni modifier la production pour préparer ces tests. Ne pas rejouer toutes les anciennes migrations : réconcilier le schéma de recette avant d'y appliquer la migration revue et autorisée.

L'APK local est `build/app/outputs/flutter-apk/app-debug.apk`. Son installation peut remplacer une application portant le même identifiant : utiliser un téléphone de test. Les anciennes distributions du dossier `dist` ne prouvent pas la validation du code actuel.

## 1. Tests réalisables sans activation USSD

| ID | Action à réaliser | Résultat attendu |
| --- | --- | --- |
| AUTH-1 | Se connecter successivement avec chaque rôle, se déconnecter puis changer de compte. | Menus autorisés uniquement ; aucune donnée du compte précédent ; session révoquée refusée. |
| NAV-1 | Sur Android physique, parcourir accueil, commande, messages, notifications puis utiliser bouton et geste Retour, y compris rapidement et avec une fenêtre ouverte. | Retour cohérent, aucune page vide ni sortie inattendue ; formulaire/modal fermé au bon niveau. |
| NAV-2 | Mettre en arrière-plan, verrouiller, reprendre puis détruire le processus et relancer. | Session et navigation récupérées sans action métier dupliquée ; reprise compréhensible si l'écran n'est pas restauré. |
| WEB-1 | Sur Chrome et Edge, ouvrir Web client et backoffice ; essayer les largeurs 360, 768 et 1280 px, actualiser une page interne et utiliser Retour navigateur. | Pas de débordement bloquant ; navigation et accès conservés ou reconnexion explicite. |
| CAT-1 | Filtrer chaque réseau/service, ouvrir une offre, couper le réseau et réessayer après reconnexion. | Filtre exact, erreurs visibles avec reprise ; une panne ne devient pas une fausse liste vide. |
| CMD-1 | En recette, créer une commande client, retrouver son historique puis vérifier la déclaration et confirmation de paiement avec des données fictives. | Montants/offre/bénéficiaire cohérents ; statut modifié uniquement par le rôle autorisé ; pas de double commande. |
| MSG-1 | Envoyer une demande client, répondre en Manager, changer de zone et de rôle ; couper temporairement Realtime/réseau. | Échange client–Manager, jamais Agent–Client ; aucun accès hors périmètre ; reprise des messages sans doublon. |
| OPS-1 | Accepter une commande attribuée ; attendre/reprendre ; terminer avec preuve ; tester séparément un échec. | Attribution exclusive, capacité et commission comptées une fois ; échec soumis au Manager ; aucun succès client prématuré. |
| SUP-1 | Ouvrir le support et réessayer après une panne. | Erreur explicite puis reprise ; absence de données hors zone. Tout accès interzone observé bloque la livraison. |
| FCM-1 | Autoriser les notifications sur Android ; recevoir attribution/message au premier plan, en arrière-plan et application fermée ; toucher la notification puis se déconnecter. | Bonne commande ouverte, pas de doublon ni données d'un autre compte ; notification client de réussite après confirmation métier uniquement. |
| FALL-1 | Ouvrir la section USSD sans schéma disponible, puis hors ligne. | Indisponibilité explicite ; traitement manuel et actions métier toujours utilisables ; aucun faux succès. |

## 2. Tests USSD après préparation autorisée de la recette

Ne jamais présenter un code fictif comme un code opérateur validé. La prévisualisation peut utiliser des données synthétiques sans envoyer de requête télécom. Tout essai opérateur exige un code confirmé et une SIM de test, un responsable et un plafond de coût acceptés avant émission ; l'ouverture du composeur seule ne doit pas lancer l'appel.

| ID | Action à réaliser | Résultat attendu |
| --- | --- | --- |
| CFG-1 | Admin : créer une famille, associer une offre, créer une règle brouillon, prévisualiser puis consulter son historique. | Variables résolues correctement ; aucun composeur depuis la prévisualisation ; historique versionné. |
| CFG-2 | Essayer une activation sans attestation SIM, puis avec une attestation réellement obtenue ; modifier/désactiver la règle. | Activation non attestée refusée ; modification repassant en brouillon ; désactivation immédiatement respectée. |
| CFG-3 | Préparer règle exacte, famille et générique ; essayer priorités égales, dates expirées, offre supprimée et paramètres manquants. | Exacte avant famille avant générique ; conflit ambigu refusé ; règle invalide inutilisable ; réassociation explicite. |
| ACL-1 | Avec de vrais JWT Firebase, tester les RPC via PostgREST avec chaque rôle, compte désactivé et appel sans identité. | Refus des accès non autorisés, y compris hors interface ; aucune écriture directe des tables USSD possible. Ne jamais joindre les tokens au procès-verbal. |
| ACL-2 | Manager A puis B : consulter configuration/signalements de leurs zones ; Agent/Cabiniste : essayer commande d'autrui et modification de règle. | Manager en lecture de configuration uniquement, cloisonnement territorial ; exécution réservée au titulaire actif autorisé ; écriture de règle refusée. |
| NUM-1 | Tester numéros 01/05/07 aux formats local, +225, 00225 et 225, puis lettres, longueur incorrecte et caractères USSD injectés. | Normalisation déterministe des formats valides ; blocage des autres ; avertissement de portabilité sans changement silencieux de réseau. |
| DIAL-1 | Android physique : confirmer puis ouvrir le composeur, vérifier le # final, annuler et revenir. | Code intact, aucun appel automatique, aucun changement de paiement/statut/preuve après ouverture ou annulation. |
| DIAL-2 | Refaire avec une puis deux SIM et pour chaque opérateur pris en charge ; vérifier le choix effectif de SIM. | Bonne SIM sélectionnable et confirmation explicite ; aucune nouvelle permission d'appel direct requise. |
| FRESH-1 | Pendant la confirmation, désactiver/expirer/modifier la règle, réattribuer la commande ou désactiver le compte ; attendre aussi l'expiration du ticket. | Nouveau contrôle serveur ; refus du lancement périmé et repli manuel. |
| SAFE-1 | Double toucher, annuler, copier, couper le réseau, provoquer délai serveur/absence de composeur, reprendre après verrouillage. | Pas de double ouverture ; copie contrôlée à nouveau ; panne visible ; commande inchangée et traitement manuel possible. |
| AUD-1 | Agent puis Cabiniste : signaler un problème ; Manager de la bonne zone le traite ; Admin consulte l'historique. | Bonne version de règle référencée, historique conservé, refus autre zone ; pas de code complet, téléphone ou token dans les journaux. Ouverture du composeur distincte d'une réussite télécom. |
| REG-1 | Après retour du composeur, refaire réussite avec preuve, échec Manager, attente/reprise et contrôles capacité/commission/notifications. | Comportement métier identique à OPS-1 ; aucune validation métier automatique par le module USSD. |

SMS : conserver les règles en brouillon tant que le service métier nécessaire n'existe pas.

## Reproduire les contrôles locaux

Depuis la racine, avec le SDK Flutter installé :

```powershell
flutter pub get
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
npm install --prefix scratch/ussd_20261031/tools --no-save @electric-sql/pglite@0.5.13
node test/ussd_sql/run.mjs
flutter build apk --debug --no-pub
flutter build web --no-pub -t lib/main_customer_web.dart --output build/ussd/customer_web
flutter build web --no-pub -t lib/main_backoffice_web.dart --output build/ussd/backoffice_web
```

Ces commandes ne remplacent pas la recette terrain. Aucune commande de migration ni de déploiement n'est incluse.

## Procès-verbal et décision

Pour chaque ligne, noter : ID, date, commit testé, environnement, version Android/navigateur, appareil/SIM, rôle/zone fictifs, étapes, résultat attendu, résultat observé, PASS/FAIL/NON TESTÉ et preuve expurgée. Ne pas partager de numéro réel, token, secret ou preuve client.

Bloquer la livraison si un accès hors rôle/zone est possible, si un montant/statut change après simple ouverture du composeur, si une commande est traitée deux fois, si une règle périmée se lance ou si le traitement manuel est perdu. Une couverture automatisée réussie ne vaut pas validation de ces points sur serveur et téléphone réels.

Voir `docs/USSD_V1_INTEGRATION.txt` pour les chemins techniques, limites et précautions de modification.
