# IzyTel — README des modifications récentes réalisées avec Codex

Document établi le **9 novembre 2026**, heure d’Abidjan. Périmètre documentaire : travaux retrouvés du **30 octobre au 7 novembre 2026**, complétés par les commits locaux récents.

## 1. Objet et méthode

Ce document concerne uniquement **IzyTel**, dont le nom technique historique est `cabine_flow`. Il décrit les changements, les validations consignées, leur état de livraison et les fichiers concernés.

Dépôt principal : `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow`.

Les informations proviennent de quatre chats Codex relus avec leur historique disponible, des événements de modification de fichiers, du bilan Administration/Finance/Notifications et de l’état Git local. Les tests cités sont les résultats historiques des interventions ; ils n’ont pas été relancés pour produire ce README. Les actions distantes sont rapportées d’après ces comptes rendus, sans nouvelle interrogation de la production.

L’inventaire distingue les modifications explicitement enregistrées dans les chats et les fichiers présents dans les commits récents. Une date de fichier ou un changement Git ne permet pas, à lui seul, d’attribuer tout son contenu à Codex. Les fichiers créés par des scripts, copiés ou générés ne sont pas tous représentés par les événements de modification des chats. Ce document couvre les éléments retrouvés ; il ne garantit pas un historique exhaustif de toutes les sessions anciennes ou archivées.

## 2. Vue d’ensemble

| Chantier | Résultat principal | État documenté |
|---|---|---|
| Stabilisation mobile/Web | Navigation Retour, conservation des onglets, reconnexion, réessais et erreurs d’authentification | Code local vérifié, compilations réalisées |
| USSD | Configuration, génération de raccourcis et intégration Agent/Cabiniste, puis reprises du module | Plusieurs révisions successives : consulter les rapports USSD pour l’état précis |
| Administration | Gestion des comptes et rôles, isolation des droits et reprise des chargements | Migrations et fonction serveur déployées selon le compte rendu du 1 novembre |
| Finance | Lectures canoniques, agrégats Wave, dépenses idempotentes et intégration mobile/Back-office | Correctifs locaux et migrations serveur consignés |
| Notifications | Outbox, routage territorial, reprise par appareil et réveil périodique | Scheduler et fonctions serveur déployés ; réception réelle à distinguer de l’acceptation FCM |
| File partagée | File « À prendre », acceptation exclusive et supervision à cinq minutes | Développée, puis migration, activation et publication ciblée consignées le 6 novembre |
| Traitement rapide | Copie du numéro, actualisation des files et retrait de la preuve obligatoire | Correctifs applicatifs et serveur réalisés |
| Managers, Zones et carte | Registres réparés, chargements indépendants et carte interactive | Migration appliquée, tests et build Web réussis le 7 novembre |

## 3. Description détaillée des modifications

### 3.1 Stabilisation des applications — 30 octobre 2026

Le Retour Android a été protégé dans les espaces Agent, Manager/Administrateur et Cabiniste. Le comportement tient compte des fenêtres ouvertes, des piles d’onglets et de la sortie depuis l’accueil. L’objectif est de conserver la navigation et d’éviter les sorties ou retours incohérents.

Les lectures du serveur ont été bornées. Les erreurs sont explicites, les réessais recréent réellement les flux et la reconnexion permet de reprendre les chargements. Les erreurs asynchrones d’authentification ont également été corrigées.

Validation consignée : **895 tests Flutter**, analyse sans diagnostic et builds Android debug, Client Web et Back-office Web réussis. Le catalogue public a été contrôlé avec 34 offres et six filtres. Les propositions concernant les droits Support et certaines fonctions serveur restent distinctes de ces correctifs.

Rapport principal : `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\RAPPORT_STABILISATION.txt`.

### 3.2 Module USSD — 31 octobre et reprises du 1 novembre

Une première intégration locale a ajouté la configuration Back-office, le moteur de génération des codes, les contrôles de rôles et l’accès depuis les parcours Agent/Cabiniste. Les contrôles prévus portent notamment sur la confirmation, le maintien du caractère #, le choix de SIM, l’annulation et la vérification des droits avant lancement.

Cette première version annonçait **979 tests Flutter**, dont 84 nouveaux tests USSD, et **69 scénarios SQL isolés**. La migration était alors préparée sans être appliquée. Une vérification ultérieure a identifié l’absence de la table et de la fonction attendues par l’écran sur le serveur : publier le code seul ne suffisait donc pas.

L’historique contient ensuite une reprise complète et des documents de correction, de migration et de suppression. Il faut lire ces documents chronologiquement avant de réutiliser la première migration : sa présence dans le dossier ne prouve pas qu’elle correspond à la dernière configuration active.

La publication du commit `ff7d010` dans une branche GitHub a été consignée à cette étape, sans fusion dans main ni déploiement applicatif associé.

Documents à consulter dans `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs` :
- `USSD_V1_INTEGRATION.txt` : première intégration et précautions.
- `USSD_CORRECTION_AFFICHAGE_20261031.md` : correction de l’écran.
- `USSD_MIGRATION_APPLICATION_20261031.md` : application de migration.
- `USSD_REPRISE_20261031.txt`, `USSD_MIGRATIONS_SERVEUR_20261101.txt`, `USSD_SUPPRESSION_20261101.txt` : évolutions suivantes.
- `RECETTE_REELLE_AVANT_LIVRAISON.md` : essais réels restant nécessaires.

### 3.3 Administration et utilisateurs — 1 novembre

Les parcours de création, modification, changement de rôle, statut, zones et réseaux ont été préparés pour les quatre populations. Les actions sensibles passent par une fonction serveur privilégiée avec le JWT Firebase. Les échecs partiels restent visibles et audités.

La session demande une reconnexion après un changement confirmé de rôle ou de statut. Les états temporaires du cache ne doivent pas provoquer cette invalidation. La suppression définitive reste refusée tant que toutes les références du compte ne sont pas identifiées.

La page Utilisateurs a été corrigée pour qu’une indisponibilité Supabase ne masque plus le registre Firestore. Les messages distinguent les deux sources et Réessayer recrée le flux. Le scénario de reprise comptait neuf tests réussis.

Deux profils historiques ont été normalisés de `supervisor` vers `manager`, sans modification des mouvements financiers ni des comptes Firebase Auth selon le rapport de migration.

Rapports : `docs\RAPPORT_1_UTILISATEURS_20261101.md`, `docs\RAPPORT_MIGRATION_DONNEES_20261101.md` et `docs\RAPPORT_DEPLOIEMENT_MIGRATIONS_20261101.md`, sous le dépôt principal.

### 3.4 Finance — 1 et 2 novembre

Les nouvelles opérations mobiles utilisent les fonctions canoniques communes au Back-office. Les versements et commissions V2 s’appuient sur Supabase. Les agrégats Wave et les capacités engagées ne dépendent plus d’une fenêtre limitée de lignes de détail ; les versements Cabinistes Wave sont inclus.

Les dépenses utilisent un reçu idempotent : une reprise après interruption conserve la même intention, afin d’éviter une double opération. Les fonctions globales Finance sont réservées à l’Administrateur. Les historiques anciens et les désynchronisations préexistantes ne sont pas présentés comme automatiquement réparés.

Les commits du 2 novembre mentionnent aussi la stabilisation Finance, l’enregistrement des zones Agent et le retrait de la modification des montants côté Agent. Ces intitulés sont des preuves de versionnement ; les rapports et les fichiers restent nécessaires pour connaître chaque règle exacte.

