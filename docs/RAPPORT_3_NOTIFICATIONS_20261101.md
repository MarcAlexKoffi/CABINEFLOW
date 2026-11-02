# Rapport 3 — Notifications — 1 novembre 2026

Ordre appliqué : ORION (photographie initiale), ATLAS (correctifs locaux), SENTINEL (contre-lecture et vérifications locales). Rapport initial : `NOTIFICATIONS_AUDIT_INITIAL_20261101.md`. Les changements ci-dessous sont préparés sur la branche active ; aucune migration appliquée à distance, aucun déploiement et aucun envoi FCM réel. En contre-revue finale, des SELECT de métadonnées ont confirmé la présence du helper système WC5, les types UUID partenaires et l'absence de pg_cron. Aucune donnée utilisateur n'a été modifiée.

## Architecture conservée

Événements SQL → `izytel_notification_outbox` → ticket nonce / pg_net → Edge Function existante → FCM. Firebase reste le transport mobile. Registre multi-appareils, authentification Firebase et messages système existants sont conservés. Aucune nouvelle clé privée embarquée, aucune variable d'environnement nouvelle. Les variables serveur existantes restent SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, FIREBASE_SERVICE_ACCOUNT_JSON.

La migration locale `20261101011937_notifications_territory_delivery_recovery.sql` a été créée avec le CLI Supabase puis remplie. Elle ajoute `next_attempt_at`, une table protégée `izytel_notification_deliveries`, un résolveur territorial privé, les événements métier ci-dessous et une reprise bornée de l'outbox. La table de livraison est inaccessible aux rôles clients ; seul service_role écrit/lit cette journalisation.

## Matrice après correctifs locaux

La colonne canal distingue la création d'un événement de sa livraison. Client Web ne dispose d'aucun token FCM ; ses événements push peuvent finir skipped/NO_ACTIVE_DEVICE. Pour paiement, remboursement et prise en charge/résolution support, un trigger AFTER INSERT de l'outbox produit aussi un message système persistant dans la messagerie existante : cette livraison in-app ne dépend pas de FCM.

| Événement | Destinataire | Canal et contenu | Clic | Priorité Android | Déduplication |
|---|---|---|---|---|---|
| Affectation / réaffectation Agent | assigned_agent_id | FCM référence/réseau/montant existants | Commande relue dans sa file | haute | Clé affectation existante |
| Affectation Cabiniste | partner_accounts.firebase_uid pour assigned_cabiniste_id et compte active | FCM texte générique | Relit les commandes de son compte puis ouvre le détail correspondant | haute | commande + partenaire + assigned_at/updated_at |
| Retrait d'affectation Agent | ancien assigned_agent_id | FCM générique | File autorisée ; repli si commande retirée | normale | commande + ancien UID + updated_at |
| Affectation manuelle | Manager actif de la zone active ; sinon Admin actifs | FCM contenu existant | Détail/liste commande | haute | Clé existante par destinataire |
| Signalement Agent nouveau | Managers des zones de l'Agent ; Admin de repli pour zone sans responsable / Agent sans zone | FCM type existant | Centre signalements | normale | issue + new + destinataire |
| Signalement résolu | Agent | FCM texte fixe | Liste signalements | normale | issue + resolved existante |
| Commande failed | Manager de zone ou escalade Admin | FCM générique « analyse nécessaire » | Commande relue | haute | commande + destinataire + updated_at |
| Paiement confirmed | customer_auth_uid | Outbox + message système persistant paiement pris en compte | Messagerie existante | normale | payment_confirmed + commande |
| Commande completed | customer_auth_uid | Événement outbox ; message système existant conservé | Payload commande ; message dans messagerie Web | normale | order_completed + commande pour push ; ancienne déduplication du message système conservée |
| Nouvelle support_request | Manager zone de commande, sinon Admin | FCM générique sans description libre | Détail commande ; supportRequestId inclus | normale | support + demande + destinataire |
| Support inProgress / resolved | customer_auth_uid | Outbox + message système persistant générique | Messagerie existante ; réponse détaillée Manager séparée | normale | événement + demande |
| Remboursement refunded | customer_auth_uid | Outbox + message système persistant ; action détaillée existante conservée | Messagerie existante | normale | refund_completed + commande |
| Message client / réponse Manager | Résolution WC7 existante | Outbox FCM ; Client Web ouvert via conversations | Conversation staff existante ; Web via navigation messagerie | normale | message + destinataire existant |

