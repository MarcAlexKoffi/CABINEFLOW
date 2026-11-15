# Rapport 2 — Finance — 2026-11-01

## État initial et décisions ORION

Inventaire détaillé, sources, règles et classement : `docs/FINANCE_AUDIT_INITIAL_20261101.md`. L'audit a confirmé plusieurs chemins financiers actifs Firestore/Supabase, une lecture commissions V2 Firestore alors que les paiements BO étaient Supabase, et des soldes calculés sur des listes bornées.

Conserver les fonctions métier et les historiques : paiements, recharges/capacités, fournisseurs, crédits, commissions Agents et Cabinistes, remboursements, dépenses/frais, caisse, fonds de roulement, rapprochement, mouvements et clôtures. Corriger les sources actives et la fiabilité des calculs. Fusionner les chemins d'écriture mobile vers les RPC canoniques existantes. Aucun écran, repository historique ni table supprimé : absence de preuve suffisante d'inutilité. Aucune migration de données réalisée.

## Correctifs ATLAS

- `SupabaseFinanceOperationsRepository` adapte les opérations mobiles aux RPC Supabase canoniques. Crédits, règlements, dépenses, Wave, clôtures, recharges et paiements fournisseurs ne créent plus de nouvelles écritures Firestore via l'écran Finance courant. Les lectures administratives financières utilisent une RPC paginée dédiée ; les historiques sont conservés. Les crédits chargent la vraie commande et passent par son autorisation canonique. Les clôtures normalisent leur date et transmettent seulement les données réellement comptées ; le serveur calcule les montants attendus.
- `FinancesPage` utilise ce repository ; une indisponibilité Supabase est remontée comme erreur, sans nouvelle écriture sur l'ancien registre. `WaveCashPage` utilise les agrégats canoniques, et la clôture contrôle le solde courant.
- `SupabaseCommissionV2Repository` traduit les données typées du registre Phase5 vers les modèles V2. La page V2 affiche les versements Supabase et les comptes canoniques, en conservant les filtres Agent/Admin. Aucune bascule automatique Firestore si Supabase est indisponible. L'ancien repository Firestore reste disponible pour historique/tests explicites.
- `HybridCommissionRepository.recordPayout` appelle maintenant la RPC de versement canonique BO. Les métriques opérationnelles historiques restent Firestore ; aucune nouvelle écriture de versement Firestore puis miroir.
- `izytel_finance_snapshot` fournit désormais `wave_totals`, agrégats SQL exhaustifs après le dernier solde d'ouverture, indépendants des fenêtres de détail. Les champs : client_payments, credit_settlements, supplier_payments, expenses, refunds, commission_payouts et cabiniste_payouts. Les versements Cabinistes Wave XOF de `compensation_payouts` sont enfin déduits ; les autres devises, canaux et acteurs restent exclus. Le détail conserve ses bornes pour l'affichage.
- Le snapshot ajoute `committed_capacities` : sommes de commandes financées, affectées, encore actives, groupées par réseau. Le fonds engagé ne dépend plus des 1000 dernières commandes du tableau.
- La contre-revue du schéma distant a confirmé que la garde historique finance_staff autorisait Manager/supervisor aux RPC BO globales sans filtre de zone. Snapshot et historique BO périodique sont maintenant Admin-only dans la migration ; les RPC territoriales dédiées au Manager restent inchangées.
- `BackofficeFinanceSnapshot` utilise ces agrégats quand présents ; compatibilité conservée avec anciens snapshots. Cette compatibilité nécessite d'appliquer la migration avant de revendiquer l'exactitude des agrégats.
- La RPC nouvelle `izytel_finance_record_expense_once` protège une intention par clé stable, auteur et contenu. Un reçu privé et un verrou transactionnel assurent qu'un retry renvoie le même identifiant ; modifier le contenu sous la même clé est refusé. Deux intentions distinctes peuvent avoir la même dépense cash. La validation métier et l'audit existants restent dans la RPC sous-jacente. Une erreur de validation ne laisse pas de reçu.
- L'API BO accepte `operationKey` pour recharge, règlement fournisseur et dépense ; les formulaires recharge/dépense créent la clé une seule fois par intention. Après erreur, leur bouton Réessayer garde cette intention et son contenu. Les références de paiements existantes restent protégées côté serveur. Les doubles clics ne constituent jamais à eux seuls la garantie d'idempotence.
- La reprise mobile utilise aussi une fenêtre explicite Réessayer : le brouillon de dépense/recharge est créé une seule fois, conservé par la fermeture du formulaire et réutilisé après une réponse perdue. Le repository Admin et le repository Manager conservent la clé de ce même objet. Un test widget parcourt réellement saisie → erreur réseau → Réessayer et vérifie que la même intention est transmise ; un test transport vérifie la clé Manager. Une nouvelle saisie est une nouvelle intention : le message demande de vérifier l'historique avant de la créer. La clé n'est pas une file locale persistante après arrêt complet de l'application.

## Sources et protections

La source opérationnelle cible est Supabase ; Firestore reste l'historique et certaines métriques opérationnelles. Les nouveaux remboursements étaient déjà Supabase-only et ont été conservés. Les transitions approved → refunded, la vérification du paiement original et le routage Manager territorial ne sont pas remplacés.

