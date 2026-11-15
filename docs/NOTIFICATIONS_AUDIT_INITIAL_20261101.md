# IzyTel — audit initial notifications — 1 novembre 2026

Intervention ORION, lecture des sources locales uniquement. Aucun appel distant, aucun envoi FCM, aucune modification de données, aucun déploiement. Ce document décrit le code présent ; il ne prouve ni l'application des SQL en base ni la configuration des secrets serveur. Les tests cités sont inventoriés, pas exécutés dans cet audit.

## Architecture constatée

- `lib/main.dart` initialise `FirebaseMessagingBootstrap`. Le bootstrap accepte Android/iOS et exclut explicitement le Web. Il installe onMessage, onMessageOpenedApp, onTokenRefresh, getInitialMessage et un handler background. Le handler background journalise seulement le type ; la notification système est fournie par le payload FCM notification envoyé par le serveur. Aucun plugin de notification locale n'est utilisé dans cette chaîne.
- La permission est demandée après connexion via ensureReady ; relecture du token avec tentatives bornées. Un payload de lancement est conservé jusqu'à consommation par un shell. Ce stockage est une seule valeur en mémoire, pas une file persistante.
- `IzyTelNotificationDeviceRegistry` exige une session Firebase cohérente avec AppUser, enregistre les tokens via RPC Supabase, écoute leur rotation, rafraîchit au retour foreground et désactive le token courant à la déconnexion. Les erreurs ne bloquent pas le métier. Une déconnexion hors ligne peut laisser un token actif côté serveur.
- `20260906_izytel_notifications_block.sql` fournit registre, outbox, enqueue privé, claim SKIP LOCKED et réveil pg_net après insertion. `20260911_phase3_stabilization_security_hardening.sql` déplace les écritures du registre dans des implémentations privées et interdit les accès directs aux tables. Les RPC de registre lient l'UID au sub du JWT Firebase ; elles ne vérifient pas ici l'état actif du registre métier.
- Plusieurs tokens peuvent appartenir au même UID ; un token est unique et réattribué au nouvel UID lors d'un upsert. Les anciens tokens d'une rotation restent actifs jusqu'à réponse invalide FCM ou désactivation explicite. Pas d'identifiant stable d'installation ni d'expiration automatique observés.
- `supabase/functions/izytel-notification-dispatch/index.ts` exige un ticket outboxId + nonce protégé, utilise service_role et FIREBASE_SERVICE_ACCOUNT_JSON exclusivement côté serveur, obtient OAuth Google et envoie FCM HTTP v1. Priorité Android `high` pour tous les événements. Pas de priorité métier stockée, pas d'ID notification transmis pour déduplication côté appareil.
- La migration WC7 ajoute les événements de messages client et Manager. La sortie système est explicitement ignorée par ce trigger (`sender_type not in ('client','manager')`).
- Les messages système de succès/support/remboursement réutilisent customer_messages via `CustomerMessagingDeliveryService`. La définition WC5 examinée est dans `supabase/wc5_territorial_routing_messaging_and_contacts.sql`, un script hors `supabase/migrations` : sa présence ne prouve pas son application distante.

## Matrice de couverture réelle

`FCM*` signifie événement outbox codé, livraison conditionnée à un appareil actif et à la configuration serveur. La priorité existante est uniformément haute Android. Les priorités recommandées figurent plus bas.

| Événement | Destinataire constaté | Canal / contenu | Clic constaté | Priorité actuelle | Déduplication existante |
|---|---|---|---|---|---|
| Nouvelle affectation | assigned_agent_id, donc Agent/Cabiniste si cet UID est affecté | FCM* référence, réseau, montant | Agent : recherche dans sa file puis détail ; Cabiniste : onglet commandes uniquement | high | order + UID + assigned_at/updated_at |
| Réaffectation | nouvel assigned_agent_id | FCM* même contenu | Même comportement | high | Même clé ; notification du précédent affectataire absente |
| Affectation manuelle requise | tous staff actifs manager/supervisor/admin | FCM* référence, réseau, montant | Staff : détail commande ou liste de repli | high | order + destinataire + updated_at |
| Nouveau signalement Agent | tous staff actifs manager/supervisor/admin | FCM* type du signalement | Centre des signalements, sans sélection issueId | high | issue + new + destinataire |
| Signalement résolu | agent_id | FCM* texte fixe | Liste des signalements Agent, sans sélection issueId | high | issue + resolved ; une seule émission à vie pour ce type |
| Message client | Manager affecté ; sinon Manager de zone active ; sinon tous Admin actifs | FCM* nom, référence éventuelle, aperçu 180 caractères | Messagerie staff + conversationId | high | message + manager/admin + UID |
| Réponse Manager | customer_auth_uid | FCM* aperçu ; Client Web ouvert : flux conversations et feedback | Pas de gestionnaire FCM Client Web ; messagerie accessible par navigation habituelle | high si FCM | message + client + UID ; feedback Web basé sur lastMessageAt |
| Commande terminée | client lié à la commande | Message système, texte serveur dans script WC5 ; appel complémentaire Flutter notifyCompletedOrder | Conversation à ouvrir dans la messagerie ; pas de push système WC7 | aucune push | Émetteur système WC5 : même texte/conversation sur fenêtre de 30 s, pas une clé durable d'événement |
| Support traité | client, action explicite Manager/Admin dans les pages support | Message système avec résolution via notifyOrder | Messagerie | aucune push | Même déduplication temporelle système WC5 ; markCustomerNotified séparé |
| Remboursement effectué | client, action explicite « notifier » dans les pages remboursement | Message système montant, référence éventuelle | Messagerie | aucune push | Même déduplication temporelle ; pas d'atomicité entre remboursement et notification |
| Demande de paiement Wave | client, action explicite sur SendWaveLinkPage | Message système avec texte de paiement | Messagerie / lien contenu dans le message | aucune push | Message puis markPaymentRequestAsSent séparés |

