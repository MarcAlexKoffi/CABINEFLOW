# Rapport ATLAS Dev — Correctif Back-office IzyTel

Date : 1er novembre 2026  
Périmètre : Administration / Utilisateurs, Vue financière, démarrage Web  
Contraintes respectées : aucun déploiement, aucune migration, aucun compte réel modifié, aucun privilège distant modifié, aucune opération financière.

## Causes démontrées

### Administration / Utilisateurs

Le registre combine Firestore (`users`) et trois enrichissements Supabase Realtime. Les abonnements Supabase pouvaient démarrer avant que le JWT Firebase restauré soit transmis au client Realtime. Une erreur d'enrichissement remplaçait ensuite le dernier registre valide par un écran d'erreur global.

Le correctif :

- attend un token Firebase valide puis exécute `realtime.setAuth(token)` avant les abonnements Supabase ;
- borne ces deux attentes à cinq secondes ;
- journalise une erreur sûre sans token ;
- classe séparément réseau, timeout, session expirée, refus RLS, RPC absent, serveur et contrat invalide ;
- conserve la dernière liste valide si un enrichissement Supabase échoue ;
- recrée réellement le flux avec « Réessayer ».

### Vue financière

Les journaux Supabase lus pour la période de la capture montrent :

- `izytel_finance_snapshot` : HTTP 200, JWT Firebase accepté, 71 à 212 ms ;
- `izytel_admin_cabiniste_finance_snapshot` : HTTP 200, JWT Firebase accepté, 36 à 58 ms ;
- aucun 401, 403, 404 ou 5xx sur ces appels échantillonnés.

L'écran global n'était donc pas causé par une indisponibilité démontrée des deux RPC. Il pouvait être déclenché côté client par l'échec transitoire ou le contrat invalide d'une lecture secondaire Cabiniste, puis par un refetch Realtime. Le refetch initial doublé est intentionnel : la première lecture fournit le snapshot, la seconde ferme la fenêtre de concurrence lors de l'abonnement au signal `finance_change_feed`.

Le correctif lance les deux RPC en parallèle, rend le snapshot principal obligatoire, traite Cabiniste comme source secondaire, conserve le dernier snapshot principal valide et affiche un code de diagnostic sûr. Une erreur principale reste bloquante et n'est jamais convertie en données vides.

Les observations à 19:10 et à 23:30 montrent le bandeau malgré des réponses HTTP 200. Ce statut ne permet pas de conclure à une exception réseau navigateur précise : l'explication antérieure par `XMLHttpRequest`/Fetch n'était pas démontrée. Les erreurs de transport sont classées, mais leur présence dans ces captures reste non établie.

La contre-vérification suivante a établi deux faits supplémentaires :

- le serveur Flutter du port 8080 était le processus lancé à 18:54 ; son JavaScript ne contenait pas la dernière reprise automatique ni les codes du bandeau ;
- l'ancien `SupabaseRealtimeRefetch` n'atteignait sa boucle de secours qu'après la fin du flux Realtime. Un WebSocket connecté mais silencieux pouvait donc empêcher indéfiniment les lectures périodiques.

Finance utilise désormais une lecture canonique bornée à 15 secondes, avec un rafraîchissement de secours indépendant toutes les 60 secondes et une reprise avec backoff des seules erreurs transitoires. Une erreur du canal Realtime ne devient pas une erreur du snapshot financier. Le minuteur ajouté dans la page pour recréer arbitrairement le flux a été retiré ; la reprise est gérée par le lecteur. Un 401/403 reste bloquant, masque les soldes en cache et ne lance aucune boucle de tentatives. L'heure du dernier snapshot reçu et une relance manuelle sont visibles.

Le serveur 8080 a été redémarré. Le JavaScript servi a été vérifié par HTTP : l'option de rafraîchissement indépendant est bien activée et l'ancien minuteur est absent. Le contrôle natif de Chrome n'était pas disponible ; aucune exception navigateur exacte n'a donc été inventée à partir des seuls journaux HTTP.

### Vérification de la commande Orange traitée à 23:28

Commande `CF-20260930-SULMBN`, montant 1 500 F, finalisation financière le 1er novembre 2026 à 23:28:44 UTC. Le mouvement et la finalisation persistés indiquent tous deux : stock Agent avant **48 500 F**, après **47 000 F**. La déduction est donc bien enregistrée une seule fois dans le registre consulté.

