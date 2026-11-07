# IzyTel — état de livraison de la file partagée

Évolution autorisée : traitement rapide sans photo pour Agents **et** Cabinistes, copie du numéro local et actualisation automatique renforcée. Migration distante `20261106230445` appliquée, 52 tests Flutter ciblés et 12 scénarios SQL réussis. Les critères historiques « preuve obligatoire » sont remplacés par la nouvelle règle demandée. Voir [FAST_PROCESSING_20261106.md](FAST_PROCESSING_20261106.md).

Activation autorisée et exécutée le 6 novembre à 22:10 UTC/Abidjan : **enabled=true**, surveillance chaque minute, premier passage réussi à 22:11. Les commandes UCTYKO, MEEBSO et J4WWAB sont publiées ; la RPC les renvoie pour les deux Agents territoriaux. Six notifications acceptées par FCM, réception physique non observée. J4WWAB (20 000 F Orange) reste non acceptable tant qu'une capacité suffisante n'est pas rechargée par le circuit existant. Paiements/historique conservés. Voir [le reçu d'activation](ACTIVATION_RECEIPT_20261106.json). Les mentions « désactivée » ci-dessous sont des étapes historiques.

Mise à jour après autorisation utilisateur : migration appliquée sous la version distante `20261106105111`, dispatch version 4 ACTIVE, file toujours désactivée et aucun job SLA. Le correctif d'harmonisation Agent/Manager a été limité à trois écrans, avec 19 contrôles ciblés réussis. Voir [l'état courant et les preuves](CORRECTIF_20261106.md) et le [reçu serveur](DEPLOYMENT_RECEIPT_20261106.json). Les lignes ci-dessous décrivent la livraison initiale avant cette autorisation ; les gates de migration/déploiement y sont maintenant franchies, ceux de distribution/activation/FCM réel restent ouverts.

6 novembre 2026. Plan ORION v3. Base `588ca83`, branche `feat/shared-agent-queue-sla`, candidate locale non commitée. Registre courant ; le [rapport de reprise](REPRISE_AUDIT_20261106.md) décrit l'état antérieur aux corrections.

Source unique d'implémentation : `cabine_flow`. Les copies sous `SUPERVISION-VISIOS/work` restent historiques. Leur migration vide ne doit pas être appliquée.

R1 reste **DESIGN_VALIDATED**, selon [DESIGN_CONTRACT.md](DESIGN_CONTRACT.md). Aucune nouvelle validation de maquette n'est requise.

| Lot | Exigences | Statut et preuves de la candidate | Gate restante |
|---|---|---|---|
| AFF-1 | AFF-01/02/06 | IMPLEMENTATION et audit local terminés : publication après paiement canonique, claim atomique/idempotent, RLS territoriale, compatibilité historique et manuelle ; 13 contrôles SQL et 12 scénarios intégrés | Migration distante désactivée, uniquement sur autorisation spécifique |
| AFF-2 | AFF-03/04/05 | VISUAL_QA locale terminée : À prendre/Mes commandes, actualisation, conflit, réponse perdue, détail sans démarrage implicite, retour Android ; tests widgets et téléphone réel | Distribution de l'application compatible avant activation globale |
| SLA-1 | SLA-01 à SLA-05 | TECHNICAL_AUDIT local terminé : seuil serveur, cycles, déduplication, alertes persistantes, réaffectation, échec distinct ; supervision mobile et Web | Exécution et observation du job minute en environnement autorisé |
| NOTIF-1 | NOTIF-01 à NOTIF-03 | Dispatch, routes, retries, multi-appareils et contrôle territorial au moment de l'envoi testés localement ; vérification TypeScript réussie | Déploiement autorisé puis réception FCM réelle foreground/background/cold start |
| QA-1 | R1 et navigation | Captures réelles à 320/390/768/1440 px ; texte à 200 %, numéro complet après acceptation, tableau large et alertes contrôlés | Rendu du prototype dans un navigateur non recontrôlé ; comparaison faite au contrat et aux sources R1 figées |
| SEC-1 | Audit transversal | Analyse sans anomalie ; 1 113 tests Flutter réussis, 1 capture opt-in ignorée puis exécutée séparément ; builds Web/Android ; 2 scénarios sur Samsung réel | Recette opérationnelle et push réels ; observation de l'activation |

REC-01, REC-02, REC-04 et REC-05 sont corrigés. REC-03 est traité par une fixture locale issue du catalogue réel : 28 tables, 45 fonctions, privilèges, policies et hooks métier concernés. Les exclusions explicites sont les clés étrangères vers des comptes hors périmètre, leurs hooks d'audit, le transport HTTP/FCM et le stockage de messagerie client ; voir les [résultats intégrés](INTEGRATION_TEST_RESULTS.json).

Les défauts reproduits pendant l'audit ont été corrigés et contre-vérifiés : anciens RPC de réconciliation/clôture/refus, écrasement du montant par rejeu/concurrence de synchronisation, publication sans horodatage confirmé relu, ouverture de notification sur l'onglet personnel, destinataire devenu non autorisé avant dispatch et débordements de texte agrandi.

Décision ORION/SENTINEL : **candidate locale prête ; TECHNICAL_AUDIT opérationnel en attente, pas de DONE global**. Les livrables, limites, commandes de recette et étapes d'activation/retour arrière sont dans [LIVRAISON_20261106.md](LIVRAISON_20261106.md).

L'utilisateur a depuis autorisé spécifiquement la migration désactivée et le dispatch : ces deux opérations sont réalisées. Aucune activation, aucun nouveau job, aucun changement de compte ou de paiement, aucun commit ni fusion dans `main` n'a été effectué.