Les alertes Client Web ouvertes acceptent désormais les messages système et les nouvelles conversations reçues après le premier instantané. Le premier instantané est toujours considéré comme historique et ne produit pas d'alertes en rafale. La comparaison temporelle reste en mémoire pendant la session.

ORION complémentaire : un événement outbox seul était insuffisant pour le Client Web. ATLAS a donc réutilisé `private.izytel_wc5_emit_customer_system_message`, le canal `customer_messages` et ses autorisations de lecture existantes. Le trigger d'insertion s'exécute uniquement pour les quatre types client précités, une fois par insertion dédupliquée ; les retries de dispatch ne rejouent pas la projection. Il ne crée aucun RPC de messages libres Agent→Client et n'expose aucun nonce au client. Le système de messagerie existant est déjà la projection de lecture du propriétaire : aucun deuxième flux de lecture outbox parallèle n'est ajouté. L'écriture est transactionnelle : une erreur de projection remonte et annule la transition au lieu d'annoncer silencieusement une notification persistante inexistante. Cette dépendance au helper WC5 doit être vérifiée en recette avant application.

## Outbox et livraison

- Claim exclusif SKIP LOCKED, cinq tentatives maximum, prochain essai exponentiel (30 s × 2^tentative), bail processing de dix minutes. Les événements failed ne sont pas réémis automatiquement au-delà du plafond.
- Un statut par couple outbox/appareil évite de réenvoyer lors d'un retry aux appareils déjà acceptés par FCM. Un succès partiel laisse la notification pending si un autre appareil présente une erreur transitoire.
- ID notification transmis et tag Android stable pour regrouper l'affichage. `sent` signifie acceptation FCM, pas lecture utilisateur.
- Classification UNREGISTERED précise : un HTTP 404 générique ne suffit plus à désactiver un token. Les réponses invalides désactivent l'appareil. Les erreurs d'écriture des statuts sont vérifiées. Mises à jour finales conditionnées par le bail acquis.
- Timeout OAuth et FCM de quinze secondes. Batch ramené à dix événements pour limiter la durée du worker.
- Réveil privé récurrent réutilisant le ticket protégé et l'endpoint existant. Si pg_cron est déjà installé, la migration prépare un job chaque minute. Sinon elle émet une NOTICE ; l'extension et le job doivent être configurés lors d'un déploiement autorisé. Un SELECT final a confirmé que pg_cron n'est actuellement pas installé sur le projet examiné. Ce prérequis est nécessaire à une reprise sans nouvel événement.

## Deep links et Web

Le clic Cabiniste relit `fetchAssignedOrders()`, qui filtre par le compte partenaire courant, avant d'ouvrir `PartnerOrderDetailPage`. Aucune donnée reçue dans le payload ne suffit à accorder un droit. Si la commande n'est plus dans cette file, un message de repli est affiché. Les parcours Agent/staff et la conservation du lancement fermé restent ceux du bootstrap existant.

Le Client Web et le Back-office restent sans Web Push : aucun VAPID, service worker FCM, permission navigateur ni notificationclick ajouté. Realtime et polling sont des canaux in-app. Cette décision évite d'annoncer une couverture background qui n'existe pas et ne crée pas de système de notification parallèle.

## Vérifications exécutées

- `node supabase/tests/notifications_pipeline_test.mjs` : PASS. Exécute le socle SQL et la nouvelle migration dans PGlite en mémoire avec schémas de test : deux zones, Manager inactif et escalade Admin, routage incidents/support, paiement et succès simultanés, répétition d'une transition, remboursement répété, exclusivité du claim, récupération bail expiré, plafond, privilèges de la table, affectation Cabiniste, échec Manager, fonction de réveil avec transport SQL simulé, prise en charge/résolution support répétées. Les quatre messages persistants attendus sont vérifiés avec un helper d'écriture système simulé ; ni répétition de transition ni dispatch ne crée une seconde projection.
- `node supabase/tests/notifications_dispatch_test.mjs` : PASS. Exécute le code réel du transport et du handler avec services simulés : ID/tag, classification token invalide, succès partiel multi-appareils puis retry uniquement de l'appareil en échec, garde du bail. Aucun réseau n'est envoyé. OAuth est simulé avec une clé éphémère générée pour ce seul processus.
- `node --experimental-strip-types --check supabase/functions/izytel-notification-dispatch/index.ts` : PASS syntaxe TypeScript. Cela ne remplace pas un contrôle Deno/types des imports réels.

