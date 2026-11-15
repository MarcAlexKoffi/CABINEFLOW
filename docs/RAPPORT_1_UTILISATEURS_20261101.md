# Rapport 1 — utilisateurs, 1 novembre 2026

## État initial vérifié

La photographie de code, la revue de sécurité et la conception AURA précèdent l'implémentation : [audit initial](UTILISATEURS_AUDIT_INITIAL_20261101.md). La [matrice distante anonymisée](IDENTITE_PHOTOGRAPHIE_DISTANTE_20261101.md), produite en lecture seule par le coordinateur, distingue les comptes clients potentiellement anonymes des identités métier. Aucun compte distant n'a été créé, corrigé, désactivé ou supprimé pendant cette mission.

Le registre initial fusionnait Firestore et partenaires SQL ; le bouton Créer affichait une explication et ne créait aucun compte. Les modifications métier Agent/Manager étaient déjà possibles dans des fiches spécialisées, avec des écritures séquentielles sur plusieurs services et sans administration Firebase Auth complète.

## Architecture implémentée côté serveur

Nouvelle Edge Function `izytel-user-admin`, Firebase Admin `13.4.0`, client SQL `2.57.4`, Firestore REST. Le bearer Firebase est vérifié avec contrôle de révocation. L'acteur doit être `admin` actif dans Firestore ET dans le registre SQL. Les origines Web sont explicitement autorisées par `IZYTEL_ADMIN_ALLOWED_ORIGINS` ; aucun wildcard. Les erreurs externes sont bornées et ne renvoient pas le détail des SDK.

Le serveur utilise exclusivement `FIREBASE_SERVICE_ACCOUNT_JSON`, `SUPABASE_URL` et `SUPABASE_SERVICE_ROLE_KEY` côté Edge. Aucune clé privée/service role n'est introduite dans Flutter. La configuration d'origines est nouvelle ; les autres secrets existaient pour le serveur de notification.

Les RPC comptes sont `SECURITY DEFINER`, ont un `search_path` vide, vérifient le rôle JWT service et sont explicitement révoquées à PUBLIC/anon/authenticated. La table d'opérations possède RLS sans politique client. Les fonctions métier existantes ne sont pas transformées arbitrairement.

Chaque mutation possède un identifiant idempotent, auteur, cible, commande, avant/état demandé, date, statut et erreur durable. Un trigger produit un événement d'audit à chaque changement d'état ; la clé service API dispose seulement de SELECT sur cette table, ce qui conserve les échecs précédents lors d'une réparation ultérieure. Une seule saga pending/failed est autorisée simultanément : ce choix bloque les mutations suivantes jusqu'à réparation d'un échec et évite un déblocage automatique dangereux. La dernière protection Admin est évaluée sous verrou SQL ; les opérations sur son propre compte sont refusées.

La création commence sans droits SQL et crée Firebase Auth désactivé. L'activation intervient après profil métier ; les étapes d'échec tentent le retrait de droits SQL, désactivation Auth et profil Firestore inactif. Une RPC de refus des droits indépendante du provisioning permet de conserver la désactivation même si une réaffectation de zone provoque le rollback de la transaction finale ; ce cas est testé. Si une compensation échoue, la réponse indique explicitement une réparation nécessaire et l'audit reste bloquant. Un compte Auth préexistant n'est jamais désactivé en compensation d'un `createUser` ayant échoué. L'absence de transaction distribuée est assumée ; aucune réponse de succès n'est produite pour une mutation partielle connue.

## Opérations et rôles