La réception foreground mobile affiche un feedback transitoire dans les shells ; aucun centre de notifications persistant ou statut lu/non lu de l'outbox n'est exposé. Les messages restent, eux, consultables dans les conversations.

## Événements minimaux sans couverture automatique démontrée

La recherche des appels à enqueue dans toutes les migrations retourne les deux seuls scripts notification ci-dessus. Elle ne démontre aucun événement outbox pour : paiement pris en compte, commande confirmée, échec de commande à analyser, échec pris en charge côté client, retrait d'affectation vers l'ancien exécutant, décision Manager spécifique, création de demande de remboursement/support hors messagerie, évolution d'un litige, incident financier critique, événement de sécurité/compte ou système global. Un écran affichant un statut ne constitue pas une notification.

Le remboursement et le support disposent bien d'actions de message système ; ils ne doivent pas être présentés comme des notifications push automatiques. Le succès dispose d'un trigger métier dans le script WC5 et d'un appel Flutter, mais les messages système sont exclus du trigger push WC7. Le feedback global Client Web ignore également les messages système : il accepte seulement lastSenderType.manager et ignore une conversation absente du précédent instantané. Une nouvelle conversation contenant un message système de succès est consultable, sans alerte globale démontrée.

## Lacunes et risques démontrés

1. **Périmètre territorial** : les boucles de `izytel_phase4_notification_trigger` pour manual_required et `izytel_agent_issue_notification_trigger` pour agent_issue_new filtrent uniquement is_active et rôle. Aucun filtre de zone. Le titre et le corps peuvent divulguer une référence/montant à des Managers hors zone, indépendamment de la protection au clic. Le canal Admin reçoit aussi toutes ces alertes ordinaires.
2. **Reprise outbox** : le claim ne prend que pending. Le dispatch écrit failed après erreur et ne reprogramme pas de retry. Aucun plafond d'essais, next_attempt_at, reprise de processing expiré ou ordonnanceur dédié observé dans cette chaîne. Un arrêt après claim laisse processing ; un échec pg_net peut laisser pending sans nouveau réveil. Une insertion ultérieure réveille un batch mais ce n'est pas une garantie de reprise.
3. **Livraison partielle** : un seul succès parmi les appareils marque toute la ligne sent. L'échec d'un autre appareil n'est conservé que dans last_error. Aucun accusé par appareil. Une réémission globale risquerait de renvoyer aux appareils déjà servis.
4. **Acceptation FCM vs réception** : sent signifie réponse HTTP positive FCM, pas preuve de lecture ni de réception physique. Les erreurs des updates Supabase finaux ne sont pas vérifiées. Une erreur après envoi réussi empêche d'affirmer l'unicité de livraison.
5. **Jetons** : désactivation prévue pour 404/UNREGISTERED ; aucun nettoyage par ancienneté. La détection traite tout 404 comme token invalide, sans distinguer une mauvaise configuration de projet. Aucun contrôle métier actif au dispatch avant lecture des appareils. La rotation ajoute un token sans désactiver l'ancien.
6. **Identité à l'ouverture** : le payload pending n'est pas lié au destinataire ni nettoyé lors d'un changement de compte par le bootstrap. Il ne faut jamais lui faire confiance pour autoriser une ressource. Agent recherche dans sa file, mais le contrôle serveur des fetch staff et des conversations nécessite recette RLS séparée. Aucun test runtime session expirée/autre compte n'a été exécuté ici.
7. **Précision de navigation** : Cabiniste ouvre une liste et non la commande ciblée ; issueId n'est pas utilisé pour sélectionner le signalement. Pas de routes notification finance/support/litige dédiées observées.
8. **Contenu écran verrouillé** : les messages peuvent contenir nom client, aperçu libre, référence et montant dans notification/body. Aucun mode de contenu minimal par événement observé.
9. **Déduplication métier système** : fenêtre de 30 secondes + texte identique ne remplace pas une clé unique d'événement ; un retry après la fenêtre peut créer un autre message. Le marquage métier client notifié est un second appel, avec échec partiel possible.

