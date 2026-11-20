# IzyTel 1.0.12 — lectures opérationnelles et file partagée

Suivi GitHub de la livraison et de la recette : [issue #13](https://github.com/MarcAlexKoffi/CABINEFLOW/issues/13).

## Changements

- Migration `20261120003409_shared_queue_total_and_pagination.sql` publiée : total territorial exact, pages de 100 commandes maximum et curseur stable `(available_at, order_id)`. Compatibilité conservée avec l'ancien RPC.
- Le compteur Accueil et celui de la file Agent utilisent le total du serveur. Navigation Précédentes/Suivantes, sans accumulation de toutes les commandes en mémoire.
- Les signaux Realtime déclenchent les lectures canoniques et une vérification périodique reste active, même lorsque le WebSocket ne transmet rien. Annulation et reconnexion utilisent le même mécanisme borné.
- Signalements Agent : abonnement stable entre les recherches et changements de filtre.
- Signalements et commissions Agent/Manager : les derniers résultats restent visibles pendant les erreurs temporaires, avec avertissement. Les refus d'accès et erreurs de contrat effacent la copie affichée. Changer de flux efface son cache. L'avertissement préserve les abonnements imbriqués.
- Cloche retirée des en-têtes mobiles Agent/partenaire et Manager. Les alertes de supervision gardent leur accès avec un pictogramme d'avertissement.

## Vérifications

- Analyse Flutter : aucune anomalie.
- 44 tests Flutter ciblés, plus un scénario de navigation entre pages et de réponse tardive : réussis.
- 13 contrôles PostgreSQL locaux : droits, masquage, borne de page, total et parcours complet d'un ensemble de plus de 1 000 commandes.
- Production après migration : 109 commandes, dont 105 en attente et 4 terminées. Lecture Agent : 100 puis 5 commandes, total 105 sur les deux pages. Deux signalements et quatre commissions lisibles. Lecture Manager : droits territoriaux conservés.
- Empreinte des 109 commandes identique avant/après migration : `c67276baf78614d2c32eef3bd8a2eab5`. Aucune écriture sur les commandes ni les comptes financiers pendant les contrôles.
- Sauvegarde du lecteur et de ses ACL : `.izytel_backups/stability_queue_schema_before.json` (ignorée par Git).
- Retour arrière : `supabase/operations/shared_queue_pagination_rollback.sql`. Réinstaller également l'ancien APK si le nouveau RPC est retiré.

L'APK de contrôle active `IZYTEL_DIAGNOSTICS=true` : les traces techniques contiennent uniquement l'événement et un code d'erreur neutralisé, sans données métier ni jetons. Les tests automatisés n'exécutent aucune opération USSD ni aucun paiement réel.

## Livraison sur téléphone

APK signé `dist/android/latest/izytel-1.0.12-build13.apk`, SHA-256 `f8dfd7563be1928e3864d114538c3bf4e3c7704ca93ad6c7df517a5695b151ce`, installé en mise à jour sur le téléphone connecté. Session conservée. Écrans constatés : Accueil 105 à prendre / 4 terminées, commissions 40 F, signalements 2 au total dont 1 en cours, cloche absente. Les signalements et commissions s'affichent malgré les erreurs du canal Realtime observées dans les traces neutralisées. Les essais manuels suivants sont repris par l'utilisateur à sa demande.