Les totaux serveur actuels correspondent à la capture : stock Orange **163 900 F**, commandes engagées **58 222 F**, libre **105 678 F**. Pour cette commande déjà réservée, la réussite réduit le stock de 1 500 F et libère simultanément 1 500 F d'engagement ; le libre peut donc rester identique. Le stock global et l'engagement avant, reconstitués pour cette opération, étaient respectivement 165 400 F et 59 722 F, donnant déjà 105 678 F libres. Un test verrouille cette distinction. Le texte de la synthèse réseau l'explique désormais dans l'interface.

Aucune réécriture de stock ni réparation financière distante n'a été nécessaire ou exécutée.

### Acceptation Agent : refus territorial confirmé

Après le redémarrage, l'utilisateur a confirmé que le bandeau Finance disparaît. Il a ensuite signalé un refus lors de l'acceptation d'une commande Agent.

Les appels `phase4_agent_action` de 23:50 à 23:52 ont répondu **HTTP 400**. Les journaux PostgreSQL donnent le motif exact : **`AGENT_NOT_ELIGIBLE_CURRENT_STATE`**. La fonction distante contrôle l'activité du compte, la disponibilité, la zone, les réseaux actifs/autorisés, le stock réservé et les plafonds ; elle n'a pas été modifiée.

L'Agent `AG-VQ35OS` est actuellement rattaché à **Zone 1, Abidjan**, mais huit commandes anciennes lui restent affectées en **Zone 2**. Leur refus est conforme au contrôle territorial. Les capacités, disponibilités, autorisations réseau et quotas contrôlés sont suffisants ; c'est la condition de zone qui échoue pour ces commandes :

| Référence | Réseau | Montant | Zone |
|---|---|---:|---|
| CF-20260918-CNQ6AO | MTN | 500 F | Zone 2 |
| CF-20260922-FMIMAI | MTN | 500 F | Zone 2 |
| CF-20260906-4NP9RJ | Orange | 10 000 F | Zone 2 |
| CF-20260909-BVIPUU | MTN | 1 500 F | Zone 2 |
| CF-20260909-ATBF9Z | MTN | 2 500 F | Zone 2 |
| CF-20260918-RJVVVZ | MTN | 2 500 F | Zone 2 |
| CF-20260915-MF184B | Moov | 2 500 F | Zone 2 |
| CF-20260913-BRSV3D | Orange | 10 000 F | Zone 2 |

Trois autres commandes affectées passent les contrôles au moment de la lecture : `CF-20260927-IXGQJC`, `CF-20260927-HUXRPU`, `CF-20260927-TN4KMP`. Aucune acceptation réelle n'a été exécutée pour les tester.

Le message Flutter générique masquait le refus métier. Le correctif affiche désormais le motif territorial lorsqu'il est confirmé par le profil chargé, ou un motif explicite de disponibilité/réseau/stock lorsque ces conditions expliquent le refus serveur. Il conserve un message prudent si le profil est absent ou si seules les réservations/quotas peuvent être en cause. Les commandes restent visibles et aucun droit n'est élargi. Le Manager ou l'Administrateur doit examiner les affectations anciennes avant leur traitement.

Tests Agent ciblés après ce changement : **10 réussis**, dont l'acceptation normale, le démarrage, la réussite, le refus territorial et l'absence de tentative automatique. Fichiers concernés : `lib/features/orders/presentation/view_models/agent_orders_view_model.dart` et `test/features/orders/presentation/view_models/agent_orders_view_model_test.dart`.

## Chronométrage du démarrage

Mesure locale par Chrome DevTools, cache désactivé, trois actualisations par variante. Le profil de mesure est isolé et non authentifié ; les tests automatisés couvrent séparément les rôles Admin/Manager et l'expiration de session.

| Étape moyenne | Debug avant | Debug après | Release après |
|---|---:|---:|---:|
| Chargement Flutter Web avant entrée Dart | 18 738 ms | 16 620 ms | 1 099 ms |
| Initialisation Firebase | 703 ms | 622 ms | 308 ms |
| Restauration Auth après persistance | 3 ms | 50 ms | 7 ms |
| Initialisation Supabase | 41 ms séquentiels | 47 ms en parallèle | 6 ms en parallèle |
| Validation du rôle | 6 ms | 5 ms | 3 ms |
| Shell jusqu'à première page utilisable | 542 ms | 607 ms | 111 ms |
| Navigation → première page utilisable | **20 547 ms** | **18 420 ms** | **1 587 ms** |

