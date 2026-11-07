# IzyTel — livraison de la file partagée et du suivi à cinq minutes

**Mise à jour :** l'utilisateur a ensuite autorisé et obtenu l'application de la migration, file désactivée, et le dispatch en version 4. Les écrans Agent/Manager ont été harmonisés sur son retour. Voir [CORRECTIF_20261106.md](CORRECTIF_20261106.md) et [le reçu serveur](DEPLOYMENT_RECEIPT_20261106.json). Le présent rapport conserve les preuves et le protocole de la livraison initiale ; son état distant « non installé » est historique. L'activation globale et la recette FCM réelle restent distinctes.

6 novembre 2026. Candidate locale sur `feat/shared-agent-queue-sla`, base `588ca83`. R1 validée par l'utilisateur. Développement, corrections, QA visuelle locale, audit technique local et builds terminés. **La mise en service distante et la réception FCM réelle restent à autoriser et à vérifier. Le statut global n'est pas DONE.**

Le [registre ORION v3](WORKFLOW_STATE.md) remplace les statuts de reprise. Le [rapport de reprise](REPRISE_AUDIT_20261106.md) reste la photographie historique avant corrections ; ses échecs et limites initiales ne décrivent pas cette candidate.

## Résultat produit et plan ORION

| Lot | Livré localement | Critère vérifié |
|---|---|---|
| AFF-1 — AFF-01/02/06 | Publication territoriale des nouvelles commandes Agent après paiement confirmé, projection minimale, acceptation SQL atomique/idempotente, version de cycle | Un seul gagnant entre deux connexions ; verrou de capacité ; refus hors zone et Agent désactivé ; aucune écriture financière lors du claim |
| AFF-2 — AFF-03/04/05 | À prendre / Mes commandes, actualisation territoriale et polling de secours, reprise, succès/conflit, accès direct au détail | Détail ouvert sans démarrage ni finalisation ; réponse perdue reconsultée ; retour et notification vers la bonne rubrique ; paiement confirmé conservé si publication différée |
| SLA-1 — SLA-01 à SLA-05 | Heure serveur, retard au-delà de cinq minutes, alertes persistantes et versionnées, suivi Manager, cycle de réaffectation | En cours reste surveillé ; finalisation et échec précoce n'émettent pas d'alerte tardive ; ancien cycle obsolète ; deux détecteurs ne doublonnent pas |
| NOTIF-1 — NOTIF-01 à NOTIF-03 | `order_available`, `order_acceptance_delay`, outbox/retry existants, navigation protégée, vérification du destinataire à l'envoi | Événement unique, pas de renvoi sur refetch, Manager effectif de la zone ; retry multi-appareils sans renvoyer aux appareils déjà servis ; destinataire devenu non autorisé ignoré |
| QA-1 | Contrat R1 conservé, captures des widgets réels, contrôles 320/390/768/1440 px et texte à 200 % | Pas de débordement dans les tests ; bénéficiaire masqué avant acceptation, numéro complet ensuite ; tableaux et actions accessibles |
| SEC-1 | Audit et contre-vérification, schéma local issu du catalogue, tests financiers et Cabiniste, Android réel, builds | Résultats et limites ci-dessous ; déploiement et recette opérationnelle séparés |

Le round-robin demeure pour le circuit historique et les parcours non concernés. La migration n'effectue pas de réattribution générale. Les interventions Manager conservent leur parcours existant ; les anciens synchroniseurs ne peuvent plus reprendre une commande partagée. Le détail Agent conserve ses actions explicites, sa preuve et la finalisation métier existante. Aucun raccourci USSD n'est exécuté à l'ouverture.

## Corrections SENTINEL et contre-vérifications

