# IzyTel — Audit de reprise de la file partagée

6 novembre 2026. ORION v2, revue anticipée SENTINEL, inspection AURA et ATLAS. Statut produit : **IMPLEMENTATION**. La référence AURA R1 est **DESIGN_VALIDATED** ; aucune nouvelle validation de maquette n'est nécessaire.

Les travaux ne sont pas perdus. L'implémentation la plus avancée est déjà dans le vrai projet Flutter `cabine_flow`, sur `feat/shared-agent-queue-sla`. La copie sous `SUPERVISION-VISIOS/work/izytel-implementation` est beaucoup moins avancée. La livraison reste à vérifier : 16 tests Flutter ciblés passent ; l'analyse statique échoue dans le test de capture visuelle ; le runner SQL d'origine échoue, mais ses 13 contrôles passent après correction du seul privilège manquant dans une copie de diagnostic.

## Sources et emplacement à conserver

| Emplacement | État observé | Décision de reprise |
|---|---|---|
| `C:/Users/koffi/Documents/PROJETS FLUTTER/cabine_flow` | Branche `feat/shared-agent-queue-sla`, HEAD `588ca83`, changements applicatifs et nouveaux fichiers non commités | Continuer ici ; préserver tous les changements présents |
| `C:/Users/koffi/Documents/PROJETS JS/SUPERVISION-VISIOS/work/izytel-file-partagee-20261106` | Audit initial, plan ORION v1, prototype R1 et suivi partiellement obsolète | Source historique de préparation et de validation |
| `C:/Users/koffi/Documents/PROJETS JS/SUPERVISION-VISIOS/work/izytel-implementation` | Dépôt indépendant, branche `fix/stabilisation-mobile-web-20261030`, même HEAD ; seuls docs, métadonnées de test et migration vide sont nouveaux | Ne pas recopier cette version sur le projet Flutter |
| `SUPERVISION-VISIOS` | Projet Angular/Node sur `main` ; changements existants dans `honoraires.html`, cache Firebase et fichiers non suivis | Ne pas mélanger ces changements avec IzyTel ; leur origine n'est pas attribuée par cette revue |

La migration de la copie isolée, `20261106003731_shared_agent_queue_and_sla.sql`, fait **0 octet**. La migration préparée dans le projet Flutter est `supabase/migrations/20261106004036_shared_agent_queue_and_sla.sql` (641 lignes). Ce ne sont pas deux migrations fonctionnelles à cumuler.

`lib/app/app.dart`, `pubspec.yaml` et `pubspec.lock` n'ont pas de différence suivie par rapport à HEAD. Les commits Finance, USSD et zones Agent sont déjà dans cette base. Cela établit leur présence, pas leur non-régression complète après les nouveaux changements.

## Validation visuelle conservée

La validation est consignée dans [DESIGN_CONTRACT.md](DESIGN_CONTRACT.md) et confirmée par l'utilisateur dans la demande de reprise. Les trois fichiers sous `aura-r1` ont les mêmes empreintes SHA-256 que ceux du prototype ouvert dans SUPERVISION-VISIOS et que les empreintes du contrat :

| Fichier | SHA-256 |
|---|---|
| `index.html` | `A6DECB12BB1732EB9FAD555B42049B4DFFC812F343362363A173DBD6567DC0EE` |
| `prototype.css` | `31C5D6AFA4F542F70317E0B91FF8B6AE7B8CDEB1609020AC988AB4128E06D288` |
| `prototype.js` | `FA220D3B1557410789FC90BE15D4493E44EA5D5A369BF615E9B4F0A7FBF32BA4` |

La fidélité de l'application exécutée à R1 n'est pas encore validée. Les tests de widgets à petite largeur ne remplacent pas cette comparaison.

## Ce qui est déjà implémenté

| Lot et exigences | Code présent | Preuves actuelles et reste à faire |
|---|---|---|
| AFF-1 — AFF-01/02/06 | Migration additive ; activation désactivée par défaut ; circuit `legacy/shared` ; projection territoriale avec bénéficiaire masqué ; claim verrouillant commande et capacité Agent ; version de cycle et retry idempotent ; garde de l'ancien RPC automatique | Diagnostic PostgreSQL local positif sur concurrence, capacité, historique, manuel et isolation partielle ; recette avec schéma et effets secondaires complets encore requise |
| AFF-2 — AFF-03/04/05 | `SharedAgentOrdersPage`, repository et ViewModel ; À prendre / Mes commandes ; chargement, conflit, erreur, indisponibilité ; retrait après claim ; détail immédiat ; refetch territorial et polling 30 s ; actualisation au retour au premier plan | Tests nouveaux : 7 réussites ; retour Android couvert par la sélection existante ; Realtime réel, reconnexion réelle et QA visuelle restent à faire |
| SLA-1 — SLA-01 à SLA-05 | `accepted_at` serveur ; version d'affectation ; détecteur SQL ; alertes persistantes, dédupliquées, résolues/obsolètes ; suivi Manager et points d'entrée mobile/Back-office | Détection, résolution et concurrence des workers testées dans la fixture ; aucun ordonnancement créé par cette migration ; activation et observation du job restent des étapes distinctes |
| NOTIF-1 — NOTIF-01 à NOTIF-03 | Enqueue `order_available` et `order_acceptance_delay` ; clés de déduplication ; responsables territoriaux ; priorité FCM du retard ; réutilisation des handlers de navigation et du pipeline existant | Le diagnostic remplace l'outbox par une table de test ; ni dispatch réel des nouveaux événements, ni réception FCM Android, ni parcours background/cold start ne sont prouvés |

