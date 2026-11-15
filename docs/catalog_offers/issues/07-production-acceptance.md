# [Recette] Valider les imports et publier le Back-office compatible

## Objectif et état

Vérifier la fonctionnalité avec les comptes de recette, puis publier le frontend compatible avec le backend catalogue déjà mis en service. Consigner les résultats pour que les collaborateurs sachent ce qui a été effectivement essayé.

**À réaliser. Le frontend est compilé localement et le backend est déployé ; aucune publication d’hébergement ni recette authentifiée complète en production n’est attestée dans le bilan.**

## Prérequis

- Code des issues Architecture, Catalogue et correctif d’affichage disponible dans la branche à livrer.
- Comptes Admin actif et non-Admin pour la recette.
- Codes réservés aux essais, par exemple `RECETTE_20261115_01` à `04` ; offres en `BROUILLON`.
- Règle métier de fraîcheur à faire renseigner par l’Admin avant les futures publications ACTIF.

## Travail et critères d’acceptation

- [ ] Exécuter `docs/catalog_offers/RECETTE.md` et joindre les résultats attendus/observés.
- [ ] Vérifier aperçu/annulation, quatre créations brouillon, réimport inchangé et modification du prix avec ID conservé.
- [ ] Vérifier doublons, import partiel explicitement choisi, désactivation, rapport, historique et restauration.
- [ ] Vérifier reprise après interruption et gestion d’une modification concurrente, avec des offres de recette.
- [ ] Vérifier le refus des opérations d’import/configuration au compte non-Admin.
- [ ] Vérifier le style et le clavier sur mobile et desktop, en incluant les largeurs intermédiaires de CAT-06.
- [ ] Identifier le build et la version frontend actuellement servis pour pouvoir revenir à cette version.
- [ ] Publier le frontend compatible dans le créneau retenu, vérifier l’origine CORS du domaine effectivement utilisé et faire un contrôle de fonctionnement après publication.
- [ ] Consigner date, version livrée, preuves de recette et personne ayant validé. Désactiver les offres de recette.

## Commandes et preuves

Lancement local :

```powershell
flutter run -d chrome -t lib/main_backoffice.dart --web-hostname localhost --web-port 8080
```

Build du Back-office :

```powershell
flutter build web --no-pub -t lib/main_backoffice.dart --output build/catalog_import_backoffice
```

Preuves existantes : `docs/catalog_offers/IMPLEMENTATION.md`, `implementation-results.json`, `deployment-results.json`. Les tests isolés et leurs commandes sont dans `test/catalog_import/README.md`.

La configuration locale actuelle utilise le backend IzyTel réel : une confirmation d’import écrit dans ce backend. Les tests SQL automatisés utilisent un PostgreSQL isolé. Les 13 échecs historiques de la suite globale sont décrits dans `docs/architecture/VALIDATION.md` ; ils doivent rester distingués des résultats de cette recette.

En cas d’incident de livraison, revenir au frontend précédent et conserver l’audit, les révisions et les snapshots. Pour un lot d’import, utiliser la restauration contrôlée ; résoudre les conflits avant toute nouvelle tentative. Le guide détaillé est dans `docs/catalog_offers/IMPLEMENTATION.md`.
