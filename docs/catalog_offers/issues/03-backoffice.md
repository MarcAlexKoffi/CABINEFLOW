# [CAT-03] Intégrer le catalogue compact et l’assistant d’import dans Flutter Web

**Intégré dans la page Flutter existante.** La dernière consigne utilisateur retient son style actuel, pas la maquette HTML. Voir [la politique de non-régression](../STYLE_NON_REGRESSION.md), [le build et les tests](../IMPLEMENTATION.md). Les cases ci-dessous servent à la revue des changements.

Correctif de recette du 15 novembre à 14:27 : plafonner la largeur des actions d’import dans l’introduction pour éviter le grand espace vide et le débordement desktop signalés en vidéo. L’échec initial est reproduit à 884 px ; le nouveau test couvre cinq largeurs intermédiaires et vérifie que les six actions restent dans l’introduction. Les 16 tests UI/repository/style ciblés passent, sans régénérer les goldens existants.

La page Catalogue > Offres doit rendre les offres lisibles et permettre d’examiner les impacts avant toute modification en masse. La R1 HTML est un prototype de conception à valider, pas le code final de l’application.

## Travail prévu

- [ ] Contrôler la fidélité au Back-office existant et conserver les références visuelles enregistrées avant l’intégration.
- [ ] Adapter `lib/app/modules/backoffice/views/catalog/backoffice_offers_page.dart` sans changer la navigation ni introduire de migration GetX.
- [ ] Présenter deux cartes compactes par ligne large, une en mobile ; opérateur, famille, statut, recherche nom/code et tri.
- [ ] Proposer les actions unitaires et une sélection en tableau avec aperçu des changements groupés.
- [ ] Brancher choix XLSX/modèle, validation/écarts, confirmation, progression/reprise, rapport et restauration aux contrats serveur.
- [ ] Garder prix opérateur et frais de checkout distincts, informer sur lignes exclues et conflits.
- [ ] Prévoir chargement, vide, erreur, succès, partiel, pause, refus de droit, focus/clavier et retour au catalogue.

## Acceptation

La présentation suit la référence validée à 320, 390, 768 et 1440 px. Les familles proviennent de la configuration serveur. Aucun import ne démarre durant l’aperçu ; la confirmation et les droits sont explicites. Les cartes/tableaux gèrent textes longs, recherche et focus. Le catalogue client et les commandes en cours gardent leurs comportements existants.

Dépendances de mise en service : CAT-01/02/04. Captures Flutter actuelles : `docs/catalog_offers/implementation-captures`. Le prototype R1 reste une archive et n’est pas une référence de style validée.