Les fichiers d'intégration modifiés sont notamment `hybrid_orders_repository.dart`, `supabase_phase4_assignment_repository.dart`, `main_shell_page.dart`, `orders_page.dart`, `backoffice_orders_page.dart` et `agent_orders_view_model.dart`. Une partie importante des différences est du formatage. Le détail Agent comporte aussi un ajustement de hauteur de son indicateur de progression, à examiner pendant la QA.

## Contrôles exécutés dans cette reprise

| Contrôle | Résultat | Preuve |
|---|---|---|
| États Git des trois dépôts, branche, HEAD et comparaison des fichiers | Exécuté — réussi | Inventaire ci-dessus ; aucune fusion, remise à zéro ou copie de code effectuée |
| Empreintes du prototype | Exécuté — réussi | Trois identités exactes, tableau ci-dessus |
| `git diff --check` | Exécuté — réussi | Aucune erreur d'espacement ; avertissements Git de conversion LF/CRLF uniquement |
| `flutter analyze --no-pub` | **Exécuté — échoué** | `scratch/shared_queue_recovery_analyze.log` ; une erreur de syntaxe et un avertissement dans le test visuel |
| Sélection Flutter ci-dessous | **Exécuté — réussi, 16 tests** | `scratch/shared_queue_recovery_flutter.log` |
| `node test/shared_queue/run.mjs` | **Exécuté — échoué** après le premier contrôle | `scratch/shared_queue_recovery_sql.log` ; `permission denied for table partner_accounts`, à la ligne 61 du runner |
| Copie locale du runner, avec privilège de fixture ajouté | **Exécuté — réussi, 13 contrôles** | `scratch/shared_queue_recovery_sql_diagnostic.log` et `scratch/shared_queue_recovery/SQL_DIAGNOSTIC_RESULTS.json` |

Sélection Flutter exécutée :

```powershell
flutter test --no-pub test/features/orders/presentation/shared_order_queue_test.dart test/features/navigation/mobile_back_platform_regression_test.dart test/core/notifications/izytel_notification_payload_test.dart test/backoffice/supabase_backoffice_finance_repository_test.dart --reporter expanded
```

Les 16 tests couvrent la fraîcheur de la file après erreur, le conflit, la réponse perdue, l'ouverture sans démarrage du traitement à 320 et 390 px, les alertes Manager à 320 et 1024 px, des retours Android des trois rôles, le parsing des notifications et deux comportements de lecture Finance. Ils n'attestent pas l'ensemble des commissions, paiements, remboursements ou parcours Cabiniste.

Le diagnostic SQL utilise PostgreSQL 17.11 embarqué, des données synthétiques et plusieurs connexions distinctes sur une instance locale temporaire. Seul le montage de la fixture a reçu `GRANT SELECT ON public.partner_accounts TO anon, authenticated` ; ni la migration métier ni le runner d'origine n'ont été modifiés. Les chemins de métadonnées et de résultat ont été adaptés à `scratch` pour ne pas écraser le résultat antérieur. Ce diagnostic prouve que les 13 assertions passent dans ce montage ; il ne prouve pas la fidélité de ce montage à tous les privilèges et triggers déployés.

Le fichier préexistant `SQL_TEST_RESULTS.json` a été conservé. Il annonce 13 contrôles mais ne comporte ni date d'exécution ni empreinte de migration ; il ne constitue pas, seul, une preuve de la version courante.

## Constats SENTINEL et relais ATLAS

