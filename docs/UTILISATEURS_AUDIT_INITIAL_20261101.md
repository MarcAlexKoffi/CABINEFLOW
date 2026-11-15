# Utilisateurs — photographie initiale, sécurité et conception

Date : 1 novembre 2026. Périmètre : chantier 1, avant implémentation ATLAS.

## 1. ORION — photographie du code réel

Lecture de `AGENTS.md.txt` et de la demande complète. Aucune donnée distante consultée ou modifiée ; aucune migration appliquée ; aucun déploiement. Ce document décrit le dépôt, pas une certification de l'état de production. Les doublons, comptes orphelins et comptes Auth manquants ne peuvent pas être comptés sans inventaire serveur autorisé en lecture.

### Sources et matrice d'identité

| Population | Authentification | Profil et rôle de connexion | Registre Supabase | Statut et zone | Droits effectifs |
| --- | --- | --- | --- | --- | --- |
| Administrateur | Firebase Auth, email/mot de passe | Firestore `users/{uid}`, `admin` ou alias UI `administrator` | `izytel_staff_access`, `staff_profiles` | `users.isActive` et registre SQL indépendants | Firestore exige précisément `admin` actif ; SQL exige son propre registre actif |
| Manager | Firebase Auth | `users.role=manager/supervisor` | `izytel_staff_access`, `manager_profiles`, `staff_profiles` | Statuts indépendants ; `territory_zones.manager_id` | Droits Manager UI, règles Firestore staff et RPC territoriales SQL |
| Agent | Firebase Auth | `users.role=agent` | `phase5_agent_capacities`, `agent_personal_profiles`, `staff_profiles` | `users.isActive` + capacités SQL actives ; zones des capacités | Shell Agent, opérations personnelles et affectations autorisées |
| Cabiniste | Firebase Auth | Lookup Supabase après profil Firestore absent/pending/inconnu, ou indisponibilité Firestore | `partner_accounts`, avec `firebase_uid` et `status` | `active/pending/suspended/closed` | Shell Cabiniste et règles partenaires SQL ; aucun compte staff à créer pour le représenter |
| Opérateur historique | Firebase Auth | `users.role=operator` | À vérifier par inventaire ; aucune conversion automatique définie | `users.isActive` | Ancienne matrice limitée dans Flutter, mais rôle inclus dans `isStaff()` Firestore |
| En attente | Firebase Auth | Profil Firestore auto-créé `pending`, inactif | Éventuel partenaire canonique | Aucun accès staff | Activation administrative nécessaire |

La session Supabase utilise le JWT Firebase via `SupabaseBootstrap.accessToken`, avec synchronisation du token Realtime par `idTokenChanges`. Il n'existe pas de connexion Supabase Auth parallèle dans ce chemin.

### Écran et opérations existantes

- `lib/backoffice/presentation/pages/backoffice_users_page.dart` : page Admin, recherche nom/email/téléphone/UID, filtres rôle/statut, fiches de détail et accès aux fiches Manager/Agent. Le bouton de création ouvre `_showCreationRoadmap`, une information sans création réelle.
- `lib/backoffice/domain/repositories/backoffice_user_repository.dart` : uniquement `watchUsers()` ; aucune API d'administration Auth.
- `lib/backoffice/data/repositories/firestore_backoffice_user_repository.dart` : flux complet Firestore `users` fusionné avec `partner_accounts`. Pas de pagination serveur ni de zone dans le modèle. Les Cabinistes ont un email vide dans cette projection.
- La liste donne priorité au partenaire pour un UID commun ; `FirebaseAuthRepository._resolveAccess` donne priorité au profil staff reconnu. Une identité contradictoire peut donc être affichée Cabiniste et ouvrir une session staff. Ne pas résoudre silencieusement cette contradiction.
- Une panne du flux partenaires est absorbée et produit une liste staff sans signalement explicite de registre incomplet.
- `BackofficeUserAccount` contient dates et activité facultatives, mais pas d'état Firebase Auth, de claims, de zone ou d'état de synchronisation.