Rapports : `docs\RAPPORT_2_FINANCE_20261101.md`, `docs\FINANCE_AUDIT_INITIAL_20261101.md` et `docs\SENTINEL_REVUE_FINANCE_ADAPTATEURS_20261101.md`.

### 3.5 Notifications et déploiement coordonné — 1 novembre

L’outbox a été conservée et complétée par le routage territorial, des reprises bornées, un bail de traitement et un suivi par appareil. Les événements de paiement, remboursement et prise en charge Support alimentent une trace persistante dans la messagerie. Les ouvertures depuis les notifications Cabinistes relisent les ressources autorisées.

Le bilan et les comptes rendus indiquent cinq migrations appliquées, `pg_cron` installé avec un réveil chaque minute, `izytel-notification-dispatch` v3 et `izytel-user-admin` v2 actifs, et les règles Firestore publiées après des échecs temporaires HTTP 503. Le dispatch passera ensuite en v4 pendant le chantier de file partagée.

Migrations locales mentionnées :
1. `20261101011937_notifications_territory_delivery_recovery.sql`
2. `20261101012308_finance_mobile_canonical_reads.sql`
3. `20261101062456_finance_exact_wave_totals_and_expense_idempotency.sql`
4. `20261101062508_admin_accounts_lifecycle.sql`
5. `20261101142339_notifications_retry_scheduler.sql`

Localisation : `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\migrations`.

Les quatre premières ont des versions distantes différentes, consignées dans le bilan. Le Web Push reste désactivé. Une réponse positive du serveur FCM ne prouve pas que la notification a effectivement été affichée sur le téléphone.

Validation globale du chantier Administration/Finance/Notifications : **1 077 tests Flutter**, analyse sans diagnostic, builds Android debug et deux applications Web réussis, avec tests Node et PostgreSQL isolés. Ces résultats ne remplacent pas une recette Firebase/FCM réelle.

### 3.6 File partagée et supervision — 5 et 6 novembre

La maquette initiale a été préparée dans un sous-dossier de SUPERVISION-VISIOS, mais concerne bien IzyTel :
`C:\Users\koffi\Documents\PROJETS JS\SUPERVISION-VISIOS\work\izytel-file-partagee-20261106`.

L’implémentation applicative de référence se trouve dans `cabine_flow`, branche historique `feat/shared-agent-queue-sla`. La copie de maquette ci-dessus ne doit pas être confondue avec le code Flutter final.

Les Agents disposent d’une file « À prendre », d’une acceptation exclusive et d’un accès direct au traitement. L’actualisation gère les conflits et évite le traitement concurrent d’une même commande. Le Manager dispose d’un suivi avec horodatage serveur et alertes après cinq minutes.

La validation locale consignée comprend **1 113 tests Flutter**, 25 contrôles SQL/intégration et deux scénarios sur un Samsung connecté. Une passe visuelle ultérieure a supprimé un en-tête Agent redondant et harmonisé cartes et états erreur/vide/désactivé avec l’interface existante.

La migration a d’abord été appliquée avec la file désactivée et le dispatch v4 déployé. Après accord distinct, la file et la surveillance ont été activées et trois commandes ciblées publiées. La surveillance s’exécute chaque minute pour contrôler le seuil de cinq minutes. Six envois FCM ont été acceptés selon le compte rendu. Les capacités restent vérifiées à l’acceptation, même si la commande est visible.

Rapports : `docs\shared_queue\REPRISE_AUDIT_20261106.md`, `LIVRAISON_20261106.md`, `CORRECTIF_20261106.md` et `WORKFLOW_STATE.md`.

### 3.7 Traitement rapide — 6 novembre

L’action Copier le numéro fournit le numéro national sans +225 ni espaces. Les files s’actualisent après les actions et une commande acceptée ne doit plus réapparaître à cause d’un rafraîchissement tardif.

La preuve de traitement obligatoire a été retirée pour les Agents et les Cabinistes ; la réussite conserve une confirmation explicite. Le compte rendu mentionne la mise à jour serveur et un nouvel APK.

Validation : **52 tests Flutter ciblés et 12 scénarios SQL réussis**. APK consigné : `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\build\shared_queue\izytel-traitement-rapide-20261106.apk`.

### 3.8 Managers, Zones et cartographie — 7 novembre

Les appels à l’ancien reprovisionnement qui bloquaient les registres Managers et Zones ont été corrigés, avec migration serveur appliquée.

Le chargement territorial est indépendant de la disponibilité de l’annuaire Agents. Une capacité inconnue s’affiche « — ». La carte ajoute recherche par zone, ville ou Manager, filtres, couverture, zoom, recentrage, plein écran et regroupement des marqueurs proches. L’éditeur synchronise ses coordonnées avec la carte.

Validation : **27 tests Flutter, huit contrôles SQL, rendu à trois largeurs et compilation Web réussis**. Le parcours authentifié complet reste non vérifié dans le compte rendu. Une incohérence géographique de Zone 1 a été signalée sans déplacement automatique.

Rapport : `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\territory_map\DELIVERY_20261107.md`.

## 4. Inventaire des fichiers enregistrés dans les chats

Chaque tableau donne le chemin absolu, les actions historiques observées et le rôle du fichier. Le rôle est une indication de lecture fondée sur son emplacement et son nom ; les détails fonctionnels figurent dans les chapitres précédents et les rapports spécialisés.

« Ajout puis modification » décrit la succession des interventions. « Suppression puis ajout » peut correspondre à un remplacement du fichier. La présence actuelle est vérifiée lors de la génération du README. Un fichier absent peut avoir été supprimé ou déplacé depuis l’intervention.


### Auditer la file partagée des command

Source : chat `01a1b00a-169c-7bb0-8c7e-7051b168b963`. 74 chemins uniques dans ce chat.