| ID | Nature et gravité | Preuve et conséquence | Correction attendue et contre-vérification |
|---|---|---|---|
| REC-01 | Défaut confirmé, moyen ; bloque l'analyse et la capture visuelle | `shared_order_queue_visual_test.dart:26–28` : accolade manquante après l'exception des fixtures Manrope. L'analyse signale `expected_token` à 57 et `dead_code` à 28 | Réparer uniquement le bloc `if`, relancer l'analyse puis le test avec `IZYTEL_SHARED_CAPTURE=1` et contrôler les captures |
| REC-02 | Défaut confirmé du montage de test, moyen | `run.mjs:41,44,61` : la fixture crée `partner_accounts` sans son privilège de lecture, alors que la nouvelle policy SELECT la consulte. Le runner reproductible s'arrête avant le test de concurrence | Réconcilier privilèges et RLS de la fixture avec le vrai schéma, sans donner de droit global aux tables métier ; relancer le runner d'origine et joindre résultat daté + empreinte |
| REC-03 | Lacune de couverture, priorité élevée avant activation ; aucune fuite de production démontrée | `run.mjs:45` conserve une policy permissive `own_order` autorisant tout staff, en plus de la policy territoriale de la migration. L'outbox et des helpers territoriaux sont simplifiés ; effets Finance/Cabiniste exclus | Tester une copie fidèle du schéma, policies et triggers existants. Vérifier lecture directe hors zone Agent/Manager, mutations, refus/réaffectations, réservations, finalisation financière, outbox et anciens synchroniseurs |
| REC-04 | Suivi documentaire incohérent, faible | Ancien WORKFLOW_STATE : tableau encore DRAFT/DESIGN_REVIEW, puis paragraphe IMPLEMENTATION ; ancien plan encore « en attente » | Utiliser le registre local de reprise ; conserver l'ancien dossier comme historique et la validation R1 comme acquise |
| REC-05 | Reproductibilité incomplète, moyen | Le runner importe PostgreSQL et `pg` depuis `scratch/shared-queue-tools/node_modules`, hors fichiers versionnés du lot | Documenter une installation locale isolée avec versions verrouillées ou fournir un manifeste de test versionné ; prouver le lancement depuis un environnement propre |

## Plan ORION révisé et critères de sortie

Les exigences et identifiants du plan v1 sont conservés. Le changement de cadrage est une reprise depuis le code réellement présent, avec maintien de R1 validée.

1. **AFF-1 / AFF-2 / SLA-1 — ATLAS, terminer la vérifiabilité locale.** Corriger REC-01/02/05 de manière bornée, réconcilier la fixture selon REC-03 et rejouer les tests ciblés. Ne pas réimporter la copie isolée et ne pas cumuler la migration vide.
2. **QA-1 — AURA, passer à VISUAL_QA avec une candidate vérifiable.** Comparer à R1 à 320, 390, 768 et 1440 px ; file et états, acceptation, retour à la rubrique source, suivi/alertes Manager, texte agrandi et contenu long. Résoudre les écarts bloquants avant TECHNICAL_AUDIT.
3. **NOTIF-1 / SEC-1 — SENTINEL, recette intégrée.** Rejouer concurrence et capacités sur le schéma fidèle ; droits territoriaux API et clics ; synchronisation Firestore/Supabase ; Finance, commissions, historique, crédit, échec Manager, USSD et Cabinistes. Tester les deux nouveaux événements avec pipeline outbox/dispatch complet, retries et multi-appareils.
4. **SEC-1 — Android réel et validation finale.** Téléphone réel : foreground, background, relance par notification, session changée/expirée, token renouvelé et coupure pendant acceptation. Distinguer événement créé, réponse FCM et réception observée. Suite Flutter complète et builds après résolution des défauts et stabilisation de la candidate.
5. **Activation distincte après recette.** Préparer la sauvegarde, les versions SQL/Edge/app compatibles, le job de détection, les contrôles et le retour arrière. Appliquer la migration, activer le circuit et créer le job uniquement avec l'autorisation spécifique prévue dans la mission. Conserver les cycles déjà pris et drainer explicitement la file lors d'un retour arrière.

Le code du détecteur est présent ; une récurrence opérationnelle à 30–60 secondes reste à configurer et vérifier dans l'environnement autorisé. [Supabase Cron](https://supabase.com/docs/guides/cron) décrit le stockage des jobs et de leurs exécutions. Les contrôles d'accès doivent vérifier ensemble privilèges et policies, conformément à la [documentation Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security). Le changelog Markdown a été demandé mais l'outil de navigation a refusé son type de contenu ; aucune conclusion de version n'en est tirée.

## Limites et décision de sortie

Pas de comparaison visuelle exécutée de la candidate, pas de build final, pas de suite Flutter complète, pas de test de charge, pas de réception FCM réelle, pas de migration distante ni de lecture de l'état de production pendant cette reprise. Les fichiers locaux ne permettent pas d'attester l'état distant laissé par l'autre conversation.

**Décision : rester en IMPLEMENTATION, design R1 validé.** La reprise demande des corrections des outils de contrôle et une recette, pas une nouvelle conception. Aucun DONE ni audit technique final n'est attribué.

Cette revue n'a modifié aucun code applicatif, aucun test d'origine, aucune migration métier, aucun compte ni donnée distante. Les ajouts sont ce rapport, le registre local et des journaux/une copie de diagnostic sous `scratch`.

Empreintes de la version auditée : migration `1F98C3770D8C5B4CF3369391233ED1E533BDDDB7AAD39D1B45C0D1886BDD5928`, runner SQL `6B6C65FBFECCCD1E98562F5F5ADA22919EAFB1D3CA5FE38635E0C513AA7B04EC`, test visuel `8A856B36BE698E3C4BDE2894EB83E1A56A97DC173C3B4FBB96278129F498D6DF`.