- Création des quatre rôles produit : Administrateur (`admin`), Manager, Agent, Cabiniste. Email de connexion requis selon le parcours Firebase actuellement utilisé ; pas de mot de passe choisi ou affiché par le navigateur. Réinitialisation séparée pour préparer le premier accès.
- Modification identité/email/téléphone/rôle/statut et zones/réseaux adaptés ; les capacités monétaires/télécom existantes ne sont pas recalculées par l'administration d'identité.
- Désactivation/réactivation des autorisations des populations concernées ; révocation des refresh tokens lors des modifications. Les anciens appareils de notification sont désactivés pour éviter les envois vers des tokens restés actifs.
- Les modifications administratives imposent une reconnexion et remettent la disponibilité/réseaux actifs hors service ; l'utilisateur doit les réactiver ensuite. Les capacités et soldes sont conservés. Une capacité seule modifiée depuis sa fiche spécialisée ne passe pas par cette saga d'identité.
- Réinitialisation : génération d'un lien Firebase, sans prétendre qu'un email a été envoyé. Le lien doit être transmis via un canal autorisé. Un retry terminé ne régénère pas ce lien sensible.
- Historique : consultation des 100 derniers événements de la cible, contrôlée par Admin ; le journal territorial existant est agrégé pour afficher les modifications de zone Manager effectuées depuis l'administration territoriale validée.
- Détail d'identité : lecture bornée du compte Firebase Auth par serveur Admin, notamment l'email réel des Cabinistes absent du registre SQL ; aucune obligation de deviner cet email pour modifier le compte, aucun profil ou claim privé renvoyé.
- Suppression définitive : refus systématique `REFERENCES_NOT_VERIFIED`. L'inventaire exhaustif des références n'est pas suffisamment prouvé ; la désactivation est l'action disponible. Cette restriction est volontaire, visible, et ne constitue pas une suppression fonctionnelle livrée.

Les alias `supervisor`, `administrator`, `partner` et l'ancien `operator` ne sont pas supprimés. Les nouvelles écritures sont canoniques. Aucune migration silencieuse d'anciens rôles n'est effectuée. Le profil Cabiniste reste SQL ; un ancien profil staff devient pending/inactif lors du passage à Cabiniste.

## Durcissement compatible et limites

Les profils écrits par la nouvelle administration sont marqués `adminManaged`. Les règles Firestore interdisent au client d'enlever ce marqueur ou d'en modifier rôle/statut. Des triggers SQL interdisent l'altération directe du rôle/statut/zones et la suppression hors service pour les UID déjà traités par une opération create/update ; l'UID Auth ne peut jamais être renommé hors service. Les opérations de réseaux et capacités métier autorisées au Manager sont préservées ; elles suivent leurs RPC métier existantes. L'auto-désactivation ou auto-déclassement SQL d'un Administrateur actif est aussi bloqué pour les comptes historiques.

La fiche Agent spécialisée est adaptée dans `firestore_agent_repository.dart` : pour un compte administré, les changements d'identité et d'accès passent par le nouvel endpoint avant les réglages de capacité. Une modification de capacité seule ne révoque pas la session et ne produit pas une mutation d'identité cachée ; l'ordre stocké des listes d'autorisation est conservé. Si le compte est modifié mais que le réglage métier échoue ensuite, le message distingue explicitement ces deux résultats. Le rôle courant est relu depuis le serveur pour refuser une fiche Agent devenue obsolète après un changement de population.

Les comptes historiques non traités conservent leurs parcours validés. Cela signifie que les chemins d'administration legacy ne sont pas universellement fermés sur ces comptes : l'application générale des garanties d'audit et du dernier Admin nécessite une migration explicitement contrôlée et l'adaptation des derniers écrans historiques. Ne pas présenter cette livraison comme une centralisation universelle déjà déployée.

Les mutations sensibles des registres SQL historiques produisent désormais aussi des événements append-only, y compris les réseaux modifiés par les RPC métier Manager ; elles sont affichées dans l'historique du compte. Leurs gardes d'autorisation existantes restent applicables. Les comptes Firestore historiques non traités restent le périmètre résiduel à migrer pour imposer partout la même saga.

Le registre d'appareils possède aussi un trigger INSERT/UPDATE : hors service, un ancien JWT ne peut pas réactiver ou inscrire un appareil actif d'un compte administré dont toutes les populations SQL sont inactives. La désactivation reste permise ; les comptes administrés actifs Staff/Agent/Cabiniste et les clients historiques inconnus sont préservés. Trois contrôles SQL couvrent le refus après désactivation, l'inscription inactive, le rétablissement après réactivation du compte et la compatibilité des populations actives/clients legacy. Le comportement FCM réel reste à tester sur appareil.

