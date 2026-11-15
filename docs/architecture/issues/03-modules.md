# [Architecture] Organiser les écrans et ViewModels par module

## Objectif

Faire correspondre les dossiers de présentation aux responsabilités visibles du
produit et faciliter la localisation d’un écran ou de son état.

## Modifications prévues

- Déplacer les pages vers `app/modules/<module>/views`.
- Ranger les ViewModels existants dans `controllers` et les composants locaux
  dans `widgets`, avec leurs noms de classes et leur fonctionnement actuels.
- Regrouper le client dans `customer`, la finance dans `finance` et les shells
  mobiles dans `home`.
- Répartir les commandes entre `agent_orders`, `manager_orders`, `staff_orders`
  et `staff_history` ; les signalements vont dans `agent_issues`.
- Conserver les parcours Cabiniste dans `partners` et le Back-office dans
  `backoffice`, avec ses sous-dossiers fonctionnels de vues.

## Critères d’acceptation

- [ ] Les écrans, libellés, actions et permissions sont conservés.
- [ ] Retour Android, piles d’onglets et navigation Web gardent leur comportement.
- [ ] Les parcours « À prendre », commande personnelle, supervision et traitement rapide restent accessibles.
- [ ] Les tests UI sous `test/app/modules`, `test/regressions` et `test/shared_queue` sont comparés à la baseline.
- [ ] Aucun passage à GetX ni renommage des API publiques n’est ajouté à ce lot.

## Dépendances et livraison

Dépend d’ARCH-01 et ARCH-02 ; à relire avec ARCH-04 et ARCH-05.
Implémentation locale préparée. La recette visuelle et sur appareil reste à consigner.
