# IzyTel - Phase 3 Stabilisation technique

Baseline cumulative preparee le 11 septembre 2026.

## Couvert
- classification centralisee des erreurs backend ;
- fallbacks limites aux pannes transitoires ;
- backoff progressif des pollers Supabase ;
- retry uniquement pour les synchronisations idempotentes ;
- persistance Firestore explicite sur Android/iOS ;
- maintien de la derniere valeur fiable pendant les coupures ;
- ponts Firestore/Supabase conserves uniquement la ou le flux valide les exige encore ;
- lecture de preuve avec fallback Firestore uniquement sur panne Supabase transitoire ;
- normalisation historique : dates ISO/epoch, montants texte, espaces, Moov Africa/Orange/MTN ;
- suppression des dates artificielles DateTime.now() pour les historiques incomplets ;
- logger central non bloquant et sans donnees metier sensibles ;
- instrumentation des erreurs silencieuses critiques ;
- durcissement des GRANT/RLS Supabase ;
- RPC publiques FCM converties en wrappers SECURITY INVOKER ;
- tables notifications interdites en acces direct client ;
- optimisation RLS init-plan sans changement de droits metier.

## Etat backend verifie avant livraison
- projet Supabase IzyTel actif et sain ;
- 24 commandes Phase 4 : 10 assigned, 14 handed_off ;
- aucun handoff sans marqueur coherent detecte ;
- aucun doublon commissions/finalisations/paiements detecte ;
- aucune capacite Agent negative detectee ;
- notifications observees : sent/skipped, aucun failed dans le snapshot audite.

## Avertissement residuel accepte
Supabase signale encore `pg_net` installe dans le schema `public`. La version de pg_net installee n'est pas relocatable et elle est actuellement utilisee par le wake-up des notifications. Elle n'est donc pas deplacee pendant la Phase 3 afin de ne pas casser FCM. Les tables/RPC exposees ont ete durcies autour de ce mecanisme.

## Hors perimetre volontaire
- aucun changement UI/branding ;
- aucun changement des roles Agent/Manager/Admin ;
- aucun renommage du package Android `com.cabineflow.cabine_flow` ;
- aucune suppression destructive des miroirs hybrides encore actifs ;
- aucune suppression d'index seulement parce qu'ils sont actuellement marques `unused`.

Le renommage package, la signature, APK/AAB et la recette fresh-install appartiennent a la Phase 4 Release.

## Correctifs de cloture terrain - 2026-09-11

La recette manuelle a revele trois anomalies qui ne ressortaient pas de la suite automatisee :

1. Apres un refus Agent, la transition Supabase reussissait mais la relecture immediate de `phase4_assignment_orders` retournait 0 ligne, car la RLS retire volontairement la visibilite de la commande a l'ancien Agent des qu'elle est reaffectee ou passe en `manual_required`.
   - Correction : `phase4_agent_action` retourne maintenant atomiquement un resultat minimal (`assignment_state`, `reassigned`, `manual_required`) issu de la transition serveur.
   - Le mobile ne relit plus la ligne apres le refus.
2. Une ouverture depuis une notification pouvait aboutir a la route de secours `Impossible d'ouvrir cette page` lors d'une restauration Android sans arguments Flutter.
   - Correction : toute route inattendue ou route nommee sans arguments requis repasse par le Splash, restaure la session puis laisse MainShell consommer le payload FCM en attente.
3. Une erreur de flux pouvait afficher une carte `Impossible de charger la file` meme lorsqu'une file deja validee restait visible, ou lorsque l'erreur provenait d'une action Agent.
   - Correction : la derniere file utile est conservee pendant une erreur de stream, et le titre distingue desormais erreur de chargement et erreur d'action.

Migration live appliquee : `phase3_refusal_atomic_outcome`.
Test de verrouillage ajoute : `test/regressions/phase3_runtime_closure_contract_test.dart`.


## v3 - verrou de test de cloture
- Corrige uniquement un contrat de non-regression trop sensible au formatage Dart.
- Aucun changement du code applicatif, du design, des roles ou du backend Supabase.
- Le test verifie maintenant separement le getter `errorTitle` et ses deux libelles attendus.


## Hotfix terrain v4 - capacité affichée suffisante mais acceptation refusée
- Cause: un ancien refus Firestore 9E survivait à un nouveau cycle manuel Supabase.
- Correction: les affectations manuelles Phase 4 créent/réparent immédiatement leur miroir Firestore.
- La capacité déjà réservée par Phase 4 n'est pas soustraite une seconde fois lors de la matérialisation du miroir.
- Manager (supervisor) et Admin sont alignés pour cette affectation manuelle dans le code; le script `tools/phase3_patch_firestore_manual_handoff.ps1` aligne les deux validations correspondantes dans `firestore.rules`.
- Après patch: déployer `firestore.rules`, puis relancer la même affectation manuelle pour réparer les lignes déjà existantes sans miroir.

### Complement v4 - remise a zero du cycle Firestore
Le diagnostic terrain a confirme que la capacite Orange du compte teste est suffisante pour la commande concernee. Le blocage provenait des anciens champs de refus 9E conserves dans Firestore apres une reaffectation manuelle Supabase.

Le correctif v4 remet donc explicitement a zero, uniquement lors d'une nouvelle affectation manuelle :
- `lastAssignmentRefusalReason` ;
- `lastAssignmentRefusedAt` ;
- `lastAssignmentRefusedAgentId` ;
- `autoAssignmentRefusedAgentIds`.

L'historique des refus n'est pas supprime : il reste dans les journaux/assignments. Seul l'etat courant necessaire au nouveau cycle est nettoye. Le patch des regles autorise ces changements dans `isValidAdminManualAssignment`, avec la permission limitee a Manager (`supervisor`) et Admin.