### Synchronisations réellement présentes

- `supabase_territory_repository.dart:121` : le client Admin lit Firestore, appelle `izytel_wc6_provision_manager_account` pour chaque Manager/Supervisor puis `izytel_sync_manager_profiles`. Synchronisation déclenchée par application, sans transaction commune Firestore/SQL.
- Migration `20260927155000_wc6_manager_registry_zone_creation_fix.sql` : provisioning SQL des Managers avec contrôle Admin SQL, statut et disponibilité séparés.
- `firestore_agent_repository.dart:590` : en mode Supabase, `updateAgentAdmin` SQL puis mise à jour `users` Firestore ; un échec intermédiaire peut désaligner les statuts et les contacts. L'activation d'un compte pending suit également un chemin de provisioning métier existant.
- Migration `20260915001633_bo3d_staff_profiles.sql` : profils staff et audit de fiche ; triggers Agent/Manager vers `staff_profiles` et RPC de synchronisation. Cet audit de fiche personnelle ne remplace pas un journal d'administration Auth.

### Rôles et règles à préserver

- `app_user.dart` conserve `administrator`, `manager`, `supervisor`, `operator`, `agent`, `cabiniste`.
- `user_permissions.dart` expose Manager pour `supervisor` et conserve `operator` avec des droits limités ; `firestoreCompatibilityRole` renvoie encore `supervisor` pour Manager, bien que les règles locales acceptent désormais `manager` dans plusieurs endroits. Préserver les déploiements historiques.
- `backoffice_user_account.dart` reconnaît aussi `partner` comme Cabiniste. L'authentification ne reconnaît pas un rôle Firestore `cabiniste` : elle résout cette population via Supabase.
- `firestore.rules:14` : `isStaff()` autorise operator/manager/supervisor/admin actifs ; `isAdmin()` exige `admin`, donc l'alias `administrator` accepté par l'UI n'a pas les mêmes droits backend.
- `firestore.rules:2036` : un Admin peut modifier des profils existants côté client ; email et création immuables, modification de son propre rôle/statut interdite. Pas de journal obligatoire dans ce chemin. Suppression Firestore interdite.
- `firestore.rules:4619` : profils lisibles par soi-même ou staff, liste permise au staff ; cette portée est plus large que l'accès Admin de la page Utilisateurs.
- Migration `20260929091500_wc13_phase4_firebase_third_party_role_compatibility.sql` : certaines politiques couvrent `anon, authenticated` car le JWT Firebase peut ne pas avoir de claim SQL `role=authenticated`. L'autorisation métier dans les prédicats reste indispensable.
- Aucune gestion de claims Firebase, révocation de sessions ou administration Firebase Auth trouvée dans le chemin Utilisateurs existant.

### Infrastructure serveur disponible

Une Edge Function Supabase existe dans `supabase/functions/izytel-notification-dispatch/index.ts`. Elle consomme un service account Firebase côté serveur pour FCM. Réutiliser le modèle d'hébergement et de secrets ; ne pas réutiliser la surface HTTP du dispatch pour des opérations comptes. Aucun backend Firebase Functions ou endpoint d'administration comptes trouvé dans les fichiers inspectés.

Les créations initiales de certaines tables/helpers SQL (notamment les helpers d'identité et le registre d'accès) ne figurent pas dans les migrations locales inspectées : les migrations présupposent un socle antérieur. L'environnement de test doit expliciter ce prérequis ; ne pas présenter l'application de toutes les migrations sur une base vide comme vérifiée.

## 2. SENTINEL — revue de sécurité initiale, en lecture seule

Cette étape est une revue statique distincte de l'architecture ci-dessus. Aucun test adversarial distant exécuté.