Le runner SQL utilise l'installation PGlite locale déjà présente dans `scratch/ussd_reprise_tools/node_modules`. Il exécute aussi le garde propriétaire existant WC5 et le contrat de policy SELECT des messages : le client voit sa conversation, un autre UID ne la voit pas. La définition distante du garde a été lue et concorde avec ce contrat. Les fixtures ne reproduisent pas toute la base distante et ses RLS. Validation consolidée : **1077 tests Flutter réussis**, analyse sans diagnostic et builds Android debug, Back-office Web et Client Web réussis. Les commandes et limites figurent dans le [bilan final](BILAN_ADMIN_FINANCE_NOTIFICATIONS_20261101.md).

## Contre-vérification SENTINEL et limites restantes

La revue a identifié puis corrigé les contrats Cabiniste : le registre utilise `status='active'`, les affectations utilisent assigned_cabiniste_id et la clé partenaire est UUID (comparaison JSON textuelle explicitement convertie). Les tests SQL incluent ce contrat avec clé UUID. Le réveil a également été exécuté localement avec un transport simulé.

Limites explicites :

- Aucun test appareil Android foreground/background/killed, permission, rotation réelle, logout hors ligne, Firebase réel ou notification reçue effectué. Aucun test navigateur fermé. Aucun test live session expirée/autre compte/interdiction RLS effectué.
- Une acceptation FCM suivie d'une panne avant écriture du journal reste une fenêtre de réémission possible ; FCM ne fournit pas ici de transaction atomique avec Postgres. ID/tag limite l'affichage dupliqué, sans garantie exactly-once physique.
- Le chantier Administration désactive les appareils des comptes modifiés et ajoute, dans `20261101062508_admin_accounts_lifecycle.sql`, un trigger du registre empêchant un ancien JWT de réinscrire/réactiver un appareil actif pour un compte administré sans population SQL active. Les Staff/Agents/Cabinistes actifs, la désactivation et les clients historiques inconnus restent compatibles. Le runner SQL comptes vérifie ces cas localement. Le dispatch lit toujours les appareils actifs : les comptes historiques jamais administrés restent à migrer, et le comportement réel après révocation/FCM reste à tester sur appareil ; aucun claim n'est modifié par ce chantier.
- Les messages système historiques gardent leur déduplication par texte sur trente secondes. Les nouveaux événements outbox ont des clés durables, mais la fenêtre des anciens messages système n'est pas présentée comme corrigée.
- Une confirmation de commande autonome n'a pas été inventée : seuls les états réellement identifiés confirmed pour paiement et completed/failed pour commande sont raccordés. Retrait Cabiniste, alerte générale de litige, demande de remboursement avant décision, décision Manager spécifique et incidents financiers/sécurité globaux restent non couverts tant que leur événement canonique et leur politique d'escalade ne sont pas définis/testés.
- Les notifications client outbox ne remplacent pas un canal Web push absent. Paiement, prise en charge/résolution support et remboursement sont consultables dans la messagerie existante après projection système ; les données historiques antérieures à la migration ne sont pas réémises. Le test local simule le helper WC5, donc sa résolution réelle du propriétaire et ses RLS complètes restent à tester en recette. Aucun « tout fonctionne » ne peut être conclu de ces tests locaux.

## Fichiers et recette restante

Fichiers métier modifiés : `lib/features/customer_order/presentation/pages/customer_order_flow_page.dart`, `lib/features/partners/presentation/pages/partner_shell_page.dart`, `supabase/functions/izytel-notification-dispatch/index.ts`. Nouveaux : migration notifications précitée, deux runners dans `supabase/tests`, audit initial et ce rapport. Les scripts de composition sous scratch sont des outils locaux de préparation, sans exécution au démarrage du produit.

Avant recette réelle : appliquer uniquement après autorisation la migration et la fonction ensemble, vérifier helpers/colonnes et RLS sur environnement de recette, configurer pg_cron, vérifier secrets serveur déjà prévus, exécuter scénarios Android/session/multi-appareils et observer pending/processing/sent/failed/skipped. Actions distantes : SELECT de métadonnées et définition de garde de lecture uniquement ; aucune écriture et aucun déploiement.

Documentation consultée pour la reprise planifiée : [Supabase — Scheduling Edge Functions](https://supabase.com/docs/guides/functions/schedule-functions), [changelog](https://supabase.com/changelog). La planification retenue conserve l'authentification nonce existante ; la clé publishable déjà présente n'est pas utilisée comme preuve d'autorisation.