| Constat | Correction | Preuve |
|---|---|---|
| REC-01 : test visuel invalide | Accolade réparée ; capture opt-in exécutable avec les vraies polices | Analyse sans anomalie et capture exécutée |
| REC-02/03 : fixture sans privilège et policy permissive supplémentaire | Grant/RLS de partner_accounts rétablis ; policy nommée comme en production pour être remplacée ; fixture intégrée avec les droits et hooks concernés | 13 contrôles SQL et 12 scénarios intégrés |
| REC-04/05 : suivi obsolète et dépendances dans scratch | Registre v3, paquet de tests et verrou de dépendances versionnés | [Commandes reproductibles](../../test/shared_queue/README.md) |
| Anciennes réconciliations pouvaient annuler une acceptation ou fermer une commande partagée | Garde de la ligne canonique dans `phase4_reconcile_acceptance`, `phase4_import_legacy_refusals`, `phase4_close_order` ; logique historique conservée | Appels des vrais RPC avant/après claim ; aucune reprise ni fermeture de la commande partagée |
| Rejeu de `phase3_sync_order` pouvait écraser montant et bénéficiaire | Verrou/relecture canonique, contrôle territorial, conflit d'insertion protégé ; une commande partagée existante est retournée sans écrasement | Rejeu simple puis deux transactions réellement concurrentes : le second upsert attend ; montant 1 000 conservé malgré une requête à 9 000 |
| Absence de relecture de l'heure de paiement pouvait publier sous une mauvaise frontière d'activation | Publication différée tant que l'horodatage confirmé du serveur n'est pas relu ; paiement et miroir Finance confirmés conservés | Deux tests comportementaux du repository |
| Notification de disponibilité pouvait lancer un chargement personnel caché | L'événement de file commune est traité par sa rubrique ; pas d'ouverture de détail personnel | Test de widget reproduisant le blocage avant correction puis réussi |
| Changement de zone/rôle entre enqueue et dispatch | RPC d'autorisation au moment de chaque tentative, réservée au service ; alerte/version/commande relues | Droits SQL et simulation du dispatch : destinataire obsolète ignoré, erreur d'autorisation mise en retry sans envoi |
| Type WebCrypto refusé par Deno récent | Import de clé RSA avec un ArrayBuffer concret | Contrôle TypeScript strict réussi et signature simulée exécutée |
| Débordements avec texte agrandi et numéro tronqué dans le détail | Hauteurs minimales flexibles, retour à la ligne, largeur de tableau et actions ajustées | Tests à 200 % et captures finales |

Les remplacements des RPC préservent leurs autorisations et le comportement `legacy`. Ils ne modifient pas les fonctions de calcul des commissions, de règlement, de débit ou de remboursement.

## Preuves de validation

| Contrôle final | Résultat | Trace |
|---|---|---|
| Analyse Flutter | Aucune anomalie | `scratch/shared_queue_final_analyze.log` |
| Suite Flutter complète | **1 113 réussites**, 1 test de capture opt-in ignoré | `scratch/shared_queue_final_tests.log` |
| UI ciblée et capture activée | **11 réussites**, dont 10 tests UI et la capture ; ces 10 tests sont déjà inclus dans les 1 113 | `scratch/shared_queue_final_visual_checks.log` |
| SQL : concurrence, capacité, historique, SLA, droits | **13 contrôles réussis** | [SQL_TEST_RESULTS.json](SQL_TEST_RESULTS.json), date et empreinte de migration |
| Intégration : vrais RPC et hooks sélectionnés | **12 scénarios réussis** | [INTEGRATION_TEST_RESULTS.json](INTEGRATION_TEST_RESULTS.json), date et empreinte |
| Dispatch exécuté avec HTTP/FCM simulés | Réussi : payload, priorité, invalidation token, retry partiel, bail, recontrôle territorial | `scratch/shared_queue_dispatch_test.log` |
| Contrôle TypeScript Deno 2.9.6 | Réussi, code de sortie 0 | `scratch/shared_queue_edge_check.log` |
| Android physique Samsung SM_A566B | **2 scénarios réussis** dans l'application QA séparée | `scratch/shared_queue_android_test.log` |
| Web application et Back-office | Deux builds réussis | `scratch/shared_queue_mobile_web_build.log`, `scratch/shared_queue_backoffice_web_build.log` |
| Android release | APK signé construit, environ 71 Mo | `scratch/shared_queue_android_release_build.log` |
| Diff Git | `git diff --check` réussi ; avertissements de conversion CRLF uniquement | Branche locale conservée, aucun commit ni merge |

PowerShell 5 affiche certains messages stderr des outils natifs comme `NativeCommandError`, notamment le message informatif Wasm, le `Check` de Deno et l'avertissement expérimental Node. Les commandes citées ont terminé avec un code de sortie nul ; aucun échec de compilation ou de typage n'est dissimulé par ce libellé.