| Risque constaté ou à vérifier | Conséquence | Décision avant ATLAS |
| --- | --- | --- |
| Deux registres d'autorisation et synchronisations client séquentielles | Désactivation/rôle appliqués seulement à une partie des services | Orchestration serveur, état d'opération durable, reprise explicite, retrait des anciens chemins sensibles dans le périmètre validé |
| Fusion partenaire gagnante différente de la connexion staff gagnante | Affichage et droits contradictoires | Retourner conflit explicite ; ne pas changer automatiquement de population |
| Alias `administrator` accepté par Flutter mais pas `isAdmin()` | Interface Admin sans autorisation Firestore correspondante | Normaliser en lecture ; persister `admin` comme valeur technique canonique |
| Règles autorisant mise à jour directe sensible d'un Admin | Contournement de l'audit et de la protection du dernier Admin côté endpoint | Durcir les règles en même temps que les appels concernés ; garder les simples contacts et parcours validés compatibles |
| Tokens déjà émis, cache Firestore et session restaurée sans reload forcé | UI temporairement ancienne ; révocation Auth seule insuffisante pour les API SQL | Autorisation serveur dynamique sur chaque opération ; désactivation de tous registres et révocation ; rafraîchissement/écoute d'accès en client |
| Vérification dernier Admin non atomique entre registres | Deux changements concurrents peuvent retirer tous les Admins | Sérialisation SQL et réservation d'opération ; interdiction de retirer son propre accès sensible ; décision explicite sur l'ensemble canonique compté |
| Suppression avec historique non inventorié | Rupture de traçabilité | Suppression refusée par défaut ; désactivation privilégiée ; autoriser suppression seulement après preuve exhaustive d'absence de références |
| RPC SECURITY DEFINER et rôle SQL service | Bypass RLS si exposée sans restriction | RPC interne service-only avec REVOKE PUBLIC/anon/authenticated et contrôle rôle ; journal d'acteur provenant du token vérifié par serveur |

### Contrat d'architecture sécurisé retenu

1. Edge Function dédiée comptes, bibliothèque Firebase Admin npm à version exacte, secrets uniquement serveur, configuration CORS bornée.
2. Exiger bearer Firebase ; vérifier signature, issuer, audience, expiration et révocation avec Firebase Admin. Charger ensuite le profil serveur `users/{actorUid}` et contrôler rôle `admin` canonique + activité. Vérifier aussi le registre SQL correspondant pour éviter une élévation par désynchronisation.
3. Valider par schéma fermé l'opération, les identifiants, les tailles, les rôles et les champs métier conditionnels ; limiter la réponse, les erreurs et la pagination. Aucune confiance dans auteur/rôle envoyés par Flutter.
4. Demander une clé d'idempotence et ouvrir une opération durable SQL via RPC réservée au service. Stocker états, auteur, motif, avant/après sans mot de passe ni token. Sérialiser les opérations sensibles concurrentes.
5. Pour création : créer l'utilisateur Firebase désactivé, créer/provisionner les registres nécessaires, écrire Firestore, puis activer uniquement après succès complet. Si échec, compenser ou laisser un état incomplet explicitement visible et bloqué ; aucun succès partiel silencieux.
6. Pour rôle/statut : traiter comme saga avec sauvegarde avant/après, retrait prioritaire des droits lors d'une réduction, mise à jour des registres concernés, claims éventuels et révocation. Une panne laisse l'opération bloquée/réparable et ne donne pas de nouveaux droits implicites.
7. Pour reset : Firebase Admin génère un lien de réinitialisation ; aucune consigne de transmission n'est envoyée automatiquement sans canal métier autorisé. Une réponse destinée à l'Admin ne doit pas exposer de mot de passe. Distinguer génération du lien et envoi effectif.
8. Pour suppression : confirmation UI avec identifiant cible et motif, contrôle serveur du dernier Admin et de toutes les références. Les compteurs inconnus, permissions insuffisantes ou services indisponibles bloquent la suppression. Ne pas effacer l'audit avec le compte.
9. Pour consultation/audit : endpoint paginé réconciliant Auth/Firestore/SQL et affichant anomalies de présence/statut/rôle ; aucun secret serveur dans le bundle Flutter.

### Migration progressive des rôles