Après l'audit initial local, des lectures de métadonnées distantes ont été autorisées par le parent. Des SELECT sur information_schema et pg_get_functiondef ont confirmé la table compensation_payouts et la RPC de versement Cabiniste : devise XOF, acteur cabiniste, canal, date, référence, auteur, clé d'idempotence, verrou de compte et contrôle de dette. Le parent a aussi confirmé le socle Phase5 distant (verrous et déduplication), absent de l'historique SQL local. Aucun SELECT de données clients/financières n'a été nécessaire dans ce chantier ; aucune écriture distante.

Le reçu de dépense est dans private, RLS activée, aucun droit direct anon/authenticated/public. La RPC vérifie Admin et UID serveur ; aucun montant de solde n'est accepté comme vérité client. Les autorisations Phase5/RLS continuent de contrôler les lectures V2 ; un paramètre agentId ne confère aucun droit.

## Fichiers et migrations

Nouveaux :

- lib/features/finances/data/repositories/supabase_finance_operations_repository.dart
- lib/features/finances/domain/services/finance_operation_key.dart
- lib/features/commissions/data/repositories/supabase_commission_v2_repository.dart
- supabase/migrations/20261101012308_finance_mobile_canonical_reads.sql
- supabase/migrations/20261101062456_finance_exact_wave_totals_and_expense_idempotency.sql
- test/finance_sql/run.mjs
- test/features/finances/data/supabase_finance_operations_repository_test.dart
- test/features/finances/data/finance_operation_key_transport_test.dart
- test/features/finances/domain/exact_wave_totals_test.dart
- test/features/commissions/data/supabase_commission_v2_repository_test.dart

Modifiés : repositories/interface Finance BO, modèle BackofficeFinanceSnapshot, formulaires BackofficeFinancePage ; FinancesPage, WaveCashPage, DailyFinancialClosingPage, finance_calculators ; HybridCommissionRepository et CommissionV2DashboardPage ; contrats de câblage mobile concernés.

Aucune nouvelle variable d'environnement ni clé. Deux migrations locales Finance, aucune appliquée à distance par ce chantier. Aucune suppression de table, publication, fusion main ni déploiement.

## Vérifications SENTINEL

Exécuté directement : `node test/finance_sql/run.mjs` — 7 cas PostgreSQL PGlite PASS, sans accès réseau :

1. 1201 commandes et 601 dépenses dépassant les fenêtres du snapshot : totaux exacts, fonds engagés exacts ; exclusion avant ouverture et canal ; Cabiniste seul, Wave seul et XOF seul.
2. Réponse perdue/retry d'une dépense : même identifiant, une seule écriture d'audit.
3. Même clé et contenu différent : refus.
4. Deux intentions distinctes et contenu cash identique : deux écritures autorisées.
5. Validation montant invalide : rollback, aucun reçu.
6. Rôles anon/authenticated : appel direct historique refusé, wrapper autorisé pour Admin synthétique.
7. Non-Admin conservant une qualité staff : snapshot, historique global et écriture refusés.

Tests Flutter exécutés : agrégats serveur vs détail tronqué, zéro exact prioritaire, mapping payout V2 Supabase et compte Agent, portée Admin/Agent, identifiant vide, transport clé stable et intentions distinctes. Le test widget de reprise mobile après réponse perdue et le transport Manager ont aussi réussi. Tous font partie de la suite complète finale de **1077 tests réussis**.

Validation finale : analyse sans diagnostic et builds Android debug, Back-office Web et Client Web réussis. Commandes, logs et restrictions de portée dans le [bilan final](BILAN_ADMIN_FINANCE_NOTIFICATIONS_20261101.md). Le dernier correctif a aussi conservé le design de feedback existant : reprise explicite par fenêtre de confirmation, sans réintroduire de SnackBar.

## Limites et recette restante

- Les migrations doivent être revues et appliquées dans un environnement de recette avant lancement de la nouvelle app. `expense_once` et la lecture paginée n'existent pas dans un backend ancien ; aucun déploiement n'a été effectué.
- La migration révoque EXECUTE sur l'ancienne RPC de dépense pour public/anon/authenticated, après vérification que le seul appel Flutter utilise expense_once. La fonction et l'historique restent conservés ; seul le wrapper privilégié l'appelle pour validation/audit. Le futur déploiement devra coordonner migration et app pour éviter un ancien BO face aux nouveaux droits.
- Le moteur de rapprochement mobile lit toujours une part d'historique Firestore (commandes/commissions/mouvements) et complète surtout preuves/remboursements Supabase. Son passage canonique complet et la pagination historique restent à faire ; ne pas interpréter sa sortie comme audit exhaustif des nouvelles opérations Supabase.
- Les synchroniseurs legacy bornés aux flux récents sont conservés ; aucune outbox de reprise de tous les échecs historiques n'est ajoutée ici. Les données déjà désynchronisées ne sont pas corrigées automatiquement.
- Les formules commerciales existantes sont préservées ; une approbation externe du forfait commission et des règles de marge n'a pas été fournie. Les tests numériques vérifient l'implémentation actuelle, pas une politique commerciale indépendante.
- Les tests PostgreSQL utilisent un schéma synthétique et ne prouvent ni RLS réellement déployée, ni concurrence multi-connexion réelle, ni volume/performance de production. Les gardes sont testées avec identités synthétiques ; aucun paiement réel.
- Recette requise : migrations sur copie/recette, permissions réelles Admin/Manager/Agent/inactif, timeout après commit et reprise avec même intention, versements Agent/Cabiniste, clôture avec écarts, données historiques, changement de session et capacité engagée à fort volume.

La Finance a reçu des correctifs ciblés et vérifiables ; une stabilisation complète des données historiques et de tous les rapprochements n'est pas affirmée.