| Fichier — localisation complète | Actions dans l’historique | Rôle | Présence actuelle |
|---|---|---|---|
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\.izytel_backups\fast_processing_finalizers_before_20261106.sql` | Ajout | Migration ou contrôle SQL : schéma, fonctions et droits serveur. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\.izytel_backups\shared_queue_before_activation_20261106.json` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\.izytel_backups\territory_profiles_before_20261107.sql` | Ajout | Migration ou contrôle SQL : schéma, fonctions et droits serveur. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\ACTIVATION_RECEIPT_20261106.json` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\CORRECTIF_20261106.md` | Modification ; Ajout | Rapport, instructions, audit ou suivi de livraison. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\DEPLOYMENT_RECEIPT_20261106.json` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\DESIGN_CONTRACT.md` | Modification | Rapport, instructions, audit ou suivi de livraison. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\EDGE_PREFLIGHT.json` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\FAST_PROCESSING_20261106.md` | Ajout ; Modification | Rapport, instructions, audit ou suivi de livraison. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\FAST_PROCESSING_RECEIPT_20261106.json` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\LIVRAISON_20261106.md` | Modification ; Ajout | Rapport, instructions, audit ou suivi de livraison. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\REPRISE_AUDIT_20261106.md` | Ajout | Rapport, instructions, audit ou suivi de livraison. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\SERVER_PREFLIGHT.json` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\WORKFLOW_STATE.md` | Modification ; Ajout | Rapport, instructions, audit ou suivi de livraison. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\territory_map\DELIVERY_20261107.md` | Ajout ; Modification | Rapport, instructions, audit ou suivi de livraison. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\data\repositories\supabase_territory_repository.dart` | Modification | Accès aux données et coordination des sources. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\domain\models\territory_models.dart` | Modification | Modèle, contrat ou règle métier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\presentation\pages\team\backoffice_managers_page.dart` | Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\presentation\pages\team\backoffice_zones_page.dart` | Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\presentation\widgets\backoffice_territory_map.dart` | Ajout ; Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\data\repositories\fake_orders_repository.dart` | Modification | Accès aux données et coordination des sources. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\data\repositories\hybrid_orders_repository.dart` | Modification | Accès aux données et coordination des sources. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\data\repositories\supabase_phase4_assignment_repository.dart` | Modification | Accès aux données et coordination des sources. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\data\repositories\supabase_shared_order_queue_repository.dart` | Modification | Accès aux données et coordination des sources. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\presentation\pages\agent_order_detail_view.dart` | Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\presentation\pages\agent_orders_page.dart` | Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\presentation\pages\order_supervision_page.dart` | Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\presentation\pages\shared_agent_orders_page.dart` | Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\presentation\view_models\shared_order_queue_view_model.dart` | Modification | Modèle, contrat ou règle métier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\partners\presentation\pages\partner_shell_page.dart` | Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\ussd\presentation\ussd_quick_processing_card.dart` | Modification | Logique applicative Flutter, intégration ou configuration. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\fast_processing_candidate.sql` | Ajout | Migration ou contrôle SQL : schéma, fonctions et droits serveur. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\shared_queue_remote_v3_deno_json` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\shared_queue_remote_v3_index_ts` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\functions\izytel-notification-dispatch\index.ts` | Modification | Fonction serveur Supabase ou composant de son traitement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\migrations\20261106004036_shared_agent_queue_and_sla.sql` | Modification | Migration ou contrôle SQL : schéma, fonctions et droits serveur. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\migrations\20261106224728_fast_processing_without_proof.sql` | Modification | Migration ou contrôle SQL : schéma, fonctions et droits serveur. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\migrations\20261107002724_territory_managed_profiles_compatibility.sql` | Modification | Migration ou contrôle SQL : schéma, fonctions et droits serveur. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\operations\shared_queue_activate.sql` | Ajout | Migration ou contrôle SQL : schéma, fonctions et droits serveur. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\operations\shared_queue_activation_executed_20261106.sql` | Ajout | Migration ou contrôle SQL : schéma, fonctions et droits serveur. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\operations\shared_queue_publish_three_20261106.sql` | Ajout | Migration ou contrôle SQL : schéma, fonctions et droits serveur. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\operations\shared_queue_rollback.sql` | Ajout | Migration ou contrôle SQL : schéma, fonctions et droits serveur. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\tests\notifications_dispatch_test.mjs` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\backoffice\territory_map_test.dart` | Ajout ; Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\backoffice\territory_map_visual_test.dart` | Ajout ; Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\backoffice\territory_repository_http_test.dart` | Ajout ; Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\orders\data\repositories\fake_orders_agent_processing_test.dart` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\orders\data\repositories\shared_queue_payment_publication_test.dart` | Ajout ; Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\orders\presentation\fast_processing_test.dart` | Ajout ; Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\orders\presentation\pages\agent_proof_source_contract_test.dart` | Modification ; Suppression | Tests ou outil de vérification du comportement. | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\orders\presentation\shared_order_queue_test.dart` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\orders\presentation\shared_order_queue_visual_test.dart` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\ussd\ussd_mobile_widget_test.dart` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\backoffice_bo3c_territory_contract_test.dart` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\notifications_complete_block_contract_test.dart` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\phase4_release_payment_resilience_contract_test.dart` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\supabase_phase4_assignment_contract_test.dart` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\wc6_manager_registry_zone_creation_fix_contract_test.dart` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\device_scenarios.dart` | Ajout ; Modification | Tests ou outil de vérification du comportement. | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\fixtures\territory_profiles_before_compatibility.sql` | Ajout | Migration ou contrôle SQL : schéma, fonctions et droits serveur. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\integration_actions.json` | Ajout | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\integration_extra_functions.json` | Ajout | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\integration_extra_metadata.json` | Ajout | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\integration_function_grants.json` | Ajout | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\integration_functions.json` | Ajout ; Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\integration_metadata.json` | Ajout | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\integration.mjs` | Modification ; Ajout | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\package.json` | Ajout ; Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\postgres.mjs` | Ajout ; Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\prepare_android_qa.ps1` | Ajout ; Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\prepare_visual_qa.ps1` | Ajout | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\README.md` | Modification ; Ajout | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\run.mjs` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\territory_profiles.mjs` | Ajout ; Modification | Tests ou outil de vérification du comportement. | Présent |

### Mettre en place une file partagée

Source : chat `01a1ae1d-6d57-7bb1-baa8-10a953b97787`. 9 chemins uniques dans ce chat.

| Fichier — localisation complète | Actions dans l’historique | Rôle | Présence actuelle |
|---|---|---|---|
| `C:\Users\koffi\Documents\PROJETS JS\SUPERVISION-VISIOS\work\iztel-placeholder.txt` | Ajout ; Suppression | Rapport, instructions, audit ou suivi de livraison. | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS JS\SUPERVISION-VISIOS\work\izytel-file-partagee-20261106\AUDIT_INITIAL.md` | Ajout | Rapport, instructions, audit ou suivi de livraison. | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS JS\SUPERVISION-VISIOS\work\izytel-file-partagee-20261106\index.html` | Ajout ; Modification | Maquette ou présentation visuelle. | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS JS\SUPERVISION-VISIOS\work\izytel-file-partagee-20261106\PLAN_ORION.md` | Ajout | Rapport, instructions, audit ou suivi de livraison. | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS JS\SUPERVISION-VISIOS\work\izytel-file-partagee-20261106\prototype.css` | Ajout | Maquette ou présentation visuelle. | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS JS\SUPERVISION-VISIOS\work\izytel-file-partagee-20261106\prototype.js` | Ajout | Script d’outillage, maquette ou validation. | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS JS\SUPERVISION-VISIOS\work\izytel-file-partagee-20261106\WORKFLOW_STATE.md` | Modification ; Ajout | Rapport, instructions, audit ou suivi de livraison. | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS JS\SUPERVISION-VISIOS\work\izytel-implementation\docs\shared_queue\DESIGN_CONTRACT.md` | Ajout | Rapport, instructions, audit ou suivi de livraison. | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS JS\SUPERVISION-VISIOS\work\izytel-implementation\test\shared_queue\existing_metadata.json` | Ajout | Tests ou outil de vérification du comportement. | Absent à ce chemin |

### Stabiliser admin, finance et alertes

Source : chat `01a194ac-693b-7d21-8724-237e595dfb24`. 91 chemins uniques dans ce chat.