Vocabulaire produit : Administrateur, Manager, Agent, Cabiniste. Valeurs techniques cibles : `admin`, `manager`, `agent`, `cabiniste`, avec adaptateur Firestore `supervisor` conservé tant que nécessaire. `administrator→admin`, `supervisor→manager`, `partner→cabiniste` sont des alias explicites de lecture. `operator` n'est pas assimilé automatiquement à Agent ou Manager : conserver ses droits historiques et présenter une action de conversion revue individuellement. Écrire uniquement les valeurs canoniques pour les nouvelles opérations, après vérification des règles réellement publiées. Produire un rapport à blanc de migration ; ne pas migrer les données pendant cet audit.

## 3. AURA — conception de l'interface dans le système existant

Réutiliser `BackofficePalette`, `BackofficeModalShell`, `BackofficeModalSection`, `BackofficeInfoGrid`, pills rôle/statut et tableaux responsive déjà présents. Garder le vocabulaire français, les espacements et les comportements de chargement/erreur existants.

- Navigation Administration → Utilisateurs : conserver l'entrée actuelle et remplacer la roadmap par une action opérationnelle quand le backend est configuré.
- Tableau : nom, contact disponible, rôle canonique avec marqueur legacy/conflit, état effectif, zone(s), dernière activité réellement connue, création, actions. Pagination serveur ; recherche et filtres rôle/statut/zone cohérents avec le serveur.
- État incomplet : afficher explicitement une source indisponible, compte sans profil, contradiction de rôle ou opération en reprise. Ne jamais déduire « aucun Cabiniste » d'une panne Supabase.
- Formulaire commun : nom/prénom selon stockage existant, email de connexion Firebase, téléphone, rôle et activité ; email requis pour le chemin email/mot de passe actuellement réellement utilisé.
- Manager : sélecteur des zones existantes, protection des affectations territoriales. Agent : zones, réseaux autorisés et capacités seulement si requis par le modèle réel ; conserver les écrans spécialisés. Cabiniste : champs requis du modèle partenaire existant, chargés explicitement depuis son schéma, sans fiche staff artificielle.
- Fiche : onglets Informations, Accès et zones, Historique. Les informations Auth absentes du registre initial doivent être chargées par serveur ; activité inconnue affichée comme telle.
- Actions : enregistrer avec état en cours et idempotence, changer le rôle avec aperçu des impacts, activer/désactiver, préparer réinitialisation, consulter audit. Les erreurs de compensation apparaissent comme état de reprise et non comme simple toast.
- Désactivation distincte de suppression. Suppression dans une zone de danger avec motif, confirmation nominative et résultat serveur du contrôle de références. Si historique ou contrôle incomplet : blocage explicite et proposition de désactivation.

## 4. Plan ATLAS proposé et critères de vérification

1. Définir contrat TypeScript partagé/testable et adaptateur serveur Firebase Admin, contrôle Admin et service-only RPC d'opérations/audit.
2. Implémenter inventaire paginé et détection de contradictions ; ne pas masquer les comptes incohérents par fusion de cartes.
3. Implémenter création, édition, rôle, statut et reset avec idempotence/compensation et protections de concurrence ; suppression bloquée tant que la preuve de non-référence n'est pas complète.
4. Étendre modèle/repository Flutter et page existante, conserver les liens vers les fiches métier et gérer accès modifiés pendant la session.
5. Durcir les règles sensibles en accompagnement des appels clients remplacés ; conserver les alias de lecture.
6. Tester les quatre créations, doublon email, rôle invalide, accès non Admin, modification, propagation session, désactivation/réactivation, suppression permise/refusée et dernier Admin. Tester retry, concurrence et panne après chaque frontière Firebase/Firestore/SQL. Faire revoir les résultats par SENTINEL.

Cette photographie n'exécute ni analyze ni builds : aucun code produit modifié. Les validations réelles Firebase Auth/claims/révocation et RLS exigent un environnement isolé configuré ; elles ne peuvent pas être annoncées réussies sur la seule base de tests statiques.

Statut de passage : ORION terminé → SENTINEL initial terminé → AURA terminé. ATLAS en attente du feu vert du coordinateur.
