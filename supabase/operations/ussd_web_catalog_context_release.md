# Raccourcis des commandes Web — 21 novembre 2026

Migration installée : `20261121142344_ussd_web_catalog_context`.

Le RPC facultatif d’association USSD n’avait enregistré aucun contexte pour les commandes Web. Le résolveur utilise désormais, en son absence, l’identifiant exact de l’offre dans la copie immuable créée par le serveur à la commande.

La copie doit correspondre à la commande : identifiant, référence, propriétaire, réseau, type, montant et bénéficiaire. Les commandes personnalisées ou incohérentes restent bloquées ; aucun rapprochement par titre ou prix n’est effectué. Une association explicite existante garde la priorité.

Les anciennes commandes Web d’une offre mixte marquées `callBundle` peuvent utiliser le raccourci de l’offre mixte réellement choisie, uniquement avec cet identifiant immuable et le service `calls`. Leur type enregistré, leur historique et leurs montants restent inchangés.

## Validation

- `node test/catalog_bonus/run.mjs --no-report` : 109 commandes Web synthétiques couvrant les 109 offres, dont 9 ouvertures Max it ; compatibilité des anciennes offres mixtes et des prix historiques ; propriétaire Cabiniste ; 13 copies invalides refusées ; numéros locaux/internationaux ; priorité des associations explicites ; refus des autres propriétaires, des sessions anonymes et des commandes non acceptées, non financées ou non démarrées. Les contrôles existants catalogue/bonus et le retour arrière passent aussi.
- Analyse Flutter : zéro erreur, un avertissement dans `legacy_finance_backfill_service.dart` et 213 informations de dépréciation avec le SDK installé. Aucun fichier Dart ni dépendance n’a été modifié pour ce correctif. Les changements automatiques du SDK ont été retirés du correctif.
- Production : 42 commandes Web possèdent une copie catalogue valide et une route active, dont 4 anciennes commandes mixtes. Empreinte des commandes identique avant/après ; 0 contexte ajouté ; 76 tentatives d’exécution avant/après. Définitions et droits de `ussd_resolve`, `ussd_prepare`, `ussd_actor` et `izytel_assert_execution` identiques. Contrôle de santé Supabase sans anomalie.

Aucun appel télécom ni paiement réel n’a été exécuté. Aucune commande n’était en traitement au contrôle final : le parcours complet sur téléphone reste à tester par l’utilisateur.

## Essai sur téléphone

Sur une commande Web payée et validée, accepter puis démarrer le traitement avec le compte Agent propriétaire. Ouvrir « Traitement rapide », puis « Actualiser le raccourci » si la page était déjà ouverte. La syntaxe ou Max it doit apparaître selon l’offre choisie. Le correctif serveur fonctionne avec l’application existante ; aucun nouvel APK n’est nécessaire.

Les offres personnalisées sans référence catalogue, les offres suspendues et les informations réellement incohérentes nécessitent toujours une vérification Manager.

## Retour arrière

Avant installation, la définition et les droits du résolveur ont été sauvegardés dans `.izytel_backups/web_shortcut_before.json` ; sa définition SQL est dans `.izytel_backups/web_shortcut_rollback.sql`. Pour annuler, restaurer uniquement cette définition via une nouvelle migration, en lisant explicitement le fichier en UTF-8. Aucune donnée métier n’est à restaurer et aucune permission n’est à élargir.