La fixture intégrée utilise les définitions de **28 tables, 422 colonnes et 45 fonctions** obtenues par lectures du catalogue uniquement. Elle reprend les contraintes hors clés étrangères, les droits, les policies et les hooks métier utiles. Les écritures sont toutes synthétiques dans un PostgreSQL local temporaire. Les clés étrangères vers des comptes hors périmètre et leurs hooks d'audit ne sont pas reproduits ; HTTP/FCM et le stockage de messagerie client sont remplacés par des puits locaux.

La finalisation Agent a exécuté le vrai parcours : preuve obligatoire, un débit de capacité, une commission fixe de 10, écritures économiques/ledger, message de fin client et retry idempotent. Le parcours Cabiniste a exécuté preuve, finalisation, débit et règlement idempotent sur son circuit historique. Cela ne remplace pas une recette intégrale de tous les produits financiers en production.

Sur 1 000 commandes synthétiques, une page masquée bornée à 100 lignes a été lue en **56/58/53 ms**. Ce résultat local ne mesure ni la concurrence de production ni la latence réseau distante.

## QA AURA

Les sources R1 et leurs empreintes restent figées dans [DESIGN_CONTRACT.md](DESIGN_CONTRACT.md). Les captures ci-dessous sont produites par les widgets de l'application, sans barres de débogage, avec Manrope et des données synthétiques.

- [Agent 320 px](visual_qa/agent-320.png) et [390 px](visual_qa/agent-390.png) : hiérarchie, rubriques, informations masquées et action principale.
- [Hors connexion](visual_qa/agent-offline-390.png), [file vide](visual_qa/agent-empty-390.png), [acceptation et détail](visual_qa/agent-accepted-390.png).
- [Manager 320 px](visual_qa/manager-320.png), [390 px](visual_qa/manager-390.png), [768 px](visual_qa/manager-768.png), [1440 px](visual_qa/manager-1440.png).
- [Alertes mobiles](visual_qa/manager-alerts-390.png) et [alertes grand écran](visual_qa/manager-alerts-1440.png).

La comparaison a porté sur le contrat et les sources R1 : palette, police, hiérarchie, cartes, états, rubriques, transitions et actions. Les éléments de simulation de la maquette ne sont pas intégrés au produit. Le détail opérationnel existant a été conservé avec ses actions ; les ajustements de hauteur et de retour à la ligne permettent le texte agrandi.

Limite : le contrôle du prototype dans un navigateur a été interrompu par Computer Use faute d'identification fiable de l'URL. Aucun comparatif navigateur pixel par pixel n'est revendiqué. Les captures de widgets ne couvrent pas les barres système et l'ensemble du shell connecté. La navigation native a été exercée par le harness Android ; les derniers ajustements de largeur/texte du détail sont contre-vérifiés par les tests et captures de widgets.

## Fichiers et livrables

- Données et navigation : `hybrid_orders_repository.dart`, `supabase_phase4_assignment_repository.dart`, `supabase_shared_order_queue_repository.dart`, interface `shared_order_queue_repository.dart`, `main_shell_page.dart`, `orders_page.dart`, `agent_orders_view_model.dart`, `shared_order_queue_view_model.dart`.
- Présentation : `shared_agent_orders_page.dart`, `agent_orders_page.dart`, `agent_order_detail_view.dart`, `order_supervision_page.dart`, `backoffice_orders_page.dart`.
- Serveur : [migration préparée](../../supabase/migrations/20261106004036_shared_agent_queue_and_sla.sql), [dispatch Edge](../../supabase/functions/izytel-notification-dispatch/index.ts), [activation](../../supabase/operations/shared_queue_activate.sql), [retour arrière](../../supabase/operations/shared_queue_rollback.sql).
- Tests : nouveaux tests de paiement/publication et de widgets/captures, fixtures/runner SQL, harness Android, simulation du dispatch et trois contrats de régression adaptés au formatage et à la relecture canonique.
- Aucun changement suivi dans `lib/app/app.dart`, `pubspec.yaml` ou `pubspec.lock`. Le cache préexistant `supabase/.temp/cli-latest` ne fait pas partie du livrable.

Artefacts générés, non versionnés :

