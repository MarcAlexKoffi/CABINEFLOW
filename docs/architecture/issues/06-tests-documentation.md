# [Architecture] Adapter les tests et documenter les déplacements

## Objectif

Rendre la réorganisation vérifiable et donner aux collaborateurs un guide pour
retrouver les fichiers cités dans les anciens comptes rendus et les nouvelles issues.

## Modifications prévues

- Organiser les tests de couches et de présentation sous `test/app`.
- Adapter les imports, les helpers relatifs et les chemins des tests de contrat.
- Conserver les suites transversales, SQL et de file partagée.
- Ajouter `docs/architecture/path-map.json`, le guide de reprise et les descriptions d’issues.
- Ajouter `tool/check_architecture.dart` pour vérifier les URI et les destinations.
- Actualiser le README d’accueil et fournir un formulaire d’issue Architecture.
- Exclure de l’analyse les instantanés historiques conservés hors du code maintenu.
- Retirer les archives redondantes et le code sans référence confirmée, en
  marquant les destinations supprimées dans la table de chemins ; consulter
  `docs/architecture/CLEANUP.md` pour le bilan et les contrôles après nettoyage.

## Critères d’acceptation

- [ ] Chaque déplacement figure dans la table ; sa destination existe ou sa suppression est explicitement documentée.
- [ ] Aucun import applicatif actif ne pointe vers l’ancienne structure.
- [ ] Les anciens comptes rendus restent lisibles grâce à la table de chemins.
- [ ] L’analyse passe et les compilations sont consignées avec leurs limites.
- [ ] Les noms des tests en échec avant et après migration sont comparés, sans masquer les échecs préexistants.
- [ ] Les recettes sur appareils ou services réels non exécutées sont identifiées.

## Dépendances et livraison

Lot transversal à tous les autres. Implémentation locale préparée.
Les résultats figurent dans `docs/architecture/VALIDATION.md` ; ne pas présenter
la suite complète comme verte si des échecs de baseline restent ouverts.
