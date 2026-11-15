# [Architecture] Centraliser le socle technique et les composants partagés

## Objectif

Retrouver les outils transversaux et le design system dans les mêmes couches que
la nouvelle architecture, sans changement de rendu.

## Modifications prévues

- Déplacer diagnostics et traces dans `app/core/logging`.
- Ranger résilience, utilitaires et historique navigateur sous `app/core`.
- Regrouper les thèmes mobile, client et Back-office dans `app/theme`.
- Déplacer les composants génériques et le design system dans `app/shared/widgets`.
- Mettre à jour les imports des écrans et des tests associés.

## Critères d’acceptation

- [ ] Couleurs, espacements, typographies et comportements des composants sont conservés.
- [ ] Les imports conditionnels de l’historique Web se résolvent.
- [ ] Les tests de résilience et de composants partagés ne présentent aucun nouvel échec.
- [ ] Aucune dépendance ni configuration de SDK n’est modifiée.

## Dépendances et livraison

À intégrer avec ARCH-03 et ARCH-05. Implémentation locale préparée ; cette issue
ne couvre aucune refonte graphique. Vérifier le rendu pendant la recette des surfaces.