Le gain debug moyen est de 2 127 ms (10,4 %). La variation dominante reste le chargeur et la compilation Flutter Web debug avant l'entrée Dart. Le build release réduit le temps total moyen de 91,4 % par rapport au debug corrigé.

La synchronisation JWT Realtime et les données secondaires ne bloquent plus le premier rendu. Elles continuent après le shell avec journalisation et reprise. Les contrôles de session, rôle et permissions restent obligatoires avant les fonctionnalités sensibles.

## Fichiers du correctif prioritaire

- `lib/core/diagnostics/startup_trace.dart`
- `lib/core/resilience/backend_failure_policy.dart`
- `lib/core/supabase/supabase_realtime_refetch.dart` (mode Finance avec polling indépendant)
- `lib/main_backoffice_web.dart`
- `lib/backoffice/backoffice_app.dart`
- `lib/backoffice/data/repositories/firestore_backoffice_user_repository.dart`
- `lib/backoffice/data/repositories/supabase_backoffice_finance_repository.dart`
- `lib/backoffice/domain/models/backoffice_finance_snapshot.dart`
- `lib/backoffice/domain/repositories/backoffice_user_repository.dart`
- `lib/backoffice/presentation/pages/backoffice_users_page.dart`
- `lib/backoffice/presentation/pages/finances/backoffice_finance_page.dart`
- `test/backoffice/supabase_backoffice_finance_repository_test.dart`
- `test/core/resilience/backend_failure_policy_test.dart`
- `test/core/resilience/supabase_finance_refresh_test.dart`
- `test/backoffice/finance_read_recovery_test.dart`
- `test/features/finances/domain/exact_wave_totals_test.dart` (stock déduit et réservation libérée)
- deux contrats de régression mis à jour pour les nouveaux types asynchrones et la classification explicite de `42501`.

## Vérifications

- tests ciblés Utilisateurs / Finance / erreurs : 17 réussis ;
- contrats startup et résilience : 8 réussis ;
- dernière suite Flutter complète : **1 094 réussis** en 2 min 35 s (`scratch/finance_refresh_all_tests.log`) ;
- `flutter analyze --no-pub` : aucun problème ;
- dernier `flutter build web --release -t lib/main_backoffice_web.dart` : réussi en **105,9 s**, sortie `build/web` (`scratch/finance_refresh_release_build.log`) ;
- mesures debug : trois actualisations avant et après ;
- mesures release : trois actualisations ;
- inspection Supabase : lecture seule des journaux, fonctions, rôles et advisors.

## Points serveur restant à traiter séparément

Les advisors Supabase signalent des avertissements existants qui n'expliquent pas les HTTP 200 observés et n'ont pas été modifiés dans ce correctif : fonctions `SECURITY DEFINER` exécutables par `anon`, tables RLS sans policy explicite et optimisations RLS/index. Toute correction exige une revue serveur dédiée, car élargir ou modifier les privilèges pendant ce correctif aurait violé le périmètre.

Références advisors :

- https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable
- https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy
- https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan

## Recette réelle

1. Lancer le debug avec `flutter run -d web-server -t lib/main_backoffice_web.dart --web-port 8080`.
2. Se connecter comme Administrateur, ouvrir Utilisateurs, vérifier la liste, actualiser trois fois et utiliser « Réessayer » après une coupure réseau temporaire. La liste déjà chargée doit rester visible avec un avertissement.
3. Laisser expirer la session ou révoquer uniquement la session de test. L'interface doit demander une reconnexion et ne jamais afficher une liste vide comme succès.
4. Ouvrir Vue financière. Les cartes principales doivent rester visibles si la source Cabiniste échoue ; un bandeau et un code sûr doivent apparaître.
5. Couper puis rétablir le réseau, cliquer « Réessayer » et vérifier la récupération réelle.
6. Consulter puis éditer un utilisateur de test autorisé. Vérifier qu'un Manager conserve son périmètre et qu'aucune action Finance Admin ne lui est ouverte.
7. Naviguer vers Caisse Wave, Dépenses, Fournisseurs, Commissions, Contrôle puis revenir à Utilisateurs.
8. Compiler le release, servir `build/web` localement et refaire les étapes 2 à 7. Le premier écran doit apparaître en quelques secondes ; ne pas juger la performance finale depuis le serveur debug.

Le serveur debug 8080 a été redémarré avec le lecteur Finance corrigé. L'utilisateur a effectué l'actualisation et **confirmé la disparition du bandeau**. En cas de nouvel incident, relever le code du bandeau et l'heure « Dernière lecture réussie ».
