# WC5 — migrations appliquées au projet IzyTel

Projet Supabase : `zrxeztxaxnzxevjuhzcc`

Les migrations ci-dessous ont été appliquées le 27/09/2026 :

- `20260927122956_wc5_territory_coverage_foundation`
- `20260927123027_wc5_zoned_orders_and_assignment`
- `20260927123100_wc5_zone_aware_customer_messaging`
- `20260927123236_wc5_inapp_customer_system_notifications`
- `20260927123307_wc5_customer_name_recovery_history`
- `20260927123316_wc5_support_refund_messaging_channel`
- `20260927123547_wc5_fixed_success_notification_bridge`

Le fichier `wc5_territorial_routing_messaging_and_contacts.sql` conserve la version consolidée et idempotente du bloc fonctionnel WC5 pour revue technique.

Principes WC5 :

- aucun nouveau flux opérationnel client ne dépend de WhatsApp ;
- les notifications client passent par la messagerie IzyTel ;
- les Agents/Cabinistes ne peuvent déclencher qu’une notification de succès système fixe, jamais un texte libre ;
- les commandes sont rattachées à une zone ;
- Agents et Cabinistes ne sont éligibles que dans la zone de la commande ;
- un Manager ne lit/prend que les conversations de ses zones ;
- une localisation hors de toute zone configurée utilise la zone centrale de repli d’Abidjan ;
- une zone reconnue mais sans Manager/Agent reste dans cette zone : elle n’est pas reroutée silencieusement vers Abidjan.
