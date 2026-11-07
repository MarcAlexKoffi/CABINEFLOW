# Traitement rapide — 6 novembre 2026

Correctif demandé et limité aux parcours de traitement Agent/Cabiniste, à leurs lectures opérationnelles et à deux fonctions de finalisation.

- **Copie directe du bénéficiaire** dans Traitement rapide : par exemple `+225 01 02 03 04 05` devient `0102030405`. Le zéro initial est conservé. La copie reste disponible sans raccourci USSD configuré et ne lance aucune opération télécom.
- **Mises à jour automatiques** : retrait immédiat après acceptation confirmée ; une ancienne lecture ne réaffiche plus la même version de commande. Une réaffectation ultérieure avec une nouvelle version reste visible. Realtime est conservé, avec lecture canonique de secours toutes les trois secondes pour file, suivi et commandes Agent. Ouvrir Mes commandes relit aussi automatiquement les affectations.
- **Agents et Cabinistes sans photo** : chargement, sélection, upload et menu de preuve retirés des détails ; réussite autorisée sans photographie côté application et serveur. La validation explicite, l'exécutant autorisé, le statut en cours, la capacité, les écritures financières et leur idempotence sont conservés. Les anciennes preuves et leurs mécanismes de stockage restent conservés.
- **Alertes Manager** : la table d'alertes est publiée en Realtime et écoutée par la supervision. La file et le job de surveillance déjà activés restent actifs.

La migration locale `20261106224728_fast_processing_without_proof.sql` a été appliquée sous la version distante **20261106230445**. Les deux fonctions ont été relues après application : aucun `PROOF_REQUIRED`, contrôles d'affectation et de capacité présents. Aucun paiement ni solde réel n'a été modifié pour la recette.

Validation : **52 tests Flutter ciblés réussis**, analyse ciblée sans anomalie et **12 scénarios SQL intégrés réussis**, notamment réussite sans preuve Agent/Cabiniste, débit/commission/règlement uniques, isolation et reprise idempotente. Le contrat de source photo devenu obsolète est remplacé par un vrai parcours de widget acceptation → démarrage → confirmation de réussite sans photo. La suite complète du projet n'a pas été relancée.

Fichiers applicatifs concernés : le composant `ussd_quick_processing_card.dart`, les détails Agent et Cabiniste, `agent_orders_page.dart`, `shared_order_queue_view_model.dart`, les repositories de file/affectation et les validations de réussite Hybrid/Fake. Aucun autre module fonctionnel n'est refondu.

Les messages de confirmation de résultat restent explicites. « Automatique » concerne l'affichage des données après les actions ; l'acceptation ne simule pas une réussite télécom.

[Preuves serveur](FAST_PROCESSING_RECEIPT_20261106.json) · [Résultats SQL](FAST_PROCESSING_INTEGRATION_RESULTS.json) · [Aperçu du traitement](visual_qa/agent-quick-processing-390.png) · [APK mis à jour](../../build/shared_queue/izytel-traitement-rapide-20261106.apk) · [Build Back-office](../../build/shared_queue/izytel-backoffice-fast-processing-20261106.zip).

Builds Android et Web réussis. La capture finale et les 22 tests USSD associés passent aussi (23 contrôles, recouvrant partiellement les 52 ci-dessus). L'APK a été vérifié : il contient le texte final sans mention de preuve. Aucune nouvelle recette physique sur téléphone n'est revendiquée pour ce correctif.

Installation du nouvel APK nécessaire sur les appareils concernés pour le bouton et les changements d'interface. Les contrôles de serveur et de widgets ne constituent pas une observation de réception FCM sur chaque téléphone. La compilation de livraison est suivie dans le manifeste.