## Android, Client Web et Back-office

Android déclare POST_NOTIFICATIONS et les métadonnées icône/couleur dans le manifest. Les listeners et getInitialMessage couvrent le branchement foreground/background/lancement fermé dans le code. Cela ne prouve pas leur fonctionnement sur appareil réel, les permissions Android, l'affichage OEM ni la reprise après authentification.

Client Web : main_customer_web ne démarre ni bootstrap FCM ni registre ; kIsWeb est exclu. Aucun firebase-messaging-sw.js, VAPID, notificationclick ou token Web n'a été trouvé dans web et la chaîne examinée. Les conversations utilisent Realtime avec relecture REST de secours ; le feedback Client Web existe uniquement lorsque l'application est ouverte. Il ne faut pas annoncer un support Web Push.

Back-office : main_backoffice_web ne démarre pas non plus FCM. Les événements destinés aux UID Admin n'apportent donc pas d'alerte push dans le Back-office. Les pages métier constituent une consultation des données ; leur existence ne prouve pas un centre transversal de notifications.

## Décisions recommandées pour ATLAS

Conserver l'architecture unique événement métier → outbox Supabase → Edge Function → FCM. Ne pas créer de deuxième registre ou transport.

1. Corriger d'abord les destinataires : fonction privée unique de résolution Manager actif par zone ; sans responsable, escalade Admin explicite. Retirer la diffusion globale des événements ordinaires. Tests SQL avec deux zones et un Admin, y compris absence de responsable.
2. Ajouter une politique de reprise bornée dans le claim et le dispatch : next_attempt_at, plafond, bail processing et récupération après expiration ; différencier erreur transitoire et terminale. Définir un réveil serveur récurrent sans exposer le nonce. Pour garantir les retries multi-device, enregistrer le résultat par notification/appareil et ignorer ceux déjà acceptés. Toute application distante de migration reste soumise à autorisation explicite.
3. Identifier chaque notification par ID et événement stable ; conserver la clé SQL unique ; lier les messages système importants à une clé durable (commande + transition/événement, remboursement + référence métier). Éviter d'émettre depuis deux couches sans ce contrat commun.
4. Ajouter les événements aux transitions serveur canoniques, pas aux boutons uniquement. Priorité recommandée : normale pour paiement/confirmation/succès/support, haute pour affectation et échec nécessitant action, haute Admin uniquement pour incident critique démontré. Définir les seuils d'incident avant ajout d'un flux Admin global.
5. Ouvrir le détail de commande Cabiniste depuis une lecture autorisée ; sélectionner le signalement ciblé ; contrôler le destinataire et relire les droits après connexion, avec repli lisible pour ressource disparue ou interdite.
6. Client Web : annoncer initialement un canal in-app et inclure les messages système importants dans le feedback dédupliqué. Si Web Push est retenu, il exige une implémentation complète permission volontaire, VAPID public, token, service worker et clic HTTPS avec reprise de session ; ce n'est pas présent aujourd'hui. Tester Client Web et Back-office séparément.
7. Raccourcir les contenus push sensibles ; garder le détail autorisé dans l'application. Vérifier compte désactivé au registre et au dispatch, et désactiver les appareils lors d'une désactivation administrative.

## Vérification à réaliser

Tests existants observés : `test/core/notifications/izytel_notification_payload_test.dart` teste la normalisation ; `notifications_complete_block_contract_test.dart`, `m5_notifications_foundation_contract_test.dart`, WC7 et les contrats mobile vérifient surtout la présence de fragments de source. Ils ne prouvent ni envoi FCM ni déduplication concurrente ni RLS en base.

Recette indispensable après corrections : événement rejoué/concurrent, retry après panne et après expiration du bail, succès partiel sur deux appareils, invalidation token, rotation, logout hors ligne, foreground/background/killed Android, clic après session expirée, compte différent/désactivé, ressource interdite et deux zones Manager. Tester séparément les messages système et les messages Manager Client Web ouvert. Si Web Push est ajouté, tester permission refusée/accordée, worker actif, onglet fermé, notificationclick et renouvellement du token.

Aucun test exécuté ni build réalisé dans cette étape d'audit documentaire. Aucun secret copié dans ce rapport. Les constats portent sur les sources locales et non sur l'état effectif de production.
