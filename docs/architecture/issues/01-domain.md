# [Architecture] Centraliser les modèles et contrats métier

## Objectif

Donner aux collaborateurs un emplacement commun pour les types, les interfaces
de repositories et les règles métier actuellement répartis dans les features.

## Modifications prévues

- Déplacer `features/*/domain/models` vers `app/domain/entities/<domaine>`.
- Déplacer les interfaces vers `app/domain/repositories`.
- Déplacer les permissions vers `app/domain/permissions`.
- Déplacer calculs et politiques vers `app/domain/policies/<domaine>`.
- Ranger le moteur USSD dans `policies/ussd` et le payload de notification dans
  `entities/notifications`.
- Mettre à jour tous les consommateurs sans renommer les types publics.

Exemples : `queue_order.dart` dans `entities/orders`, `app_user.dart` dans
`entities/auth`, `automatic_assignment_selector.dart` dans `policies/orders`.
Correspondances exhaustives : `docs/architecture/path-map.json`.

## Critères d’acceptation

- [ ] Les statuts persistés, les formules financières et les règles d’éligibilité sont conservés.
- [ ] Les interfaces gardent leurs signatures et leurs usages existants.
- [ ] Les tests métier sous `test/app/domain` ne présentent aucun nouvel échec.
- [ ] Le contrôle des URI locales et l’analyse statique passent.

## Dépendances et livraison

Socle pour ARCH-02 et ARCH-03. Implémentation locale préparée ; les imports des
consommateurs font partie du même changement cohérent. Aucun changement de schéma.
