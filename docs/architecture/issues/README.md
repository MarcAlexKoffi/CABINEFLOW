# Issues GitHub à créer

Ces textes sont prêts à copier dans GitHub. Aucune issue distante n’a été créée.
Pour publier les cinq issues principales de l’ensemble du chantier, utiliser le [dossier GitHub consolidé](../../GITHUB_ISSUES.md). Les lots ci-dessous permettent de répartir la revue d’architecture plus finement.
Ils décrivent la réorganisation locale du 14 novembre 2026, déjà implémentée dans
ce dossier, et les validations à contrôler pendant la revue et la fusion.

| Identifiant local | Titre | Dépendances de travail |
|---|---|---|
| [ARCH-00](00-epic.md) | Réorganiser IzyTel selon l’architecture de référence | pilote les lots suivants |
| [ARCH-01](01-domain.md) | Centraliser les modèles et contrats métier | socle |
| [ARCH-02](02-data-services.md) | Regrouper les accès aux données et services | ARCH-01 |
| [ARCH-03](03-modules.md) | Organiser les écrans et ViewModels par module | ARCH-01, ARCH-02 |
| [ARCH-04](04-core-theme-shared.md) | Centraliser le socle technique et les composants partagés | avec ARCH-03 |
| [ARCH-05](05-entrypoints.md) | Harmoniser les points d’entrée et routes | ARCH-02, ARCH-03, ARCH-04 |
| [ARCH-06](06-tests-documentation.md) | Adapter les tests et documenter les déplacements | tous les lots |
| [ARCH-07](07-cleanup.md) | Retirer le code inutilisé et les artefacts obsolètes | après réorganisation ; nettoyage déjà effectué |

Les identifiants ARCH sont des repères documentaires, pas des numéros GitHub.
Remplacer les dépendances par les liens réels après création des issues.
Labels suggérés, s’ils existent dans le dépôt : `refactor`, `documentation`, `tests`.

Publier d’abord l’epic, puis ses six sous-issues et associer l’ensemble à la PR.
Les lots servent au repérage et à la revue ; l’ensemble doit être fusionné dans
un état compilable. Pour chaque issue, joindre le diff concerné, le résultat de
validation et la référence au [guide d’architecture](../README.md).

Les évolutions fonctionnelles antérieures restent décrites dans
[README_MODIFICATIONS_IZYTEL.md](../../../README_MODIFICATIONS_IZYTEL.md).
Utiliser la [table de chemins](../path-map.json) pour retrouver leurs fichiers
actuels. Elles ne doivent pas être annoncées comme de nouvelles fonctionnalités
livrées par cette réorganisation.
