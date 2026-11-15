# Architecture IzyTel — guide de reprise

Réorganisation du **14 novembre 2026**, à partir de l’architecture locale de
`IzyTel-main`. Le périmètre validé est l’arborescence et les imports, avec le
comportement de `cabine_flow` conservé. Le dossier de référence reste inchangé.

## Où chercher le code

```text
lib/
├── main_staff.dart                 # personnel mobile
├── main_customer.dart              # client Web
├── main_backoffice.dart            # administration Web
└── app/
    ├── app.dart                    # composition de l’application mobile
    ├── customer_order_app.dart      # composition de l’application client
    ├── backoffice_app.dart          # composition du Back-office
    ├── config/                     # options Firebase générées
    ├── core/
    │   ├── logging/                 # diagnostics et traces de démarrage
    │   ├── platform/                # historique du navigateur client
    │   ├── resilience/              # erreurs, délais et reprise de lecture
    │   └── utils/
    ├── data/
    │   ├── repositories/            # implémentations fake/Firebase/Supabase
    │   ├── mappers/
    │   ├── models/                  # représentations propres à la persistance
    │   ├── platform/                # acquisition, géolocalisation, stockage, USSD
    │   └── sources/                 # initialisations et refetch Realtime
    ├── domain/
    │   ├── entities/                # modèles métier, regroupés par domaine
    │   ├── repositories/            # interfaces et contrats
    │   ├── permissions/
    │   └── policies/                # calculs et règles métier existants
    ├── modules/                    # écrans organisés par fonction
    │   └── <module>/
    │       ├── controllers/        # ViewModels existants, lorsque présents
    │       ├── views/              # pages existantes
    │       └── widgets/            # composants propres au module
    ├── routes/
    ├── services/                   # notifications, backfills et synchronisation
    ├── shared/widgets/             # composants et design system partagés
    └── theme/                      # thèmes mobile, client et Back-office

test/
├── app/                            # tests des couches et des modules
├── support/                        # doubles de test partagés
├── regressions/                    # contrats transversaux historiques
├── shared_queue/                   # scénarios de file partagée
├── finance_sql/
└── ussd_sql/
```

Les tests de couches sont regroupés dans `test/app/domain/<domaine>` et
`test/app/data/<domaine>`. Les scénarios UI sont dans `test/app/modules/<module>`.
Les suites transversales et SQL gardent leur organisation et leurs scénarios.

## Correspondance avec les anciennes fonctionnalités

| Ancien emplacement | Emplacement principal actuel |
|---|---|
| `features/auth` | `modules/auth`, `modules/profile`, `domain/entities/auth` |
| `features/agents` | `modules/agent_ops`, `modules/agent_issues`, `modules/profile` |
| `features/customer_order` | `modules/customer`, `domain/entities/customer` |
| `features/dashboard`, `features/navigation` | `modules/home` |
| `features/orders` | `modules/agent_orders`, `manager_orders`, `staff_orders`, `staff_history` |
| `features/finances` | `modules/finance`, `domain/entities/finance` |
| `features/managers`, `features/team` | `modules/team` |
| `features/partners` | `modules/partners` |
| `features/more` | `modules/home`, `modules/control` |
| `features/commissions`, `offers`, `payments`, `refunds`, `support`, `messaging`, `ussd` | modules du même nom |
| `backoffice/presentation` | `modules/backoffice`, `theme/backoffice_theme.dart` |
| `*/data/repositories` | `app/data/repositories` |
| `*/domain/repositories` | `app/domain/repositories` |
| `core/notifications` | `services/notifications`, `domain/entities/notifications` |
| `core/migrations` | `services/migrations` |
| `shared/widgets` | `app/shared/widgets` |

La [table exhaustive des déplacements](path-map.json) donne un chemin `from`
et un chemin `to` pour chaque fichier déplacé. Les entrées `status: removed`
identifient le code inutilisé supprimé pendant le nettoyage du 15 novembre.
Elle permet aussi de retrouver les fichiers cités dans les anciens comptes rendus.

Exemple PowerShell :