`SessionAccessBoundary`, branché dans l'application mobile et le Back-office, demande une reconnexion après un changement confirmé de rôle/statut. Les événements Firestore en cache ou avec écriture locale non confirmée sont ignorés ; une panne de lecture ne simule jamais une révocation. Le statut Cabiniste est suivi dans son registre SQL. Les autorisations effectives restent contrôlées par les règles Firestore et registres SQL. Les tests widget couvrent alias, changement de rôle, désactivation, erreur réseau et invalidation unique ; la révocation et le rafraîchissement d'un token réel n'ont pas été testés sur appareil. Aucun claim de privilège n'est créé : les profils et registres protégés restent les sources d'autorisation des backends existants.

Une opération échouée exige une réparation côté serveur documentée avant le déblocage de nouvelles mutations. Aucun outil de réparation automatique ou bouton utilisateur ne déverrouille cette situation. L'indisponibilité est préférée à une élévation de privilèges partielle.

Une réponse de finalisation perdue est réconciliée avec le statut durable : un commit confirmé n'est pas annulé. Si même sa lecture est impossible, le résultat est explicitement « non confirmé » ; il faut consulter l'historique avant une nouvelle action. Les modifications métier peuvent alors être entièrement appliquées, mais leur accusé de réception est incertain ; le serveur ne prétend pas un échec métier certain ni un succès non vérifié.

## Fichiers serveur et contrôles

- `supabase/functions/izytel-user-admin/core.mjs` : validation et saga testable.
- `supabase/functions/izytel-user-admin/index.ts` : adaptation Auth/Firestore/SQL, contrôle de token et CORS.
- `supabase/functions/izytel-user-admin/core.test.mjs` : tests de comportement avec dépendances injectées.
- `supabase/functions/izytel-user-admin/deno.json` et `README.md` : configuration et procédure de recette future.
- Migration SQL comptes : `supabase/migrations/20261101062508_admin_accounts_lifecycle.sql`, créée avec la CLI puis remplie localement, non appliquée à distance.
- `supabase/tests/user_admin_preflight.sql` : contrôles SQL en lecture seule à exécuter dans l'environnement de recette après migration.
- `firestore.rules` : marqueur et protection des accès administrés.
- `lib/features/agents/data/repositories/firestore_agent_repository.dart` : compatibilité de la fiche Agent spécialisée avec les comptes administrés.

Exécuté : **25 tests Node réussis**, couvrant les quatre créations, validation, utilisateur non Admin, self-operation, suppression refusée, pannes des différentes étapes, compensation en échec, retry terminé/en réparation, email déjà attribué, état inactif, audit et révocation avant activation. **21 contrôles SQL de comportement PGlite réussis** : privilèges RPC anon/authenticated, Admin actif, quatre populations sans droits puis activées, retry, conflits de zones/identifiant, conservation des capacités lors d'un changement de rôle, appareils désactivés, refus de suppression, dernier Admin protégé par interdiction d'auto-opération, audit d'échec, événements d'audit non effaçables par le rôle service API et blocage des écritures legacy sur compte administré. Le schéma fixture reproduit les colonnes utilisées, pas l'intégralité de tous les triggers de production. `node --check index.ts` réussit : il vérifie la syntaxe et ne prouve pas le fonctionnement des imports npm dans Supabase Edge.

Non exécuté à ce stade : runtime Deno et Firebase Admin en Edge, création réelle Firebase, livraison de lien de reset, rotation/révocation sur appareil, application SQL contre le schéma complet ou distant, déploiement règles et fonction. L'équipe intègre séparément les contrôles Flutter et la revue SENTINEL finale ; leurs résultats doivent compléter ce rapport, sans transformer des mocks en preuve de recette réelle.

## Actions distantes

Uniquement SELECT de schémas/contraintes pour lire les modèles réellement présents et photographie d'identité en lecture seule par le coordinateur. Aucun DDL/DML distant, paiement, suppression, envoi de message, merge, publication ou déploiement.

## SENTINEL final

Revue indépendante du serveur, de la saga, des gardes SQL, des journaux et de la compatibilité fiche Agent terminée. Aucun nouveau P0/P1 démontré restant dans les fichiers examinés après correction du contournement OLD→NEW UID, séparation du refus SQL et agrégation de l'audit territorial. Les contraintes legacy et la recette distante non exécutée décrites ci-dessus restent applicables ; il ne s'agit pas d'un certificat de fonctionnement global.

