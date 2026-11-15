# [Recette] Valider les imports et le Back-office déployé

## Objectif et état

Vérifier la fonctionnalité déployée avec les comptes de recette. Consigner les résultats pour que les collaborateurs distinguent les tests automatisés, les contrôles serveur et la recette authentifiée.

**Back-office et backend déployés. La recette authentifiée complète reste à réaliser.** Le comportement actuel, import puis publication en une confirmation, est décrit dans CAT-08 et `docs/catalog_offers/RECETTE.md`.

## Prérequis

- Code des issues Architecture, Catalogue et correctif d’affichage disponible dans la branche à livrer.
- Comptes Admin actif et non-Admin pour la recette.
- Codes réservés aux essais, par exemple `RECETTE_20261115_01` à `04`. La confirmation d’import publie les lignes UPSERT, même si le fichier indique BROUILLON ; désactiver les offres de recette ensuite.
- Les informations de vérification sont facultatives et ne bloquent plus la publication.

## Travail et critères d’acceptation

- [ ] Exécuter `docs/catalog_offers/RECETTE.md` et joindre les résultats attendus/observés.
- [ ] Vérifier aperçu/annulation, quatre créations ACTIF après Importer et publier, réimport inchangé et modification du prix avec ID conservé.
- [ ] Vérifier doublons, import partiel explicitement choisi, désactivation, rapport, historique et restauration.
- [ ] Vérifier reprise après interruption et gestion d’une modification concurrente, avec des offres de recette.
- [ ] Vérifier le refus des opérations d’import/configuration au compte non-Admin.
- [ ] Vérifier le style et le clavier sur mobile et desktop, en incluant les largeurs intermédiaires de CAT-06.
- [x] Identifier le build et la version frontend servis : Hosting `7118b910604dda10`, version précédente `7cba1e9be87fd860`, preuves dans `direct-import-results.json`.
- [x] Publier le Back-office sur `https://izytel-backoffice-4bca7.web.app` et vérifier les fichiers livrés, les origines CORS et les refus non authentifiés : 13 contrôles HTTP réussis.
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

Preuves initiales : `docs/catalog_offers/IMPLEMENTATION.md`, `implementation-results.json`, `deployment-results.json`. Preuves de la livraison actuelle : `direct-import-results.json`, `presentation-results.json` et `sql-results.json`. Les tests isolés et leurs commandes sont dans `test/catalog_import/README.md`.

La configuration locale actuelle utilise le backend IzyTel réel : une confirmation d’import écrit dans ce backend. Les tests SQL automatisés utilisent un PostgreSQL isolé. Les 13 échecs historiques de la suite globale sont décrits dans `docs/architecture/VALIDATION.md` ; ils doivent rester distingués des résultats de cette recette.

En cas d’incident de livraison, revenir au frontend précédent et conserver l’audit, les révisions et les snapshots. Pour un lot d’import, utiliser la restauration contrôlée ; résoudre les conflits avant toute nouvelle tentative. Le guide détaillé est dans `docs/catalog_offers/IMPLEMENTATION.md`.