| Fichier — localisation complète | Actions dans l’historique | Rôle | Présence actuelle |
|---|---|---|---|
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\.izytel_backups\agent_capacity_fix_20261102\firestore_live_before.rules` | Ajout | Règles de sécurité Firebase. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\.izytel_backups\agent_capacity_fix_20261102\supabase_before.json` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\.izytel_backups\agent_capacity_fix_20261102\verification.json` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\.izytel_backups\reset_20261102_keep_admin\manifest.json` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\.izytel_backups\reset_20261102_keep_admin\reset_supabase_dry_run.sql` | Ajout | Migration ou contrôle SQL : schéma, fonctions et droits serveur. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\.izytel_backups\reset_20261102_keep_admin\reset_supabase.sql` | Ajout | Migration ou contrôle SQL : schéma, fonctions et droits serveur. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\.izytel_backups\reset_20261102_keep_admin\result.json` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\.izytel_backups\reset_20261102_keep_admin\supabase_00.json` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\.izytel_backups\reset_20261102_keep_admin\supabase_01.json` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\.izytel_backups\reset_20261102_keep_admin\supabase_02.json` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\.izytel_backups\reset_20261102_keep_admin\supabase_03.json` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\.izytel_backups\reset_20261102_keep_admin\supabase_04.json` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\.izytel_backups\reset_20261102_keep_admin\supabase_05.json` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\.izytel_backups\reset_20261102_keep_admin\supabase_06.json` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\.izytel_backups\reset_20261102_keep_admin\supabase_07.json` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\.izytel_backups\reset_20261102_keep_admin\supabase_verification.json` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\BILAN_ADMIN_FINANCE_NOTIFICATIONS_20261101.md` | Modification ; Ajout | Rapport, instructions, audit ou suivi de livraison. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\IDENTITE_PHOTOGRAPHIE_DISTANTE_20261101.md` | Ajout | Rapport, instructions, audit ou suivi de livraison. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\RAPPORT_1_UTILISATEURS_20261101.md` | Modification | Rapport, instructions, audit ou suivi de livraison. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\RAPPORT_2_FINANCE_20261101.md` | Modification | Rapport, instructions, audit ou suivi de livraison. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\RAPPORT_3_NOTIFICATIONS_20261101.md` | Modification | Rapport, instructions, audit ou suivi de livraison. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\RAPPORT_ATLAS_CORRECTIF_BACKOFFICE_20261101.md` | Modification ; Ajout | Rapport, instructions, audit ou suivi de livraison. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\RAPPORT_DEPLOIEMENT_MIGRATIONS_20261101.md` | Ajout | Rapport, instructions, audit ou suivi de livraison. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\RAPPORT_MIGRATION_DONNEES_20261101.md` | Ajout | Rapport, instructions, audit ou suivi de livraison. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\SENTINEL_REVUE_FINANCE_ADAPTATEURS_20261101.md` | Modification | Rapport, instructions, audit ou suivi de livraison. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\firestore.rules` | Modification | Règles de sécurité Firebase. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\app\app.dart` | Modification | Logique applicative Flutter, intégration ou configuration. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\backoffice_app.dart` | Modification | Logique applicative Flutter, intégration ou configuration. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\data\repositories\backoffice_user_administration_repository.dart` | Modification | Accès aux données et coordination des sources. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\data\repositories\firestore_backoffice_user_repository.dart` | Modification | Accès aux données et coordination des sources. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\data\repositories\supabase_backoffice_finance_repository.dart` | Modification | Accès aux données et coordination des sources. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\domain\models\backoffice_finance_snapshot.dart` | Modification | Modèle, contrat ou règle métier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\domain\repositories\backoffice_user_repository.dart` | Modification | Accès aux données et coordination des sources. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\presentation\pages\backoffice_users_page.dart` | Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\presentation\pages\finances\backoffice_finance_page.dart` | Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\presentation\widgets\backoffice_user_admin_dialog.dart` | Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\core\diagnostics\startup_trace.dart` | Ajout | Logique applicative Flutter, intégration ou configuration. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\core\resilience\backend_failure_policy.dart` | Modification | Logique applicative Flutter, intégration ou configuration. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\core\supabase\supabase_realtime_refetch.dart` | Modification | Logique applicative Flutter, intégration ou configuration. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\agents\data\repositories\fake_agent_repository.dart` | Modification | Accès aux données et coordination des sources. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\agents\data\repositories\supabase_agent_operations_repository.dart` | Modification | Accès aux données et coordination des sources. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\agents\domain\models\agent_models.dart` | Modification | Modèle, contrat ou règle métier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\agents\presentation\view_models\agent_activity_view_model.dart` | Modification | Modèle, contrat ou règle métier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\auth\presentation\widgets\session_access_boundary.dart` | Modification ; Ajout | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\commissions\data\repositories\supabase_commission_v2_repository.dart` | Modification | Accès aux données et coordination des sources. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\finances\data\repositories\manager_read_only_finance_operations_repository.dart` | Modification | Accès aux données et coordination des sources. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\finances\data\repositories\supabase_finance_operations_repository.dart` | Ajout ; Modification | Accès aux données et coordination des sources. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\finances\domain\services\finance_calculators.dart` | Modification | Modèle, contrat ou règle métier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\finances\presentation\pages\daily_financial_closing_page.dart` | Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\finances\presentation\pages\finance_expenses_page.dart` | Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\finances\presentation\pages\finances_page.dart` | Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\finances\presentation\pages\supplier_finance_page.dart` | Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\finances\presentation\pages\wave_cash_page.dart` | Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\finances\presentation\widgets\financial_intent_retry.dart` | Ajout ; Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\presentation\view_models\agent_orders_view_model.dart` | Modification | Modèle, contrat ou règle métier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\main_backoffice_web.dart` | Modification | Logique applicative Flutter, intégration ou configuration. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\pubspec.yaml` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\apply_agent_capacity_ui_fix.mjs` | Ajout ; Modification | Script d’outillage, maquette ou validation. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\deploy_agent_rules.mjs` | Ajout | Script d’outillage, maquette ou validation. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\measure_startup.mjs` | Ajout ; Modification | Script d’outillage, maquette ou validation. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\reset_cloud_data.mjs` | Ajout ; Modification | Script d’outillage, maquette ou validation. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\reset_storage.ps1` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\static_server.dart` | Ajout | Logique applicative Flutter, intégration ou configuration. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\functions\izytel-user-admin\index.ts` | Modification | Fonction serveur Supabase ou composant de son traitement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\migrations\20261101012308_finance_mobile_canonical_reads.sql` | Modification | Migration ou contrôle SQL : schéma, fonctions et droits serveur. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\migrations\20261101062841_finance_integrity_aggregates_idempotency.sql` | Suppression | Migration ou contrôle SQL : schéma, fonctions et droits serveur. | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\migrations\20261101142339_notifications_retry_scheduler.sql` | Modification | Migration ou contrôle SQL : schéma, fonctions et droits serveur. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\migrations\20261102011000_agent_operations_staff_capacity.sql` | Ajout ; Modification | Migration ou contrôle SQL : schéma, fonctions et droits serveur. | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\tests\agent_operations_capacity_test.mjs` | Ajout ; Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\tests\finance_mobile_canonical_test.mjs` | Ajout | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\backoffice\finance_read_recovery_test.dart` | Ajout ; Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\backoffice\supabase_backoffice_finance_repository_test.dart` | Ajout | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\backoffice\user_administration_dialog_test.dart` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\backoffice\user_administration_repository_test.dart` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\core\resilience\backend_failure_policy_test.dart` | Modification ; Ajout | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\core\resilience\supabase_finance_refresh_test.dart` | Ajout | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\agents\presentation\view_models\agent_activity_view_model_test.dart` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\auth\presentation\session_access_boundary_test.dart` | Ajout | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\finances\data\finance_operation_key_transport_test.dart` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\finances\data\supabase_finance_operations_repository_test.dart` | Ajout ; Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\finances\domain\exact_wave_totals_test.dart` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\finances\financial_intent_retry_widget_test.dart` | Ajout ; Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\orders\presentation\view_models\agent_orders_auto_assignment_test.dart` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\orders\presentation\view_models\agent_orders_view_model_test.dart` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\backoffice_bo1_foundation_contract_test.dart` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\customer_web_responsive_startup_realtime_contract_test.dart` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\phase3_runtime_closure_contract_test.dart` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\phase3_stabilization_contract_test.dart` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\supabase_phase3_suppliers_contract_test.dart` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\wc9_1_compile_scope_hotfix_contract_test.dart` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\tool\atlas_startup_baseline.dart` | Ajout ; Suppression | Logique applicative Flutter, intégration ou configuration. | Absent à ce chemin |

### Auditer le projet IzyTel

Source : chat `01a18f02-de8c-71d0-ab7d-d5f43234c875`. 76 chemins uniques dans ce chat.

| Fichier — localisation complète | Actions dans l’historique | Rôle | Présence actuelle |
|---|---|---|---|
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\.gitignore` | Modification | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\android\app\src\main\kotlin\com\izytel\app\MainActivity.kt` | Modification | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\RECETTE_REELLE_AVANT_LIVRAISON.md` | Ajout | Rapport, instructions, audit ou suivi de livraison. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\USSD_CORRECTION_AFFICHAGE_20261031.md` | Ajout ; Modification | Rapport, instructions, audit ou suivi de livraison. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\USSD_MIGRATION_APPLICATION_20261031.md` | Ajout | Rapport, instructions, audit ou suivi de livraison. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\USSD_MIGRATIONS_SERVEUR_20261101.txt` | Ajout | Rapport, instructions, audit ou suivi de livraison. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\USSD_REPRISE_20261031.txt` | Modification ; Ajout | Rapport, instructions, audit ou suivi de livraison. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\USSD_SUPPRESSION_20261101.txt` | Modification ; Ajout | Rapport, instructions, audit ou suivi de livraison. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\USSD_V1_INTEGRATION.txt` | Ajout ; Modification | Rapport, instructions, audit ou suivi de livraison. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\presentation\pages\backoffice_shell_page.dart` | Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\presentation\pages\team\backoffice_agent_issues_page.dart` | Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\core\resilience\backend_failure_policy.dart` | Modification | Logique applicative Flutter, intégration ou configuration. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\core\resilience\backend_read_stream.dart` | Ajout ; Modification | Logique applicative Flutter, intégration ou configuration. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\core\supabase\supabase_bootstrap.dart` | Modification | Logique applicative Flutter, intégration ou configuration. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\agents\presentation\pages\agent_home_page.dart` | Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\auth\data\repositories\firebase_auth_repository.dart` | Modification | Accès aux données et coordination des sources. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\customer_order\presentation\pages\customer_catalog_page.dart` | Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\customer_order\presentation\pages\customer_offer_page.dart` | Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\messaging\data\repositories\supabase_customer_messaging_repository.dart` | Modification | Accès aux données et coordination des sources. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\messaging\presentation\pages\customer_messaging_page.dart` | Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\messaging\presentation\pages\staff_customer_messaging_page.dart` | Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\navigation\presentation\pages\main_shell_page.dart` | Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\navigation\presentation\widgets\izytel_mobile_back_scope.dart` | Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\data\mappers\firestore_order_mapper.dart` | Modification | Logique applicative Flutter, intégration ou configuration. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\data\repositories\fake_orders_repository.dart` | Modification | Accès aux données et coordination des sources. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\data\repositories\firestore_orders_repository.dart` | Modification | Accès aux données et coordination des sources. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\data\repositories\supabase_phase4_assignment_repository.dart` | Modification | Accès aux données et coordination des sources. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\domain\models\queue_order.dart` | Modification | Modèle, contrat ou règle métier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\presentation\pages\agent_order_detail_view.dart` | Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\partners\presentation\pages\partner_shell_page.dart` | Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\support\presentation\pages\support_request_center_page.dart` | Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\ussd\data\supabase_ussd_repository.dart` | Modification ; Ajout | Accès aux données et coordination des sources. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\ussd\domain\ussd_engine.dart` | Modification ; Ajout | Modèle, contrat ou règle métier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\ussd\domain\ussd_repository.dart` | Modification ; Ajout | Accès aux données et coordination des sources. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\ussd\platform\ussd_dialer.dart` | Ajout | Logique applicative Flutter, intégration ou configuration. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\ussd\presentation\backoffice_ussd_page.dart` | Modification ; Ajout | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\ussd\presentation\ussd_activity_page.dart` | Ajout ; Modification | Écran ou composant d’interface Flutter. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\ussd\presentation\ussd_deletion_dialogs.dart` | Ajout ; Modification | Logique applicative Flutter, intégration ou configuration. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\ussd\presentation\ussd_quick_processing_card.dart` | Ajout ; Modification | Logique applicative Flutter, intégration ou configuration. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\ussd\presentation\ussd_rule_dialogs.dart` | Ajout ; Modification | Logique applicative Flutter, intégration ou configuration. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\pubspec.yaml` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\prepare_git_publication.ps1` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\publish_git_snapshot.ps1` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\PROPOSITION_SQL_DROITS_MESSAGERIE_NON_APPLIQUEE.sql` | Ajout | Migration ou contrôle SQL : schéma, fonctions et droits serveur. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\RAPPORT_STABILISATION.txt` | Ajout ; Modification | Rapport, instructions, audit ou suivi de livraison. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\Restore-Stabilisation.ps1` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\analysis_options.yaml` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\finalize_validation.mjs` | Ajout ; Modification | Script d’outillage, maquette ou validation. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\make_manifest.mjs` | Ajout | Script d’outillage, maquette ou validation. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\reduce_formatting.mjs` | Ajout ; Modification | Script d’outillage, maquette ou validation. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\Restore-Ussd.ps1` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_server_migrations_20261101.json` | Ajout | Configuration ou ressource du chantier. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\migrations\20261031005603_ussd_dynamic_shortcuts_v1.sql` | Modification | Migration ou contrôle SQL : schéma, fonctions et droits serveur. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\migrations\20261101003245_ussd_admin_deletion.sql` | Modification | Migration ou contrôle SQL : schéma, fonctions et droits serveur. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\tests\ussd_preflight.sql` | Ajout | Migration ou contrôle SQL : schéma, fonctions et droits serveur. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\tests\ussd_reprise_preflight.sql` | Modification ; Ajout | Migration ou contrôle SQL : schéma, fonctions et droits serveur. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\core\resilience\backend_read_stream_test.dart` | Ajout ; Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\core\resilience\operational_repositories_http_test.dart` | Ajout | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\auth\data\firebase_auth_access_failure_test.dart` | Ajout ; Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\customer_order\presentation\customer_catalog_retry_filter_test.dart` | Ajout | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\navigation\cabiniste_back_regression_test.dart` | Ajout ; Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\navigation\mobile_back_platform_regression_test.dart` | Ajout ; Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\support\presentation\support_retry_regression_test.dart` | Ajout ; Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\ussd\ussd_backoffice_widget_test.dart` | Modification ; Ajout | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\ussd\ussd_dialer_test.dart` | Ajout | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\ussd\ussd_engine_test.dart` | Ajout ; Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\ussd\ussd_mobile_widget_test.dart` | Ajout ; Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\ussd\ussd_repository_http_test.dart` | Modification ; Ajout | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\ussd\ussd_test_doubles.dart` | Modification ; Ajout | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\staff_team_navigation_contract_test.dart` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\wc13_mobile_navigation_and_zone_assignment_contract_test.dart` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\wc9_mobile_navigation_manager_agents_contract_test.dart` | Modification | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\ussd_sql\baseline_fixture.sql` | Ajout ; Modification | Migration ou contrôle SQL : schéma, fonctions et droits serveur. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\ussd_sql\deletion_cases.mjs` | Ajout | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\ussd_sql\generation_vectors.json` | Ajout | Tests ou outil de vérification du comportement. | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\ussd_sql\run.mjs` | Modification ; Ajout | Tests ou outil de vérification du comportement. | Présent |

## 5. Versions et compléments issus de Git

L’état Git est relevé le 9 novembre 2026. Les fichiers de commits complètent les événements des chats, notamment pour les écritures effectuées par scripts. Ils peuvent inclure des travaux utilisateur ou antérieurs : leur présence ne vaut pas attribution exclusive à Codex.

### État du dépôt IzyTel

Dossier : `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow`.

Aucun changement non enregistré signalé par Git lors du relevé. Cela ne signifie pas que tout le code est déployé.

Derniers commits :

- `7070624 2026-11-07 finaliser la file partagée, la supervision, le traitement rapide et la cartographie` 
- `588ca83 2026-11-02 Enregistrement des zones de l’agent, puis retrait de la modification des montants côté Agent` 
- `0b5aaee 2026-11-02 stabilisation de la partie finance` 
- `c49c24b 2026-11-01 Reprise complète du module USSD` 
- `b2ce53d 2026-10-31 chore: ignore scratch node_modules` 
- `c746026 2026-10-31 chore: exclude local Supabase CLI dependencies` 
- `10cb205 2026-10-31 feat: integration module USSD et recette` 
- `1ab7cdf 2026-10-31 Suite des modifications de code USSD` 

### Fichiers touchés par les commits depuis le 24 octobre 2026

Ce complément énumère les chemins versionnés, y compris ceux qui ne figurent pas dans les événements de modification des chats. Les chemins sont reconstruits depuis la racine du dépôt ; certains peuvent avoir été supprimés dans un commit suivant.

| Chemin absolu | Présence actuelle |
|---|---|
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\.gitignore` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\.izytel_backups\mobile_1.0.1_build2_20260918-002720\pubspec.lock` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\.izytel_backups\mobile_1.0.1_build2_r2_20260918-003524\pubspec.lock` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\AGENTS.md.txt` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\android\app\src\main\kotlin\com\izytel\app\MainActivity.kt` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\BILAN_ADMIN_FINANCE_NOTIFICATIONS_20261101.md` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\FINANCE_AUDIT_INITIAL_20261101.md` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\IDENTITE_PHOTOGRAPHIE_DISTANTE_20261101.md` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\NOTIFICATIONS_AUDIT_INITIAL_20261101.md` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\RAPPORT_1_UTILISATEURS_20261101.md` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\RAPPORT_2_FINANCE_20261101.md` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\RAPPORT_3_NOTIFICATIONS_20261101.md` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\RAPPORT_ATLAS_CORRECTIF_BACKOFFICE_20261101.md` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\RAPPORT_DEPLOIEMENT_MIGRATIONS_20261101.md` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\RAPPORT_MIGRATION_DONNEES_20261101.md` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\RECETTE_REELLE_AVANT_LIVRAISON.md` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\SENTINEL_REVUE_FINANCE_ADAPTATEURS_20261101.md` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\ACTIVATION_RECEIPT_20261106.json` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\aura-r1\index.html` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\aura-r1\prototype.css` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\aura-r1\prototype.js` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\CORRECTIF_20261106.md` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\DELIVERY_MANIFEST.json` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\DEPLOYMENT_RECEIPT_20261106.json` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\DESIGN_CONTRACT.md` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\EDGE_PREFLIGHT.json` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\FAST_PROCESSING_20261106.md` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\FAST_PROCESSING_INTEGRATION_RESULTS.json` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\FAST_PROCESSING_RECEIPT_20261106.json` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\INTEGRATION_TEST_RESULTS.json` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\LIVRAISON_20261106.md` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\REPRISE_AUDIT_20261106.md` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\SERVER_PREFLIGHT.json` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\SQL_TEST_RESULTS.json` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\visual_qa\agent-320.png` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\visual_qa\agent-390.png` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\visual_qa\agent-accepted-390.png` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\visual_qa\agent-empty-390.png` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\visual_qa\agent-offline-390.png` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\visual_qa\agent-personal-390.png` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\visual_qa\agent-quick-processing-390.png` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\visual_qa\manager-1024.png` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\visual_qa\manager-1440.png` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\visual_qa\manager-320.png` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\visual_qa\manager-390.png` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\visual_qa\manager-768.png` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\visual_qa\manager-alerts-1024.png` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\visual_qa\manager-alerts-1440.png` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\visual_qa\manager-alerts-320.png` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\visual_qa\manager-alerts-390.png` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\visual_qa\manager-alerts-768.png` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\shared_queue\WORKFLOW_STATE.md` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\territory_map\DELIVERY_20261107.md` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\territory_map\RECEIPT_20261107.json` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\territory_map\visual_qa\map-1440.png` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\territory_map\visual_qa\map-390.png` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\territory_map\visual_qa\map-768.png` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\USSD_CORRECTION_AFFICHAGE_20261031.md` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\USSD_MIGRATION_APPLICATION_20261031.md` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\USSD_MIGRATIONS_SERVEUR_20261101.txt` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\USSD_REPRISE_20261031.txt` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\USSD_SUPPRESSION_20261101.txt` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\USSD_V1_INTEGRATION.txt` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\docs\UTILISATEURS_AUDIT_INITIAL_20261101.md` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\fichier_test.txt` | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\firestore.rules` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\IzyTel_debug_bundle_20260901.txt` | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\IzyTel_sources_correction.zip` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\izytel_web_navigation_20260928_173512.zip` | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\app\app.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\backoffice_app.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\data\repositories\backoffice_user_administration_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\data\repositories\firestore_backoffice_user_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\data\repositories\supabase_backoffice_finance_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\data\repositories\supabase_territory_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\domain\models\backoffice_finance_snapshot.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\domain\models\backoffice_user_account.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\domain\models\territory_models.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\domain\repositories\backoffice_finance_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\domain\repositories\backoffice_user_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\presentation\pages\backoffice_shell_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\presentation\pages\backoffice_users_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\presentation\pages\finances\backoffice_finance_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\presentation\pages\operations\backoffice_orders_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\presentation\pages\team\backoffice_agent_issues_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\presentation\pages\team\backoffice_managers_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\presentation\pages\team\backoffice_zones_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\presentation\widgets\backoffice_territory_map.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\backoffice\presentation\widgets\backoffice_user_admin_dialog.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\core\diagnostics\startup_trace.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\core\resilience\backend_failure_policy.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\core\resilience\backend_read_stream.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\core\supabase\supabase_bootstrap.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\core\supabase\supabase_realtime_refetch.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\agents\data\repositories\fake_agent_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\agents\data\repositories\firestore_agent_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\agents\data\repositories\supabase_agent_operations_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\agents\domain\models\agent_models.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\agents\presentation\pages\agent_activity_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\agents\presentation\pages\agent_home_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\agents\presentation\view_models\agent_activity_view_model.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\auth\data\repositories\firebase_auth_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\auth\presentation\widgets\session_access_boundary.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\commissions\data\repositories\hybrid_commission_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\commissions\data\repositories\supabase_commission_v2_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\commissions\presentation\pages\commission_v2_dashboard_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\customer_order\data\repositories\supabase_customer_offer_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\customer_order\presentation\pages\customer_catalog_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\customer_order\presentation\pages\customer_offer_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\customer_order\presentation\pages\customer_order_flow_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\finances\data\repositories\manager_read_only_finance_operations_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\finances\data\repositories\supabase_finance_operations_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\finances\domain\services\finance_calculators.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\finances\domain\services\finance_operation_key.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\finances\presentation\pages\daily_financial_closing_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\finances\presentation\pages\finance_expenses_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\finances\presentation\pages\finances_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\finances\presentation\pages\supplier_finance_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\finances\presentation\pages\wave_cash_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\finances\presentation\widgets\financial_intent_retry.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\messaging\data\repositories\supabase_customer_messaging_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\messaging\presentation\pages\customer_messaging_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\messaging\presentation\pages\staff_customer_messaging_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\navigation\presentation\pages\main_shell_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\navigation\presentation\widgets\izytel_mobile_back_scope.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\data\mappers\firestore_order_mapper.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\data\repositories\fake_orders_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\data\repositories\firestore_orders_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\data\repositories\hybrid_orders_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\data\repositories\supabase_phase4_assignment_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\data\repositories\supabase_shared_order_queue_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\domain\models\queue_order.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\domain\repositories\shared_order_queue_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\presentation\pages\agent_order_detail_view.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\presentation\pages\agent_orders_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\presentation\pages\order_supervision_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\presentation\pages\orders_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\presentation\pages\shared_agent_orders_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\presentation\view_models\agent_orders_view_model.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\orders\presentation\view_models\shared_order_queue_view_model.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\partners\presentation\pages\partner_shell_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\support\data\repositories\supabase_support_request_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\support\presentation\pages\support_request_center_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\ussd\data\supabase_ussd_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\ussd\domain\ussd_engine.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\ussd\domain\ussd_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\ussd\platform\ussd_dialer.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\ussd\presentation\backoffice_ussd_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\ussd\presentation\ussd_activity_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\ussd\presentation\ussd_deletion_dialogs.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\ussd\presentation\ussd_quick_processing_card.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\features\ussd\presentation\ussd_rule_dialogs.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\lib\main_backoffice_web.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\pubspec.lock` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\pubspec.yaml` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\artifacts_sha256.json` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\before.sha256` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\changes_manifest.json` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\original\lib\core\resilience\backend_failure_policy.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\original\lib\core\supabase\supabase_bootstrap.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\original\lib\core\supabase\supabase_realtime_refetch.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\original\lib\features\agents\presentation\pages\agent_home_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\original\lib\features\auth\data\repositories\firebase_auth_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\original\lib\features\customer_order\data\repositories\supabase_customer_offer_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\original\lib\features\customer_order\presentation\pages\customer_catalog_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\original\lib\features\customer_order\presentation\pages\customer_offer_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\original\lib\features\messaging\data\repositories\supabase_customer_messaging_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\original\lib\features\messaging\presentation\pages\customer_messaging_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\original\lib\features\messaging\presentation\pages\staff_customer_messaging_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\original\lib\features\navigation\presentation\pages\main_shell_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\original\lib\features\navigation\presentation\widgets\izytel_mobile_back_scope.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\original\lib\features\partners\presentation\pages\partner_shell_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\original\lib\features\support\data\repositories\supabase_support_request_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\original\lib\features\support\presentation\pages\support_request_center_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\original\test\features\navigation\navigation_and_search_regression_contract_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\original\test\regressions\backoffice_supabase_realtime_fallback_and_dialog_contract_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\original\test\regressions\bo4_catalog_realtime_end_to_end_contract_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\original\test\regressions\customer_web_responsive_startup_realtime_contract_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\original\test\regressions\customer_web_v2_wc3b_live_refresh_contract_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\original\test\regressions\phase14_ui_runtime_fixes_contract_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\original\test\regressions\wc9_mobile_navigation_manager_agents_contract_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\PROPOSITION_SQL_DROITS_MESSAGERIE_NON_APPLIQUEE.sql` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\RAPPORT_STABILISATION.txt` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\Restore-Stabilisation.ps1` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\stabilisation_20261030\VALIDATION.json` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\baseline.json` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\formatted\lib\backoffice\presentation\pages\backoffice_shell_page.dart` | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\formatted\lib\backoffice\presentation\pages\backoffice_shell_page.dart.txt` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\formatted\lib\backoffice\presentation\pages\team\backoffice_agent_issues_page.dart` | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\formatted\lib\backoffice\presentation\pages\team\backoffice_agent_issues_page.dart.txt` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\formatted\lib\features\orders\data\mappers\firestore_order_mapper.dart` | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\formatted\lib\features\orders\data\mappers\firestore_order_mapper.dart.txt` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\formatted\lib\features\orders\data\repositories\fake_orders_repository.dart` | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\formatted\lib\features\orders\data\repositories\fake_orders_repository.dart.txt` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\formatted\lib\features\orders\data\repositories\firestore_orders_repository.dart` | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\formatted\lib\features\orders\data\repositories\firestore_orders_repository.dart.txt` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\formatted\lib\features\orders\data\repositories\supabase_phase4_assignment_repository.dart` | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\formatted\lib\features\orders\data\repositories\supabase_phase4_assignment_repository.dart.txt` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\formatted\lib\features\orders\domain\models\queue_order.dart` | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\formatted\lib\features\orders\domain\models\queue_order.dart.txt` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\formatted\lib\features\orders\presentation\pages\agent_order_detail_view.dart` | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\formatted\lib\features\orders\presentation\pages\agent_order_detail_view.dart.txt` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\formatted\lib\features\partners\presentation\pages\partner_shell_page.dart` | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\formatted\lib\features\partners\presentation\pages\partner_shell_page.dart.txt` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\minimal\lib\backoffice\presentation\pages\backoffice_shell_page.dart` | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\minimal\lib\backoffice\presentation\pages\backoffice_shell_page.dart.txt` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\minimal\lib\backoffice\presentation\pages\team\backoffice_agent_issues_page.dart` | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\minimal\lib\backoffice\presentation\pages\team\backoffice_agent_issues_page.dart.txt` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\minimal\lib\features\orders\data\mappers\firestore_order_mapper.dart` | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\minimal\lib\features\orders\data\mappers\firestore_order_mapper.dart.txt` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\minimal\lib\features\orders\data\repositories\fake_orders_repository.dart` | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\minimal\lib\features\orders\data\repositories\fake_orders_repository.dart.txt` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\minimal\lib\features\orders\data\repositories\firestore_orders_repository.dart` | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\minimal\lib\features\orders\data\repositories\firestore_orders_repository.dart.txt` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\minimal\lib\features\orders\data\repositories\supabase_phase4_assignment_repository.dart` | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\minimal\lib\features\orders\data\repositories\supabase_phase4_assignment_repository.dart.txt` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\minimal\lib\features\orders\domain\models\queue_order.dart` | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\minimal\lib\features\orders\domain\models\queue_order.dart.txt` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\minimal\lib\features\orders\presentation\pages\agent_order_detail_view.dart` | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\minimal\lib\features\orders\presentation\pages\agent_order_detail_view.dart.txt` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\minimal\lib\features\partners\presentation\pages\partner_shell_page.dart` | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\minimal\lib\features\partners\presentation\pages\partner_shell_page.dart.txt` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\original\lib\backoffice\presentation\pages\backoffice_shell_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\original\lib\backoffice\presentation\pages\team\backoffice_agent_issues_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\original\lib\features\orders\data\mappers\firestore_order_mapper.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\original\lib\features\orders\data\repositories\fake_orders_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\original\lib\features\orders\data\repositories\firestore_orders_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\original\lib\features\orders\data\repositories\supabase_phase4_assignment_repository.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\original\lib\features\orders\domain\models\queue_order.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\original\lib\features\orders\presentation\pages\agent_order_detail_view.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\original\lib\features\partners\presentation\pages\partner_shell_page.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\original\MainActivity.kt` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\scratch\ussd_20261031\reduce_formatting.mjs` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\.temp\cli-latest` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\functions\izytel-notification-dispatch\index.ts` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\functions\izytel-user-admin\core.mjs` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\functions\izytel-user-admin\core.test.mjs` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\functions\izytel-user-admin\deno.json` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\functions\izytel-user-admin\index.ts` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\functions\izytel-user-admin\README.md` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\migrations\20261031005603_ussd_dynamic_shortcuts_v1.sql` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\migrations\20261031224809_ussd_template_aliases_secret_and_draft_catalog.sql` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\migrations\20261101003245_ussd_admin_deletion.sql` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\migrations\20261101011937_notifications_territory_delivery_recovery.sql` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\migrations\20261101012308_finance_mobile_canonical_reads.sql` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\migrations\20261101062456_finance_exact_wave_totals_and_expense_idempotency.sql` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\migrations\20261101062508_admin_accounts_lifecycle.sql` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\migrations\20261101142339_notifications_retry_scheduler.sql` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\migrations\20261102012359_agent_operations_staff_capacity.sql` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\migrations\20261106004036_shared_agent_queue_and_sla.sql` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\migrations\20261106224728_fast_processing_without_proof.sql` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\migrations\20261107002724_territory_managed_profiles_compatibility.sql` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\operations\shared_queue_activate.sql` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\operations\shared_queue_activation_executed_20261106.sql` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\operations\shared_queue_publish_three_20261106.sql` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\operations\shared_queue_rollback.sql` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\tests\agent_operations_capacity_test.mjs` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\tests\finance_mobile_canonical_test.mjs` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\tests\notifications_dispatch_test.mjs` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\tests\notifications_pipeline_test.mjs` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\tests\user_admin_behavior_test.mjs` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\tests\user_admin_preflight.sql` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\tests\ussd_preflight.sql` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\supabase\tests\ussd_reprise_preflight.sql` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\backoffice\finance_read_recovery_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\backoffice\supabase_backoffice_finance_repository_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\backoffice\territory_map_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\backoffice\territory_map_visual_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\backoffice\territory_repository_http_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\backoffice\user_administration_dialog_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\backoffice\user_administration_repository_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\core\resilience\backend_failure_policy_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\core\resilience\backend_read_stream_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\core\resilience\operational_repositories_http_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\core\resilience\supabase_finance_refresh_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\agents\presentation\view_models\agent_activity_view_model_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\auth\data\firebase_auth_access_failure_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\auth\presentation\session_access_boundary_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\commissions\data\supabase_commission_v2_repository_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\customer_order\presentation\customer_catalog_retry_filter_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\finances\data\finance_operation_key_transport_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\finances\data\supabase_finance_operations_repository_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\finances\domain\exact_wave_totals_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\finances\financial_intent_retry_widget_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\navigation\cabiniste_back_regression_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\navigation\mobile_back_platform_regression_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\navigation\navigation_and_search_regression_contract_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\orders\data\repositories\fake_orders_agent_processing_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\orders\data\repositories\shared_queue_payment_publication_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\orders\presentation\fast_processing_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\orders\presentation\pages\agent_proof_source_contract_test.dart` | Absent à ce chemin |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\orders\presentation\shared_order_queue_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\orders\presentation\shared_order_queue_visual_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\orders\presentation\view_models\agent_orders_auto_assignment_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\orders\presentation\view_models\agent_orders_view_model_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\support\presentation\support_retry_regression_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\ussd\ussd_backoffice_widget_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\ussd\ussd_dialer_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\ussd\ussd_engine_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\ussd\ussd_mobile_widget_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\ussd\ussd_repository_http_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\features\ussd\ussd_test_doubles.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\finance_sql\run.mjs` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\backoffice_bo1_foundation_contract_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\backoffice_bo3c_territory_contract_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\backoffice_supabase_realtime_fallback_and_dialog_contract_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\bo4_catalog_realtime_end_to_end_contract_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\customer_web_responsive_startup_realtime_contract_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\customer_web_v2_wc3b_live_refresh_contract_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\notifications_complete_block_contract_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\phase14_ui_runtime_fixes_contract_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\phase3_runtime_closure_contract_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\phase3_stabilization_contract_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\phase4_release_payment_resilience_contract_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\staff_team_navigation_contract_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\supabase_phase3_suppliers_contract_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\supabase_phase4_assignment_contract_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\wc13_mobile_navigation_and_zone_assignment_contract_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\wc6_manager_registry_zone_creation_fix_contract_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\wc9_1_compile_scope_hotfix_contract_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\regressions\wc9_mobile_navigation_manager_agents_contract_test.dart` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\device_scenarios.dart.template` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\existing_metadata.json` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\fixtures\territory_profiles_before_compatibility.sql` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\integration_actions.json` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\integration_extra_functions.json` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\integration_extra_metadata.json` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\integration_function_grants.json` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\integration_functions.json` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\integration_metadata.json` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\integration.mjs` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\package-lock.json` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\package.json` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\postgres.mjs` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\prepare_android_qa.ps1` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\prepare_visual_qa.ps1` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\README.md` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\run.mjs` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\shared_queue\territory_profiles.mjs` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\ussd_sql\baseline_fixture.sql` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\ussd_sql\deletion_cases.mjs` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\ussd_sql\generation_vectors.json` | Présent |
| `C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow\test\ussd_sql\run.mjs` | Présent |


## 6. Limites et vérifications restantes

- L’état distant est celui consigné lors des interventions, pas une nouvelle certification de production.
- Les différentes versions USSD doivent être interprétées chronologiquement ; ne pas appliquer une ancienne migration sur la seule base de ce README.
- Les builds locaux et APK ne prouvent pas que chaque utilisateur utilise la nouvelle application.
- La réception FCM sur appareil, les parcours authentifiés et les cas sur appareils physiques restent à confronter aux rapports de recette.
- Les historiques financiers, comptes legacy et capacités insuffisantes conservent les limites indiquées dans les rapports.
- Les tests cités appartiennent à des versions et périmètres différents : leurs nombres ne doivent pas être additionnés.

## 7. Sources documentaires

Les quatre chats examinés sont « Auditer le projet IzyTel », « Stabiliser admin, finance et alertes », « Mettre en place une file partagée » et « Auditer la file partagée des command » (titre tel que retourné par l’application).

Les documents locaux de référence sont le bilan Administration/Finance/Notifications, les rapports USSD, le rapport de stabilisation, le dossier shared_queue et le rapport territory_map mentionnés plus haut. Les autres projets ont été exclus, hormis le dossier de maquette IzyTel historiquement rangé dans SUPERVISION-VISIOS.

