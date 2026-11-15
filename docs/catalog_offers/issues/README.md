# Issues à créer — catalogue et imports

Brouillons locaux prêts à copier sur GitHub. Aucune issue distante créée. Les identifiants CAT ci-dessous sont des repères documentaires, à remplacer par les numéros et liens réels.

Pour les changements actuels, utiliser l’issue unique **[CAT-08](08-import-publication-presentation.md)** et le [dossier de livraison GitHub](../GITHUB_DELIVERY.md). Les lots CAT-01 à CAT-05 décrivent l’intégration initiale ; CAT-06 décrit le correctif vidéo et CAT-07 la recette authentifiée restante.

| Repère | Sujet | État du travail | Dépendances |
|---|---|---|---|
| [CAT-00](00-epic.md) | Catalogue et imports conservateurs | Intégré ; backend déployé avec accord utilisateur | pilote CAT-01 à CAT-05 |
| [CAT-01](01-catalog-schema.md) | Codes, configuration et publication | Migration ciblée appliquée ; 35 offres conservées | configuration Admin et codes historiques |
| [CAT-02](02-server-import.md) | Validation et fusion serveur | Fonction v1 ACTIVE ; droits vérifiés à distance | recette authentifiée sans import automatique |
| [CAT-03](03-backoffice.md) | Catalogue et assistant Flutter Web | Intégré au style existant ; build Web réussi | frontend compatible avec le backend installé |
| [CAT-04](04-revisions.md) | Révisions, reprise et restauration | Persistance serveur, reprise et restauration testées | recette après mise en service |
| [CAT-05](05-acceptance.md) | Recette et non-régression | 36 tests Flutter, 16 SQL, 5 parseur réussis | recette authentifiée et opérationnelle restante |
| [CAT-06](06-responsive-intro.md) | Débordement des actions du catalogue | Corrigé ; 16 tests UI/repository/style réussis | contrôle visuel dans la session utilisateur |
| [CAT-07](07-production-acceptance.md) | Recette authentifiée du Back-office déployé | Hébergement publié ; recette complète restante | comptes de recette et preuves de validation |
| [CAT-08](08-import-publication-presentation.md) | Publication directe, volumes et natures commerciales | Implémenté et déployé ; revue et recette restantes | livraison GitHub actuelle |

Décision confirmée : Supabase canonique, imports réservés à l’Admin et publication directe après confirmation. Backend et Back-office sont déployés. Les bilans initiaux restent consultables ; `direct-import-results.json` et `presentation-results.json` décrivent la livraison actuelle. Les cases des tickets servent à la revue/recette et ne signifient pas que le code est absent.

Les [issues d’architecture](../../architecture/issues/README.md) décrivent un lot distinct : déplacement de code et imports, sans changement de comportement. Ne pas mélanger leurs critères avec les évolutions fonctionnelles de ce catalogue.