Le cas d'initialisation répétée Firestore a été vérifié dans le [code officiel Firebase Admin 13.4.0](https://raw.githubusercontent.com/firebase/firebase-admin-node/v13.4.0/src/firestore/firestore-internal.ts) : les mêmes options `preferRest` réutilisent l'instance déjà initialisée. Ce n'est donc pas une anomalie des appels successifs de cet endpoint. Les imports npm et leur fonctionnement effectif dans Supabase Edge restent à éprouver en recette.

## Interface et transport Flutter — ATLAS

Le bouton Nouvel utilisateur ouvre désormais un formulaire opérationnel des quatre rôles canoniques. Les champs métiers utilisent les zones actives réelles et les réseaux Orange/MTN/Moov du modèle existant. L'édition relit les autorisations depuis leur registre canonique et récupère l'e-mail réel Firebase via l'action serveur `details`, notamment pour les Cabinistes dont le registre SQL n'affiche pas l'e-mail. Une panne de lecture de ces données bloque la soumission plutôt que de remplacer les autorisations par des listes vides.

Le transport joint un bearer Firebase rafraîchi au nouvel endpoint privilégié ; aucune création Auth, clé service, écriture administrative Firestore ou modification d'autorisation SQL directe n'est ajoutée dans Flutter. Le même identifiant de demande et le même payload sont conservés après une réponse réseau incertaine. Une demande exigeant réparation bloque la nouvelle soumission ; le résultat non confirmé demande de consulter l'historique. Le formulaire avertit explicitement de la reconnexion et de la réactivation opérationnelle nécessaires après modification.

Le détail de compte expose modification/activation/désactivation, génération du lien de réinitialisation sans envoi automatique, consultation de l'historique et demande de suppression confirmée par saisie de l'UID. Le refus serveur de suppression reste présenté avec le recours à la désactivation. Les opérations sur son propre compte sont masquées ; le contrôle serveur demeure l'autorité. Les identités partenaires sans UID Firebase ne sont pas rendues administrables par un identifiant inventé.

Le registre conserve ses sources Firestore et partenaires ; il enrichit les informations territoriales depuis les profils opérationnels SQL, propose filtre zone et pages de 50 résultats affichés. Une erreur partielle reste visible. Un partenaire suspendu conservé pour l'historique ne masque plus le nouveau rôle staff du même UID ; deux populations actives contradictoires sont signalées comme conflit. Un ancien rôle non canonique doit être choisi explicitement dans le formulaire avant modification : aucune conversion silencieuse n'est réalisée.

Fichiers Flutter de ce sous-chantier :

- `lib/backoffice/data/repositories/backoffice_user_administration_repository.dart` : transport et lectures bornées des détails métier.
- `lib/backoffice/presentation/widgets/backoffice_user_admin_dialog.dart` : formulaire, contrôle des champs et reprise de demande.
- `lib/backoffice/presentation/pages/backoffice_users_page.dart` : actions administratives, audit, filtres et pagination affichée.
- `lib/backoffice/domain/models/backoffice_user_account.dart` et `lib/backoffice/data/repositories/firestore_backoffice_user_repository.dart` : autorisations affichées et résolution explicite des conflits de population.
- `test/backoffice/user_administration_repository_test.dart` et `test/backoffice/user_administration_dialog_test.dart` : tests comportementaux écrits pour transport bearer, refus sans session, réponse partielle/malformée, fusion des rôles, quatre créations, demande rejouée avec ID identique, formulaire bloqué si réparation/métadonnées absentes, e-mail Auth réel et avertissement de reconnexion.

Validation finale consolidée : **1077 tests Flutter réussis**, analyse sans diagnostic, builds Android debug, Back-office Web et Client Web réussis. Les commandes, logs et limites sont détaillés dans le [bilan final](BILAN_ADMIN_FINANCE_NOTIFICATIONS_20261101.md). La pagination affichée borne le rendu, pas le chargement initial du registre historique ; une pagination serveur du registre utilisateurs complet n'est pas revendiquée.