- [APK Android release](../../build/app/outputs/flutter-apk/app-release.apk).
- [Archive des deux builds Web](../../build/shared_queue/izytel-web-candidate-20261106.zip), dossiers `backoffice_web` et `mobile_web`. Le second sert ici de validation de compilation ; choisir explicitement la cible d'hébergement avant toute publication.
- [Manifeste des empreintes](DELIVERY_MANIFEST.json), reliant sources sensibles, résultats, captures et artefacts. Les journaux sous `scratch` sont locaux ; les résumés JSON et ce rapport sont conservés avec les sources.

## État distant constaté, sans mutation

[Précontrôle du 6 novembre](SERVER_PREFLIGHT.json), projet Supabase `zrxeztxaxnzxevjuhzcc`, requête de catalogue en transaction READ ONLY : pg_cron 1.6.4 présent ; nouveaux paramètres, colonnes et détecteur absents à cette heure. La fonctionnalité de cette candidate n'est donc pas installée sur ce serveur. Ce constat n'est pas une sauvegarde et doit être relu juste avant une intervention autorisée.

Le [précontrôle Edge](EDGE_PREFLIGHT.json) identifie le dispatch actuellement ACTIVE en version 3, avec `verify_jwt=false` et `deno.json` strict. Sa source a été comparée à la candidate : seuls l'import de clé RSA, la priorité du retard et le recontrôle des destinataires changent. Le futur déploiement doit conserver cette configuration et les contrôles d'autorisation applicatifs existants ; aucune modification des secrets ni de l'autre fonction `izytel-user-admin` n'est prévue.

Aucune migration, aucun déploiement, aucun job distant, aucune modification de compte ou de donnée métier, aucune notification réelle et aucune fusion dans main n'ont été exécutés. Les deux tests sur téléphone utilisent l'application QA séparée ; ils n'attestent pas une session Agent/Manager réelle ni une réception FCM.

## Procédure de mise en service, après autorisations spécifiques

L'autorisation de développement et la validation de R1 ne valent pas autorisation de production. La mission utilisateur impose : « Aucune migration, aucun déploiement, aucune modification des comptes ou données de production sans autorisation spécifique. »

1. **Préparer l'environnement autorisé.** Confirmer la cible et sa sauvegarde/restauration, relire le diff et le manifeste, vérifier les migrations réellement appliquées et les RPC/triggers existants. Ne pas lancer un `db push` global qui appliquerait d'autres migrations en attente. N'appliquer que la migration de cette livraison après revue. La migration vide de l'autre dossier est exclue.
2. **Installer le serveur avec la file désactivée.** Appliquer la migration préparée puis déployer uniquement `izytel-notification-dispatch` avec sa configuration d'authentification et ses secrets existants. Le déploiement Edge vient après le nouveau RPC d'autorisation. Vérifier les droits, l'absence de fuite hors zone, `enabled=false` et l'absence de nouveau job. Contrôler les notifications historiques et le retry existant. Aucun secret ne doit être copié dans un rapport.
3. **Distribuer les clients compatibles.** Installer/publier la nouvelle version Agent et le Back-office selon leur circuit autorisé. Tous les Agents concernés doivent disposer de la rubrique commune avant activation : le paramètre est global et une ancienne application peut ne pas afficher les nouvelles commandes. Vérifier les versions réellement utilisées et leur connexion. Une simple compilation ne satisfait pas ce prérequis.
4. **Faire la recette de transport sur les comptes de test approuvés**, selon la section suivante. Si un environnement de recette séparé existe, y dérouler aussi le cycle complet avec une commande synthétique clairement identifiée. En production, ne créer, modifier, payer ni antidater une commande sans autorisation spécifique supplémentaire.
5. **Activer séparément**, seulement après validation du déploiement et du parc client : exécuter `supabase/operations/shared_queue_activate.sql`. Ce script verrouille la table pendant la bascule, fixe la frontière serveur, active le paramètre et crée/active seulement `izytel-acceptance-delay-monitor`, chaque minute, commande `select private.izytel_detect_order_delays(200);`. Il refuse d'écraser un job existant de même nom mais différent. Le pg_cron existant est un prérequis ; le script n'installe pas l'extension.
6. **Observer la bascule.** Contrôler les premières nouvelles commandes réellement payées, leur zone, l'unicité d'acceptation, l'historique et les débits uniquement à la finalisation. Vérifier les exécutions du job, leur durée/erreurs, les alertes et l'outbox. Le seuil est strictement supérieur à cinq minutes, avec le délai supplémentaire normal du passage minute ; une fréquence n'est pas une preuve de réception du push. Vérifier que les anciens workers ne réaffectent pas les nouvelles commandes et qu'aucun rattrapage financier n'est déclenché.

