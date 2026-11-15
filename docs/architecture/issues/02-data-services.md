# [Architecture] Regrouper les accès aux données et services

## Objectif

Retrouver les adaptateurs Firebase/Supabase, les doubles de démonstration et les
services transversaux sans parcourir chaque fonctionnalité.

## Modifications prévues

- Déplacer les repositories concrets vers `app/data/repositories`.
- Ranger les mappers et modèles de persistance dans `data/mappers` et `data/models`.
- Ranger les initialisations et le helper Realtime dans `data/sources`.
- Ranger acquisition, géolocalisation, stockage navigateur et composeur USSD
  dans `data/platform`, en conservant les imports conditionnels Web/stub.
- Regrouper notifications, synchronisations et backfills dans `app/services`.

Fichiers repères : `supabase_shared_order_queue_repository.dart`,
`supabase_backoffice_finance_repository.dart`, `supabase_ussd_repository.dart`,
`firebase_bootstrap.dart` et `supabase_realtime_refetch.dart`.

## Critères d’acceptation

- [ ] Les noms de RPC, tables, collections et paramètres sont conservés.
- [ ] Les implémentations fake, hybrides et canoniques restent sélectionnées comme avant.
- [ ] Les règles de reprise, de session et d’idempotence sont conservées.
- [ ] Les tests HTTP et repositories sous `test/app/data` sont comparés à la baseline.
- [ ] Aucun script, test ou build ne déclenche de migration ou déploiement distant.

## Dépendances et livraison

Dépend d’ARCH-01 ; alimente ARCH-03 et ARCH-05. Implémentation locale préparée.
Les contrôles automatisés utilisent les doubles existants, sans recette de production.