```powershell
$moves = (Get-Content docs/architecture/path-map.json -Raw | ConvertFrom-Json).moves
$moves | Where-Object { $_.from -like '*shared_order_queue*' } | Format-Table
```

## Conventions pour contribuer

- Placer une nouvelle interface de repository dans `domain/repositories` et son
  implémentation dans `data/repositories`.
- Placer un modèle métier dans `domain/entities/<domaine>` ; réserver
  `data/models` aux formats propres à une source de données.
- Placer une règle de calcul ou d’éligibilité dans `domain/policies/<domaine>`.
- Placer les pages dans `modules/<module>/views`, leurs composants dans `widgets`
  et leurs ViewModels dans `controllers`.
- Importer le code applicatif avec `package:cabine_flow/app/...`.
- Conserver les noms de classes actuels (`*Page`, `*ViewModel`, repositories).
  Un changement de dossier ne nécessite pas de renommer leur API publique.
- Consulter les [issues prêtes à reprendre](issues/README.md) avant de découper
  une contribution ou une revue.

## Adaptation de l’architecture de référence

La structure reprend les couches de `IzyTel-main`. Le code métier reste celui de
ce dépôt : file partagée, traitement rapide, supervision, finance, administration,
notifications, USSD et cartographie sont conservés.

Le package reste `cabine_flow`. GetX, les bindings, les traductions et les nouvelles
versions de dépendances du dossier de référence ne sont pas importés dans ce
chantier. Les ViewModels gardent leur fonctionnement actuel. Les trois démarrages
restent distincts pour conserver leur ordre d’initialisation : FCM sur le personnel,
persistance locale du client et initialisations parallèles du Back-office.

Certains écrans construisent encore directement leurs repositories ou utilisent
des SDK backend, comme avant la réorganisation. Le déplacement ne certifie pas
l’isolation stricte des couches du projet de référence. Un tel changement doit
faire l’objet d’un chantier fonctionnel et de tests dédiés.

Les plateformes, les assets utilisés, les migrations SQL, les fonctions serveur et
les règles de sécurité conservent leurs emplacements. `firebase.json` suit le
nouveau chemin de `config/firebase_options.dart`. Les anciens instantanés
`izytel_correctif_wc5_v2/` et `original_dashboard_widgets.dart` ont été supprimés
lors du [nettoyage du 15 novembre](CLEANUP.md). Les répertoires locaux ignorés
`scratch/`, `dist/` et `.izytel_backups/` restent exclus de l’analyse. Les outils de
test et les sauvegardes de données encore utiles y sont conservés.

## Lancement et vérifications

Le SDK et les dépendances de ce dépôt sont conservés. Environnement vérifié :
Flutter **3.44.8**, Dart **3.12.2**.

```powershell
flutter run -t lib/main_staff.dart
flutter run -d chrome -t lib/main_customer.dart
flutter run -d chrome -t lib/main_backoffice.dart
dart tool/check_architecture.dart
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
```

Ajouter les options `--dart-define` habituelles de l’environnement. Les anciennes
entrées `main.dart`, `main_customer_web.dart` et `main_backoffice_web.dart` restent
des relais vers les nouvelles : les commandes existantes continuent à fonctionner.

Le [compte rendu de validation](VALIDATION.md) distingue la baseline, les résultats
après déplacement et les vérifications non réalisées.

## Revue et retour arrière

Les issues décrivent des lots logiques de revue. Les déplacements et la mise à jour
de leurs consommateurs forment toutefois un ensemble cohérent : fusionner un lot
isolé sans adapter les imports associés rendrait la branche incomplète.

Pour lire une PR, afficher la détection des renommages et consulter la table des
chemins. Après commit, `git show --find-renames` facilite cette lecture. Avant le
premier commit, les destinations apparaissent encore comme fichiers non suivis.

Pour annuler après livraison, révoquer le commit ou la PR de réorganisation et
relancer les contrôles. Il n’y a aucune migration de données à annuler. Ne pas
utiliser de remise à zéro globale sur un espace contenant d’autres modifications.