Les scripts opérateur sont préparés et relus ; ils n'ont pas été exécutés sur le serveur. Conserver le résultat et l'heure de chaque étape autorisée dans un procès-verbal de recette distinct.

## Recette FCM sur le téléphone réel

Prérequis : environnement serveur installé et autorisé, APK IzyTel compatible, réseau, notifications Android autorisées, compte Agent de test et compte Manager de test explicitement identifiés par leurs UID et zones. Ne demander ni mot de passe, ni clé de service. L'application QA synthétique ne sert pas à cette recette.

| Situation | Action et résultat à observer |
|---|---|
| Application ouverte | Avec un événement de recette autorisé, constater la bannière/in-app, la file ou l'alerte persistante ; clic vers la rubrique ou le détail autorisé, sans acceptation ni traitement implicite |
| Arrière-plan | Mettre IzyTel en arrière-plan ; constater la notification système, puis son clic et la bonne session/commande |
| Démarrage à froid | Retirer l'application des tâches sans utiliser le force-stop Android ; recevoir puis ouvrir la notification ; attendre la session et le contrôle territorial avant d'afficher les données |
| Session ou rôle changé | Ouvrir un ancien payload après changement de compte ou perte d'autorisation ; aucune donnée ni action de la zone précédente ne doit être exposée |
| Reprise réseau et appareils multiples | Vérifier retry, absence de renvoi à l'appareil déjà servi et déduplication ; un token devenu invalide ne doit pas désactiver les autres appareils |
| Alerte Manager | Dans un environnement de recette autorisé, accepter une commande synthétique et la laisser non finalisée au-delà du seuil ; constater un seul cycle, l'alerte persistante, puis sa résolution/obsolescence après les actions métier approuvées |

Pour chaque essai, consigner séparément : **événement créé** (identifiant outbox et clé de déduplication), **envoi accepté par FCM** (message ID/résultat serveur), **réception observée sur l'appareil** (heure et état de l'application), puis résultat du clic. Un statut outbox `sent` ne prouve pas à lui seul la réception.

Un message de transport clairement libellé « RECETTE » peut être envoyé uniquement aux UID de test avec autorisation explicite, sans toucher aux paiements. Cela ne prouve pas à lui seul l'enqueue métier des deux nouveaux événements. Ne pas fabriquer un événement métier incohérent ni désactiver son contrôle d'autorisation pour obtenir un push. Les contrôles réels de seuil et d'acceptation demandent un environnement ou une commande de recette autorisés.

## Retour arrière

1. Avant toute baisse de version, un Manager autorisé termine ou réaffecte explicitement les commandes partagées encore actives par les actions métier existantes. Ne pas convertir en masse les historiques et ne pas effacer les acceptations.
2. Après autorisation, exécuter `supabase/operations/shared_queue_rollback.sql`. Le script prend le verrou de bascule et **refuse** le retour arrière si une commande partagée est encore `paidReady`, `inProgress` ou `onHold`. Résoudre le motif avec le Manager puis recommencer ; ne pas contourner ce refus.
3. Le script désactive la file, remet sa frontière d'activation à null et désactive uniquement le nouveau job SLA. Il conserve commandes, cycles, alertes, événements, écritures financières et job de retry des notifications existant. Les nouvelles commandes repartent dans le circuit historique ; une réactivation ultérieure reçoit une nouvelle frontière.
4. Conserver le schéma additif et le dispatch compatible pendant la vérification. Ne pas lancer de migration inverse destructrice. Recontrôler historique, commandes personnelles, Cabinistes, notifications et finance avant toute autre publication.

**Avis SENTINEL local : favorable pour la candidate testée, sous les limites décrites.** Le gate restant porte sur l'autorisation et la recette opérationnelle distante, en particulier le push réel et le déploiement des clients. Il ne demande pas de refaire la maquette.
