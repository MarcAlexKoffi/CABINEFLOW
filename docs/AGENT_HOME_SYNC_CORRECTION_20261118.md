# Accueil Agent : commandes réelles et carte de priorité bleue

## Erreurs du projet

L’analyse initiale signalait 68 erreurs causées par des imports visant l’ancienne arborescence. Dix fichiers concernés utilisent maintenant les chemins `app/` existants. L’ancien chemin du moteur USSD réexporte la version maintenue au lieu de conserver une grammaire divergente. Le test historique transmet aussi le code secret prévu dans ses vecteurs de génération.

## Synchronisation

L’accueil suivait uniquement les commandes déjà affectées, tandis que l’onglet Commandes propose également les commandes de la file partagée. Son geste de rafraîchissement attendait 220 ms sans relire les données.

Le nouveau contrôleur d’accueil lit les deux sources du même dépôt opérationnel que l’onglet Commandes : `watchAssignedOrders` et `watchAvailableOrders`. Il compte la file partagée autorisée par le serveur et les affectations de l’Agent, déduplique les identifiants pendant les transitions et écarte les commandes affectées à un autre Agent. Les états personnels correspondent à ceux de l’onglet Commandes. Aucune commande n’est affectée ou acceptée depuis l’accueil.

Le rafraîchissement et le retour au premier plan relisent réellement les deux sources. Une mise à jour du flux reçue pendant un rafraîchissement prime sur sa réponse plus ancienne. Les abonnements restent stables pendant les reconstructions de l’écran et sont libérés à sa fermeture ou au changement d’utilisateur.

Un chargement ou une erreur initiale n’affiche plus un faux état « Aucune commande urgente ». En cas de panne transitoire, les derniers compteurs restent accompagnés d’un message et d’une reprise. Un refus d’accès masque les données personnelles précédentes.

## Présentation

La carte conserve un traitement bleu dans les états actif et vide : dégradé bleu nuit/bleu IzyTel, motif circulaire discret, titre blanc, statut de lecture et bouton blanc. L’en-tête se replie sur un petit écran avec texte agrandi. Les chargements et erreurs possèdent un contenu explicite. Le compteur indique « À prendre » lorsque la file partagée est active.

## Vérifications

- Analyse complète du projet : aucune anomalie, contre 68 erreurs initiales.
- 153 tests réussis : 151 tests ciblant l’accueil, les chemins réparés et les commandes ; 2 captures de rendu Flutter avec des commandes fictives.
- Les scénarios couvrent les nouvelles commandes partagées, l’acceptation et la clôture, les doublons, le périmètre Agent, le rafraîchissement, les réponses concurrentes, les pannes et le retour au premier plan.
- Mise en page vérifiée à 320 px avec texte normal et agrandi à 160 % ; captures à 390 px avec la police Manrope et les valeurs du thème de production, en utilisant une police fournie localement pour la recette.
- Contraste texte secondaire / bleu le plus clair : environ 4,68:1 ; cette vérification ne constitue pas un audit global d’accessibilité.
- Aucune migration, écriture de commande ni modification de données réelles n’est nécessaire pour cette correction.
- APK `1.0.6` build `7` générée dans `dist/android/1.0.6-build7/`, paquet `com.izytel.app`. Signature vérifiée et identique à celle de la version précédente ; empreinte SHA-256 et métadonnées livrées à côté de l’APK.

Preuves locales exclues de Git : `scratch/agent_home_project_analyze_before.log`, `scratch/agent_home_project_analyze_final.log`, `scratch/agent_home_verified_tests.log`, `scratch/agent_home_blue_0.png` et `scratch/agent_home_blue_3.png`.

## Recette réelle

Installer l’APK mise à jour sans désinstaller l’application. Avec un Agent autorisé, comparer l’accueil avec les onglets « À prendre » et « Mes commandes ». Créer normalement une commande payée dans sa zone, puis vérifier son arrivée sur les deux écrans. Accepter et traiter cette commande : les compteurs de l’accueil doivent suivre son état. Tester aussi le geste de rafraîchissement, le retour depuis l’arrière-plan et une coupure/reprise réseau. Les données des captures sont fictives ; ce parcours authentifié sur le téléphone reste à effectuer.
